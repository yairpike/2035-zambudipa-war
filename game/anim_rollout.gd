extends Node3D
## Animation rollout preview. Every faction's roster cycles through its actions on real RTSUnit nodes, then an
## 8-direction walk with live facing error, close-ups of infantry firing, and three buildings collapsing by material.
## Run: godot --path . --rendering-driver opengl3 --resolution 1920x1080 --write-movie out.avi --fixed-fps 30 \
##   res://game/anim_rollout.tscn -- --stills=/dir

const Forms = preload("res://game/unit_meshes.gd")
const Motion = preload("res://game/unit_motion.gd")
const BuildingFx = preload("res://game/building_fx.gd")
const World = preload("res://game/world_view.gd")
const Catalog = preload("res://game/model_catalog.gd")

const FACTIONS: PackedStringArray = ["gtfc", "mvd", "nmrf", "black_market"]
const FACTION_NAMES: Dictionary = {"gtfc": "GTFC", "mvd": "MVD", "nmrf": "NMRF", "black_market": "Black Market"}
const GRID_TIME: float = 14.0
## (start, action) pairs inside one faction grid.
const GRID_BEATS: Array = [[0.0, "idle"], [2.0, "walk"], [4.6, "run"], [6.8, "shoot"], [9.4, "ability"], [11.2, "flinch"], [12.2, "die"]]
const COMPASS: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const LEG_TIME: float = 1.5
const WALK_SPEED: float = 2.6
const CLOSE_IDS: PackedStringArray = ["militia", "olive_ranger", "clearance_trooper", "ruby_lancer"]
const CLOSE_TIME: float = 2.4
const RUINS: PackedStringArray = ["bamboo_hide", "barracks", "mvd_war_factory"]

var t: float = 0.0
var act: int = -1
var act_t: float = 0.0
var acts: Array[Dictionary] = []
var cam: Camera3D
var title: Label
var caption: Label
var units: Array[RTSUnit] = []
var dummy: RTSUnit
var stills_dir: String = ""
var only: String = ""
var close_ids: PackedStringArray = CLOSE_IDS
var shots: Array[Dictionary] = []
var beat: String = ""
var walkers: Array[RTSUnit] = []
var leg: int = -1
var tags: Dictionary = {}
var errors: Dictionary = {}
var close_unit: RTSUnit
var ruins: Array[MeshInstance3D] = []

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="):
			stills_dir = arg.trim_prefix("--stills=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--close="):
			close_ids = PackedStringArray(arg.trim_prefix("--close=").split(",", false))
	get_window().size = Vector2i(1280, 720)
	_dress_stage()
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	_hud()
	for i: int in FACTIONS.size():
		acts.append({"name": "grid", "faction": FACTIONS[i], "length": GRID_TIME, "origin": Vector3(220.0 * float(i), 0, 0)})
	acts.append({"name": "compass", "length": LEG_TIME * 8.0 + 2.6, "origin": Vector3(0, 0, 220)})
	for i: int in close_ids.size():
		acts.append({"name": "close", "id": close_ids[i], "length": CLOSE_TIME, "origin": Vector3(220.0 + 30.0 * float(i), 0, 220)})
	acts.append({"name": "ruins", "length": 24.0, "origin": Vector3(0, 0, 440)})
	if only != "":
		acts = acts.filter(func(a: Dictionary) -> bool: return str(a["name"]) == only or str(a.get("faction", "")) == only or str(a.get("id", "")) == only)

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
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	ground.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.13)
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(300, 0, 300)
	add_child(ground)

func _hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	title = _label(layer, 46, Vector2(48, 32))
	caption = _label(layer, 34, Vector2(48, 96))

func _label(layer: CanvasLayer, size: int, at: Vector2) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.position = at
	layer.add_child(l)
	return l

func _faction_units(faction: String) -> Array:
	var data: Dictionary = SMCatalog.faction(faction)
	var raw: Variant = data.get("units", [])
	return raw as Array if raw is Array else []

func _colors(faction: String) -> Array[Color]:
	var c: Dictionary = SMCatalog.faction(faction).get("colors", {}) as Dictionary
	return [Color(str(c.get("primary_hex", "#888888"))), Color(str(c.get("accent_hex", "#DDDDDD")))]

func _spawn(id: String, role: String, loco: String, at: Vector3, team: int, ink: Array[Color]) -> RTSUnit:
	var u: RTSUnit = RTSUnit.new()
	u.name = "%s_%d" % [id, units.size()]
	u.unit_type = StringName(id)
	u.team = team
	u.max_hp = 100000.0
	add_child(u)
	u.hp = u.max_hp
	u.position = at
	u.set_meta("locomotion", loco)
	var body: MeshInstance3D = Forms.dress_unit(id, role, loco, ink[1], ink[0], ink[1])
	u.add_child(body)
	Motion.attach(u, body)
	units.append(u)
	return u

func _tag(u: RTSUnit, text: String, size: int = 40) -> Label3D:
	var tag: Label3D = Label3D.new()
	tag.text = text
	tag.font_size = size
	tag.pixel_size = 0.011
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.98, 0.95, 0.86)
	tag.outline_size = 10
	tag.no_depth_test = true
	tag.position = u.position + Vector3(0, 0.05, 2.1)
	add_child(tag)
	return tag

func _aim(focus: Vector3, dir: Vector3, dist: float) -> void:
	cam.global_position = focus + dir.normalized() * dist
	cam.look_at(focus, Vector3.UP)

func _process(delta: float) -> void:
	t += delta
	act_t += delta
	if act < 0 or act_t >= float(acts[act]["length"]):
		_next_act()
	_step_act(delta)
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
	for u: Variant in tags.keys():
		var tag: Label3D = tags[u] as Label3D
		if is_instance_valid(u) and is_instance_valid(tag) and not walkers.has(u):
			tag.position = (u as Node3D).position + Vector3(0, 0.05, 2.1)
	_snap()

func _next_act() -> void:
	_clear_units()
	act += 1
	act_t = 0.0
	beat = ""
	Engine.time_scale = 1.0
	if act >= acts.size():
		get_tree().quit()
		return
	var a: Dictionary = acts[act]
	var kind: String = str(a["name"])
	if kind == "grid":
		_begin_grid(a)
	elif kind == "compass":
		_begin_compass(a)
	elif kind == "close":
		_begin_close(a)
	elif kind == "ruins":
		_begin_ruins(a)

func _clear_units() -> void:
	for u: RTSUnit in units:
		if is_instance_valid(u):
			u.queue_free()
	units.clear()
	walkers.clear()
	for tag: Variant in tags.values():
		if is_instance_valid(tag):
			(tag as Node).queue_free()
	tags.clear()
	if dummy != null and is_instance_valid(dummy):
		dummy.queue_free()
	dummy = null

func _step_act(delta: float) -> void:
	if act < 0 or act >= acts.size():
		return
	var a: Dictionary = acts[act]
	var kind: String = str(a["name"])
	if kind == "grid":
		_step_grid(a)
	elif kind == "compass":
		_step_compass(a)
	elif kind == "close":
		_step_close(a, delta)
	elif kind == "ruins":
		_step_ruins(a)

# --- Faction grids ---------------------------------------------------------------------------------

func _begin_grid(a: Dictionary) -> void:
	var faction: String = str(a["faction"])
	var origin: Vector3 = a["origin"]
	var roster: Array = _faction_units(faction)
	var ink: Array[Color] = _colors(faction)
	var cols: int = 6
	var rows: int = int(ceil(float(roster.size()) / float(cols)))
	for i: int in roster.size():
		var item: Dictionary = roster[i] as Dictionary
		var id: String = str(item.get("id", ""))
		var role: String = str(item.get("role", "infantry"))
		var loco: String = str(item.get("locomotion", "ground"))
		var col: int = i % cols
		var row: int = i / cols
		var at: Vector3 = origin + Vector3((float(col) - 2.5) * 5.2, 0.0, (float(row) - float(rows - 1) * 0.5) * 6.0)
		var u: RTSUnit = _spawn(id, role, loco, at, 0, ink)
		u.speed = WALK_SPEED
		u.attack_range = 200.0
		u.attack_interval = 0.55
		u.attack_damage = 0.0
		u.set_meta("ability", str(item.get("ability", "")))
		u.set_meta("home", at)
		tags[u] = _tag(u, id.replace("_", " "))
	dummy = RTSUnit.new()
	dummy.name = "Target"
	dummy.team = 1
	dummy.max_hp = 1e9
	add_child(dummy)
	dummy.hp = dummy.max_hp
	dummy.position = origin + Vector3(0, 0, 40)
	title.text = "%s · %d units" % [FACTION_NAMES[faction], roster.size()]
	_aim(origin + Vector3(0.0, 0.4, 0.8), Vector3(0.0, 0.58, 1.0), 31.0 if rows >= 3 else 25.0)

func _step_grid(a: Dictionary) -> void:
	var now: String = "idle"
	for pair: Array in GRID_BEATS:
		if act_t >= float(pair[0]):
			now = str(pair[1])
	if now == beat:
		return
	beat = now
	caption.text = "action: %s" % now
	for u: RTSUnit in units:
		if not is_instance_valid(u) or u == dummy:
			continue
		var home: Vector3 = u.get_meta("home", u.position)
		if now == "walk":
			u.speed = WALK_SPEED
			u.set_path(PackedVector3Array([home + Vector3(3.2, 0, 0)]))
		elif now == "run":
			u.speed = 7.0
			u.set_path(PackedVector3Array([home]))
		elif now == "shoot":
			u.stop()
			u.speed = WALK_SPEED
			u.attack_target = dummy
		elif now == "ability":
			u.attack_target = null
			_cast(u)
		elif now == "flinch":
			_clear_ability(u)
			u.take_damage(1.0)
		elif now == "die":
			u.take_damage(1e9)

## Mirrors the metas SMCast.apply sets that change how a unit moves, then starts the cooldown the view watches for.
func _cast(u: RTSUnit) -> void:
	var name: String = str(u.get_meta("ability", ""))
	if name == "Slag Jump Thruster":
		u.set_meta("jump", true)
	elif name in ["Last-Stand Ram", "Magnetic Hull Breach", "Electro-Latch Detonate"]:
		u.set_meta("ram", true)
	elif name in ["Monsoon Bull-Charge", "Sprint Skates"]:
		u.set_meta("charge", true)
	elif name == "Magnetic Harpoon Grinder":
		u.set_meta("harpoon", true)
	elif name in ["Ramming Hydro-Shield", "Nano-Deflector Barrier", "Ballistic Riot Shield"]:
		u.set_meta("shielded", true)
	elif name == "Aegis Dome":
		u.set_meta("aegis", true)
	elif name == "Chemical Afterburner":
		u.set_meta("afterburner", true)
	elif name in ["Jet Interceptor", "Chopper Mode", "Afterburner Return", "Submersible or Sky-Jet"]:
		u.set_meta("chopper", true)
		u.set_meta("locomotion", "air")
	elif name == "Land Legs":
		u.set_meta("legs", true)
		u.set_meta("locomotion", "ground")
	elif name in ["Salvage Leech Beam", "Fiber-Optic Tether", "Electro-Stasis Tether", "Artillery Telemetry Link", "Target Painter", "Laser Target Lock", "Satellite Laser Designation"]:
		u.set_meta("beam_kind", "beam")
	u.set_meta("f_ready", 9.0)

func _clear_ability(u: RTSUnit) -> void:
	for key: String in ["jump", "ram", "charge", "harpoon", "shielded", "aegis", "afterburner", "chopper", "legs", "beam_kind"]:
		if u.has_meta(key):
			u.remove_meta(key)
	u.set_meta("f_ready", 0.0)

# --- 8-direction walk ------------------------------------------------------------------------------

func _begin_compass(a: Dictionary) -> void:
	var origin: Vector3 = a["origin"]
	title.text = "8-direction walk · drawn forward vs move vector"
	var picks: Array = [["militia", "infantry", "ground", "gtfc"], ["clearance_trooper", "infantry", "ground", "mvd"], ["cyan_sentry", "infantry", "ground", "mvd"], ["amber_tank", "armor", "ground", "gtfc"]]
	var side: float = WALK_SPEED * LEG_TIME
	var radius: float = side / (2.0 * sin(PI / 8.0))
	var start: Vector3 = Vector3(-radius * cos(PI / 8.0), 0, side * 0.5)
	for i: int in picks.size():
		var p: Array = picks[i]
		var centre: Vector3 = origin + Vector3((float(i % 2) - 0.5) * 14.5, 0, (float(i / 2) - 0.5) * 13.0)
		_rose(centre, radius * 0.72)
		var u: RTSUnit = _spawn(str(p[0]), str(p[1]), str(p[2]), centre + start, 0, _colors(str(p[3])))
		u.speed = WALK_SPEED
		walkers.append(u)
		tags[u] = _tag(u, str(p[0]).replace("_", " "), 44)
	leg = -1
	_aim(origin + Vector3(0, 0, -1.2), Vector3(0.0, 1.0, 0.3), 41.0)

func _rose(centre: Vector3, reach: float) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.76, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i: int in COMPASS.size():
		var ang: float = float(i) * PI / 4.0
		var dir: Vector3 = Vector3(sin(ang), 0, -cos(ang))
		var spoke: MeshInstance3D = MeshInstance3D.new()
		var bar: BoxMesh = BoxMesh.new()
		bar.size = Vector3(0.08, 0.02, reach if i % 2 == 0 else reach * 0.8)
		spoke.mesh = bar
		spoke.material_override = mat
		add_child(spoke)
		spoke.position = centre + dir * bar.size.z * 0.5 + Vector3(0, 0.02, 0)
		spoke.rotation.y = atan2(-dir.x, -dir.z)
		var letter: Label3D = Label3D.new()
		letter.text = COMPASS[i]
		letter.font_size = 64 if i % 2 == 0 else 44
		letter.pixel_size = 0.01
		letter.modulate = Color(0.95, 0.88, 0.6)
		letter.outline_size = 12
		letter.rotation_degrees = Vector3(-90, 0, 0)
		add_child(letter)
		letter.position = centre + dir * (bar.size.z + 0.5) + Vector3(0, 0.05, 0)

func _step_compass(_a: Dictionary) -> void:
	var now: int = int(floor((act_t - 0.6) / LEG_TIME))
	if act_t < 0.6:
		caption.text = "ready"
		return
	if now >= COMPASS.size():
		caption.text = "back at the start"
		for u: RTSUnit in walkers:
			if is_instance_valid(u):
				u.stop()
		_measure()
		return
	if now != leg:
		leg = now
		var ang: float = float(leg) * PI / 4.0
		var dir: Vector3 = Vector3(sin(ang), 0, -cos(ang))
		for u: RTSUnit in walkers:
			if is_instance_valid(u):
				u.set_path(PackedVector3Array([u.position + dir * WALK_SPEED * LEG_TIME]))
				u.set_meta("move_dir", dir)
	caption.text = "walking %s" % COMPASS[leg]
	_measure()

## Labels each walker with the angle between the forward drawn from its own skeleton (or hull) and its move vector.
func _measure() -> void:
	for u: RTSUnit in walkers:
		if not is_instance_valid(u):
			continue
		var tag: Label3D = tags.get(u) as Label3D
		var body: Node3D = u.get_node_or_null("Body") as Node3D
		if tag == null or body == null:
			continue
		tag.position = u.position + Vector3(0, 2.8, 0)
		var move: Vector3 = u.get_meta("move_dir", Vector3.FORWARD)
		var err: float = rad_to_deg(absf(Motion.rendered_forward(body).signed_angle_to(move, Vector3.UP)))
		tag.text = "%s  %s %.0f°" % [str(u.unit_type).replace("_", " "), "Δ", err]
		tag.modulate = Color(0.6, 1.0, 0.6) if err <= 15.0 else Color(1.0, 0.5, 0.4)

# --- Firing close-ups -------------------------------------------------------------------------------

func _begin_close(a: Dictionary) -> void:
	var origin: Vector3 = a["origin"]
	var id: String = str(a["id"])
	var faction: String = "gtfc"
	var role: String = "infantry"
	for f: String in FACTIONS:
		for item: Variant in _faction_units(f):
			if item is Dictionary and str((item as Dictionary).get("id", "")) == id:
				faction = f
				role = str((item as Dictionary).get("role", role))
	close_unit = _spawn(id, role, "ground", origin, 0, _colors(faction))
	close_unit.attack_range = 200.0
	close_unit.attack_interval = 0.42
	close_unit.attack_damage = 0.0
	close_unit.rotation.y = -PI * 0.5
	dummy = RTSUnit.new()
	dummy.name = "Target"
	dummy.team = 1
	dummy.max_hp = 1e9
	add_child(dummy)
	dummy.hp = dummy.max_hp
	dummy.position = origin + Vector3(30, 0, 0)
	Engine.time_scale = 0.5
	title.text = "Firing close-up · %s" % id.replace("_", " ")
	caption.text = "rigid weapon on the hand socket · flash and recoil at the muzzle · half speed"
	var tall: float = _height_of(close_unit)
	var k: float = 1.0 if tall > 1.2 and tall < 2.0 else clampf(tall / 1.75, 0.5, 2.5)
	var lift: float = maxf(0.85 * k, 0.55 * tall) if tall >= 2.0 else 0.85 * k
	_aim(origin + Vector3(0.45 * k, lift, 0), Vector3(0.3, 0.22, 1.0), 3.1 * k * (1.15 if tall >= 2.0 else 1.0))

## Outside the modifier pass the skeleton reports the clip's pose, so the off hand's rendered gap to its grip is
## sampled when the skeleton finishes updating.
func _watch_grip() -> void:
	if not is_instance_valid(close_unit):
		return
	var ik: OffHandIK = close_unit.find_child("OffHandIK", true, false) as OffHandIK
	if ik == null or ik.target == null or ik.has_meta("rendered_gap"):
		return
	ik.set_meta("rendered_gap", -1.0)
	var skel: Skeleton3D = ik.get_skeleton()
	skel.skeleton_updated.connect(func() -> void:
		if is_instance_valid(ik) and is_instance_valid(ik.target):
			var hand: Vector3 = skel.global_transform * skel.get_bone_global_pose(ik.hand).origin
			ik.set_meta("rendered_gap", hand.distance_to(ik.target.global_position)))

func _height_of(u: Node3D) -> float:
	var top: float = 0.0
	for node: Node in u.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh != null and mi.visible:
			var box: AABB = mi.global_transform * mi.mesh.get_aabb()
			top = maxf(top, box.end.y - u.global_position.y)
	return top if top > 0.1 else 1.75

func _step_close(_a: Dictionary, _delta: float) -> void:
	_watch_grip()
	if act_t >= 0.25 and is_instance_valid(close_unit) and close_unit.attack_target == null:
		close_unit.attack_target = dummy

# --- Building collapses -----------------------------------------------------------------------------

func _begin_ruins(a: Dictionary) -> void:
	var origin: Vector3 = a["origin"]
	ruins.clear()
	title.text = "Buildings · rise, working, damage, collapse by material"
	for i: int in RUINS.size():
		var id: String = RUINS[i]
		var at: Vector3 = origin + Vector3((float(i) - 1.0) * 11.0, 0, 0)
		var size: Vector3 = SMPointer.BUILDING_SIZE * 2.0
		var mi: MeshInstance3D = World.slab(self, "Built_%s" % id, Vector3(at.x, size.y * 0.5, at.z), size, Color(0.6, 0.5, 0.4))
		ruins.append(mi)
		var tag: Label3D = Label3D.new()
		tag.text = "%s · %s" % [id.replace("_", " "), " + ".join(Catalog.materials_of(id))]
		tag.font_size = 48
		tag.pixel_size = 0.01
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.outline_size = 12
		tag.position = at + Vector3(0, 0.3, 5.8)
		add_child(tag)
	_aim(origin + Vector3(0, 2.0, 1.0), Vector3(0.0, 0.55, 1.0), 29.0)

func _step_ruins(a: Dictionary) -> void:
	var origin: Vector3 = a["origin"]
	var stages: Array = [[0.0, "construction: scaffold and rise"], [3.6, "working loop"], [6.0, "damaged: smoke"], [7.4, "badly damaged: fire"],
		[9.0, "bamboo hide collapses: thatch embers, bamboo poles, timber splinters"], [13.6, "brick barracks collapses: brick dust, timber splinters"],
		[18.2, "steel and glass factory collapses: sparks, shattered glass"], [22.2, "rubble in each building's own palette"]]
	var now: String = ""
	var idx: int = 0
	for i: int in stages.size():
		if act_t >= float(stages[i][0]):
			now = str(stages[i][1])
			idx = i
	if now == beat:
		return
	beat = now
	caption.text = now
	if idx == 2:
		for mi: MeshInstance3D in ruins:
			BuildingFx.set_health(mi, 0.55)
	elif idx == 3:
		for mi: MeshInstance3D in ruins:
			BuildingFx.set_health(mi, 0.25)
	elif idx >= 4 and idx <= 6:
		var mi: MeshInstance3D = ruins[idx - 4]
		mi.visible = false
		var at: Vector3 = origin + Vector3((float(idx - 4) - 1.0) * 11.0, 0, 0)
		_aim(at + Vector3(0, 1.6, 0), Vector3(0.25, 0.5, 1.0), 14.0)
	elif idx == 7:
		_aim(origin + Vector3(0, 0.8, 1.0), Vector3(0.0, 0.7, 1.0), 27.0)

# --- Stills ------------------------------------------------------------------------------------------

func _snap() -> void:
	if stills_dir == "" or act < 0 or act >= acts.size():
		return
	var a: Dictionary = acts[act]
	var kind: String = str(a["name"])
	var marks: Array = []
	if kind == "grid":
		var f: String = str(a["faction"])
		marks = [[3.6, "grid-%s-walk" % f], [8.4, "grid-%s-shoot" % f], [10.3, "grid-%s-ability" % f]]
	elif kind == "compass":
		marks = [[0.6 + LEG_TIME * 1.6, "compass-NE"], [0.6 + LEG_TIME * 5.6, "compass-SW"]]
	elif kind == "close":
		marks = [[0.2, "ready-%s" % str(a["id"])], [1.6, "fire-%s" % str(a["id"])]]
	elif kind == "ruins":
		marks = [[2.2, "bldg-rise"], [8.6, "bldg-fire"], [10.0, "collapse-bamboo"], [14.6, "collapse-brick"], [19.2, "collapse-steel-glass"], [23.6, "rubble"]]
	for pair: Array in marks:
		var key: String = str(pair[1])
		if act_t < float(pair[0]) or shots.any(func(s: Dictionary) -> bool: return str(s["key"]) == key):
			continue
		shots.append({"key": key})
		get_viewport().get_texture().get_image().save_png(stills_dir.path_join("%s.png" % key))
		if kind == "close" and is_instance_valid(close_unit):
			var ik: OffHandIK = close_unit.find_child("OffHandIK", true, false) as OffHandIK
			if ik != null and ik.has_meta("rendered_gap"):
				print("STILL %s off hand to grip %.3f m (IK influence %.2f)" % [key, float(ik.get_meta("rendered_gap")), ik.influence])
