extends Node3D

const Fx = preload("res://game/fx_view.gd")
const Ground = preload("res://game/ground_view.gd")
const Served = preload("res://game/served_art.gd")
## One solo text briefing. The objective button runs the sim system for that mission.

var campaign: SMCampaign = SMCampaign.new()
var field: SMPointer = SMPointer.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var grid: SMDomainGrid
var briefing_text: String = ""
var mission_id: String = ""
var status: Label
var ui_layer: CanvasLayer
var story: SMStory = SMStory.new()
## Cells round the rally that scenery leaves open for the base.
const BASE_CLEAR: Rect2i = Rect2i(5, 2, 18, 18)

func _ready() -> void:
	preload("res://game/sim_presenter.gd").follow(self)
	mission_id = SMCampaign.selected
	if mission_id == "":
		mission_id = "tachileik"
	briefing_text = SMCampaign.briefing_of(mission_id)
	grid = SMDomainGrid.new(36, 24, 4.0, Vector3(-72.0, 0.0, -48.0))
	_world()
	_ui()
	var faction: String = SMCampaign.player_faction(mission_id)
	SMFront.faction_id = faction
	preload("res://game/model_registry.gd").look_faction = SMCampaign.enemy_faction(mission_id)
	roster.setup(faction)
	var rally: Vector3 = Vector3(-6.0, 0.0, -2.0)
	side.prepare(self, status, grid, rally, roster.economy, faction)
	if side.yard.style != SMBuildYard.Style.INTERNAL:
		side.yard.radius = maxf(side.yard.radius, 40.0)
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, SMCampaign.title_of(mission_id), rally, Callable(self, "fire_secondary"), grid, cam)
	hud.set_tutorial(SMGuide.tutorial_for(mission_id))
	preload("res://game/match_settings.gd").apply_scene(self)
	var fx: Script = preload("res://game/fx_view.gd")
	fx.dress(self)
	preload("res://game/set_piece.gd").attach(self, mission_id)

func scripted_playthrough() -> bool:
	return finish_objective()

func finish_objective() -> bool:
	var ok: bool = campaign.play(mission_id)
	if ok and (mission_id == "plain_of_jars" or mission_id == "tonle_sap"):
		var foes: Array[RTSUnit] = field.units_of(SMPointer.ENEMY)
		if not foes.is_empty():
			field.apply_status(foes[0], "frozen", 8.0)
	_say(campaign.result_text)
	if ok:
		SMSave.mark(mission_id)
	return ok

func fire_secondary() -> int:
	return field.secondary_strike()

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.07, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 20, 0)
	add_child(sun)
	Ground.dress(self, grid, "mission", null, BASE_CLEAR, SMMapPlan.dressing(mission_id))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-76, -52, 152, 104)
	cam.distance = 46.0
	cam.zoom_max = 90.0
	cam.edge_pan_px = 16.0
	cam.focus = Vector3(0, 0, 2)
	add_child(cam)
	cam.current = true

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title: Label = Label.new()
	title.name = "MissionHeading"
	title.text = SMCampaign.title_of(mission_id)
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 18)
	title.position = Vector2(220, 108)
	title.size = Vector2(840, 26)
	title.clip_text = false
	ui_layer.add_child(title)
	var brief: Label = Label.new()
	brief.name = "Briefing"
	brief.position = Vector2(220, 136)
	brief.size = Vector2(760, 72)
	brief.custom_minimum_size = Vector2(760, 72)
	brief.clip_text = true
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief.text = briefing_text
	ui_layer.add_child(brief)
	_still(ui_layer)
	var goal: Button = Button.new()
	goal.name = "ObjectiveButton"
	goal.text = "Complete objective"
	goal.position = Vector2(400, 216)
	goal.visible = false
	goal.pressed.connect(finish_objective)
	ui_layer.add_child(goal)
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(220, 216)
	back.custom_minimum_size = Vector2(160, 36)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	ui_layer.add_child(back)
	status = Label.new()
	status.name = "Status"
	status.text = "Read the briefing, then meet it on the field."
	status.position = Vector2(220, 186)
	status.size = Vector2(760, 40)
	status.custom_minimum_size = Vector2(760, 40)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = true
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	ui_layer.add_child(status)

func _still(layer: CanvasLayer) -> void:
	var still: TextureRect = TextureRect.new()
	still.name = "BriefingStill"
	still.position = Vector2(980, 108)
	still.size = Vector2(260, 146)
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(still)
	var rel: String = SMCampaign.still_of(mission_id)
	if rel == "":
		still.visible = false
	else:
		Served.bind(still, rel)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, side.faction_id)
	field.use_open(36, 24, 2.0, Vector3(-36.0, 0.0, -24.0))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMCampaign.company_of(side.faction_id)
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, Vector3(-6.0 + float(i) * 2.4, 0.0, -2.0), kinds[i])
	if mission_id == "shattered_monsoon":
		field.next_look = "nmrf"
	field.spawn(SMPointer.ENEMY, Vector3(6.0, 0.0, 3.0), &"raider")
	preload("res://game/match_settings.gd").apply_story(story)
	story.bind_mission(self, mission_id, field, side, roster, ui_layer, grid)
	story.scale_field()

func _say(text: String) -> void:
	if status != null:
		status.text = text
	(load("res://game/match_audio.gd") as GDScript).call("announce_line", self, side.faction_id, text)

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)

func _process(delta: float) -> void:
	if hud.guide_blocks():
		return
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null and not hud.blocks_edge():
		var vp: Viewport = get_viewport()
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
			SMSave.mark(mission_id)
		_outro(true)
	elif status != null:
		status.text = story.progress()
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
