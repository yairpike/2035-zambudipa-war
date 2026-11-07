extends Node3D

const Power = preload("res://addons/rts_advanced/sm_power.gd")
const Fx = preload("res://game/fx_view.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Ground = preload("res://game/ground_view.gd")
## Phillips Channel. Two land masses, a deep channel, shallow crossings.
## The far shore builds, expands, and attacks.

var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var raider: SMRaider = SMRaider.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var outcome: SMOutcome = SMOutcome.new()
var sight: SMSight = SMSight.new()
var status: Label
var explore_bus: AudioStreamPlayer
var combat_bus: AudioStreamPlayer
var ui_layer: CanvasLayer

func _ready() -> void:
	preload("res://game/sim_presenter.gd").follow(self)
	sim.setup_phillips("gtfc")
	roster.setup(SMFront.current())
	roster.price_scale = Callable(self, "_price_scale")
	_world()
	_audio()
	_ui()
	side.prepare(self, status, sim.grid, sim.yard.center, roster.economy)
	if side.yard.style != SMBuildYard.Style.INTERNAL:
		side.yard.radius = maxf(side.yard.radius, 44.0)
	_arm_units()
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	hud.mount(ui_layer, field, roster, side, "Phillips Channel", sim.yard.center, Callable(self, "fire_ability"), sim.grid, cam)
	hud.use_goods(sim.goods)
	outcome.mount(self, ui_layer)
	sight.bind(sim.grid)
	hud.use_sight(sight)
	hud.use_tech(sim.tech)
	SMSight.update_match(sight, field, self, sim.tech, raider)
	preload("res://game/match_settings.gd").apply_scene(self)
	_late_crowd()

func scripted_playthrough() -> bool:
	return sim.script_phillips()

func _late_crowd() -> void:
	if not OS.has_feature("web"):
		return
	var href: String = str(JavaScriptBridge.eval("window.location.search", true))
	if href == "" or href == "null" or href == "<null>":
		return
	var settings: GDScript = preload("res://game/match_settings.gd")
	if href.contains("gfx=high"):
		settings.call("set_graphics", "high")
		settings.call("apply_scene", self)
	elif href.contains("gfx=low"):
		settings.call("set_graphics", "low")
		settings.call("apply_scene", self)
	var mark: int = href.find("late=")
	if mark < 0:
		return
	var digits: String = ""
	var rest: String = href.substr(mark + 5)
	for i: int in rest.length():
		var ch: String = rest.substr(i, 1)
		if ch < "0" or ch > "9":
			break
		digits += ch
	var count: int = 150 if digits == "" else int(digits)
	count = clampi(count, 0, 220)
	# West bank, north of the cliff, inside the opening camera. The old grid sat in the channel.
	var cols: int = 15
	var rows: int = 1 if count == 0 else int((count + cols - 1) / cols)
	var step: float = 1.55
	var origin: Vector3 = Vector3(-61.0, 0.0, -36.0)
	for i: int in count:
		var at: Vector3 = origin + Vector3(float(i % cols) * step, 0.0, float(int(i / cols)) * step)
		field.spawn(SMPointer.PLAYER, at, &"militia")
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null and count > 0:
		cam.distance = 48.0
		cam.focus_on(origin + Vector3(float(cols - 1) * step * 0.5, 0.0, float(rows - 1) * step * 0.5))
	SMSight.update_match(sight, field, self, sim.tech, raider)
	JavaScriptBridge.eval("console.log('late crowd %d')" % count, true)

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.12, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.66)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 20, 0)
	add_child(sun)
	Ground.dress(self, sim.grid, "phillips", null, Rect2i(), SMMapPlan.dressing("phillips_channel"))
	_slab("PlayerYard", SMPointer.building_at(sim.yard.center), SMPointer.BUILDING_SIZE, SMFront.primary())
	_slab("EnemyBase", SMPointer.building_at(sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(32, 12)))), SMPointer.BUILDING_SIZE, Color(0.16, 0.17, 0.18))
	sim.paint_sites(self)
	_capsule("Jammer", sim.ew.center + Vector3(0, 1.2, 0), Color(0.15, 0.75, 0.82))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-112.0, -68.0, 224.0, 136.0)
	cam.distance = 32.0
	cam.zoom_max = 90.0
	cam.edge_pan_px = 20.0
	cam.focus = Vector3(-58, 0, -12)
	add_child(cam)
	cam.current = true

func _audio() -> void:
	var silent: AudioStreamWAV = AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_16_BITS
	silent.mix_rate = 22050
	silent.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(882)
	silent.data = bytes
	explore_bus = AudioStreamPlayer.new()
	explore_bus.name = "ExploreStem"
	explore_bus.stream = silent
	explore_bus.volume_db = -8.0
	add_child(explore_bus)
	combat_bus = AudioStreamPlayer.new()
	combat_bus.name = "CombatStem"
	combat_bus.stream = silent
	combat_bus.volume_db = -80.0
	add_child(combat_bus)
	explore_bus.play()
	combat_bus.play()

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	var layer: CanvasLayer = ui_layer
	add_child(layer)
	sim.protocols.mount_panel(layer, roster.economy, sim.player, sim.abilities, Callable(self, "_say"))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.name = "MatchActions"
	actions.position = Vector2(250, 88)
	actions.add_theme_constant_override("separation", 8)
	actions.visible = false
	layer.add_child(actions)
	_action(actions, "Train unit", _on_train)
	_action(actions, "Build pipeline", _on_build)
	_action(actions, "Cross channel", _on_cross)
	_action(actions, "Engage", _on_engage)
	status = Label.new()
	status.name = "Status"
	status.visible = true
	status.text = "Raise a yard, claim Golden Slag / Aurum-9, cross, then press F."
	status.position = Vector2(250, 608)
	status.size = Vector2(740, 40)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	status.custom_minimum_size = Vector2(0, 36)
	layer.add_child(status)
	preload("res://game/sim_presenter.gd").seat_status(status)

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, SMFront.current())
	field.ew = sim.ew
	field.use_domain(sim.grid)
	field.bind_tech(sim.tech, Callable(self, "_bridge_down"))
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMFront.kinds()
	var cells: Array[Vector2i] = [SMDomainGrid.at("phillips", Vector2i(1, 8)), SMDomainGrid.at("phillips", Vector2i(3, 8)), SMDomainGrid.at("phillips", Vector2i(5, 8)), SMDomainGrid.at("phillips", Vector2i(8, 8)), SMDomainGrid.at("phillips", Vector2i(10, 8)), SMDomainGrid.at("phillips", Vector2i(12, 8))]
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, sim.grid.cell_center(cells[i]), kinds[i])
	field.spawn_support(sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(1, 6))))
	for cell: Vector2i in [SMDomainGrid.at("phillips", Vector2i(30, 12)), SMDomainGrid.at("phillips", Vector2i(31, 14)), SMDomainGrid.at("phillips", Vector2i(33, 11))]:
		field.spawn(SMPointer.ENEMY, sim.grid.cell_center(cell), &"raider")
	raider.attach(field, sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(30, 12))))
	raider.bind_plan(sim.goods, sim.tech, &"bullion_east", &"bullion_north", &"cyber", "Bo Mya")
	preload("res://game/match_settings.gd").apply_raider(raider)

func _action(row: HBoxContainer, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.text = caption
	b.pressed.connect(fn)
	row.add_child(b)

func train_unit() -> String:
	if not Power.online(side.yard):
		return ""
	var done: StringName = roster.train_and_finish(SMFront.train_kind())
	if done == &"":
		return ""
	var at: Vector3 = sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(1, 6)))
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	var label: String = field.name_of(u)
	_say(label)
	return label

func _on_train() -> void:
	train_unit()

func _on_build() -> void:
	_say("pipeline ready" if sim.run_player_pipeline() else "pipeline blocked")

func _on_cross() -> void:
	_say("crossed" if sim.cross_channel() else "cannot cross")

func fire_ability() -> bool:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var cast: String = field.cast_f(field.aim_from_camera(cam, get_viewport().get_mouse_position()))
	var ok: bool = cast != "" or sim.use_f()
	_say("ability fired" if ok else "ability not ready")
	return ok

func _on_ability() -> void:
	fire_ability()

func _price_scale(id: StringName) -> float:
	return sim.tech.discount(SMPointer.PLAYER, roster.unit_tag(id))

## Income, night shift, rare-earth stock, water harm, cyber siphon, and clinic healing.
func _bridge_down(id: StringName) -> void:
	sim.collapse_bridge(id, field, self)

func tick_world(delta: float) -> void:
	sim.tick_live(delta, roster.economy, field, raider.economy)
	sim.show_collectors(self)
	side.yard.cool_super(delta)
	sim.protocols.cool(delta)

func _on_engage() -> void:
	_say("channel clear" if sim.fight_passive() else "still fighting")

func _say(text: String) -> void:
	if status != null:
		status.text = text

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	if not Forms.dress_structure(mi, size, color):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat
	add_child(mi)

func _capsule(node_name: String, pos: Vector3, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.55
	mesh.height = 2.0
	mi.mesh = mesh
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)

func _process(delta: float) -> void:
	if hud.guide_blocks():
		return
	if preload("res://game/lan_link.gd").holding():
		return
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null and not hud.blocks_edge():
		var vp: Viewport = get_viewport()
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	if explore_bus != null and combat_bus != null and sim.audio != null:
		explore_bus.volume_db = linear_to_db(maxf(sim.audio.exploration, 0.001))
		combat_bus.volume_db = linear_to_db(maxf(sim.audio.combat, 0.001))
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
		_on_ability()
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
