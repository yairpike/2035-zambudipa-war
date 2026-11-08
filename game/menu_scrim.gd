extends Control
## Atmospheric menu overlay: crisp dark left-rail vignette behind menu text,
## animated searchlight beams, tactical radar sweep in the lower-right corner,
## monsoon rain streaks, and rising embers on the battlefield side.

var _spin: float = 0.0
var _sparks: Array[Vector3] = []
var _rain: Array[Vector3] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i: int in 48:
		_sparks.append(Vector3(randf(), randf(), randf_range(0.14, 0.6)))
	for i: int in 36:
		_rain.append(Vector3(randf(), randf(), randf_range(0.35, 0.9)))

func _process(delta: float) -> void:
	_spin += delta * 0.45
	for i: int in _sparks.size():
		var mote: Vector3 = _sparks[i]
		mote.y -= delta * mote.z * 0.09
		mote.x += delta * 0.012
		if mote.y < 0.0:
			mote.y = 1.0
			mote.x = randf()
		_sparks[i] = mote
	for i: int in _rain.size():
		var drop: Vector3 = _rain[i]
		drop.y += delta * drop.z * 0.55
		drop.x -= delta * drop.z * 0.14
		if drop.y > 1.0 or drop.x < 0.0:
			drop.y = -0.05
			drop.x = randf_range(0.35, 1.08)
		_rain[i] = drop
	queue_redraw()

func _draw() -> void:
	if size.x < 64.0 or size.y < 64.0:
		return
	var rail_w: float = size.x * (0.8 if size.y > size.x else 0.4)
	# Crisp dark left-rail vignette gradient so menu text is effortless to read
	var bands: int = 16
	for b: int in bands:
		var t0: float = float(b) / float(bands)
		var x0: float = rail_w * 0.75 + t0 * (size.x * 0.22)
		var bw: float = (size.x * 0.22) / float(bands) + 2.0
		var alpha: float = (1.0 - t0) * (1.0 - t0) * 0.58
		draw_rect(Rect2(x0, 0.0, bw, size.y), Color(0.015, 0.02, 0.03, alpha))
	# Subtle top and bottom vignette bands
	draw_rect(Rect2(0.0, 0.0, size.x, 42.0), Color(0.01, 0.014, 0.022, 0.42))
	draw_rect(Rect2(0.0, size.y - 48.0, size.x, 48.0), Color(0.01, 0.014, 0.022, 0.55))

	# Sweeping anti-air searchlight beams on the right battlefield side
	for s_idx: int in 2:
		var base_x: float = size.x * (0.58 + float(s_idx) * 0.22)
		var base_y: float = size.y * 0.96
		var sway: float = sin(_spin * (0.55 + float(s_idx) * 0.23) + float(s_idx) * 1.9) * 0.28
		var dir := Vector2(sin(sway - 0.18), -cos(sway - 0.18)).normalized()
		var ortho := Vector2(-dir.y, dir.x)
		var beam_len: float = size.y * 0.92
		var p0 := Vector2(base_x, base_y)
		var p1: Vector2 = p0 + dir * beam_len + ortho * 52.0
		var p2: Vector2 = p0 + dir * beam_len - ortho * 52.0
		var beam_col := Color(0.95, 0.78, 0.42, 0.038) if s_idx == 0 else Color(0.45, 0.78, 0.92, 0.032)
		draw_colored_polygon(PackedVector2Array([p0, p1, p2]), beam_col)

	# Monsoon rain streaks over the right scene
	for drop: Vector3 in _rain:
		if drop.x < 0.41:
			continue
		var p_start := Vector2(drop.x * size.x, drop.y * size.y)
		var p_end: Vector2 = p_start + Vector2(-9.0 * drop.z, 26.0 * drop.z)
		draw_line(p_start, p_end, Color(0.75, 0.85, 0.95, 0.075 * drop.z), 1.0)

	# Glowing battlefield embers
	for mote: Vector3 in _sparks:
		if mote.x < 0.41:
			continue
		var at := Vector2(mote.x * size.x, mote.y * size.y)
		var ink := Color(1.0, 0.72, 0.36, 0.32 + mote.z * 0.28)
		draw_rect(Rect2(at, Vector2(1.6 + mote.z * 2.2, 1.6 + mote.z * 2.2)), ink)

	# Animated tactical radar sweep in the bottom-right corner
	if size.x >= 900.0:
		var center := Vector2(size.x - 104.0, size.y - 108.0)
		var radius: float = 54.0
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.38, 0.78, 0.72, 0.18), 1.2)
		draw_arc(center, radius * 0.62, 0.0, TAU, 32, Color(0.38, 0.78, 0.72, 0.12), 1.0)
		draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), Color(0.38, 0.78, 0.72, 0.12), 1.0)
		draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), Color(0.38, 0.78, 0.72, 0.12), 1.0)
		var angle: float = fmod(_spin * 1.8, TAU)
		var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, tip, Color(0.45, 0.95, 0.82, 0.38), 1.6)
		var trail_a: float = angle - 0.42
		var p_arc1: Vector2 = center + Vector2(cos(trail_a), sin(trail_a)) * radius
		draw_colored_polygon(PackedVector2Array([center, p_arc1, tip]), Color(0.38, 0.88, 0.76, 0.09))
