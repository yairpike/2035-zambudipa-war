extends Control
## Settings page: one unit fills the scroll view. Its actions wrap across that width.
## Each filled cell loops the real clip. Drag a cell to orbit the model.

const Actions = preload("res://game/unit_actions.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Models = preload("res://game/model_registry.gd")
const Motion = preload("res://game/unit_motion.gd")

const FACTIONS: PackedStringArray = ["gtfc", "nmrf", "mvd", "black_market"]
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
		_layout_rows()
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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	scroll.gui_input.connect(_on_scroll_input)
	var board := Control.new()
	board.name = "UnitBoard"
	scroll.add_child(board)
	var list := Control.new()
	list.name = "UnitRows"
	board.add_child(list)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var scroll: Control = get_node_or_null("UnitScroll") as Control
		if scroll != null:
			scroll.size = Vector2(size.x, maxf(120.0, size.y - 40.0))
			_layout_rows()

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		call_deferred("_fill_visible")

func _show_faction(id: String) -> void:
	_ensure_chrome()
	if id == _faction and _rows_built:
		_layout_rows()
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
	var data: Dictionary = SMCatalog.faction(id)
	for item: Dictionary in SMCatalog.units_of(data):
		list.add_child(_row(id, item))
	_layout_rows()
	call_deferred("_fill_visible")

func _ensure_chrome() -> void:
	if get_node_or_null("FactionRow") == null:
		_chrome()

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

func _row(faction: String, item: Dictionary) -> Panel:
	var id: String = str(item.get("id", ""))
	var line := Panel.new()
	line.name = "UnitRow_%s" % id
	line.set_meta("unit_id", id)
	line.set_meta("faction", faction)
	line.set_meta("unit_row", item)
	line.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.name = "UnitName"
	name_label.text = str(item.get("display_name", id))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)
	for action: String in _ordered(item):
		var cell := Panel.new()
		cell.name = "Cell_%s" % action
		cell.set_meta("action", action)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.08, 0.09, 0.11, 1)
		plate.border_color = Color(1, 1, 1, 0.18)
		plate.set_border_width_all(1)
		cell.add_theme_stylebox_override("panel", plate)
		var caption := Label.new()
		caption.name = "ActionLabel"
		caption.text = action
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(caption)
		cell.gui_input.connect(_on_cell_input.bind(cell))
		line.add_child(cell)
	return line

func _ordered(item: Dictionary) -> PackedStringArray:
	var mine: PackedStringArray = _mine(item)
	var out := PackedStringArray()
	for action: String in COLUMN_ORDER:
		if mine.has(action):
			out.append(action)
	var extra := PackedStringArray()
	for action: String in mine:
		if not out.has(action) and not extra.has(action):
			extra.append(action)
	extra.sort()
	for action: String in extra:
		out.append(action)
	return out

func _mine(item: Dictionary) -> PackedStringArray:
	var mine: PackedStringArray = Actions.list_for(item)
	for clip: String in _clips(str(item.get("id", ""))):
		var column: String = _column_for(clip)
		if column != "" and not mine.has(column) and not SKIP_CLIPS.has(clip):
			mine.append(column)
		elif column == "" and not SKIP_CLIPS.has(clip) and not mine.has(clip):
			mine.append(clip)
	return mine

func _layout_rows() -> void:
	var scroll: ScrollContainer = get_node_or_null("UnitScroll") as ScrollContainer
	var board: Control = get_node_or_null("UnitScroll/UnitBoard") as Control
	var list: Control = get_node_or_null("UnitScroll/UnitBoard/UnitRows") as Control
	if scroll == null or board == null or list == null:
		return
	if scroll.size.x < 40.0 or scroll.size.y < 40.0:
		return
	var gutter: float = 14.0
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar != null and bar.get_minimum_size().x > 1.0:
		gutter = bar.get_minimum_size().x
	var inner: float = maxf(80.0, scroll.size.x - gutter)
	var page_h: float = scroll.size.y
	var rows: Array[Control] = []
	for child: Node in list.get_children():
		var row: Control = child as Control
		if row != null and str(row.name).begins_with("UnitRow_"):
			rows.append(row)
	if rows.is_empty():
		return
	var content_h: float = page_h * float(rows.size())
	board.custom_minimum_size = Vector2(inner, content_h)
	board.size = Vector2(inner, content_h)
	list.position = Vector2.ZERO
	list.custom_minimum_size = Vector2(inner, content_h)
	list.size = Vector2(inner, content_h)
	for i: int in rows.size():
		var row: Control = rows[i]
		row.position = Vector2(0, page_h * float(i))
		row.size = Vector2(inner, page_h)
		row.custom_minimum_size = Vector2(inner, page_h)
		_place_cells(row, inner, page_h)

func _place_cells(row: Control, width: float, height: float) -> void:
	var name_label: Label = row.get_node_or_null("UnitName") as Label
	if name_label != null:
		name_label.position = Vector2(8, 2)
		name_label.size = Vector2(maxf(40.0, width - 16.0), 24)
	var cells: Array[Control] = []
	for child: Node in row.get_children():
		if str(child.name).begins_with("Cell_"):
			var cell: Control = child as Control
			if cell != null:
				cells.append(cell)
	if cells.is_empty():
		return
	var top: float = 28.0
	var gap: float = 4.0
	var area_w: float = maxf(40.0, width - 8.0)
	var area_h: float = maxf(40.0, height - top - 4.0)
	var cols: int = _best_cols(cells.size(), area_w, area_h)
	var lines: int = int(ceili(float(cells.size()) / float(cols)))
	var cw: float = (area_w - gap * float(cols - 1)) / float(cols)
	var ch: float = (area_h - gap * float(lines - 1)) / float(lines)
	for i: int in cells.size():
		var cell: Control = cells[i]
		var col: int = i % cols
		var line_i: int = int(float(i) / float(cols))
		cell.position = Vector2(4.0 + float(col) * (cw + gap), top + float(line_i) * (ch + gap))
		cell.size = Vector2(cw, ch)
		cell.custom_minimum_size = Vector2(cw, ch)
		var caption: Label = cell.get_node_or_null("ActionLabel") as Label
		if caption != null:
			caption.position = Vector2(4, ch - 20.0)
			caption.size = Vector2(maxf(8.0, cw - 8.0), 16)
		var box: Control = cell.get_node_or_null("ActionView") as Control
		if box != null:
			box.position = Vector2(2, 2)
			box.size = Vector2(maxf(8.0, cw - 4.0), maxf(8.0, ch - 24.0))
		var note: Label = cell.get_node_or_null("PoseNote") as Label
		if note != null:
			note.position = Vector2(6, maxf(4.0, ch - 64.0))
			note.size = Vector2(maxf(8.0, cw - 12.0), 36)

func _best_cols(count: int, width: float, height: float) -> int:
	var best: int = 1
	var best_min: float = -1.0
	var gap: float = 4.0
	for cols: int in range(1, count + 1):
		var lines: int = int(ceili(float(count) / float(cols)))
		var cw: float = (width - gap * float(cols - 1)) / float(cols)
		var ch: float = (height - gap * float(lines - 1)) / float(lines)
		var score: float = minf(cw, ch)
		if score > best_min:
			best_min = score
			best = cols
	return best

func _fill_visible() -> void:
	_layout_rows()
	var list: Node = get_node_or_null("UnitScroll/UnitBoard/UnitRows")
	var scroll: Control = get_node_or_null("UnitScroll") as Control
	if list == null or scroll == null:
		return
	var view := Rect2(scroll.global_position, scroll.size).grow(4.0)
	var index: int = 0
	for child: Node in list.get_children():
		var row: Control = child as Control
		if row == null:
			continue
		var rect: Rect2 = row.get_global_rect()
		var on_screen: bool = index == 0 or (rect.size.y > 8.0 and view.intersects(rect))
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
	box.size = Vector2(maxf(8.0, cell.size.x - 4.0), maxf(8.0, cell.size.y - 24.0))
	box.stretch = true
	box.stretch_shrink = 1
	box.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(box)
	var view := SubViewport.new()
	view.name = "ActionViewport"
	view.own_world_3d = true
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
	cam.position = Vector3(0.4, 1.4, -2.8)
	cam.current = true
	world.add_child(cam)
	var pivot := Node3D.new()
	pivot.name = "OrbitPivot"
	world.add_child(pivot)
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
	pivot.add_child(unit)
	var ink: PackedColorArray = _colors(faction)
	var body: MeshInstance3D = Forms.dress_unit(str(item.get("id", "")), str(item.get("role", "")), str(item.get("locomotion", "ground")), ink[1], ink[0], ink[1], faction)
	unit.add_child(body)
	_strip_standin(body)
	Motion.attach(unit, body)
	SMArms.arm(unit, item)
	unit.set_meta("preview_cell", cell)
	_frame(cam, body)
	_pose(unit)

func _on_cell_input(event: InputEvent, cell: Panel) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		cell.set_meta("orbit_drag", button.pressed)
		cell.get_viewport().set_input_as_handled()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and bool(cell.get_meta("orbit_drag", false)):
		_orbit(cell, motion.relative)
		cell.get_viewport().set_input_as_handled()

## Drag delta in pixels. Yaw and pitch stay on this cell's pivot, and the clip keeps looping.
func _orbit(cell: Control, delta: Vector2) -> void:
	var pivot: Node3D = cell.find_child("OrbitPivot", true, false) as Node3D
	if pivot == null:
		return
	pivot.rotation.y -= delta.x * 0.01
	pivot.rotation.x = clampf(pivot.rotation.x + delta.y * 0.01, -1.15, 1.15)

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
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 18)
		note.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(note)
	note.position = Vector2(6, maxf(4.0, cell.size.y - 64.0))
	note.size = Vector2(maxf(8.0, cell.size.x - 12.0), 36)
	note.text = missing
	note.visible = true

func _cell_of(unit: RTSUnit) -> Control:
	var kept: Variant = unit.get_meta("preview_cell") if unit.has_meta("preview_cell") else null
	return kept as Control if kept != null and is_instance_valid(kept) else null

## The eye sits on the -Z side. Authored forward is -Z, so the face, cockpit or gun looks at the camera.
## The pivot is the visual centre, so a drag spins the mesh in place.
func _frame(cam: Camera3D, body: MeshInstance3D) -> void:
	var box: AABB = _bounds(body)
	var center: Vector3 = box.get_center()
	var unit: Node3D = body.get_parent() as Node3D
	var pivot: Node3D = unit.get_parent() as Node3D if unit != null else null
	if pivot != null and str(pivot.name) == "OrbitPivot":
		pivot.position = center
		unit.position = -center
		center = pivot.position
	var span: float = maxf(box.size.length(), 1.2)
	var eye: Vector3 = center + Vector3(span * 0.14, span * 0.22, -span * 1.05)
	cam.name = "PreviewCamera"
	cam.fov = 48.0
	cam.look_at_from_position(eye, center)

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
