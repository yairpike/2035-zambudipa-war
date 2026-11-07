extends Control
## Veterancy chevrons for the unit panel: none, one, two, or two and a star.

var rank: int = 0
var ink: Color = Color(0.98, 0.84, 0.4)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_rank(value: int, color: Color) -> void:
	if value == rank and color == ink:
		return
	rank = value
	ink = color
	queue_redraw()

func _draw() -> void:
	var h: float = size.y
	for i: int in mini(rank, 2):
		var y: float = h - 4.0 - float(i) * 6.0
		var pts: PackedVector2Array = PackedVector2Array([Vector2(1, y - 4), Vector2(8, y), Vector2(15, y - 4)])
		draw_polyline(pts, Color(0, 0, 0, 0.7), 4.0, true)
		draw_polyline(pts, ink, 2.0, true)
	if rank >= 3:
		var c: Vector2 = Vector2(8, 4)
		var star: PackedVector2Array = PackedVector2Array()
		for k: int in 10:
			var r: float = 4.0 if k % 2 == 0 else 1.8
			var a: float = -PI * 0.5 + float(k) * PI / 5.0
			star.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(star, ink)
