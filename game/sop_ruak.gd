extends Node3D

const Power = preload("res://addons/rts_advanced/sm_power.gd")
const Fx = preload("res://game/fx_view.gd")
const Ground = preload("res://game/ground_view.gd")
## Sop Ruak. Three land sectors split by a Y-shaped river.
## GTFC versus one enemy across a Y-shaped river. Same pointer controls as Phillips Channel.

var grid: SMDomainGrid
var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var raider: SMRaider = SMRaider.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var outcome: SMOutcome = SMOutcome.new()
var sight: SMSight = SMSight.new()
var status: Label
var ui_layer: CanvasLayer

func _ready() -> void:
	preload("res://game/sim_presenter.gd").follow(self)
	grid = SMDomainGrid.sop_ruak_layout()
	sim.place_sites("sop_ruak", grid)
	roster.setup(SMFront.current())
	roster.price_scale = Callable(self, "_price_scale")
	_prepare_ability()
	_world()
	_ui()
	var rally: Vector3 = grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(8, 22)))
	side.prepare(self, status, grid, rally, roster.economy)
	if side.yard.style != SMBuildYard.Style.INTERNAL:
		side.yard.radius = maxf(side.yard.radius, 44.0)
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, "Sop Ruak", rally, Callable(self, "fire_ability"), grid, cam)
	hud.use_goods(sim.goods)
	outcome.mount(self, ui_layer)
	sight.bind(grid)
	hud.use_sight(sight)
	hud.use_tech(sim.tech)
	SMSight.update_match(sight, field, self, sim.tech, raider)
	preload("res://game/match_settings.gd").apply_scene(self)

func train_unit() -> String:
	if not Power.online(side.yard):
		return ""
	var done: StringName = roster.train_and_finish(SMFront.train_kind())
	if done == &"":
		return ""
	var at: Vector3 = grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(8, 24)))
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	var label: String = field.name_of(u)
	_say(label)
	return label

func fire_ability() -> bool:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var cast: String = field.cast_f(field.aim_from_camera(cam, get_viewport().get_mouse_position()))
	var ok: bool = cast != "" or sim.use_f()
	_say("ability fired" if ok else "ability not ready")
	return ok

func _prepare_ability() -> void:
	sim.abilities = SMAbilities.new()
	sim.yard = SMBuildYard.new()
	sim.yard.center = grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(8, 22)))
	sim.abilities.add_unit(10, sim.yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	sim.abilities.add_unit(11, sim.yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	sim.abilities.add_unit(12, sim.yard.center + Vector3(8.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.1, 0.13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 25, 0)
	add_child(sun)
	Ground.dress(self, grid, "sop", null, Rect2i(), SMMapPlan.dressing("sop_ruak"))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-100.0, -100.0, 200.0, 200.0)
	cam.distance = 32.0
	cam.zoom_max = 90.0
	cam.edge_pan_px = 20.0
	cam.focus = Vector3(-36, 0, 16)
	add_child(cam)
	cam.current = true
	sim.paint_sites(self)

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	status = Label.new()
	status.name = "Status"
	status.visible = true
	status.text = "The enemy builds, expands, and attacks. Cross a ford to reach them."
	status.position = Vector2(240, 608)
	status.size = Vector2(760, 40)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	status.custom_minimum_size = Vector2(0, 36)
	ui_layer.add_child(status)
	preload("res://game/sim_presenter.gd").seat_status(status)
	sim.protocols.mount_panel(ui_layer, roster.economy, SMPointer.PLAYER, sim.abilities, Callable(self, "_say"))

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, SMFront.current())
	field.use_domain(grid)
	field.bind_tech(sim.tech, Callable(self, "_bridge_down"))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMFront.kinds()
	var cells: Array[Vector2i] = [SMDomainGrid.at("sop_ruak", Vector2i(6, 22)), SMDomainGrid.at("sop_ruak", Vector2i(8, 22)), SMDomainGrid.at("sop_ruak", Vector2i(10, 22)), SMDomainGrid.at("sop_ruak", Vector2i(6, 26)), SMDomainGrid.at("sop_ruak", Vector2i(8, 26)), SMDomainGrid.at("sop_ruak", Vector2i(10, 26))]
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, grid.cell_center(cells[i]), kinds[i])
	field.spawn_support(grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(6, 20))))
	for cell: Vector2i in [SMDomainGrid.at("sop_ruak", Vector2i(26, 22)), SMDomainGrid.at("sop_ruak", Vector2i(28, 22)), SMDomainGrid.at("sop_ruak", Vector2i(27, 26))]:
		field.spawn(SMPointer.ENEMY, grid.cell_center(cell), &"raider")
	raider.attach(field, grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(26, 22))))
	raider.bind_plan(sim.goods, sim.tech, &"bullion_a", &"bullion_b", &"cyber_b", "Iskandar")
	preload("res://game/match_settings.gd").apply_raider(raider)

func _bridge_down(id: StringName) -> void:
	sim.collapse_bridge(id, field, self)

func tick_world(delta: float) -> void:
	sim.tick_live(delta, roster.economy, field, raider.economy)
	sim.show_collectors(self)
	side.yard.cool_super(delta)
	sim.protocols.cool(delta)

func _price_scale(id: StringName) -> float:
	return sim.tech.discount(SMPointer.PLAYER, roster.unit_tag(id))

func _say(text: String) -> void:
	if status != null:
		status.text = text

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
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
	return mi

func _process(delta: float) -> void:
	if hud.guide_blocks():
		return
	if preload("res://game/lan_link.gd").holding():
		return
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null and not hud.blocks_edge():
		var vp: Viewport = get_viewport()
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	raider.tick(delta)
	raider.show_markers(self)
	field.tick(delta)
	field.place_beacon(field.enemy_anchor())
	tick_world(delta)
	sight.advance_weather(delta)
	SMSight.update_match(sight, field, self, sim.tech, raider)
	Fx.drive(self, field, sim.goods, sim.ew)
	hud.refresh()
	var players: Array[SMBuildYard] = [side.yard, sim.yard]
	var foes: Array[SMBuildYard] = [raider.yard]
	outcome.tick(field, players, foes, delta)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		preload("res://game/sim_presenter.gd").play_selected_ability(self)
		fire_ability()
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
