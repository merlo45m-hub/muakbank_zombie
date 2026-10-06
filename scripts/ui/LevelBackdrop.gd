## LevelBackdrop.gd — hand-built vector-art graveyard backdrop for menu screens.
## Pure polygons + gradients: no textures, no 3D, crisp at every resolution.
## Built once on _ready; fog drifts and embers flicker in _process.
extends Control

const SKY_TOP := Color(0.045, 0.035, 0.09)
const SKY_MID := Color(0.13, 0.08, 0.20)
const SKY_LOW := Color(0.06, 0.045, 0.10)
const HILL := Color(0.105, 0.075, 0.155)
const MID_TOMB := Color(0.085, 0.06, 0.12)
const FRONT_TOMB := Color(0.045, 0.032, 0.07)
const MOON := Color(0.94, 0.93, 0.87)
const MOON_GLOW := Color(0.85, 0.86, 0.95)
const FOG := Color(0.75, 0.78, 0.92)
const EMBER := Color(1.0, 0.78, 0.38)

const W := 1600.0
const H := 900.0

var _t := 0.0
var _fog: Array[Dictionary] = []
var _embers: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	_sky()
	_stars()
	_moon()
	_hills()
	_graveyard(560.0, MID_TOMB, 1.0, 20261005)
	_graveyard(645.0, FRONT_TOMB, 1.22, 777)
	_fog_bands()
	_embers_init()
	_vignette()


func _add_poly(points: PackedVector2Array, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = col
	add_child(p)
	return p


func _circle(c: Vector2, r: float, steps: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _sky() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([SKY_TOP, SKY_MID, SKY_LOW])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


func _stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	for i in range(46):
		var pos := Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, H * 0.42))
		var r := rng.randf_range(0.9, 2.1)
		var a := rng.randf_range(0.22, 0.8)
		_add_poly(_circle(pos, r, 8), Color(1, 1, 1, a))


func _moon() -> void:
	# Top-right corner, clear of the card grid; keeps the centre for content.
	var c := Vector2(1390.0, 148.0)
	_add_poly(_circle(c, 142.0, 48), Color(MOON_GLOW.r, MOON_GLOW.g, MOON_GLOW.b, 0.04))
	_add_poly(_circle(c, 104.0, 48), Color(MOON_GLOW.r, MOON_GLOW.g, MOON_GLOW.b, 0.085))
	_add_poly(_circle(c, 70.0, 48), MOON)
	# soft maria for texture
	_add_poly(_circle(c + Vector2(-16, -6), 14, 20), Color(0.78, 0.77, 0.72, 0.35))
	_add_poly(_circle(c + Vector2(18, 20), 10, 20), Color(0.78, 0.77, 0.72, 0.30))
	# cloud streaks across the face so it reads painted, not pasted
	_add_poly(PackedVector2Array([
		c + Vector2(-106, -24), c + Vector2(94, -32), c + Vector2(102, -8), c + Vector2(-90, -4),
	]), Color(0.09, 0.07, 0.13, 0.26))
	_add_poly(PackedVector2Array([
		c + Vector2(-88, 24), c + Vector2(86, 18), c + Vector2(78, 42), c + Vector2(-72, 46),
	]), Color(0.09, 0.07, 0.13, 0.18))


func _hills() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 620))
	var steps := 24
	for i in range(steps + 1):
		var x := W * float(i) / float(steps)
		var y := 470.0 - sin(float(i) * 0.9) * 26.0 - sin(float(i) * 0.33 + 1.7) * 18.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(W, 620))
	_add_poly(pts, HILL)


func _graveyard(base_y: float, col: Color, scale_s: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var x := 40.0 * scale_s
	while x < W - 40.0:
		var kind := rng.randi_range(0, 4)
		var s := rng.randf_range(0.85, 1.25) * scale_s
		_tomb(x, base_y, s, kind, col)
		x += rng.randf_range(70.0, 150.0) * scale_s


func _tomb(x: float, base_y: float, s: float, kind: int, col: Color) -> void:
	match kind:
		0:  # round-top stone
			var w := 46.0 * s
			var h := 66.0 * s
			var pts := PackedVector2Array([
				Vector2(x, base_y), Vector2(x, base_y - h * 0.72),
				Vector2(x + w * 0.12, base_y - h),
				Vector2(x + w * 0.5, base_y - h - w * 0.16),
				Vector2(x + w * 0.88, base_y - h),
				Vector2(x + w, base_y - h * 0.72), Vector2(x + w, base_y),
			])
			_add_poly(pts, col)
		1:  # cross
			var bw := 16.0 * s
			var bh := 96.0 * s
			var aw := 54.0 * s
			var ah := 18.0 * s
			var ay := base_y - bh * 0.62
			_add_poly(PackedVector2Array([
				Vector2(x, base_y), Vector2(x, base_y - bh),
				Vector2(x + bw, base_y - bh), Vector2(x + bw, base_y),
			]), col)
			_add_poly(PackedVector2Array([
				Vector2(x - (aw - bw) * 0.5, ay), Vector2(x - (aw - bw) * 0.5, ay + ah),
				Vector2(x + bw + (aw - bw) * 0.5, ay + ah), Vector2(x + bw + (aw - bw) * 0.5, ay),
			]), col)
		2:  # gabled slab, slight lean
			var w2 := 52.0 * s
			var h2 := 74.0 * s
			var lean := 6.0 * s
			_add_poly(PackedVector2Array([
				Vector2(x, base_y), Vector2(x + lean, base_y - h2),
				Vector2(x + lean + w2, base_y - h2), Vector2(x + w2, base_y),
			]), col)
		3:  # dead tree
			_add_poly(PackedVector2Array([
				Vector2(x - 6 * s, base_y), Vector2(x - 2 * s, base_y - 120 * s),
				Vector2(x + 2 * s, base_y - 120 * s), Vector2(x + 6 * s, base_y),
			]), col)
			_add_poly(PackedVector2Array([
				Vector2(x - 2 * s, base_y - 84 * s), Vector2(x - 34 * s, base_y - 108 * s),
				Vector2(x - 30 * s, base_y - 114 * s), Vector2(x + 2 * s, base_y - 96 * s),
			]), col)
			_add_poly(PackedVector2Array([
				Vector2(x + 2 * s, base_y - 100 * s), Vector2(x + 36 * s, base_y - 122 * s),
				Vector2(x + 32 * s, base_y - 129 * s), Vector2(x + 2 * s, base_y - 110 * s),
			]), col)
		4:  # crypt box with gable roof
			var w3 := 84.0 * s
			var h3 := 58.0 * s
			var r3 := 26.0 * s
			_add_poly(PackedVector2Array([
				Vector2(x, base_y), Vector2(x, base_y - h3),
				Vector2(x + w3, base_y - h3), Vector2(x + w3, base_y),
			]), col)
			_add_poly(PackedVector2Array([
				Vector2(x - 6 * s, base_y - h3), Vector2(x + w3 * 0.5, base_y - h3 - r3),
				Vector2(x + w3 + 6 * s, base_y - h3),
			]), col)


func _fog_bands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var ys := [575.0, 650.0, 735.0]
	var alphas := [0.05, 0.075, 0.095]
	for bi in range(3):
		var pts := PackedVector2Array()
		var base_y: float = ys[bi]
		var h := 46.0 + float(bi) * 14.0
		var steps := 16
		pts.append(Vector2(-80.0, base_y))
		for i in range(steps + 1):
			var x := -80.0 + (W + 160.0) * float(i) / float(steps)
			pts.append(Vector2(x, base_y - h * (0.5 + 0.5 * sin(float(i) * 1.1 + float(bi) * 2.3))))
		pts.append(Vector2(W + 80.0, base_y))
		pts.append(Vector2(W + 80.0, base_y + h))
		pts.append(Vector2(-80.0, base_y + h))
		var p := _add_poly(pts, Color(FOG.r, FOG.g, FOG.b, alphas[bi]))
		_fog.append({"node": p, "x0": p.position.x, "speed": 6.0 + float(bi) * 4.0, "phase": rng.randf_range(0.0, TAU)})


func _embers_init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(14):
		var x := rng.randf_range(80.0, W - 80.0)
		var y := rng.randf_range(520.0, 820.0)
		var r := rng.randf_range(1.6, 3.4)
		var n := _add_poly(_circle(Vector2(x, y), r, 8), Color(EMBER.r, EMBER.g, EMBER.b, rng.randf_range(0.25, 0.6)))
		_embers.append({"node": n, "x0": x, "y0": y, "phase": rng.randf_range(0.0, TAU), "amp": rng.randf_range(9.0, 22.0)})


func _vignette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.72, 1.0])
	grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)


func _process(delta: float) -> void:
	_t += delta
	for f in _fog:
		var n: Polygon2D = f["node"]
		if is_instance_valid(n):
			n.position.x = sin(_t * 0.06 + f["phase"]) * 26.0
	for e in _embers:
		var n2: Polygon2D = e["node"]
		if is_instance_valid(n2):
			n2.position.x = sin(_t * 0.4 + e["phase"]) * e["amp"]
			n2.position.y = cos(_t * 0.7 + e["phase"] * 1.7) * e["amp"] * 0.5
			n2.color.a = 0.28 + 0.3 * (0.5 + 0.5 * sin(_t * 1.6 + e["phase"]))