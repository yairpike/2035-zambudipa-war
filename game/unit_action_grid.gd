extends Control
## Settings page: one row per unit, one column per action that unit really performs.
## Each filled cell loops that action on the unit's own model.

const Actions = preload("res://game/unit_actions.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Motion = preload("res://game/unit_motion.gd")
const WeaponMode = preload("res://game/weapon_mode_view.gd")

const FACTIONS: PackedStringArray = ["gtfc", "nmrf", "mvd", "black_market"]
const NAME_W: float = 168.0
const CELL_W: float = 132.0
const CELL_H: float = 108.0

var _faction: String = ""
var _rows_built: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(_on_visibility)

func _on_visibility() -> void:
	if visible:
		call_deferred("_ensure")

func _process(delta: float) -> void:
	if not visible:
		return
	for node: Node in find_children("PreviewUnit", "RTSUnit", true, false):
		var unit: RTSUnit = node as RTSUnit
		if unit != null:
			_drive(unit, delta)

func _ensure() -> void:
	if not visible:
		return
	if get_node_or_null("FactionRow") == null:
		_chrome()
	if _faction == "":
		_show_faction("gtfc")
	else:
		_fill_visible()

func _chrome() -> void:
	var row := HBoxContainer.new()
	row.name = "FactionRow"
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(0, 0)
	row.size = Vector2(640, 32)
	add_child(row)
	for id: String in FACTIONS:
		var button := Button.new()
		button.name = "Faction_%s" % id
		button.text = id.to_upper()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(72, 28)
		button.pressed.connect(_show_faction.bind(id))
		row.add_child(button)
	var header := HBoxContainer.new()
	header.name = "ActionHeader"
	header.position = Vector2(0, 36)
	header.add_theme_constant_override("separation", 4)
	add_child(header)
	var scroll := ScrollContainer.new()
	scroll.name = "UnitScroll"
	scroll.position = Vector2(0, 64)
	scroll.size = Vector2(size.x, maxf(120.0, size.y - 64.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	scroll.gui_input.connect(_on_scroll_input)
	var list := VBoxContainer.new()
	list.name = "UnitRows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var scroll: Control = get_node_or_null("UnitScroll") as Control
		if scroll != null:
			scroll.size = Vector2(size.x, maxf(120.0, size.y - 64.0))

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		call_deferred("_fill_visible")

func _show_faction(id: String) -> void:
	_ensure_chrome()
	if id == _faction and _rows_built:
		_fill_visible()
		return
	_faction = id
	_rows_built = true
	var list: Node = get_node("UnitScroll/UnitRows")
	var stale: Array[Node] = []
	for child: Node in list.get_children():
		stale.append(child)
	for child: Node in stale:
		list.remove_child(child)
		child.free()
	var columns: PackedStringArray = _columns(id)
	_header(columns)
	var data: Dictionary = SMCatalog.faction(id)
	for item: Dictionary in SMCatalog.units_of(data):
		list.add_child(_row(id, item, columns))
	call_deferred("_fill_visible")

func _ensure_chrome() -> void:
	if get_node_or_null("FactionRow") == null:
		_chrome()

func _columns(faction: String) -> PackedStringArray:
	var seen: Dictionary = {}
	for item: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction)):
		for action: String in Actions.list_for(item):
			seen[action] = true
	var out: PackedStringArray = PackedStringArray()
	for action: String in Actions.ORDER:
		if bool(seen.get(action, false)):
			out.append(action)
	return out

func _header(columns: PackedStringArray) -> void:
	var header: HBoxContainer = get_node("ActionHeader") as HBoxContainer
	var stale: Array[Node] = []
	for child: Node in header.get_children():
		stale.append(child)
	for child: Node in stale:
		header.remove_child(child)
		child.free()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(NAME_W, 22)
	header.add_child(spacer)
	for action: String in columns:
		var label := Label.new()
		label.name = "ActionHead_%s" % action
		label.text = action
		label.custom_minimum_size = Vector2(CELL_W, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.4))
		header.add_child(label)

func _row(faction: String, item: Dictionary, columns: PackedStringArray) -> HBoxContainer:
	var id: String = str(item.get("id", ""))
	var line := HBoxContainer.new()
	line.name = "UnitRow_%s" % id
	line.add_theme_constant_override("separation", 4)
	line.set_meta("unit_id", id)
	line.set_meta("faction", faction)
	line.set_meta("unit_row", item)
	var name_label := Label.new()
	name_label.name = "UnitName"
	name_label.text = str(item.get("display_name", id))
	name_label.custom_minimum_size = Vector2(NAME_W, CELL_H)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	line.add_child(name_label)
	var mine: PackedStringArray = Actions.list_for(item)
	for action: String in columns:
		if not mine.has(action):
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(CELL_W, CELL_H)
			line.add_child(gap)
			continue
		var cell := Panel.new()
		cell.name = "Cell_%s" % action
		cell.custom_minimum_size = Vector2(CELL_W, CELL_H)
		cell.set_meta("action", action)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.08, 0.09, 0.11, 1)
		plate.border_color = Color(1, 1, 1, 0.18)
		plate.set_border_width_all(1)
		cell.add_theme_stylebox_override("panel", plate)
		var caption := Label.new()
		caption.name = "ActionLabel"
		caption.text = action
		caption.position = Vector2(4, CELL_H - 20)
		caption.size = Vector2(CELL_W - 8, 16)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(caption)
		line.add_child(cell)
	return line

func _fill_visible() -> void:
	var list: Node = get_node_or_null("UnitScroll/UnitRows")
	var scroll: Control = get_node_or_null("UnitScroll") as Control
	if list == null or scroll == null:
		return
	var view: Rect2 = Rect2(scroll.global_position, scroll.size)
	view = view.grow(CELL_H)
	var index: int = 0
	for child: Node in list.get_children():
		var row: Control = child as Control
		if row == null:
			continue
		var on_screen: bool = index < 4 or view.intersects(row.get_global_rect())
		if on_screen:
			_fill_row(row)
		index += 1

func _fill_row(row: Control) -> void:
	if bool(row.get_meta("filled", false)):
		return
	row.set_meta("filled", true)
	var faction: String = str(row.get_meta("faction", ""))
	var item: Dictionary = row.get_meta("unit_row", {}) as Dictionary
	for child: Node in row.get_children():
		var cell: Panel = child as Panel
		if cell == null or not str(cell.name).begins_with("Cell_"):
			continue
		_mount_cell(cell, faction, item, str(cell.get_meta("action", "")))

func _mount_cell(cell: Panel, faction: String, item: Dictionary, action: String) -> void:
	var box := SubViewportContainer.new()
	box.name = "ActionView"
	box.position = Vector2(2, 2)
	box.size = Vector2(CELL_W - 4, CELL_H - 24)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.size = Vector2i(int(CELL_W - 4), int(CELL_H - 24))
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.disable_3d = false
	box.add_child(view)
	var world := Node3D.new()
	world.name = "PreviewWorld"
	view.add_child(world)
	var env := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.12, 0.14, 0.16)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.62, 0.64, 0.68)
	sky.ambient_light_energy = 1.0
	env.environment = sky
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.shadow_enabled = false
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(2.6, 2.1, 3.6)
	cam.current = true
	world.add_child(cam)
	cam.look_at_from_position(Vector3(2.6, 2.1, 3.6), Vector3(0, 0.9, 0))
	var unit := RTSUnit.new()
	unit.name = "PreviewUnit"
	unit.unit_type = StringName(str(item.get("id", "")))
	unit.speed = float(item.get("speed", 5.0))
	unit.hp = float(item.get("hp", 100.0))
	unit.max_hp = unit.hp
	unit.attack_range = 30.0
	unit.attack_damage = float(item.get("weapon_damage", 8.0))
	unit.set_meta("preview_action", action)
	unit.set_meta("preview_row", item)
	world.add_child(unit)
	var ink: PackedColorArray = _colors(faction)
	var body: MeshInstance3D = Forms.dress_unit(str(item.get("id", "")), str(item.get("role", "")), str(item.get("locomotion", "ground")), ink[1], ink[0], ink[1], faction)
	unit.add_child(body)
	Motion.attach(unit, body)
	SMArms.arm(unit, item)
	var foe := RTSUnit.new()
	foe.name = "PreviewFoe"
	foe.team = 1
	foe.hp = 20.0
	foe.visible = false
	foe.position = Vector3(0, 0, -1.6)
	unit.add_child(foe)

func _drive(unit: RTSUnit, delta: float) -> void:
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var action: String = str(unit.get_meta("preview_action", "idle"))
	var foe: RTSUnit = unit.get_node_or_null("PreviewFoe") as RTSUnit
	if action == "move":
		unit.attack_target = null
		if unit.path.is_empty():
			unit.set_path(PackedVector3Array([unit.global_position + Vector3(0, 0, -4)]))
	elif action == "attack" or action == "secondary":
		unit.path = PackedVector3Array()
		if SMArms.armed(unit):
			SMArms.equip(unit, SMArms.SECONDARY if action == "secondary" else SMArms.PRIMARY)
			var slot: String = SMArms.slot_of(unit)
			var tint: Color = Color.html(str(SMArms.profile(unit, slot).get("tint", "#FFD15A")))
			WeaponMode.show(unit, slot, tint)
		unit.attack_target = foe
		body.set_meta("anim_shot", 0.7)
	elif action == "ability":
		unit.stop()
		if float(body.get_meta("anim_ability", 0.0)) < 0.25:
			Motion.start_ability(unit, body, Motion.player_of(body))
	elif action == "deploy":
		unit.stop()
		body.set_meta("anim_still", Motion.BRACE_AFTER + 0.5)
	else:
		unit.stop()
		body.set_meta("anim_shot", 0.0)
		body.set_meta("anim_ability", 0.0)
		body.set_meta("anim_still", 0.0)
	Motion.pose(unit, delta)

func _colors(faction: String) -> PackedColorArray:
	if faction == "nmrf":
		return PackedColorArray([Color.html("#5A6824"), Color.html("#1F9E66")])
	if faction == "mvd":
		return PackedColorArray([Color.html("#2A2E32"), Color.html("#26BFD1")])
	return PackedColorArray([Color.html("#B81E2D"), Color.html("#E0A106")])
