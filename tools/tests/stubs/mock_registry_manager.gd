## mock_registry_manager.gd — Test double for CollectionManager (issue #85).
## Mirrors CollectionManager.record_item() / record_defeat() without /root/Save
## or WorldProgression wiring, exposing a captured ledger so a headless
## SceneTree probe can assert exactly which ids reached the sink.
extends Node

var item_ledger: Array = []
var defeat_ledger: Array = []
var last_item_id: String = ""
var last_item_qty: int = 1
var last_defeat_id: String = ""

func record_item(asset_id: String, quantity: int = 1) -> void:
	if asset_id.is_empty():
		return
	last_item_id = asset_id
	last_item_qty = quantity
	item_ledger.append({"id": asset_id, "qty": quantity})

func record_defeat(entity_id: String) -> void:
	if entity_id.is_empty():
		return
	last_defeat_id = entity_id
	defeat_ledger.append(entity_id)

func record_dismantle(prop_asset_id: String, tool_tier: int = 1) -> void:
	pass

func clear() -> void:
	item_ledger.clear()
	defeat_ledger.clear()
	last_item_id = ""
	last_item_qty = 1
	last_defeat_id = ""

func get_item_ledger() -> Array:
	return item_ledger

func get_defeat_ledger() -> Array:
	return defeat_ledger

func get_last_item_id() -> String:
	return last_item_id

func get_last_item_qty() -> int:
	return last_item_qty

func get_last_defeat_id() -> String:
	return last_defeat_id
