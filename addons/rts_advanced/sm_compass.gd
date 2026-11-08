class_name SMCompass
extends HBoxContainer
## Camera compass beside the minimap: rotate left, a north needle that resets the view, rotate right.
## Gives trackpad and touch players the 360-degree orbit without a middle mouse button.

var camera: RTSCamera

func setup(p_camera: RTSCamera) -> void:
	camera = p_camera
	name = "CameraCompass"
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_button("CompassLeft", "⟲", "Rotate the camera left (Q)", _turn.bind(-SMCamRig.TURN_STEP))
	var dial: SMCompassDial = SMCompassDial.new()
	dial.name = "CompassNorth"
	dial.camera = camera
	dial.custom_minimum_size = Vector2(40, 40)
	dial.tooltip_text = "Reset to north (Home)"
	dial.pressed.connect(_north)
	add_child(dial)
	_button("CompassRight", "⟳", "Rotate the camera right (E)", _turn.bind(SMCamRig.TURN_STEP))

func _button(node_name: String, glyph: String, tip: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = glyph
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 40)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", ThemeDB.fallback_font)
	b.pressed.connect(fn)
	add_child(b)

func _turn(degrees: float) -> void:
	var rig: SMCamRig = SMCamRig.of(camera)
	if rig != null:
		rig.turn(degrees)

func _north() -> void:
	var rig: SMCamRig = SMCamRig.of(camera)
	if rig != null:
		rig.north()

func _process(_delta: float) -> void:
	var dial: Control = get_node_or_null("CompassNorth") as Control
	if dial != null:
		dial.queue_redraw()
