extends Node3D
## Animation pilot stage. Drives real RTSUnit nodes and a real Built_ slab through the same view hooks the match uses.
## Run: godot --path . --rendering-driver opengl3 --write-movie out.avi --fixed-fps 30 res://game/anim_pilot.tscn -- --stills=/dir

const Forms = preload("res://game/unit_meshes.gd")
const Motion = preload("res://game/unit_motion.gd")
const BuildingFx = preload("res://game/building_fx.gd")
const World = preload("res://game/world_view.gd")

const LENGTH: float = 41.0
const GTFC_RED: Color = Color("#B81E2D")
const GTFC_AMBER: Color = Color("#E0A106")
const MVD_CHARCOAL: Color = Color("#2A2E32")
const MVD_CYAN: Color = Color("#26BFD1")

const SHOTS: Dictionary = {
	"01-infantry-idle": 1.6, "02-infantry-walk": 4.0, "03-infantry-shoot": 7.4, "04-infantry-die": 11.3,
	"05-tank-move-turret": 16.4, "07-tank-destroyed": 24.4,
	"08-building-scaffold-rise": 28.2, "09-building-damaged": 33.4, "10-building-collapse": 36.0, "11-building-rubble": 40.0,
}

var t: float = 0.0
var units: Array[RTSUnit] = []
var cam: Camera3D
var militia: RTSUnit
var trooper: RTSUnit
var ifv: RTSUnit
var tank: RTSUnit
var foe: RTSUnit
var barracks: MeshInstance3D
var stills_dir: String = ""
var taken: Dictionary = {}
var fired_events: Array[String] = []
var fire_still: bool = false

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="):
			stills_dir = arg.trim_prefix("--stills=")
	get_window().size = Vector2i(1280, 720)
	_dress_stage()
	militia = _spawn(&"militia", "infantry", "ground", Vector3(-15.2, 0, 3.2), 0, GTFC_RED, GTFC_AMBER)
	trooper = _spawn(&"clearance_trooper", "infantry", "ground", Vector3(-13.0, 0, 3.6), 0, MVD_CHARCOAL, MVD_CYAN)
	ifv = _spawn(&"cyan_ifv", "armor", "ground", Vector3(-13.5, 0, -7.5), 1, MVD_CHARCOAL, MVD_CYAN)
	ifv.rotation.y = PI
	ifv.max_hp = 100000.0
	ifv.hp = ifv.max_hp
	tank = _spawn(&"amber_tank", "armor", "ground", Vector3(3, 0, 9), 0, GTFC_RED, GTFC_AMBER)
	foe = _spawn(&"cyan_ifv", "armor", "ground", Vector3(-6, 0, -9), 1, MVD_CHARCOAL, MVD_CYAN)
	foe.max_hp = 100000.0
	foe.hp = foe.max_hp
	foe.rotation.y = -PI * 0.75
	for u: RTSUnit in [militia, trooper]:
		u.attack_range = 9.0
		u.attack_interval = 0.45
		u.attack_damage = 1.0
		u.speed = 2.6
		u.rotation.y = PI
	ifv.attack_range = 30.0
	ifv.attack_interval = 1.6
	ifv.attack_damage = 45.0
	tank.attack_range = 1.0
	tank.attack_interval = 1.5
	tank.attack_damage = 1.0
	tank.speed = 2.4
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true
	_aim(Vector3(-14.2, 0.6, -0.8), 11.5)

func _dress_stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.55, 0.72)
	sky_mat.sky_horizon_color = Color(0.78, 0.76, 0.68)
	sky_mat.ground_horizon_color = Color(0.5, 0.46, 0.38)
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(160, 160)
	ground.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.28, 0.16)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)
	var road: MeshInstance3D = MeshInstance3D.new()
	var strip: PlaneMesh = PlaneMesh.new()
	strip.size = Vector2(5, 60)
	road.mesh = strip
	var dirt: StandardMaterial3D = StandardMaterial3D.new()
	dirt.albedo_color = Color(0.38, 0.31, 0.22)
	dirt.roughness = 1.0
	road.material_override = dirt
	road.position = Vector3(3, 0.01, 0)
	add_child(road)

func _spawn(kind: StringName, role: String, loco: String, at: Vector3, team: int, primary: Color, trim: Color) -> RTSUnit:
	var u: RTSUnit = RTSUnit.new()
	u.name = "%s_%d" % [kind, units.size()]
	u.unit_type = kind
	u.team = team
	u.max_hp = 80.0
	add_child(u)
	u.hp = u.max_hp
	u.position = at
	var body: MeshInstance3D = Forms.dress_unit(str(kind), role, loco, trim, primary, trim)
	u.add_child(body)
	Motion.attach(u, body)
	u.fired.connect(_note_shot)
	units.append(u)
	return u

func _note_shot(u: RTSUnit, _target: RTSUnit) -> void:
	fired_events.append(str(u.unit_type))
	if u == tank and t > 20.0 and not taken.has("06-tank-fire"):
		fire_still = true

func _aim(focus: Vector3, dist: float) -> void:
	var dir: Vector3 = Vector3(0.38, 0.78, 0.5).normalized()
	cam.global_position = focus + dir * dist
	cam.look_at(focus, Vector3.UP)

func _glide(focus: Vector3, dist: float, seconds: float) -> void:
	var dir: Vector3 = Vector3(0.38, 0.78, 0.5).normalized()
	var to: Vector3 = focus + dir * dist
	var from: Vector3 = cam.global_position
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		cam.global_position = from.lerp(to, k)
		cam.look_at(focus.lerp(focus, k), Vector3.UP), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _at(when: float, delta: float) -> bool:
	return t >= when and t - delta < when

func _process(delta: float) -> void:
	t += delta
	_script(delta)
	var alive: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if not is_instance_valid(u):
			continue
		if not u.is_alive():
			u.queue_free()
			continue
		u.advance(delta)
		Forms.animate(u, delta)
		alive.append(u)
	units = alive
	_snap()
	if t >= LENGTH:
		get_tree().quit()

func _script(delta: float) -> void:
	if _at(2.2, delta):
		militia.set_path(PackedVector3Array([Vector3(-15.2, 0, -0.4)]))
		trooper.set_path(PackedVector3Array([Vector3(-13.0, 0, 0.0)]))
	if _at(5.6, delta):
		militia.attack_target = ifv
		trooper.attack_target = ifv
	if _at(8.0, delta):
		ifv.attack_target = militia
	if _at(10.0, delta) and is_instance_valid(militia):
		ifv.attack_target = trooper
	if _at(13.6, delta):
		_glide(Vector3(0.5, 0.5, 2.0), 16.0, 1.6)
	if _at(14.2, delta):
		tank.set_path(PackedVector3Array([Vector3(3, 0, 4), Vector3(3, 0, 0)]))
		tank.attack_target = foe
	if _at(17.6, delta):
		tank.attack_range = 30.0
	if _at(23.6, delta) and is_instance_valid(tank):
		tank.attack_target = null
		tank.take_damage(99999.0)
	if _at(26.0, delta):
		_glide(Vector3(16, 1.0, 0), 9.0, 1.4)
	if _at(27.4, delta):
		barracks = World.slab(self, "Built_barracks", SMPointer.building_at(Vector3(16, 0, 0)), SMPointer.BUILDING_SIZE, GTFC_AMBER)
	if _at(31.6, delta):
		BuildingFx.set_health(barracks, 0.55)
	if _at(33.0, delta):
		BuildingFx.set_health(barracks, 0.25)
	if _at(35.2, delta):
		barracks.visible = false

func _snap() -> void:
	if stills_dir == "":
		return
	if fire_still and not taken.has("06-tank-fire"):
		if bool(get_meta("fire_wait", false)):
			taken["06-tank-fire"] = true
			get_viewport().get_texture().get_image().save_png(stills_dir.path_join("06-tank-fire.png"))
		set_meta("fire_wait", true)
	for key: String in SHOTS.keys():
		if taken.has(key) or t < float(SHOTS[key]):
			continue
		taken[key] = true
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(stills_dir.path_join("%s.png" % key))
