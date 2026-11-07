extends Node3D

const Power = preload("res://addons/rts_advanced/sm_power.gd")
const Fx = preload("res://game/fx_view.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Ground = preload("res://game/ground_view.gd")
## NMRF mobile packer, or MVD internal queue with clearance.
## Same pointer controls as Sop Ruak. Six named placeholders.

@export var faction_id: String = "nmrf"

var grid: SMDomainGrid
var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var raider: SMRaider = SMRaider.new()
var roster: SMRoster = SMRoster.new()
var yard: SMBuildYard = SMBuildYard.new()
var economy: RTSEconomy = RTSEconomy.new()
var outcome: SMOutcome = SMOutcome.new()
var sight: SMSight = SMSight.new()
var status: Label
var ui_layer: CanvasLayer
var packer_mesh: MeshInstance3D
var hub_mesh: MeshInstance3D

func _ready() -> void:
	preload("res://game/sim_presenter.gd").follow(self)
	grid = SMDomainGrid.phillips_layout()
	roster.setup(faction_id)
	economy.set_credits(0, 4000)
	_prepare_yard()
	_prepare_ability()
	_world()
	_ui()
	_arm_units()
	outcome.mount(self, ui_layer)
	sight.bind(grid)
	SMSight.update_match(sight, field, self, sim.tech, raider)
	preload("res://game/settings_panel.gd").attach(ui_layer)
	preload("res://game/match_settings.gd").apply_scene(self)

func train_unit() -> String:
	if not Power.online(yard):
		return ""
	var id: StringName = &"cyan_sentry" if faction_id == "mvd" else &"olive_ranger"
	var done: StringName = roster.train_and_finish(id)
	if done == &"":
		return ""
	var at: Vector3 = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(1, 6)))
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	var label: String = field.name_of(u)
	_say(label)
	return label

func fire_ability() -> bool:
	preload("res://game/sim_presenter.gd").play_selected_ability(self)
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var cast: String = field.cast_f(field.aim_from_camera(cam, get_viewport().get_mouse_position()))
	var ok: bool = cast != "" or sim.use_f()
	_say("ability fired" if ok else "ability not ready")
	return ok

func move_packer() -> bool:
	if faction_id != "nmrf":
		return false
	var dest: Vector3 = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(18, 5)))
	var ok: bool = yard.move_packer(dest)
	if ok and packer_mesh != null:
		packer_mesh.position = SMPointer.building_at(dest)
	_say("packer sailed" if ok else "packer stayed packed")
	return ok

func unpack_core() -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.unpack(&"gun_wharf")
	_say("wharf unpacked" if ok else "already unpacked")
	return ok

func upgrade_wharf() -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.upgrade_factory(&"gun_wharf")
	_say("wharf level %d" % yard.factory_level(&"gun_wharf") if ok else "wharf not ready")
	return ok

func queue_hub() -> bool:
	if faction_id != "mvd":
		return false
	var ok: bool = yard.queue_internal(&"command_hub")
	if ok:
		yard.advance(5.0)
	_say("hub ready to place" if ok and yard.ready.has(&"command_hub") else "hub not queued")
	return ok and yard.ready.has(&"command_hub")

func buy_clearance() -> bool:
	if faction_id != "mvd":
		return false
	var level: int = yard.clearance + 1
	var ok: bool = yard.buy_clearance(level, 200)
	_say("clearance %d" % yard.clearance if ok else "clearance refused")
	return ok

func place_hub() -> bool:
	if faction_id != "mvd":
		return false
	var pos: Vector3 = Vector3(4.0, 0.0, 0.0)
	var ok: bool = yard.place_finished(&"command_hub", pos)
	if ok and hub_mesh != null:
		hub_mesh.position = SMPointer.building_at(pos)
		hub_mesh.visible = true
	_say("hub placed" if ok else "hub not ready")
	return ok

func _prepare_yard() -> void:
	var data: Dictionary = SMCatalog.faction(faction_id)
	yard.team = 0
	yard.economy = economy
	yard.center = Vector3.ZERO
	yard.radius = float(data.get("yard_radius", 14))
	_load_buildings(data)
	if faction_id == "mvd":
		yard.style = SMBuildYard.Style.INTERNAL
		yard.clearance = 1
		yard.radius = 25.0
	else:
		yard.style = SMBuildYard.Style.MOBILE
		yard.grid = grid
		yard.packer_pos = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(4, 8)))

func _load_buildings(data: Dictionary) -> void:
	var raw: Variant = data.get("buildings", [])
	if not (raw is Array):
		return
	for item: Variant in raw:
		if item is Dictionary:
			var id: StringName = StringName(str(item.get("id", "")))
			yard.building_tier[id] = int(item.get("tier", 1))
			yard.building_time[id] = float(item.get("time", 4.0))

func _prepare_ability() -> void:
	sim.abilities = SMAbilities.new()
	sim.yard = yard
	sim.abilities.add_unit(10, yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	sim.abilities.add_unit(11, yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	sim.abilities.add_unit(12, yard.center + Vector3(8.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.1, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 25, 0)
	add_child(sun)
	if faction_id == "mvd":
		Ground.dress(self, grid, "mvd")
		hub_mesh = _slab("HubShell", SMPointer.building_at(Vector3(4, 0, 0)), SMPointer.BUILDING_SIZE, Color(0.15, 0.75, 0.82))
		hub_mesh.visible = false
	else:
		Ground.dress(self, grid, "nmrf")
		packer_mesh = _slab("PackerCore", SMPointer.building_at(yard.packer_pos), SMPointer.BUILDING_SIZE, Color(0.12, 0.62, 0.4))
	var cam: RTSCamera = RTSCamera.new()
	cam.name = "Camera"
	cam.bounds = Rect2(-90, -60, 180, 120)
	cam.distance = 32.0
	cam.zoom_max = 90.0
	cam.edge_pan_px = 20.0
	cam.focus = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(4, 8)))
	add_child(cam)
	cam.current = true

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title: Label = Label.new()
	title.name = "YardTitle"
	title.text = _title()
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(16, 12)
	ui_layer.add_child(title)
	var ability: Button = Button.new()
	ability.name = "AbilityButton"
	ability.text = "Ability (F)"
	ability.position = Vector2(16, 44)
	ability.pressed.connect(fire_ability)
	ui_layer.add_child(ability)
	var train: Button = Button.new()
	train.name = "TrainButton"
	train.text = "Train unit"
	train.position = Vector2(16, 120)
	train.pressed.connect(train_unit)
	ui_layer.add_child(train)
	if faction_id == "mvd":
		_button("QueueHub", "Queue hub", Vector2(160, 44), queue_hub)
		_button("BuyClearance", "Buy clearance", Vector2(300, 44), buy_clearance)
		_button("PlaceHub", "Place hub", Vector2(460, 44), place_hub)
	else:
		_button("MovePacker", "Move packer", Vector2(160, 44), move_packer)
		_button("UnpackCore", "Unpack", Vector2(320, 44), unpack_core)
		_button("UpgradeWharf", "Upgrade wharf", Vector2(440, 44), upgrade_wharf)
	status = Label.new()
	status.name = "Status"
	status.text = _blurb()
	status.clip_text = true
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.anchor_right = 1.0
	status.offset_left = 16.0
	status.offset_top = 84.0
	status.offset_right = -16.0
	status.offset_bottom = 112.0
	ui_layer.add_child(status)
	var hint: Label = Label.new()
	hint.text = "Left click selects. Right click moves. F ability."
	hint.clip_text = true
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 16.0
	hint.offset_top = -36.0
	hint.offset_right = -16.0
	hint.offset_bottom = -8.0
	ui_layer.add_child(hint)

func _button(node_name: String, caption: String, pos: Vector2, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.position = pos
	b.pressed.connect(fn)
	ui_layer.add_child(b)

func _title() -> String:
	if faction_id == "mvd":
		return "MVD  charcoal / cyan    internal queue"
	return "NMRF  olive / emerald    mobile core"

func _blurb() -> String:
	if faction_id == "mvd":
		return "Queue the hub inside the pad, buy clearance, then place it. The enemy builds, expands, and attacks."
	return "The packer sails, unpacks a wharf, then upgrades it. The enemy builds, expands, and attacks."

func _arm_units() -> void:
	var cam: RTSCamera = get_node("Camera") as RTSCamera
	field.bind_faction(self, cam, faction_id)
	field.use_domain(grid)
	field.attach_box(ui_layer)
	var kinds: Array[StringName] = SMPointer.MVD_KINDS if faction_id == "mvd" else SMPointer.NMRF_KINDS
	var cells: Array[Vector2i] = [SMDomainGrid.at("phillips", Vector2i(1, 8)), SMDomainGrid.at("phillips", Vector2i(3, 8)), SMDomainGrid.at("phillips", Vector2i(5, 8)), SMDomainGrid.at("phillips", Vector2i(8, 8)), SMDomainGrid.at("phillips", Vector2i(10, 8)), SMDomainGrid.at("phillips", Vector2i(12, 8))]
	for i: int in kinds.size():
		field.spawn(SMPointer.PLAYER, grid.cell_center(cells[i]), kinds[i])
	field.spawn_support(grid.cell_center(SMDomainGrid.at("phillips", Vector2i(1, 6))))
	for cell: Vector2i in [SMDomainGrid.at("phillips", Vector2i(30, 12)), SMDomainGrid.at("phillips", Vector2i(31, 14)), SMDomainGrid.at("phillips", Vector2i(33, 11))]:
		field.spawn(SMPointer.ENEMY, grid.cell_center(cell), &"raider")
	raider.attach(field, grid.cell_center(SMDomainGrid.at("phillips", Vector2i(30, 12))))
	preload("res://game/match_settings.gd").apply_raider(raider)

func _say(text: String) -> void:
	if status != null:
		status.text = text

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
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
	return mi

func _process(delta: float) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	if cam != null:
		var vp: Viewport = get_viewport()
		cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	raider.tick(delta)
	raider.show_markers(self)
	field.tick(delta)
	field.place_beacon(field.enemy_anchor())
	sight.advance_weather(delta)
	SMSight.update_match(sight, field, self, sim.tech, raider)
	Fx.drive(self, field, sim.goods, sim.ew)
	var players: Array[SMBuildYard] = [yard]
	var foes: Array[SMBuildYard] = [raider.yard]
	outcome.tick(field, players, foes, delta)

func _unhandled_input(event: InputEvent) -> void:
	var cam: RTSCamera = get_node_or_null("Camera") as RTSCamera
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		fire_ability()
		return
	if cam == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if field.handle_button(mb):
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
