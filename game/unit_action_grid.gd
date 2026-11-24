extends Control
## Settings page: one row per unit, one column per action that unit really performs.
## Each filled cell loops that action on the unit's own model.

const Actions = preload("res://game/unit_actions.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Models = preload("res://game/model_registry.gd")
const Motion = preload("res://game/unit_motion.gd")

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

func _process(_delta: float) -> void:
	if not visible:
		return
	for node: Node in find_children("PreviewUnit", "RTSUnit", true, false):
		var unit: RTSUnit = node as RTSUnit
		if unit != null:
			_pose(unit)

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
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	unit.set_meta("preview_cell", cell)
	_frame(cam, body)
	_pose(unit)

## Holds one obvious frame of the action. A missing clip is named on the cell instead of another idle.
func _pose(unit: RTSUnit) -> void:
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var action: String = str(unit.get_meta("preview_action", "idle"))
	var player: AnimationPlayer = Motion.player_of(body)
	var missing: String = ""
	var clip: String = ""
	if action == "move":
		clip = _move_clip(player)
		if clip == "" and not _roll(body):
			missing = "no move clip"
	elif action == "attack":
		clip = Motion.resolve(player, "shoot")
		if clip == "" and not _aim(body):
			missing = "no attack clip"
	elif action == "secondary":
		if _other_weapon(body):
			clip = Motion.resolve(player, "shoot")
		elif Motion.resolve(player, "secondary") != "":
			clip = Motion.resolve(player, "secondary")
		else:
			missing = "no secondary clip"
	elif action == "ability":
		clip = Motion.resolve(player, "ability")
		if clip == "" or clip == "idle":
			missing = "no ability clip"
			clip = ""
	elif action == "deploy":
		clip = Motion.resolve(player, "deploy")
		if clip == "":
			missing = "no deploy clip"
	else:
		clip = Motion.resolve(player, "idle")
	if missing == "" and clip != "":
		_hold(player, clip, 0.0 if action == "idle" else 0.42)
	if missing == "" and (action == "attack" or action == "secondary"):
		_flash(body, action == "secondary")
	if missing == "" and action == "ability":
		_ring(body)
	unit.set_meta("preview_pose", missing if missing != "" else (clip if clip != "" else action))
	_note(unit, missing)
	var cell: Control = _cell_of(unit)
	if cell != null:
		var view: Node = cell.get_node_or_null("ActionView")
		if view != null:
			view.visible = missing == ""

func _move_clip(player: AnimationPlayer) -> String:
	var run: String = Motion.resolve(player, "run")
	if run != "" and run != "walk" and run != "idle":
		return run
	var walk: String = Motion.resolve(player, "walk")
	if walk == "" or walk == "idle":
		return ""
	return walk

func _hold(player: AnimationPlayer, clip: String, fraction: float) -> void:
	if player == null or not Motion.play(player, clip, 1.0):
		return
	var anim: Animation = player.get_animation(player.current_animation)
	if anim == null:
		return
	player.seek(anim.length * clampf(fraction, 0.0, 0.95), true)
	player.pause()

func _roll(body: MeshInstance3D) -> bool:
	var wheels: Node3D = body.get_node_or_null("Wheels") as Node3D
	if wheels == null or wheels.get_child_count() == 0:
		return false
	for idx: int in wheels.get_child_count():
		var wheel: Node3D = wheels.get_child(idx) as Node3D
		if wheel != null:
			wheel.rotation.x = 1.35
	body.rotation.x = -0.55
	body.position.z = -0.45
	_dust(body)
	return true

func _aim(body: MeshInstance3D) -> bool:
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	if turret == null:
		return false
	turret.rotation.y = 1.35
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D
	if barrel != null:
		if not barrel.has_meta("preview_rest"):
			barrel.set_meta("preview_rest", barrel.position)
		var rest: Vector3 = barrel.get_meta("preview_rest")
		barrel.position = rest + Vector3(0.0, 0.0, 0.35)
	return true

func _other_weapon(body: MeshInstance3D) -> bool:
	var weapons: Array[MeshInstance3D] = Motion.weapons_of(body)
	if weapons.size() < 2:
		return false
	for i: int in weapons.size():
		weapons[i].visible = i == 1
	return true

func _flash(body: MeshInstance3D, secondary: bool) -> void:
	var flash: MeshInstance3D = body.get_node_or_null("PreviewFlash") as MeshInstance3D
	if flash == null:
		flash = MeshInstance3D.new()
		flash.name = "PreviewFlash"
		flash.mesh = BoxMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		flash.material_override = mat
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(flash)
	var span: Vector3 = _bounds(body).size
	var reach: float = maxf(maxf(span.x, span.z), 1.2)
	var bolt: BoxMesh = flash.mesh as BoxMesh
	bolt.size = Vector3(reach * 0.42, reach * 0.42, reach * 0.55)
	var mat: StandardMaterial3D = flash.material_override as StandardMaterial3D
	var ink: Color = Color(1.0, 0.22, 0.18) if secondary else Color(1.0, 0.78, 0.12)
	mat.albedo_color = ink
	mat.emission = ink
	if flash.get_parent() != body:
		flash.reparent(body)
	flash.position = Vector3(0.0, span.y * 0.62, -reach * 0.62)
	flash.rotation = Vector3.ZERO

func _dust(body: MeshInstance3D) -> void:
	if body.get_node_or_null("PreviewDust") != null:
		return
	var dust := Node3D.new()
	dust.name = "PreviewDust"
	var span: Vector3 = _bounds(body).size
	var reach: float = maxf(span.z, 1.2)
	for i: int in 3:
		var puff := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = reach * (0.16 + float(i) * 0.05)
		ball.height = ball.radius * 2.0
		puff.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.72, 0.58, 0.32, 0.8)
		puff.material_override = mat
		puff.position = Vector3(0.15 * float(i - 1), span.y * 0.25, reach * (0.35 + float(i) * 0.22))
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dust.add_child(puff)
	body.add_child(dust)

func _ring(body: MeshInstance3D) -> void:
	if body.get_node_or_null("PreviewRing") != null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "PreviewRing"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.15
	disc.height = 0.06
	ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.85, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.85, 1.0)
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.08, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ring)

func _note(unit: RTSUnit, missing: String) -> void:
	var cell: Control = _cell_of(unit)
	if cell == null:
		return
	var note: Label = cell.get_node_or_null("PoseNote") as Label
	if missing == "":
		if note != null:
			note.visible = false
		return
	if note == null:
		note = Label.new()
		note.name = "PoseNote"
		note.position = Vector2(6, 28)
		note.size = Vector2(CELL_W - 12, 48)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(note)
	note.text = missing
	note.visible = true

func _cell_of(unit: RTSUnit) -> Control:
	var kept: Variant = unit.get_meta("preview_cell") if unit.has_meta("preview_cell") else null
	return kept as Control if kept != null and is_instance_valid(kept) else null

func _frame(cam: Camera3D, body: MeshInstance3D) -> void:
	var box: AABB = _bounds(body)
	var center: Vector3 = box.get_center()
	var span: float = maxf(box.size.length(), 1.2)
	var eye: Vector3 = center + Vector3(span * 0.55, span * 0.42, span * 0.85)
	cam.look_at_from_position(eye, Vector3(center.x, center.y, center.z))

func _bounds(body: MeshInstance3D) -> AABB:
	var model: Node3D = body.get_node_or_null("Model") as Node3D
	if model != null:
		return model.transform * Models._merged_aabb(model)
	if body.mesh != null:
		return body.get_aabb()
	return AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 1.6, 1.2))

func _colors(faction: String) -> PackedColorArray:
	if faction == "nmrf":
		return PackedColorArray([Color.html("#5A6824"), Color.html("#1F9E66")])
	if faction == "mvd":
		return PackedColorArray([Color.html("#2A2E32"), Color.html("#26BFD1")])
	return PackedColorArray([Color.html("#B81E2D"), Color.html("#E0A106")])
