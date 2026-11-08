class_name SMCompassDial
extends BaseButton
## Round dial whose red needle points at map north for the current camera yaw. Clicking it resets north.

var camera: RTSCamera

func _init() -> void:
	focus_mode = Control.FOCUS_NONE

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - 1.0
	draw_circle(c, r, Color(0.05, 0.06, 0.07, 0.88))
	draw_arc(c, r, 0.0, TAU, 28, Color(0.95, 0.82, 0.35, 0.9), 1.5, true)
	var yaw: float = deg_to_rad(camera.yaw_degrees) if camera != null else 0.0
	var north: Vector2 = Vector2(sin(yaw), -cos(yaw))
	var side: Vector2 = Vector2(-north.y, north.x)
	var tip: Vector2 = c + north * (r - 2.0)
	var tail: Vector2 = c - north * (r - 4.0)
	draw_colored_polygon(PackedVector2Array([tip, c + side * 3.5, c - side * 3.5]), Color(0.92, 0.22, 0.2))
	draw_colored_polygon(PackedVector2Array([tail, c + side * 3.0, c - side * 3.0]), Color(0.85, 0.85, 0.85))
	draw_string(ThemeDB.fallback_font, tip + north * 1.0 - Vector2(3.5, -3.5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
