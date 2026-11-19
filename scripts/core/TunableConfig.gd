extends Node

## TunableConfig — signed live-tunables fetcher (live-config directive 2026-11-19).
## Launch: GET mesh endpoint manifest + HMAC sig; verify, range-validate, then
## apply what the runtime exposes today (quality tier via node lookup + Rules
## flags) and persist last-good. Reject-wholesale: any failure keeps bundled
## defaults, logs, never partial-applies.
## KEY MODEL v1 (dev-tier, documented tradeoff): HMAC key constant below must
## equal /root/secrets/tunable_hmac.key on the endpoint host. Upgrade path
## (rollout issue): per-install derived key or asymmetric signing; the client
## already prefers a provisioned key file if present (user://tunable_key).
## Const timers (RUN_DURATION etc.) migrate to manifest-backed exports per
## minigame family in follow-up increments.

const ENDPOINT: String = "http://10.9.0.1:8097"
const BUNDLED_DEFAULTS: String = "res://resources/world/tunable_baseline.json"
const LAST_GOOD: String = "user://tunable_last_good.json"
const KEY_FILE: String = "user://tunable_key"
const DEV_HMAC_KEY: String = "TUNABLE_DEV_KEY_v1"

const RANGES: Dictionary = {
	"sections.spawning.base_interval_s": [0.5, 60.0],
	"sections.spawning.max_alive": [1.0, 64.0],
	"sections.spawning.grace_s": [0.0, 60.0],
	"sections.combat.damage_multiplier": [0.1, 5.0],
	"sections.economy.drop_chance": [0.0, 1.0],
	"sections.presentation.quality_tier": [0.0, 1.0],
}

var active: Dictionary = {}
var source: String = "bundled"
var pending_doc: Dictionary = {}
var pending_bytes: PackedByteArray = PackedByteArray()
var _http: HTTPRequest = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bundled()
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_manifest)
	_http.request(ENDPOINT + "/manifest.json", [], false, HTTPClient.METHOD_GET)


func _key_bytes() -> PackedByteArray:
	if FileAccess.file_exists(KEY_FILE):
		var f: FileAccess = FileAccess.open(KEY_FILE, FileAccess.READ)
		if f != null:
			return f.get_buffer(f.get_length()).strip_edges()
	return DEV_HMAC_KEY.to_utf8_buffer()


func _sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()


func _hmac_sha256(key: PackedByteArray, msg: PackedByteArray) -> PackedByteArray:
	var const_block: int = 64
	var k: PackedByteArray = key
	if k.size() > const_block:
		k = _sha256(k)
	while k.size() < const_block:
		k.append(0)
	var ipad: PackedByteArray = k.duplicate()
	var opad: PackedByteArray = k.duplicate()
	for i in range(const_block):
		ipad[i] = k[i] ^ 0x36
		opad[i] = k[i] ^ 0x5c
	return _sha256(opad + _sha256(ipad + msg))


func _get_path(doc: Dictionary, path: String) -> Variant:
	var cur: Variant = doc
	for part in path.split("."):
		if typeof(cur) != TYPE_DICTIONARY or not (cur as Dictionary).has(part):
			return null
		cur = (cur as Dictionary)[part]
	return cur


func _validate(doc: Dictionary) -> bool:
	if int(doc.get("schema_version", -1)) != 1:
		return false
	if int(doc.get("expires_at", 0)) <= int(doc.get("issued_at", 0)):
		return false
	if int(doc.get("expires_at", 0)) < int(Time.get_unix_time_from_system()):
		return false
	for pathv in RANGES.keys():
		var path: String = String(pathv)
		var v: Variant = _get_path(doc, path)
		if v == null:
			continue
		var num: float = float(v)
		var bounds: Array = RANGES[path] as Array
		if num < float(bounds[0]) or num > float(bounds[1]):
			return false
	return true


func _on_manifest(result: int, code: int, _headers: Array, body: PackedByteArray) -> void:
	if result != OK or code != 200 or body.is_empty():
		push_warning("[TunableConfig] fetch failed rc=%d code=%d; bundled defaults stand" % [result, code])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[TunableConfig] unparseable manifest; nothing applied")
		return
	var doc: Dictionary = parsed as Dictionary
	if not _validate(doc):
		push_warning("[TunableConfig] manifest rejected (schema/expiry/ranges); nothing applied")
		return
	pending_doc = doc
	pending_bytes = body
	_http.request_completed.disconnect(_on_manifest)
	_http.request_completed.connect(_on_sig)
	_http.request(ENDPOINT + "/manifest.sig", [], false, HTTPClient.METHOD_GET)


func _on_sig(result: int, code: int, _headers: Array, body: PackedByteArray) -> void:
	if result != OK or code != 200:
		push_warning("[TunableConfig] sig fetch failed; nothing applied")
		return
	var want: String = _hmac_sha256(_key_bytes(), pending_bytes).hex_encode()
	var got: String = body.get_string_from_utf8().strip_edges()
	if not got.equal_exact(want):
		push_warning("[TunableConfig] HMAC MISMATCH - manifest discarded, defaults stand")
		return
	active = pending_doc
	source = "server:" + String(pending_doc.get("manifest_id", "?"))
	var f: FileAccess = FileAccess.open(LAST_GOOD, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(pending_doc))
		f.close()
	_apply()
	print("[TunableConfig] APPLIED ", source)


func _load_bundled() -> void:
	if not FileAccess.file_exists(BUNDLED_DEFAULTS):
		return
	var f: FileAccess = FileAccess.open(BUNDLED_DEFAULTS, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var doc: Dictionary = parsed as Dictionary
		active = doc
		if _validate(doc):
			_apply()


func _apply() -> void:
	var root_node: Node = get_tree().root if get_tree() != null else null
	if root_node != null:
		var look: Node = root_node.find_child("VinylLook", true, false)
		var tier: Variant = _get_path(active, "sections.presentation.quality_tier")
		if look != null and tier != null:
			var has_tier: bool = false
			for pi in look.get_property_list():
				if String(pi.get("name", "")) == "tier":
					has_tier = true
					break
			if has_tier:
				look.set("tier", int(tier))
	var rules: Node = get_node_or_null("/root/Rules")
	if rules != null and rules.has_method("set_parameter_enabled"):
		var blood: Variant = _get_path(active, "sections.presentation.blood_fx")
		if blood != null:
			rules.call("set_parameter_enabled", "BLOOD_FX", bool(blood))
