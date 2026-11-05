extends Node
## Advisory training and one-time match toasts. Orders are never refused.

static var armed: bool = false

var step: int = 0
var coaching: bool = false
var infantry_at: int = 0
var used_f: bool = false
var toasted: Dictionary[String, bool] = {}
var super_seen: float = -1.0
var toast_until: int = 0
var toast_queue: PackedStringArray = PackedStringArray()
var pulsed: bool = false
var card: Control
var prompt: Label
var toast_panel: Control
var toast_line: Label

func _ready() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var path: String = str(host.scene_file_path)
	coaching = path.ends_with("mission_kokang.tscn") or armed
	armed = false
	set_process_unhandled_input(true)
	call_deferred("_mount")

func _mount() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	_cap_brief(host)
	infantry_at = _infantry()
	var column: Node = host.find_child("CommandColumn", true, false)
	if column == null:
		return
	var layer: Node = column.get_parent()
	if layer == null:
		return
	_build_toast(layer)
	if not coaching:
		return
	_build_card(layer)
	_hook_ability(layer)
	_show_step()

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F:
		return
	_mark_f()

func _process(_delta: float) -> void:
	_place()
	_fade_toast()
	_watch_world()
	if not coaching:
		return
	_pulse_tab()
	if step >= 6:
		_hide_card()
		return
	if _done(step):
		step += 1
		_show_step()

func _done(which: int) -> bool:
	var host: Node = get_parent()
	if host == null:
		return false
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return false
	if which == 0:
		return field.selection.count() > 0
	if which == 1:
		return _moved(field)
	if which == 2:
		return _attacking(field)
	if which == 3:
		return _has_role(host, "power")
	if which == 4:
		return _has_role(host, "barracks") and _infantry() >= infantry_at + 3
	if which == 5:
		return used_f
	return true

func _prompt(which: int) -> String:
	if which == 0:
		return "Drag a box around your units."
	if which == 1:
		return "Right-click the ground to move."
	if which == 2:
		return "Right-click an enemy to attack."
	if which == 3:
		return "Build a power plant."
	if which == 4:
		return "Build a barracks and train 3 infantry."
	if which == 5:
		return "Press F to use an ability."
	return ""

func _show_step() -> void:
	if prompt == null:
		return
	if step >= 6:
		_hide_card()
		return
	prompt.text = _prompt(step)
	if card != null:
		card.visible = true

func _hide_card() -> void:
	coaching = false
	if card != null:
		card.visible = false

func _skip() -> void:
	step = 6
	_hide_card()

func _mark_f() -> void:
	used_f = true

func _build_card(layer: Node) -> void:
	var panel: Control = Control.new()
	panel.name = "CoachCard"
	panel.z_index = 12
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(360, 32)
	layer.add_child(panel)
	card = panel
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var line: Label = Label.new()
	line.name = "CoachLine"
	line.position = Vector2(8, 6)
	line.size = Vector2(250, 22)
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	panel.add_child(line)
	prompt = line
	var skip: Button = Button.new()
	skip.name = "CoachSkip"
	skip.text = "Skip"
	skip.position = Vector2(268, 2)
	skip.size = Vector2(84, 28)
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_skip)
	panel.add_child(skip)

func _build_toast(layer: Node) -> void:
	var panel: Control = Control.new()
	panel.name = "ToastLane"
	panel.visible = false
	panel.z_index = 13
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	layer.add_child(panel)
	toast_panel = panel
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var line: Label = Label.new()
	line.name = "ToastLine"
	line.position = Vector2(8, 4)
	line.size = Vector2(300, 20)
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	panel.add_child(line)
	toast_line = line

func _place() -> void:
	var view: Viewport = get_viewport()
	if view == null:
		return
	var sz: Vector2 = view.get_visible_rect().size
	if card != null and card.visible:
		card.position = Vector2(72, 66)
		card.size = Vector2(360, 32)
	if toast_panel == null:
		return
	var sidebar: float = sz.x - 268.0
	var card_top: float = sz.y - 140.0
	var x: float = 72.0
	var y: float = 348.0
	var w: float = 320.0
	if y + 28.0 > card_top:
		x = 448.0
		y = 68.0
		w = minf(320.0, sidebar - x - 8.0)
	if x + w > sidebar:
		w = maxf(80.0, sidebar - x - 8.0)
	toast_panel.position = Vector2(x, y)
	toast_panel.size = Vector2(w, 28)
	if toast_line != null:
		toast_line.size = Vector2(maxf(40.0, w - 16.0), 20)

func _hook_ability(layer: Node) -> void:
	var button: BaseButton = layer.find_child("AbilityButton", true, false) as BaseButton
	if button != null and not button.pressed.is_connected(_mark_f):
		button.pressed.connect(_mark_f)

func _pulse_tab() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var tab: CanvasItem = host.find_child("TabBuildings", true, false) as CanvasItem
	if tab == null:
		return
	if step == 3 and coaching:
		var wave: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
		tab.modulate = Color(1.0, wave, 0.35)
		pulsed = true
		return
	if not pulsed:
		return
	pulsed = false
	var board: SMHud = host.get("hud") as SMHud
	if board != null:
		board.show_build_tab(board.build_tab)

func _watch_world() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var field: SMPointer = host.get("field") as SMPointer
	var yard: SMBuildYard = _yard(host)
	if yard != null:
		var pair: Vector2i = preload("res://addons/rts_advanced/sm_power.gd").tally(yard)
		if pair.y > 0 and pair.x < pair.y:
			_once("power", "Low power. Build a plant.")
		if super_seen < 0.0:
			super_seen = yard.super_left
		elif super_seen > 0.0 and yard.super_left <= 0.0:
			_once("super", "Superweapon ready.")
		super_seen = yard.super_left
	if field == null:
		return
	var foe: RTSUnit = _near_enemy(field)
	if foe != null:
		field.set_meta("alert_at", foe.global_position)
		_once("enemy", "Enemy spotted.")
	if _near_pad(host, field):
		_once("pad", "Resource pad in sight.")

func _once(key: String, text: String) -> void:
	if bool(toasted.get(key, false)):
		return
	toasted[key] = true
	if toast_line == null or toast_panel == null:
		return
	if _briefing_shown() or toast_until > Time.get_ticks_msec():
		toast_queue.append(text)
		return
	_show_toast(text)

func _show_toast(text: String) -> void:
	if toast_line == null or toast_panel == null:
		return
	toast_line.text = text
	toast_panel.modulate.a = 1.0
	toast_panel.visible = true
	toast_until = Time.get_ticks_msec() + 5000

func _briefing_shown() -> bool:
	var host: Node = get_parent()
	if host == null:
		return false
	var brief: CanvasItem = host.find_child("Briefing", true, false) as CanvasItem
	if brief != null:
		return brief.visible
	var piece: Node = host.get_node_or_null("SetPiece")
	if piece != null and not bool(piece.get("intro_done")):
		return true
	return false

func _fade_toast() -> void:
	if toast_panel == null:
		return
	if _briefing_shown():
		if toast_until > 0 and toast_line != null and toast_line.text != "":
			toast_queue.insert(0, toast_line.text)
			toast_until = 0
		toast_panel.visible = false
		return
	if toast_until <= 0:
		if not toast_queue.is_empty():
			var next_text: String = toast_queue[0]
			toast_queue.remove_at(0)
			_show_toast(next_text)
		return
	var left: int = toast_until - Time.get_ticks_msec()
	if left <= 0:
		toast_panel.visible = false
		toast_until = 0
		if not toast_queue.is_empty():
			var next_text: String = toast_queue[0]
			toast_queue.remove_at(0)
			_show_toast(next_text)
		return
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0 if left >= 800 else clampf(float(left) / 800.0, 0.0, 1.0)

func _cap_brief(host: Node) -> void:
	var brief: Label = host.find_child("Briefing", true, false) as Label
	if brief == null or bool(brief.get_meta("capped", false)):
		return
	brief.set_meta("capped", true)
	brief.max_lines_visible = 2
	brief.add_theme_font_size_override("font_size", 16)
	brief.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	var parent: Node = brief.get_parent()
	if parent == null:
		return
	var shade: ColorRect = ColorRect.new()
	shade.name = "BriefingShade"
	shade.color = Color(0.05, 0.06, 0.07, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = brief.position
	shade.size = brief.size
	parent.add_child(shade)
	parent.move_child(shade, brief.get_index())
	var details: Button = Button.new()
	details.name = "BriefingDetails"
	details.text = "Details"
	details.focus_mode = Control.FOCUS_NONE
	details.position = Vector2(brief.position.x + brief.size.x - 108.0, brief.position.y + 4.0)
	details.custom_minimum_size = Vector2(96, 28)
	details.add_theme_font_size_override("font_size", 16)
	details.pressed.connect(_toggle_brief.bind(brief))
	parent.add_child(details)
	var dismiss: Button = Button.new()
	dismiss.name = "BriefingDismiss"
	dismiss.text = "Got it"
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.position = Vector2(brief.position.x + brief.size.x - 212.0, brief.position.y + 4.0)
	dismiss.custom_minimum_size = Vector2(96, 28)
	dismiss.add_theme_font_size_override("font_size", 16)
	dismiss.pressed.connect(_dismiss_brief.bind(brief))
	parent.add_child(dismiss)

func _dismiss_brief(brief: Label) -> void:
	if brief == null:
		return
	brief.visible = false
	var base: Node = brief.get_parent()
	if base == null:
		return
	for node_name: String in ["MissionHeading", "BriefingShade", "BriefingShadeGlass", "BriefingDetails", "BriefingDismiss", "BriefingStill"]:
		var item: CanvasItem = base.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.visible = false

func _toggle_brief(brief: Label) -> void:
	if brief == null:
		return
	brief.max_lines_visible = 0 if brief.max_lines_visible == 2 else 2

func _moved(field: SMPointer) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if u != null and is_instance_valid(u) and u.is_alive() and not u.path.is_empty():
			return true
	return false

func _attacking(field: SMPointer) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if u == null or not is_instance_valid(u) or not u.is_alive():
			continue
		if u.attack_target != null and is_instance_valid(u.attack_target) and u.attack_target.is_alive():
			return true
	return false

func _near_enemy(field: SMPointer) -> RTSUnit:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if u == null or not is_instance_valid(u) or not u.is_alive():
			continue
		for foe: RTSUnit in field.units_of(SMPointer.ENEMY):
			if foe != null and is_instance_valid(foe) and foe.is_alive() and u.global_position.distance_to(foe.global_position) <= 12.0:
				return foe
	return null

func _near_pad(host: Node, field: SMPointer) -> bool:
	var net: SMCommodityNet = _goods(host)
	if net == null:
		return false
	for node: Dictionary in net.nodes:
		var spot: Variant = node.get("pos", null)
		if not (spot is Vector3):
			continue
		var at: Vector3 = spot as Vector3
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if u != null and is_instance_valid(u) and u.is_alive() and u.global_position.distance_to(at) <= 12.0:
				return true
	return false

func _infantry() -> int:
	var host: Node = get_parent()
	if host == null:
		return 0
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return 0
	var n: int = 0
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if u != null and is_instance_valid(u) and u.is_alive() and str(u.get_meta("role", "")) == "infantry":
			n += 1
	return n

func _has_role(host: Node, role: String) -> bool:
	var yard: SMBuildYard = _yard(host)
	if yard == null:
		return false
	for id: StringName in yard.finished:
		var named: String = str(id)
		if role == "power" and (named.contains("hydro") or named.contains("plant") or named.contains("reactor") or named.contains("generator")):
			return true
		if str(yard.building_role.get(id, "")) == role:
			return true
	return false

func _yard(host: Node) -> SMBuildYard:
	var side: SMSide = host.get("side") as SMSide
	if side == null:
		return null
	return side.yard

func _goods(host: Node) -> SMCommodityNet:
	var sim: SMMatch = host.get("sim") as SMMatch
	if sim != null and sim.goods != null:
		return sim.goods
	var story: SMStory = host.get("story") as SMStory
	if story != null:
		return story.goods
	return null
