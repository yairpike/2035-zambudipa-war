extends Button
## Plain menu row. Hover and selection turn the label white. The rest stay dim.

const Sfx = preload("res://game/menu_sfx.gd")

func _ready() -> void:
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		pass
	else:
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not has_theme_font_size_override("font_size"):
		add_theme_font_size_override("font_size", 22)
	_colors(false)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 2
	empty.content_margin_right = 8
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	focus_mode = Control.FOCUS_ALL
	if not pressed.is_connected(_clicked):
		pressed.connect(_clicked)
	if not mouse_entered.is_connected(_hovered):
		mouse_entered.connect(_hovered)
	if not mouse_exited.is_connected(queue_redraw):
		mouse_exited.connect(queue_redraw)
	if not focus_entered.is_connected(queue_redraw):
		focus_entered.connect(queue_redraw)
	if not focus_exited.is_connected(queue_redraw):
		focus_exited.connect(queue_redraw)

func _clicked() -> void:
	Sfx.play(self, "ui_click")

func _hovered() -> void:
	Sfx.play(self, "ui_hover")
	queue_redraw()

func _process(_delta: float) -> void:
	if not bool(get_meta("nav", false)):
		return
	var base: Vector2 = get_meta("base_pos", position)
	var hot: bool = (not disabled) and (is_hovered() or has_focus() or bool(get_meta("lit", false)))
	var want: Vector2 = base + Vector2(8.0 if hot else 0.0, 0.0)
	if position.distance_to(want) > 0.4:
		position = want

func _draw() -> void:
	var hot: bool = (not disabled) and (is_hovered() or has_focus() or bool(get_meta("lit", false)))
	_colors(hot)
	if bool(get_meta("nav", false)) and hot:
		draw_rect(Rect2(-8.0, 8.0, 4.0, maxf(8.0, size.y - 16.0)), Color(0.93, 0.78, 0.38, 1.0))
	elif bool(get_meta("bar", false)) and hot:
		draw_rect(Rect2(0.0, 1.0, size.x, maxf(8.0, size.y - 2.0)), Color(1, 1, 1, 0.14))
	for child: Node in get_children():
		var label: Label = child as Label
		if label == null or label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			continue
		label.add_theme_color_override("font_color", _ink(hot, disabled))

func _colors(hot: bool) -> void:
	var ink: Color = _ink(hot, disabled)
	add_theme_color_override("font_color", ink)
	add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.28))

func _ink(hot: bool, off: bool) -> Color:
	if off:
		return Color(1, 1, 1, 0.45)
	if hot:
		return Color(1, 1, 1, 1)
	return Color(1, 1, 1, 0.94)
