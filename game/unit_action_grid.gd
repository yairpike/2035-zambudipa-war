extends Control
## Settings page: one row per unit, one column per action or clip that unit really has.
## Each filled cell plays that clip in a loop on the mounted model, at the cell's own resolution.

const Actions = preload("res://game/unit_actions.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Models = preload("res://game/model_registry.gd")
const Motion = preload("res://game/unit_motion.gd")

const FACTIONS: PackedStringArray = ["gtfc", "nmrf", "mvd", "black_market"]
const NAME_W: float = 168.0
## Several times the old 132×108 still, so a soldier reads as a model instead of a speck.
const CELL_W: float = 460.0
const CELL_H: float = 380.0
const COLUMN_ORDER: PackedStringArray = ["idle", "move", "attack", "ability", "deploy", "die", "flinch", "secondary"]
const SKIP_CLIPS: PackedStringArray = ["crawl", "hide"]

var _faction: String = ""
var _rows_built: bool = false
var _clip_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(_on_visibility)

func _on_visibility() -> void:
	if visible:
		call_deferred("_ensure")

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
	var scroll := ScrollContainer.new()
	scroll.name = "UnitScroll"
	scroll.position = Vector2(0, 40)
	scroll.size = Vector2(size.x, maxf(120.0, size.y - 40.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	scroll.gui_input.connect(_on_scroll_input)
	var board := VBoxContainer.new()
	board.name = "UnitBoard"
	board.add_theme_constant_override("separation", 6)
	scroll.add_child(board)
	var header := HBoxContainer.new()
	header.name = "ActionHeader"
	header.add_theme_constant_override("separation", 4)
	board.add_child(header)
	var list := VBoxContainer.new()
	list.name = "UnitRows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	board.add_child(list)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var scroll: Control = get_node_or_null("UnitScroll") as Control
		if scroll != null:
			scroll.size = Vector2(size.x, maxf(120.0, size.y - 40.0))

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
	var list: Node = get_node("UnitScroll/UnitBoard/UnitRows")
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
	var clips: Dictionary = {}
	for item: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction)):
		for action: String in Actions.list_for(item):
			seen[action] = true
		for clip: String in _clips(str(item.get("id", ""))):
			clips[clip] = true
			var column: String = _column_for(clip)
			if column != "":
				seen[column] = true
	var out: PackedStringArray = PackedStringArray()
	for action: String in COLUMN_ORDER:
		if bool(seen.get(action, false)):
			out.append(action)
	var extra: PackedStringArray = PackedStringArray()
	for clip: String in clips.keys():
		if _column_for(clip) == "" and not SKIP_CLIPS.has(clip) and not extra.has(clip):
			extra.append(clip)
	extra.sort()
	for clip: String in extra:
		out.append(clip)
	return out

## A clip the model actually contains. Rigged Tripo first, then the in-repo model. No invented names.
func _clips(id: String) -> PackedStringArray:
	if _clip_cache.has(id):
		return _clip_cache[id] as PackedStringArray
	var names := PackedStringArray()
	var scene: Node3D = Models._scene(Models.RIGGED + id)
	if scene == null:
		scene = Models._scene(id)
	if scene != null:
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			for clip_name: StringName in player.get_animation_list():
				var key: String = str(clip_name).get_slice("/", str(clip_name).get_slice_count("/") - 1).to_lower()
				if key != "" and not names.has(key):
					names.append(key)
		scene.free()
	_clip_cache[id] = names
	return names

func _column_for(clip: String) -> String:
	if clip == "idle":
		return "idle"
	if clip == "walk" or clip == "run":
		return "move"
	if clip == "shoot":
		return "attack"
	if clip == "ability" or clip == "deploy" or clip == "die" or clip == "flinch" or clip == "secondary":
		return clip
	return ""

func _header(columns: PackedStringArray) -> void:
	var header: HBoxContainer = get_node("UnitScroll/UnitBoard/ActionHeader") as HBoxContainer
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
	var mine: PackedStringArray = _mine(item)
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

func _mine(item: Dictionary) -> PackedStringArray:
	var mine: PackedStringArray = Actions.list_for(item)
	for clip: String in _clips(str(item.get("id", ""))):
		var column: String = _column_for(clip)
		if column != "" and not mine.has(column) and not SKIP_CLIPS.has(clip):
			mine.append(column)
		elif column == "" and not SKIP_CLIPS.has(clip) and not mine.has(clip):
			mine.append(clip)
	return mine

func _fill_visible() -> void:
	var list: Node = get_node_or_null("UnitScroll/UnitBoard/UnitRows")
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
	box.stretch_shrink = 1
	box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var view := SubViewport.new()
	view.name = "ActionViewport"
	view.own_world_3d = true
	view.size = Vector2i(int(CELL_W - 4), int(CELL_H - 28))
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.disable_3d = false
	view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	view.scaling_3d_scale = 1.0
	view.msaa_3d = Viewport.MSAA_4X
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	view.use_taa = false
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
	_strip_standin(body)
	Motion.attach(unit, body)
	SMArms.arm(unit, item)
	unit.set_meta("preview_cell", cell)
	_frame(cam, body)
	_pose(unit)

## Plays the clip the unit actually has. A missing clip stays a short label on top of the mounted mesh.
func _pose(unit: RTSUnit) -> void:
	if bool(unit.get_meta("preview_set", false)):
		return
	unit.set_meta("preview_set", true)
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var action: String = str(unit.get_meta("preview_action", "idle"))
	var player: AnimationPlayer = Motion.player_of(body)
	var clip: String = _clip_for(player, action)
	var missing: String = ""
	if clip == "":
		missing = "no %s clip" % action
	elif not _loop(player, clip, 0.35 if action == "idle" else 1.0):
		missing = "no %s clip" % action
		clip = ""
	unit.set_meta("preview_pose", missing if missing != "" else clip)
	_note(unit, missing)

func _clip_for(player: AnimationPlayer, action: String) -> String:
	if action == "move":
		return _move_clip(player)
	if action == "attack":
		return "shoot" if Motion.has_clip(player, "shoot") else ""
	if action == "ability":
		return "ability" if Motion.has_clip(player, "ability") else ""
	if action == "idle":
		return "idle" if Motion.has_clip(player, "idle") else ""
	return action if Motion.has_clip(player, action) else ""

func _move_clip(player: AnimationPlayer) -> String:
	if Motion.has_clip(player, "run"):
		return "run"
	if Motion.has_clip(player, "walk"):
		return "walk"
	return ""

## A private copy of the library, so looping a preview never changes the match clips.
func _loop(player: AnimationPlayer, key: String, pace: float) -> bool:
	if player == null:
		return false
	_own_clips(player)
	if not Motion.play(player, key, pace):
		return false
	player.speed_scale = pace
	return true

func _own_clips(player: AnimationPlayer) -> void:
	if bool(player.get_meta("preview_owned", false)):
		return
	player.set_meta("preview_owned", true)
	var ids: PackedStringArray = player.get_animation_library_list()
	for lib_id: String in ids:
		var library: AnimationLibrary = player.get_animation_library(StringName(lib_id))
		if library == null:
			continue
		var local: AnimationLibrary = library.duplicate(true) as AnimationLibrary
		if local == null:
			continue
		for anim_name: StringName in local.get_animation_list():
			var anim: Animation = local.get_animation(anim_name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		player.remove_animation_library(StringName(lib_id))
		player.add_animation_library(StringName(lib_id), local)

## Drops the box wheels, barrel and shadow once a Tripo or in-repo mesh is mounted.
func _strip_standin(body: MeshInstance3D) -> void:
	if str(body.get_meta("model", "")) == "":
		return
	var drop: Array[Node] = []
	_collect_procedural(body, drop)
	for node: Node in drop:
		if node == body or node.get_parent() == null:
			continue
		node.get_parent().remove_child(node)
		node.free()

func _collect_procedural(node: Node, drop: Array[Node]) -> void:
	for child: Node in node.get_children():
		if bool(child.get_meta("procedural_part", false)) or str(child.name) == "ContactShadow":
			drop.append(child)
		else:
			_collect_procedural(child, drop)

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
		note.position = Vector2(6, CELL_H - 68)
		note.size = Vector2(CELL_W - 12, 40)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 18)
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
	var eye: Vector3 = center + Vector3(span * 0.42, span * 0.32, span * 0.64)
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
