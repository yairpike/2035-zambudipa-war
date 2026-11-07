extends Node3D

const Fx = preload("res://game/fx_view.gd")
const Ground = preload("res://game/ground_view.gd")
const Served = preload("res://game/served_art.gd")
const Models = preload("res://game/model_registry.gd")
const Env = preload("res://game/env_dress.gd")
const MapArt = preload("res://game/hud_minimap_art.gd")
## GTFC night raid. Scaffold, ruby night shift, one rare-earth node. Text briefing.

static var _model_cache: Dictionary = {}

static func clear_cache() -> void:
	for key: Variant in _model_cache.keys():
		var node: Node = _model_cache[key] as Node
		if node != null and is_instance_valid(node):
			node.free()
	_model_cache.clear()

var mission: SMMission = SMMission.new()
var field: SMPointer = SMPointer.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var grid: SMDomainGrid
var briefing_text: String = ""
var status: Label
var ui_layer: CanvasLayer
var story: SMStory = SMStory.new()
## Cells round the rally that scenery leaves open for the base.
const BASE_CLEAR: Rect2i = Rect2i(3, 1, 18, 16)

func _ready() -> void:
	preload("res://game/sim_presenter.gd").follow(self)
	mission.setup()
	briefing_text = mission.briefing
	grid = SMDomainGrid.new(28, 18, 4.0, Vector3(-56.0, 0.0, -36.0))
	_world()
	_ui()
	SMFront.faction_id = "gtfc"
	preload("res://game/model_registry.gd").look_faction = SMCampaign.enemy_faction("kokang")
	roster.setup("gtfc")
	var rally: Vector3 = Vector3(-6.0, 0.0, -4.0)
	side.prepare(self, status, grid, rally, roster.economy, "gtfc")
	side.yard.radius = maxf(side.yard.radius, 36.0)
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, SMCampaign.title_of("kokang"), rally, Callable(self, "fire_secondary"), grid, cam)
	_paint_minimap()
	hud.set_tutorial(SMGuide.tutorial_for("kokang"))
	preload("res://game/match_settings.gd").apply_scene(self)
	preload("res://game/set_piece.gd").attach(self, "kokang")

func scripted_playthrough() -> bool:
	var ok: bool = mission.playthrough()
	briefing_text = mission.briefing
	_say("Raid complete" if ok else "Raid stalled")
	return ok

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.4, 0.55)
	add_child(env)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 40, 0)
	moon.light_color = Color(0.7, 0.75, 0.9)
	add_child(moon)
	Ground.dress(self, grid, "kokang", null, BASE_CLEAR, SMMapPlan.dressing("kokang"))
	_feature("Scaffold", "scaffold_yard", Vector3(2.0, 0.0, 0.0), Vector3(6.0, 4.5, 6.0), Color(0.72, 0.12, 0.18), "scaffold")
	_feature("RubyNode", "rock_set", Vector3(6.0, 0.0, 2.0), Vector3(2.4, 1.4, 2.4), Color(0.78, 0.1, 0.22), "ruby")
	_feature("RareNode", "rock_set", Vector3(-6.0, 0.0, 4.0), Vector3(2.4, 1.4, 2.4), Color(0.42, 0.62, 0.3), "rare")
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-60, -40, 120, 80)
	cam.distance = 44.0
	cam.zoom_max = 90.0
	cam.edge_pan_px = 16.0
	cam.focus = Vector3(0, 0, 2)
	add_child(cam)
	cam.current = true

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	var layer: CanvasLayer = ui_layer
	add_child(layer)
	var brief: Label = Label.new()
	brief.name = "Briefing"
	brief.position = Vector2(220, 108)
	brief.size = Vector2(760, 72)
	brief.custom_minimum_size = Vector2(760, 72)
	brief.clip_text = true
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief.text = briefing_text
	layer.add_child(brief)
	var still: TextureRect = TextureRect.new()
	still.name = "BriefingStill"
	still.position = Vector2(980, 108)
	still.size = Vector2(260, 146)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(still)
	Served.bind(still, SMCampaign.still_of("kokang"))
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(220, 230)
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	_debug(row, "DebugScaffold", "Raise scaffold", _on_scaffold)
	_debug(row, "DebugRuby", "Mine rubies", _on_ruby)
	_debug(row, "DebugRare", "Secure rare earth", _on_rare)
	status = Label.new()
	status.name = "Status"
	status.text = "Golden Slag / Aurum-9 stays in the yard ledger. Ruby and rare earth are the raid."
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	layer.add_child(status)
	preload("res://game/sim_presenter.gd").seat_status(status)
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(220, 188)
	back.custom_minimum_size = Vector2(160, 36)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	layer.add_child(back)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, "gtfc")
	field.use_open(28, 18, 2.0, Vector3(-28.0, 0.0, -18.0))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMPointer.GTFC_KINDS
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, Vector3(-6.0 + float(i) * 2.0, 0.0, -4.0), kinds[i])
	field.spawn(SMPointer.ENEMY, Vector3(8.0, 0.0, -2.0), &"raider")
	field.spawn(SMPointer.ENEMY, Vector3(9.0, 0.0, 3.0), &"raider")
	preload("res://game/match_settings.gd").apply_story(story)
	story.bind_raid(self, mission, field, side)
	story.scale_field()

func fire_secondary() -> int:
	var n: int = field.secondary_strike()
	_say("F ability struck an enemy" if n > 0 else "F ability found no enemy")
	return n

func _debug(row: HBoxContainer, node_name: String, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.visible = false
	b.pressed.connect(fn)
	row.add_child(b)

func _on_scaffold() -> void:
	_say("Scaffold up" if mission.raise_scaffold() else "Scaffold stalled")
	_finish_if_ready()

func _on_ruby() -> void:
	_say("Night shift paying" if mission.run_night_ruby() else "Ruby not paying")
	_finish_if_ready()

func _on_rare() -> void:
	_say("Rare-earth stock secured" if mission.secure_rare() else "No stock yet")
	_finish_if_ready()

func _finish_if_ready() -> void:
	if mission.try_win():
		_say("Raid complete. Scaffold, night ruby, rare-earth stock.")

func _say(text: String) -> void:
	if status != null:
		status.text = text
	(load("res://game/match_audio.gd") as GDScript).call("announce_line", self, "gtfc", text)

func _feature(node_name: String, model_id: String, at: Vector3, footprint: Vector3, tint: Color, kind: String) -> void:
	var existing: Node = get_node_or_null(node_name)
	if existing != null:
		remove_child(existing)
		existing.free()
	var root: Node3D = _instance_model(model_id)
	if root != null:
		var bounds: AABB = _merged_aabb(root)
		var span: Vector3 = bounds.size
		var sx: float = footprint.x / maxf(span.x, 0.05)
		var sy: float = footprint.y / maxf(span.y, 0.05)
		var sz: float = footprint.z / maxf(span.z, 0.05)
		var fit: float = minf(sx, minf(sy, sz))
		root.scale = Vector3.ONE * fit
		root.position = Vector3(at.x, -bounds.position.y * fit, at.z)
		if kind == "rare":
			root.rotation.y = 2.1
		elif kind == "ruby":
			root.rotation.y = 0.6
		if kind == "ruby" or kind == "rare":
			var top: Vector3 = bounds.position + Vector3(span.x * 0.5, span.y, span.z * 0.45)
			_crystal(root, top + Vector3(-span.x * 0.12, span.y * 0.08, 0.0), Vector3(span.x * 0.12, span.y * 0.38, span.z * 0.1), tint)
			_crystal(root, top + Vector3(span.x * 0.14, span.y * 0.02, span.z * 0.08), Vector3(span.x * 0.08, span.y * 0.28, span.z * 0.08), tint.lightened(0.15))
		root.name = node_name
		add_child(root)
		return
	var built: Node3D = Node3D.new()
	built.name = node_name
	built.position = at
	add_child(built)
	if kind == "scaffold":
		_scaffold_mesh(built, tint)
	else:
		_ore_mesh(built, tint)
	if OS.has_feature("web"):
		built.visible = false
		built.set_meta("standin_held", true)
		if model_id == "rock_set":
			Env.pull_web(self, PackedStringArray(["rock_set"]))

func _on_env_ready(id: String) -> void:
	if id == "rock_set":
		_feature("RubyNode", "rock_set", Vector3(6.0, 0.0, 2.0), Vector3(2.4, 1.4, 2.4), Color(0.78, 0.1, 0.22), "ruby")
		_feature("RareNode", "rock_set", Vector3(-6.0, 0.0, 4.0), Vector3(2.4, 1.4, 2.4), Color(0.42, 0.62, 0.3), "rare")

func _instance_model(model_id: String) -> Node3D:
	if model_id == "rock_set":
		var env_root: Node3D = Env._load("rock_set")
		if env_root != null:
			return env_root
	else:
		var reg_root: Node3D = Models._scene(model_id)
		if reg_root != null:
			return reg_root
	if _model_cache.has(model_id) and _model_cache[model_id] != null:
		var kept: Node = _model_cache[model_id] as Node
		if is_instance_valid(kept):
			return kept.duplicate() as Node3D
	var path: String = _model_path(model_id)
	if path == "":
		return null
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: Error = FAILED
	if path.begins_with("user://") or path.begins_with("res://"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			err = doc.append_from_buffer(bytes, "", state)
		if err != OK:
			err = doc.append_from_file(ProjectSettings.globalize_path(path), state)
	else:
		err = doc.append_from_file(path, state)
	if err != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	var root: Node3D = generated as Node3D
	if root == null:
		return null
	_model_cache[model_id] = root
	return root.duplicate() as Node3D

func _model_path(model_id: String) -> String:
	if model_id == "rock_set":
		return Env._file("rock_set")
	return Models._path(model_id)

func _merged_aabb(root: Node3D) -> AABB:
	var merged: AABB = AABB()
	var any: bool = false
	var pending: Array[Node] = [root]
	while pending.size() > 0:
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var xf: Transform3D = _to_root(root, mesh_node)
		var box: AABB = xf * mesh_node.mesh.get_aabb()
		if not any:
			merged = box
			any = true
		else:
			merged = merged.merge(box)
	if not any:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return merged

func _to_root(root: Node3D, node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cursor: Node3D = node
	while cursor != null and cursor != root:
		xf = cursor.transform * xf
		cursor = cursor.get_parent() as Node3D
	return xf

func _crystal(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Crystal"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	mi.rotation_degrees = Vector3(0.0, 18.0, 8.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	parent.add_child(mi)

func _scaffold_mesh(parent: Node3D, tint: Color) -> void:
	var steel: Color = Color(0.45, 0.38, 0.34)
	var deck: Color = Color(0.32, 0.26, 0.22)
	_part(parent, Vector3(-1.3, 1.1, -1.3), Vector3(0.14, 2.2, 0.14), steel)
	_part(parent, Vector3(1.3, 1.1, -1.3), Vector3(0.14, 2.2, 0.14), steel)
	_part(parent, Vector3(-1.3, 1.1, 1.3), Vector3(0.14, 2.2, 0.14), steel)
	_part(parent, Vector3(1.3, 1.1, 1.3), Vector3(0.14, 2.2, 0.14), steel)
	_part(parent, Vector3(0.0, 0.7, 0.0), Vector3(2.5, 0.1, 2.5), deck)
	_part(parent, Vector3(0.0, 1.7, 0.0), Vector3(2.7, 0.1, 2.7), deck)
	_part(parent, Vector3(0.0, 2.15, -1.3), Vector3(2.6, 0.8, 0.08), tint)
	_part(parent, Vector3(1.6, 2.5, 0.2), Vector3(1.4, 0.08, 0.08), steel)
	_part(parent, Vector3(2.2, 1.3, 0.2), Vector3(0.08, 2.4, 0.08), steel)

func _ore_mesh(parent: Node3D, tint: Color) -> void:
	var rock: Color = Color(0.38, 0.34, 0.3)
	_part(parent, Vector3(0.0, 0.28, 0.0), Vector3(1.5, 0.45, 1.2), rock)
	_part(parent, Vector3(-0.35, 0.5, 0.15), Vector3(0.7, 0.4, 0.65), rock.darkened(0.15))
	_part(parent, Vector3(0.4, 0.42, -0.2), Vector3(0.55, 0.32, 0.5), rock.lightened(0.08))
	_crystal(parent, Vector3(-0.1, 0.85, 0.05), Vector3(0.16, 0.55, 0.14), tint)
	_crystal(parent, Vector3(0.28, 0.7, -0.12), Vector3(0.12, 0.38, 0.12), tint.lightened(0.12))

func _part(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)

func _paint_minimap() -> void:
	if hud.minimap == null or grid == null:
		return
	var art: Texture2D = hud.minimap.backdrop
	if art == null:
		art = MapArt.bake(grid, "kokang")
	if art == null:
		return
	var img: Image = art.get_image()
	if img == null:
		return
	img = img.duplicate()
	_blot(img, Vector3(2.0, 0.0, 0.0), Color(0.72, 0.16, 0.18), 4)
	_blot(img, Vector3(6.0, 0.0, 2.0), Color(0.84, 0.08, 0.2), 3)
	_blot(img, Vector3(-6.0, 0.0, 4.0), Color(0.32, 0.62, 0.28), 3)
	var step: int = 0
	while step < 14:
		_blot(img, Vector3(-22.0, 0.0, -14.0 + float(step) * 2.2), Color(0.06, 0.24, 0.4), 2)
		step += 1
	hud.minimap.backdrop = ImageTexture.create_from_image(img)

func _blot(img: Image, world: Vector3, color: Color, radius: int) -> void:
	var span_x: float = float(grid.cols) * grid.cell_size
	var span_z: float = float(grid.rows) * grid.cell_size
	if span_x <= 0.0 or span_z <= 0.0:
		return
	var cx: int = int(((world.x - grid.origin.x) / span_x) * float(img.get_width()))
	var cy: int = int(((world.z - grid.origin.z) / span_z) * float(img.get_height()))
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			img.set_pixel(x, y, color)

func _process(delta: float) -> void:
	if hud.guide_blocks():
		return
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam == null:
		return
	var vp: Viewport = get_viewport()
	if not hud.blocks_edge():
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	field.tick(delta)
	story.tick(delta)
	var piece: Node = get_node_or_null("SetPiece")
	if piece != null:
		piece.call("drive", delta)
	Fx.drive(self, field, null, field.ew)
	field.place_beacon(story.beacon())
	if story.lost:
		if status != null and status.text != "Objective failed":
			_say("Objective failed")
		_outro(false)
	elif story.done:
		if status != null and status.text != "Objective complete":
			_say("Objective complete")
			SMSave.mark("kokang")
		_outro(true)
	elif status != null:
		status.text = story.progress()
	var scaf: Node3D = get_node_or_null("Scaffold") as Node3D
	if scaf != null and bool(scaf.get_meta("standin_held", false)) and Models._again("scaffold_yard") != null:
		_feature("Scaffold", "scaffold_yard", Vector3(2.0, 0.0, 0.0), Vector3(6.0, 4.5, 6.0), Color(0.72, 0.12, 0.18), "scaffold")
	hud.refresh()

func _outro(won: bool) -> void:
	preload("res://game/menu_outro.gd").show(ui_layer, won)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		preload("res://game/sim_presenter.gd").play_selected_ability(self)
		fire_secondary()
		return
	if cam == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if field.handle_button(mb):
			return
		if hud.column_hovered() and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_toward(1.0, cam.ground_at(mb.position))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_toward(-1.0, cam.ground_at(mb.position))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	field.handle_motion(motion)
	if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		cam.orbit(motion.relative.x * 0.25)
