extends Node3D

const Power = preload("res://addons/rts_advanced/sm_power.gd")
const Fx = preload("res://game/fx_view.gd")
const Ground = preload("res://game/ground_view.gd")
## Shared GTFC skirmish. The map id picks the terrain. Controls match Sop Ruak.

@export var map_id: String = "burma_road"

var grid: SMDomainGrid
var plan: SMMapPlan
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
	plan = SMMapPlan.of(map_id)
	grid = _grid_for(map_id)
	sim.place_sites(map_id, grid)
	roster.setup(SMFront.current())
	roster.price_scale = Callable(self, "_price_scale")
	_prepare_ability()
	_world()
	_ui()
	var rally: Vector3 = grid.cell_center(_yard_cell())
	side.prepare(self, status, grid, rally, roster.economy)
	if side.yard.style != SMBuildYard.Style.INTERNAL:
		side.yard.radius = maxf(side.yard.radius, 48.0)
	side.plan.keep_nets(sim.goods, sim.tech)
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, _map_name(), rally, Callable(self, "fire_ability"), grid, cam)
	hud.use_goods(sim.goods)
	hud.use_tech(sim.tech)
	outcome.mount(self, ui_layer)
	sight.bind(grid)
	hud.use_sight(sight)
	SMSight.update_match(sight, field, self, sim.tech, raider, side.yard)
	preload("res://game/match_settings.gd").apply_scene(self)

func train_unit() -> String:
	if not Power.online(side.yard):
		return ""
	var done: StringName = roster.train_and_finish(SMFront.train_kind())
	if done == &"":
		return ""
	var at: Vector3 = grid.cell_center(_player_cells()[0]) + Vector3(2.0, 0.0, 0.0)
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
	sim.yard.center = grid.cell_center(_yard_cell())
	sim.abilities.add_unit(10, sim.yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	sim.abilities.add_unit(11, sim.yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	sim.abilities.add_unit(12, sim.yard.center + Vector3(8.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)

func _grid_for(id: String) -> SMDomainGrid:
	if plan != null:
		return plan.grid()
	if id == "showcase":
		return SMDomainGrid.showcase_layout()
	return SMDomainGrid.burma_road_layout()

func _player_cells() -> Array[Vector2i]:
	if plan != null:
		return plan.spawn_cells(0, 6)
	return _shift_cells([Vector2i(8, 40), Vector2i(10, 40), Vector2i(12, 40), Vector2i(8, 43), Vector2i(10, 43), Vector2i(12, 43)])

## Construction yard cell. Planned maps put it on the start; spawns stand beside it.
func _yard_cell() -> Vector2i:
	if plan != null:
		return plan.start(0)
	return _player_cells()[0]

func _enemy_yard_cell() -> Vector2i:
	if plan != null:
		return plan.start(plan.starts.size() / 2)
	return _enemy_cells()[0]

func _plan_name() -> String:
	if plan != null:
		return plan.bot("name", "Bo Mya")
	return "Bo Mya"

func _plan_a() -> StringName:
	return StringName(plan.bot("plan_a")) if plan != null else &""

func _plan_b() -> StringName:
	return StringName(plan.bot("plan_b")) if plan != null else &""

func _plan_site() -> StringName:
	return StringName(plan.bot("site")) if plan != null else &""

func _extra_sides() -> void:
	if plan != null and plan.starts.size() >= 4:
		var ally: Array[Vector2i] = plan.spawn_cells(1, 6)
		var foe: Array[Vector2i] = plan.spawn_cells(3, 6)
		_seat(2, Color(0.85, 0.72, 0.28), 0, ally[0], "Ally", "PersonalityAlly")
		_seat(4, Color(0.45, 0.7, 0.4), 0, ally[3], "Ally", "PersonalityAllyB")
		_seat(3, Color(0.85, 0.45, 0.12), 1, foe[0], "Iskandar", "PersonalityIskandar")
		_seat(5, Color(0.55, 0.35, 0.75), 1, foe[3], "Tran", "PersonalityTran")
		field.teams.set_relation(2, 4, RTSTeams.Relation.ALLY)
		field.teams.set_relation(1, 3, RTSTeams.Relation.ALLY)
		field.teams.set_relation(1, 5, RTSTeams.Relation.ALLY)
		field.teams.set_relation(3, 5, RTSTeams.Relation.ALLY)
	elif map_id == "ten_degree_atolls" or map_id == "mekong_delta":
		_seat(2, Color(0.85, 0.72, 0.28), 0, _player_cells()[3], "Tran", "PersonalityTran")
		_seat(3, Color(0.85, 0.45, 0.12), 1, _enemy_cells()[2], "Iskandar", "PersonalityIskandar")
		field.teams.set_relation(1, 3, RTSTeams.Relation.ALLY)

func _seat(team: int, color: Color, ally_of: int, cell: Vector2i, caption: String, node_name: String) -> void:
	field.teams.add_team(team, color)
	field.teams.set_relation(team, ally_of, RTSTeams.Relation.ALLY)
	var origin: Vector3 = grid.cell_center(cell)
	for i: int in 3:
		field.spawn(team, origin + Vector3(float(i) * 1.6, 0.0, 2.2), &"raider")
	var tag: Label3D = Label3D.new()
	tag.name = node_name
	tag.text = caption
	tag.font_size = 48
	tag.pixel_size = 0.02
	tag.position = origin + Vector3(1.6, 4.2, 2.2)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	add_child(tag)

func _enemy_cells() -> Array[Vector2i]:
	if plan != null:
		return plan.spawn_cells(plan.starts.size() / 2, 3)
	return _shift_cells([Vector2i(58, 8), Vector2i(60, 8), Vector2i(62, 8)])

func _move_cell() -> Vector2i:
	if plan != null:
		return plan.spawn_cells(0, 9)[8]
	return Vector2i(12, 40) + SMDomainGrid.pad_of(map_id)

func _shift_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var pad: Vector2i = SMDomainGrid.pad_of(map_id)
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		out.append(cell + pad)
	return out

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
	if map_id == "showcase":
		Ground.dress(self, grid, "showcase")
	elif map_id == "ten_degree_atolls":
		_atoll_world()
	elif map_id == "mekong_delta":
		_mekong_world()
	elif map_id == "chiang_rai":
		_chiang_world()
	else:
		_burma_world()
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	var span: Vector2 = Vector2(float(grid.cols) * grid.cell_size, float(grid.rows) * grid.cell_size)
	cam.bounds = Rect2(grid.origin.x - 8.0, grid.origin.z - 8.0, span.x + 16.0, span.y + 16.0)
	cam.distance = 60.0 if map_id == "showcase" else (56.0 if map_id == "chiang_rai" else 52.0)
	cam.zoom_max = 90.0
	cam.edge_pan_px = 20.0
	cam.focus = grid.cell_center(_yard_cell())
	add_child(cam)
	cam.current = true
	sim.paint_sites(self)

func _burma_world() -> void:
	Ground.dress(self, grid, "burma", plan)

func _atoll_world() -> void:
	Ground.dress(self, grid, "atolls", plan)

func _mekong_world() -> void:
	Ground.dress(self, grid, "mekong", plan)
	if plan == null:
		_slab("BridgeWest", Vector3(-26, 0.15, 0), Vector3(14, 0.28, 16), Color(0.45, 0.4, 0.3))
		_slab("BridgeEast", Vector3(30, 0.15, 0), Vector3(14, 0.28, 16), Color(0.45, 0.4, 0.3))
		return
	_deck("BridgeWest", plan.site_span(&"bridge_a").merge(plan.site_span(&"bridge_b")))
	_deck("BridgeEast", plan.site_span(&"bridge_c").merge(plan.site_span(&"bridge_d")))

func _deck(node_name: String, span: Rect2i) -> void:
	var size: Vector3 = Vector3(float(span.size.x) * grid.cell_size + 2.0, 0.28, float(span.size.y) * grid.cell_size)
	_slab(node_name, plan.rect_center(span) + Vector3(0.0, 0.15, 0.0), size, Color(0.45, 0.4, 0.3))

func _chiang_world() -> void:
	Ground.dress(self, grid, "chiang", plan)

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	status = Label.new()
	status.name = "Status"
	status.visible = true
	status.text = _blurb()
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

func _map_name() -> String:
	if map_id == "showcase":
		return "Golden Confluence"
	if map_id == "ten_degree_atolls":
		return "Ten Degree Atolls"
	if map_id == "mekong_delta":
		return "Mekong Delta"
	if map_id == "chiang_rai":
		return "Siege of Chiang Rai"
	return "Burma Road"

func _blurb() -> String:
	if map_id == "showcase":
		return "A city bank, a jungle bank, and a river between them. The landmark does not burn."
	if map_id == "ten_degree_atolls":
		return "Islands in deep water. Shoals are the crossings. The enemy builds, expands, and attacks."
	if map_id == "mekong_delta":
		return "Canals cut the paddies. Right-click a bridge to drop it. The enemy builds, expands, and attacks."
	if map_id == "chiang_rai":
		return "A larger field. Fords cross the river. The enemy builds, expands, and attacks."
	return "Highland cliffs block the climb. The road is open ground. The enemy builds, expands, and attacks."

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, SMFront.current())
	field.use_domain(grid)
	field.bind_tech(sim.tech, Callable(self, "_bridge_down"))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMFront.kinds()
	var cells: Array[Vector2i] = _player_cells()
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, grid.cell_center(cells[i]), kinds[i])
	field.spawn_support(grid.cell_center(cells[0]) + Vector3(0.0, 0.0, 4.0))
	for cell: Vector2i in _enemy_cells():
		field.spawn(SMPointer.ENEMY, grid.cell_center(cell), &"raider")
	raider.attach(field, grid.cell_center(_enemy_yard_cell()))
	raider.bind_plan(sim.goods, sim.tech, _plan_a(), _plan_b(), _plan_site(), _plan_name())
	preload("res://game/match_settings.gd").apply_raider(raider)
	_extra_sides()

func _bridge_down(id: StringName) -> void:
	sim.collapse_bridge(id, field, self)
	_say("Bridge down")

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
	SMSight.update_match(sight, field, self, sim.tech, raider, side.yard)
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
