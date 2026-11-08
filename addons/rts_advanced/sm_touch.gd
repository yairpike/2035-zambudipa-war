extends Node
## Web touch: one finger pans the match camera, two fingers pinch to zoom and twist to orbit.
## Match keys: Q/E or [/] orbit the camera, Home faces north, arrows pan at any yaw. WASD pans when nothing is
## selected; with units selected W selects the same type, A arms attack-move, S stops, D arms reverse move.
## Alt + left drag or the middle mouse orbits and tilts. While placing a building R turns it and Esc cancels.

const HOLD_DELAY: float = 0.3

var points: Dictionary[int, Vector2] = {}
var span: float = 0.0
var moved: bool = false
var travel: float = 0.0
var last_group: int = -1
var last_group_ms: int = 0
var twist: float = 0.0
var turn_held: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _orbit_mouse(event):
		return
	if _toggle_help(event):
		return
	if _toggle_protocols(event):
		return
	if _command_key(event):
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			points[touch.index] = touch.position
			if points.size() == 1:
				moved = false
				travel = 0.0
		else:
			points.erase(touch.index)
		span = _span()
		twist = _twist()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	points[drag.index] = drag.position
	travel += drag.relative.length()
	if travel > 12.0:
		moved = true
	var camera: RTSCamera = _camera()
	if camera == null:
		return
	if points.size() >= 2:
		var next: float = _span()
		if span > 1.0 and next > 1.0:
			pinch_camera(camera, span, next)
		span = next
		var angle: float = _twist()
		if absf(twist) > 0.0 and absf(angle - twist) < PI:
			twist_camera(camera, twist, angle)
		twist = angle
	else:
		pan_camera(camera, drag.relative)

func _toggle_help(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_H:
		return false
	var overlay: Control = get_tree().root.find_child("HowToOverlay", true, false) as Control
	if overlay == null:
		return false
	overlay.visible = not overlay.visible
	get_viewport().set_input_as_handled()
	return true

func _toggle_protocols(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_P:
		return false
	var toggle: BaseButton = get_tree().root.find_child("ProtocolsToggle", true, false) as BaseButton
	if toggle == null:
		return false
	toggle.pressed.emit()
	get_viewport().set_input_as_handled()
	return true

func _command_key(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	var match_field: SMPointer = _field()
	if match_field == null:
		return false
	if key.keycode == KEY_TAB or key.keycode == KEY_SPACE:
		if _line_focused() or _pause_open():
			return false
		if key.keycode == KEY_TAB and _cycle_tab():
			get_viewport().set_input_as_handled()
			return true
		if key.keycode == KEY_SPACE and _jump_alert(match_field):
			get_viewport().set_input_as_handled()
			return true
		return false
	if _line_focused() or _pause_open():
		return false
	var placing: SMPlacement = _placement()
	if placing != null and placing.active:
		if key.keycode == KEY_R:
			placing.rotate(-1 if key.shift_pressed else 1)
			get_viewport().set_input_as_handled()
			return true
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			placing.confirm()
			get_viewport().set_input_as_handled()
			return true
	var rig: SMCamRig = SMCamRig.of(_camera())
	var turn: float = turn_dir(key.keycode)
	if turn != 0.0 and rig != null:
		rig.turn(turn * SMCamRig.TURN_STEP)
		turn_held = 0.0
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_HOME and rig != null:
		rig.north()
		get_viewport().set_input_as_handled()
		return true
	var units_picked: bool = match_field.selection.count() > 0
	if key.keycode == KEY_X or (units_picked and key.keycode == KEY_S):
		match_field.halt_selected()
		get_viewport().set_input_as_handled()
		return true
	if units_picked and key.keycode == KEY_A:
		match_field.attack_armed = true
		match_field.reverse_armed = false
		match_field.group_note = "Attack-move: right-click a spot"
		match_field.group_note_t = 2.0
		get_viewport().set_input_as_handled()
		return true
	if units_picked and key.keycode == KEY_D:
		if not match_field.selection_can_reverse():
			match_field.group_note = "Only vehicles and boats reverse"
			match_field.group_note_t = 1.4
		else:
			match_field.reverse_armed = true
			match_field.attack_armed = false
			match_field.group_note = "Reverse: right-click where to back up"
			match_field.group_note_t = 2.0
		get_viewport().set_input_as_handled()
		return true
	if units_picked and key.keycode == KEY_W:
		match_field.select_same()
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_Z:
		match_field.toggle_line()
		get_viewport().set_input_as_handled()
		return true
	if key.keycode == KEY_R:
		var board: SMHud = _hud()
		if board == null:
			return false
		var rally_cam: RTSCamera = _camera()
		board.set_rally(match_field.aim_from_camera(rally_cam, get_viewport().get_mouse_position()))
		get_viewport().set_input_as_handled()
		return true
	var index: int = _digit(key.keycode)
	if index < 1:
		return false
	if key.ctrl_pressed or key.meta_pressed:
		match_field.bind_group(index, true)
	else:
		match_field.bind_group(index, false)
		var now: int = Time.get_ticks_msec()
		if last_group == index and now - last_group_ms < 420:
			var focus: Vector3 = match_field.selection_focus()
			var jump_cam: RTSCamera = _camera()
			if jump_cam != null and focus != Vector3.INF:
				jump_cam.focus_on(focus)
		last_group = index
		last_group_ms = now
	get_viewport().set_input_as_handled()
	return true

func _digit(code: Key) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return int(code) - int(KEY_1) + 1
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return int(code) - int(KEY_KP_1) + 1
	return 0

func _line_focused() -> bool:
	var view: Viewport = get_viewport()
	if view == null:
		return false
	var owner: Control = view.gui_get_focus_owner()
	return owner is LineEdit or owner is TextEdit

func _pause_open() -> bool:
	var pause: CanvasItem = get_tree().root.find_child("PauseMenu", true, false) as CanvasItem
	return pause != null and pause.visible

func _cycle_tab() -> bool:
	var board: SMHud = _hud()
	if board == null:
		return false
	var order: PackedStringArray = _tab_order()
	var start: int = order.find(board.build_tab)
	if start < 0:
		start = 0
	var n: int = 0
	while n < order.size():
		var which: String = order[(start + 1 + n) % order.size()]
		var button: BaseButton = get_tree().root.find_child("Tab%s" % which.capitalize(), true, false) as BaseButton
		if button != null and button.visible:
			board.show_build_tab(which)
			return true
		n += 1
	return false

func _tab_order() -> PackedStringArray:
	var order: PackedStringArray = PackedStringArray()
	order.append("buildings")
	order.append("defenses")
	order.append("infantry")
	order.append("vehicles")
	return order

func _jump_alert(match_field: SMPointer) -> bool:
	if match_field == null or not match_field.has_meta("alert_at"):
		return false
	var at: Variant = match_field.get_meta("alert_at")
	if not (at is Vector3):
		return false
	var point: Vector3 = at as Vector3
	if point == Vector3.INF:
		return false
	var cam: RTSCamera = _camera()
	if cam == null:
		return false
	cam.focus_on(point)
	return true

func _hud() -> SMHud:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var raw: Variant = scene.get("hud")
	if raw is SMHud:
		return raw as SMHud
	return null

func _field() -> SMPointer:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var raw: Variant = scene.get("field")
	if raw is SMPointer:
		return raw as SMPointer
	return null

func _process(delta: float) -> void:
	if points.is_empty():
		moved = false
		travel = 0.0
	var camera: RTSCamera = _camera()
	if camera == null:
		return
	var rig: SMCamRig = SMCamRig.of(camera)
	var match_field: SMPointer = _field()
	if match_field != null and not _line_focused() and not _pause_open() and DisplayServer.window_is_focused():
		var spin: float = 0.0
		for code: Key in [KEY_Q, KEY_E, KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
			if Input.is_physical_key_pressed(code):
				spin += turn_dir(code)
		turn_held = turn_held + delta if spin != 0.0 else 0.0
		if turn_held > HOLD_DELAY:
			rig.hold(signf(spin), delta)
		rig.pan_keys(key_pan(match_field.selection.count() > 0), delta)
	rig.step(delta)

## -1 turns the camera left, +1 right, 0 for any other key.
static func turn_dir(code: Key) -> float:
	if code == KEY_Q or code == KEY_BRACKETLEFT:
		return -1.0
	if code == KEY_E or code == KEY_BRACKETRIGHT:
		return 1.0
	return 0.0

## Held pan keys in camera terms: x right, y forward. WASD only pans while nothing is selected.
static func key_pan(units_picked: bool) -> Vector2:
	var dir: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or (not units_picked and Input.is_physical_key_pressed(KEY_A)):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or (not units_picked and Input.is_physical_key_pressed(KEY_D)):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or (not units_picked and Input.is_physical_key_pressed(KEY_W)):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or (not units_picked and Input.is_physical_key_pressed(KEY_S)):
		dir.y -= 1.0
	return dir

## Alt + left drag orbits and tilts; the middle button tilts (match scenes already yaw on it).
func _orbit_mouse(event: InputEvent) -> bool:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return false
	var camera: RTSCamera = _camera()
	if camera == null or _field() == null:
		return false
	var rig: SMCamRig = SMCamRig.of(camera)
	if motion.alt_pressed and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		rig.drag(motion.relative)
		get_viewport().set_input_as_handled()
		return true
	if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		rig.tilt_by(-motion.relative.y * 0.15)
		return true
	return false

func twist_camera(camera: RTSCamera, previous: float, current: float) -> void:
	var rig: SMCamRig = SMCamRig.of(camera)
	if rig == null:
		return
	rig.turn(rad_to_deg(wrapf(current - previous, -PI, PI)))

func _twist() -> float:
	if points.size() < 2:
		return 0.0
	var keys: Array[int] = []
	for key: int in points.keys():
		keys.append(key)
		if keys.size() == 2:
			break
	var d: Vector2 = points[keys[1]] - points[keys[0]]
	return d.angle() if d.length() > 1.0 else 0.0

func _placement() -> SMPlacement:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var raw: Variant = scene.get("side")
	if raw is SMSide:
		return (raw as SMSide).placement
	return null

func pan_camera(camera: RTSCamera, slide: Vector2) -> void:
	if camera == null:
		return
	camera.pan(Vector2(slide.x, -slide.y) * 0.02, 1.0)

func pinch_camera(camera: RTSCamera, previous: float, current: float) -> void:
	if camera == null or previous <= 1.0 or current <= 1.0:
		return
	var steps: float = (current - previous) / 30.0
	camera.zoom(steps)

func _camera() -> RTSCamera:
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d() as RTSCamera

func _span() -> float:
	if points.size() < 2:
		return 0.0
	var keys: Array[int] = []
	for key: int in points.keys():
		keys.append(key)
		if keys.size() == 2:
			break
	return points[keys[0]].distance_to(points[keys[1]])
