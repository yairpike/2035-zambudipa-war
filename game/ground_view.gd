extends RefCounted
## Terrain from a domain grid. Pathing flags are not changed.
## Land is one mesh, water is one shaded mesh, plants and houses are MultiMeshes.

const WATER_SHADER = preload("res://game/shaders/channel_water.gdshader")
const RAIN_SHADER = preload("res://game/shaders/monsoon_rain.gdshader")
const Settings = preload("res://game/match_settings.gd")
const Art = preload("res://game/served_art.gd")
const Env = preload("res://game/env_dress.gd")
const RAIN_CAP: int = 24
const TREE_REACH: float = 80.0
const CANOPY_MIN: float = 5.0

const GRASS: Color = Color(0.3, 0.46, 0.22)
const MUD: Color = Color(0.38, 0.29, 0.18)
const SAND: Color = Color(0.74, 0.66, 0.42)
const DIRT: Color = Color(0.5, 0.39, 0.24)
const ROCK: Color = Color(0.46, 0.44, 0.4)
const WOOD: Color = Color(0.42, 0.3, 0.18)
const LEAF: Color = Color(0.18, 0.4, 0.16)
const PADDY: Color = Color(0.42, 0.58, 0.28)
## Tripo scenery puts its street face on -Z, so a house facing yaw turns half round from its authored pose.
const FRONT_TURN: float = 180.0

static var _land_ink: StandardMaterial3D
static var _water_ink: ShaderMaterial
static var _rain_ink: ShaderMaterial
static var _site_ink: StandardMaterial3D
static var _prop_cache: Dictionary = {}
static var _plan: SMMapPlan
static var _keep: Rect2i = Rect2i()
static var _dressing: SMMapPlan

## A map plan draws its own roads and keeps scenery to cliffs and the margins, off plateaus, lanes and resources.
## Towns and orchards come from the plan, or from a campaign dressing: streets are road, every house squares to its street.
static func dress(host: Node3D, grid: SMDomainGrid, profile: String, plan: SMMapPlan = null, keep_clear: Rect2i = Rect2i(), dressing: SMMapPlan = null) -> void:
	if host == null or grid == null:
		return
	_plan = plan
	_keep = keep_clear
	_dressing = dressing
	var land_stem: String = "sand" if profile == "atolls" else "grass"
	var land: SurfaceTool = _begin(_ground(land_stem, profile != "atolls"))
	var mud: SurfaceTool = _begin(_ground("mud", false))
	var sand: SurfaceTool = _begin(_ground("sand", false))
	var road: SurfaceTool = _begin(_ground("road", false))
	var land_fade: SurfaceTool = _begin(_ground(land_stem, profile != "atolls", true))
	var mud_fade: SurfaceTool = _begin(_ground("mud", false, true))
	var sand_fade: SurfaceTool = _begin(_ground("sand", false, true))
	var road_fade: SurfaceTool = _begin(_ground("road", false, true))
	var water: SurfaceTool = _begin(_water_material())
	var paddy: SurfaceTool = _begin(_ground("paddy", false))
	var trees: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var houses: Array[Transform3D] = []
	var stilts: Array[Transform3D] = []
	var campaign: bool = profile == "kokang" or profile == "mission"
	var tree_cap: int = 28 if campaign else (16 if grid.cols < 24 else (160 if plan != null else 64))
	var palm_cap: int = 16 if campaign else (10 if grid.cols < 24 else (60 if plan != null else 36))
	var house_cap: int = 8 if campaign else (6 if grid.cols < 24 else 14)
	var land_n: int = 0
	var mud_n: int = 0
	var sand_n: int = 0
	var road_n: int = 0
	var land_fade_n: int = 0
	var mud_fade_n: int = 0
	var sand_fade_n: int = 0
	var road_fade_n: int = 0
	var water_n: int = 0
	var paddy_n: int = 0
	for y: int in grid.rows:
		for x: int in grid.cols:
			var cell: Vector2i = Vector2i(x, y)
			var domain: int = grid.domain_at_cell(cell)
			if _wet(domain):
				var deep: float = 1.0 if domain != SMDomainGrid.Domain.SHALLOW else 0.0
				_flat(water, grid, cell, -0.2 if deep > 0.5 else -0.08, Color(deep, 0.0, 0.0), 0.54)
				water_n += 1
				continue
			var high: float = 1.55 if domain == SMDomainGrid.Domain.CLIFF else 0.22
			var bank: bool = _bank(grid, cell)
			var track: bool = domain == SMDomainGrid.Domain.LAND and _track(profile, cell)
			var tint: Color = _tint(profile, cell, domain, bank, track)
			var kind: String = _kind(profile, tint, track, false)
			var shade: float = _vary(cell)
			var ink: Color = _ink(kind, tint, shade, 1.0)
			if kind == "road":
				_sloped(road, grid, cell, high, ink)
				road_n += 1
			elif kind == "sand":
				_sloped(sand, grid, cell, high, ink)
				sand_n += 1
			elif kind == "mud":
				_sloped(mud, grid, cell, high, ink)
				mud_n += 1
			else:
				_sloped(land, grid, cell, high, ink)
				land_n += 1
			var fade_kind: String = _blend(profile, grid, cell, kind, high, shade, land_fade, mud_fade, sand_fade, road_fade)
			if fade_kind.contains("land"):
				land_fade_n += 1
			if fade_kind.contains("mud"):
				mud_fade_n += 1
			if fade_kind.contains("sand"):
				sand_fade_n += 1
			if fade_kind.contains("road"):
				road_fade_n += 1
			if _plan != null:
				_scatter(grid, cell, domain, high, bank, trees, palms)
				var key: Vector2i = _plan.canon(cell)
				var field_roll: int = _hash(key.x, key.y)
				var paddy_ok: bool = domain == SMDomainGrid.Domain.LAND and not track and not bank and paddy_n < 64 and _plan.clear_of_props(cell)
				if paddy_ok and (profile == "mekong" and field_roll % 3 == 0 or field_roll % 23 == 1):
					var plan_shade: float = _vary(cell)
					_flat(paddy, grid, cell, high + 0.05, Color(plan_shade, plan_shade, plan_shade, 1.0))
					paddy_n += 1
				continue
			if domain != SMDomainGrid.Domain.LAND or _busy(profile, cell):
				continue
			if _dressing != null and not _dressing.clear_of_props(cell):
				continue
			var roll: int = _hash(x, y)
			if bank and roll % 7 == 0:
				palms.append(_xf(grid, cell, high, roll))
			elif not bank and roll % 11 == 0:
				trees.append(_xf(grid, cell, high, roll))
			if bank and roll % 17 == 3:
				stilts.append(_square(grid, cell, high, _to_water(grid, cell)))
			elif not bank and not track and roll % 37 == 4 and (_dressing == null or _dressing.lots.is_empty()):
				houses.append(_square(grid, cell, high, 0.0 if posmod(cell.y, 8) < 3 else 180.0))
			var rice: bool = profile == "mekong" and roll % 3 == 0 or roll % 23 == 1
			if rice and not track and not bank and paddy_n < 48 and not _bridge_cell(cell):
				var rice_shade: float = _vary(cell)
				_flat(paddy, grid, cell, high + 0.05, Color(rice_shade, rice_shade, rice_shade, 1.0))
				paddy_n += 1
	_commit(host, _land_name(profile), land, land_n > 0)
	_commit(host, "TerrainMud", mud, mud_n > 0)
	_commit(host, "TerrainSand", sand, sand_n > 0)
	_commit(host, _water_name(profile), water, water_n > 0)
	if profile == "burma":
		_commit(host, "Road", road, road_n > 0)
	elif road_n > 0:
		_commit(host, "TerrainRoad", road, true)
	if paddy_n > 0:
		_commit(host, "Paddy", paddy, true)
	_commit(host, "TerrainLandBlend", land_fade, land_fade_n > 0)
	_commit(host, "TerrainMudBlend", mud_fade, mud_fade_n > 0)
	_commit(host, "TerrainSandBlend", sand_fade, sand_fade_n > 0)
	_commit(host, "TerrainRoadBlend", road_fade, road_fade_n > 0)
	_multi(host, "JungleTrees", _prop("tree", profile), _spread(trees, tree_cap))
	_multi(host, "Palms", _prop("palm", profile), _spread(palms, palm_cap))
	_multi(host, "Houses", _prop("house", profile), _spread(houses, house_cap))
	_multi(host, "Stilts", _prop("stilt", profile), _spread(stilts, 10))
	_settle(host, grid, _plan if _plan != null else _dressing)
	_tag_prop(host, "JungleTrees", Env.tree_id(profile))
	_tag_prop(host, "Palms", Env.palm_id(profile))
	_tag_prop(host, "Houses", Env.house_id(profile))
	_tag_prop(host, "Stilts", "mekong_stilt_house" if profile == "mekong" or profile == "atolls" else "shan_stilt_house")
	host.set_meta("env_profile", profile)
	host.set_meta("env_grid", grid)
	host.set_meta("map_plan", "" if plan == null else plan.id)
	Env.pull_web(host, Env.wanted(profile, plan if plan != null else dressing))
	_markers(host, profile)
	_ocean_skirt(host, grid)
	_sky(host)
	Env.stamp(host, grid, profile)
	_plan = null
	_keep = Rect2i()
	_dressing = null

## One MultiMesh per model: "Town_<id>" for lots, "Orchard_<id>" for planted rows. Missing models fall back to boxes until the web pack lands.
static func _settle(host: Node3D, grid: SMDomainGrid, layout: SMMapPlan) -> void:
	if layout == null:
		return
	var built: Dictionary = {}
	for lot: Dictionary in layout.lots:
		var r: Rect2i = lot["rect"] as Rect2i
		var at: Vector3 = grid.origin + Vector3((float(r.position.x) + float(r.size.x) * 0.5) * grid.cell_size, 0.22, (float(r.position.y) + float(r.size.y) * 0.5) * grid.cell_size)
		_gather(built, "Town_%s" % lot["id"], Transform3D(Basis(Vector3.UP, deg_to_rad(float(lot["yaw"]) + FRONT_TURN)), at))
	for tree: Dictionary in layout.groves:
		var cell: Vector2i = tree["cell"] as Vector2i
		if not grid.in_bounds(cell) or grid.domain_at_cell(cell) != SMDomainGrid.Domain.LAND:
			continue
		var spot: Vector3 = grid.cell_center(cell)
		spot.y = 0.22
		_gather(built, "Orchard_%s" % tree["id"], Transform3D(Basis.IDENTITY, spot))
	for key: String in built:
		var model: String = key.substr(key.find("_") + 1)
		var mesh: Mesh = Env.mesh_of(model)
		if mesh == null:
			mesh = _prop("tree" if key.begins_with("Orchard_") else "house", "")
		var spots: Array[Transform3D] = []
		spots.assign(built[key] as Array)
		_multi(host, key, mesh, spots)
		_tag_prop(host, key, model)

static func _gather(built: Dictionary, key: String, xf: Transform3D) -> void:
	if not built.has(key):
		built[key] = []
	(built[key] as Array).append(xf)

static func _square(grid: SMDomainGrid, cell: Vector2i, high: float, yaw_deg: float) -> Transform3D:
	var at: Vector3 = grid.cell_center(cell)
	at.y = high
	return Transform3D(Basis(Vector3.UP, deg_to_rad(snappedf(yaw_deg, 90.0) + FRONT_TURN)), at)

## Stilt houses face the nearest water, squared to the bank.
static func _to_water(grid: SMDomainGrid, cell: Vector2i) -> float:
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for i: int in dirs.size():
		var next: Vector2i = cell + dirs[i]
		if grid.in_bounds(next) and _wet(grid.domain_at_cell(next)):
			return float(i) * 90.0
	return 0.0

## Planned maps: forest on cliffs, a fringe of trees along cliff feet and the margin. Houses only stand in towns.
static func _scatter(grid: SMDomainGrid, cell: Vector2i, domain: int, high: float, bank: bool, trees: Array[Transform3D], palms: Array[Transform3D]) -> void:
	if domain != SMDomainGrid.Domain.LAND and domain != SMDomainGrid.Domain.CLIFF:
		return
	if grid.holding(cell) or not _plan.clear_of_props(cell):
		return
	var key: Vector2i = _plan.canon(cell)
	var roll: int = _hash(key.x, key.y)
	if domain == SMDomainGrid.Domain.CLIFF:
		if roll % 5 == 0:
			palms.append(_xf(grid, cell, high, roll))
		elif roll % 3 == 0:
			trees.append(_xf(grid, cell, high, roll))
		return
	var margin: int = mini(mini(cell.x, cell.y), mini(grid.cols - 1 - cell.x, grid.rows - 1 - cell.y))
	var foot: bool = _near_cliff(grid, cell)
	if not foot and not bank and margin > 4:
		return
	if bank and roll % 4 == 0:
		palms.append(_xf(grid, cell, high, roll))
	elif roll % 4 == 1:
		trees.append(_xf(grid, cell, high, roll))

static func _near_cliff(grid: SMDomainGrid, cell: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var next: Vector2i = cell + Vector2i(dx, dy)
			if grid.in_bounds(next) and grid.domain_at_cell(next) == SMDomainGrid.Domain.CLIFF:
				return true
	return false

static func _ocean_skirt(host: Node3D, grid: SMDomainGrid) -> void:
	if host.get_node_or_null("OceanSkirt") != null:
		return
	var mesh: PlaneMesh = PlaneMesh.new()
	var span: float = maxf(float(grid.cols), float(grid.rows)) * grid.cell_size
	mesh.size = Vector2(span * 8.0, span * 8.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "OceanSkirt"
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.1, 0.14)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	var mid: Vector3 = grid.cell_center(Vector2i(int(grid.cols / 2), int(grid.rows / 2)))
	mi.position = Vector3(mid.x, -0.55, mid.z)
	host.add_child(mi)

static func dress_site(mi: MeshInstance3D, form: String, accent: Color) -> void:
	mi.mesh = _site(form, accent)
	mi.material_override = null
	mi.set_meta("form", form)

static func apply_sky(host: Node3D, sight: SMSight) -> void:
	if host == null or sight == null:
		return
	var env: WorldEnvironment = host.find_child("WorldEnvironment", false, false) as WorldEnvironment
	var low: bool = Settings.low()
	if env != null and env.environment != null:
		if low:
			env.environment.fog_enabled = false
		else:
			_fog(env.environment, sight)
	var rain: MeshInstance3D = host.get_node_or_null("Rain") as MeshInstance3D
	if rain == null and not low:
		rain = _rain(sight)
		host.add_child(rain)
	if rain != null:
		rain.visible = sight.monsoon and not low

static func _fog(env: Environment, sight: SMSight) -> void:
	if sight.hazy:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.0055
		env.fog_light_color = Color(0.68, 0.63, 0.52)
		env.fog_light_energy = 0.45
		env.fog_aerial_perspective = 0.12
	elif sight.monsoon:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = 0.004
		env.fog_light_color = Color(0.55, 0.58, 0.62)
		env.fog_light_energy = 0.45
		env.fog_aerial_perspective = 0.1
	else:
		env.fog_enabled = false

static func _land_name(profile: String) -> String:
	if profile == "sop":
		return "WestSector"
	if profile == "burma":
		return "HighlandWest"
	if profile == "atolls":
		return "WestIsle"
	if profile == "chiang":
		return "Plain"
	if profile == "mvd":
		return "CharcoalPad"
	if profile == "nmrf":
		return "OliveGround"
	if profile == "mission" or profile == "kokang":
		return "Ground"
	return "TerrainLand"

static func _water_name(profile: String) -> String:
	if profile == "sop":
		return "RiverStem"
	if profile == "atolls":
		return "Sea"
	if profile == "mekong":
		return "CanalWest"
	if profile == "chiang":
		return "SiegeRiver"
	if profile == "mvd":
		return "CyanRing"
	if profile == "nmrf":
		return "EmeraldWater"
	return "TerrainWater"

static func _markers(host: Node3D, profile: String) -> void:
	if profile == "sop":
		_ghost(host, "EastSector")
		_ghost(host, "NorthSector")
	elif profile == "chiang":
		_ghost(host, "WallWest")
	elif profile == "mekong":
		_ghost(host, "CanalEast")

static func _ghost(host: Node3D, node_name: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.visible = false
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	mi.mesh = box
	host.add_child(mi)

static func _wet(domain: int) -> bool:
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP or domain == SMDomainGrid.Domain.AIR

static func _bank(grid: SMDomainGrid, cell: Vector2i) -> bool:
	return _touches_water(grid, cell, -1, 0) or _touches_water(grid, cell, 1, 0) or _touches_water(grid, cell, 0, -1) or _touches_water(grid, cell, 0, 1)

static func _touches_water(grid: SMDomainGrid, cell: Vector2i, sx: int, sz: int) -> bool:
	if sx == 0 and sz == 0:
		return false
	var stepx: int = -1 if sx < 0 else (1 if sx > 0 else 0)
	var stepz: int = -1 if sz < 0 else (1 if sz > 0 else 0)
	var samples: Array[Vector2i] = [Vector2i(cell.x + stepx, cell.y), Vector2i(cell.x, cell.y + stepz), Vector2i(cell.x + stepx, cell.y + stepz)]
	for sample: Vector2i in samples:
		if stepx == 0 and sample.x != cell.x:
			continue
		if stepz == 0 and sample.y != cell.y:
			continue
		if _wet(grid.domain_at_cell(sample)):
			return true
	return false

static func _track(profile: String, cell: Vector2i) -> bool:
	if _plan != null:
		for r: Rect2i in _plan.roads:
			if r.has_point(cell):
				return true
		return _plan.on_street(cell)
	if _dressing != null and _dressing.on_street(cell):
		return true
	return cell.y % 8 == 3

static func _bridge_cell(cell: Vector2i) -> bool:
	if _plan != null:
		for row: Dictionary in _plan.sites:
			if (row["span"] as Rect2i).grow(1).has_point(cell):
				return true
	return false

static func _busy(profile: String, cell: Vector2i) -> bool:
	if _keep.has_point(cell):
		return true
	if profile == "phillips":
		var pad: Vector2i = SMDomainGrid.pad_of("phillips")
		if cell.y >= 7 + pad.y and cell.y <= 9 + pad.y and cell.x <= 14 + pad.x:
			return true
		if cell.x >= 29 + pad.x and cell.x <= 34 + pad.x and cell.y >= 10 + pad.y and cell.y <= 15 + pad.y:
			return true
	return false

static func _tint(profile: String, cell: Vector2i, domain: int, bank: bool, road: bool) -> Color:
	if domain == SMDomainGrid.Domain.CLIFF:
		return ROCK
	if road:
		return DIRT
	if profile == "atolls":
		return SAND
	if bank:
		var roll: int = _hash(cell.x + 3, cell.y + 9)
		return SAND if roll % 2 == 0 else MUD
	return GRASS

static func _hash(x: int, y: int) -> int:
	var n: int = x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return n & 2147483647

static func _xf(grid: SMDomainGrid, cell: Vector2i, high: float, roll: int) -> Transform3D:
	var at: Vector3 = grid.cell_center(cell)
	at.y = high
	var yaw: float = float(roll % 628) * 0.01
	return Transform3D(Basis(Vector3.UP, yaw), at)

static func _commit(host: Node3D, node_name: String, st: SurfaceTool, keep: bool) -> void:
	if not keep or node_name == "":
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	st.generate_normals()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)

## Keep props from both ends of a long map. Filling the cap from the north-west corner left the far shore bare.
static func _spread(spots: Array[Transform3D], cap: int) -> Array[Transform3D]:
	if cap <= 0 or spots.size() <= cap:
		return spots
	var out: Array[Transform3D] = []
	var step: float = float(spots.size()) / float(cap)
	var i: int = 0
	while out.size() < cap:
		out.append(spots[mini(spots.size() - 1, int(float(i) * step))])
		i += 1
	return out

static func _tag_prop(host: Node3D, node_name: String, id: String) -> void:
	var node: MultiMeshInstance3D = host.get_node_or_null(node_name) as MultiMeshInstance3D
	if node == null or id == "":
		return
	node.set_meta("env_id", id)
	if OS.has_feature("web") and not Env.has_mesh(id):
		node.set_meta("standin_held", true)
		node.visible = false

static func _multi(host: Node3D, node_name: String, mesh: Mesh, spots: Array[Transform3D]) -> void:
	if spots.is_empty():
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _fade_mesh(mesh)
	mm.instance_count = spots.size()
	for i: int in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.set_meta("all_spots", spots)
	node.name = node_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)

static func _begin(mat: Material) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	return st

static func _flat(st: SurfaceTool, grid: SMDomainGrid, cell: Vector2i, y: float, color: Color, cover: float = 0.46) -> void:
	var c: Vector3 = grid.cell_center(cell)
	var h: float = grid.cell_size * cover
	_quad(st, Vector3(c.x - h, y, c.z - h), Vector3(c.x + h, y, c.z - h), Vector3(c.x + h, y, c.z + h), Vector3(c.x - h, y, c.z + h), color)

static func _kind(profile: String, tint: Color, track: bool, cut: bool) -> String:
	if cut or track:
		return "road"
	if profile != "atolls" and tint == SAND:
		return "sand"
	if profile != "atolls" and (tint == MUD or tint == DIRT):
		return "mud"
	return "land"

static func _kind_at(profile: String, grid: SMDomainGrid, cell: Vector2i) -> String:
	var domain: int = grid.domain_at_cell(cell)
	if _wet(domain):
		return "water"
	var bank: bool = _bank(grid, cell)
	var track: bool = domain == SMDomainGrid.Domain.LAND and _track(profile, cell)
	var tint: Color = _tint(profile, cell, domain, bank, track)
	return _kind(profile, tint, track, false)

static func _vary(cell: Vector2i) -> float:
	return 0.88 + float(_hash(cell.x + 11, cell.y + 5) % 13) * 0.01

static func _ink(kind: String, tint: Color, shade: float, alpha: float) -> Color:
	if kind == "land" and tint == ROCK:
		return Color(tint.r * shade, tint.g * shade, tint.b * shade, alpha)
	return Color(shade, shade * 0.98, shade * 0.94, alpha)

static func _blend(profile: String, grid: SMDomainGrid, cell: Vector2i, kind: String, high: float, shade: float, land: SurfaceTool, mud: SurfaceTool, sand: SurfaceTool, road: SurfaceTool) -> String:
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var used: PackedStringArray = PackedStringArray()
	for dir: Vector2i in dirs:
		var next: Vector2i = cell + dir
		if next.x < 0 or next.y < 0 or next.x >= grid.cols or next.y >= grid.rows:
			continue
		var neighbor: String = _kind_at(profile, grid, next)
		if neighbor == kind or neighbor == "water":
			continue
		var tool: SurfaceTool = land
		if neighbor == "road":
			tool = road
		elif neighbor == "sand":
			tool = sand
		elif neighbor == "mud":
			tool = mud
		_fade(tool, grid, cell, high + 0.045, Color(shade, shade, shade, 1.0), dir)
		if not used.has(neighbor):
			used.append(neighbor)
	return ",".join(used)

static func _sky(host: Node3D) -> void:
	var env: WorldEnvironment = host.find_child("WorldEnvironment", false, false) as WorldEnvironment
	if env == null or env.environment == null:
		return
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.45, 0.62, 0.78)
	mat.sky_horizon_color = Color(0.78, 0.7, 0.56)
	mat.ground_bottom_color = Color(0.42, 0.58, 0.74)
	mat.ground_horizon_color = Color(0.74, 0.66, 0.52)
	mat.sun_angle_max = 28.0
	var sky := Sky.new()
	sky.sky_material = mat
	env.environment.sky = sky
	env.environment.background_mode = Environment.BG_SKY

static func _sloped(st: SurfaceTool, grid: SMDomainGrid, cell: Vector2i, high: float, color: Color) -> void:
	var c: Vector3 = grid.cell_center(cell)
	var h: float = grid.cell_size * 0.54
	var y00: float = _corner(grid, cell, -1, -1, high)
	var y10: float = _corner(grid, cell, 1, -1, high)
	var y11: float = _corner(grid, cell, 1, 1, high)
	var y01: float = _corner(grid, cell, -1, 1, high)
	_quad(st, Vector3(c.x - h, y00, c.z - h), Vector3(c.x + h, y10, c.z - h), Vector3(c.x + h, y11, c.z + h), Vector3(c.x - h, y01, c.z + h), color)

static func _corner(grid: SMDomainGrid, cell: Vector2i, sx: int, sz: int, high: float) -> float:
	if _touches_water(grid, cell, sx, sz):
		return 0.0
	return high

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_vert(st, a, color)
	_vert(st, b, color)
	_vert(st, c, color)
	_vert(st, a, color)
	_vert(st, c, color)
	_vert(st, d, color)

static func _vert(st: SurfaceTool, p: Vector3, color: Color) -> void:
	st.set_uv(Vector2(p.x, p.z) / 4.0)
	st.set_color(color)
	st.add_vertex(p)

static func _fade(st: SurfaceTool, grid: SMDomainGrid, cell: Vector2i, high: float, color: Color, dir: Vector2i) -> void:
	var c: Vector3 = grid.cell_center(cell)
	var h: float = grid.cell_size * 0.54
	var y00: float = _corner(grid, cell, -1, -1, high)
	var y10: float = _corner(grid, cell, 1, -1, high)
	var y11: float = _corner(grid, cell, 1, 1, high)
	var y01: float = _corner(grid, cell, -1, 1, high)
	var p00: Vector3 = Vector3(c.x - h, y00, c.z - h)
	var p10: Vector3 = Vector3(c.x + h, y10, c.z - h)
	var p11: Vector3 = Vector3(c.x + h, y11, c.z + h)
	var p01: Vector3 = Vector3(c.x - h, y01, c.z + h)
	var c00: Color = _fade_color(color, dir, -1, -1)
	var c10: Color = _fade_color(color, dir, 1, -1)
	var c11: Color = _fade_color(color, dir, 1, 1)
	var c01: Color = _fade_color(color, dir, -1, 1)
	_vert(st, p00, c00)
	_vert(st, p10, c10)
	_vert(st, p11, c11)
	_vert(st, p00, c00)
	_vert(st, p11, c11)
	_vert(st, p01, c01)

static func _fade_color(color: Color, dir: Vector2i, sx: int, sz: int) -> Color:
	var along: float = 0.0
	if dir.x != 0:
		along = 1.0 if sx == dir.x else 0.0
	else:
		along = 1.0 if sz == dir.y else 0.0
	return Color(color.r, color.g, color.b, color.a * along)

static func _box(st: SurfaceTool, c: Vector3, s: Vector3, color: Color) -> void:
	var hx: float = s.x * 0.5
	var hy: float = s.y * 0.5
	var hz: float = s.z * 0.5
	var x0: float = c.x - hx
	var x1: float = c.x + hx
	var y0: float = c.y - hy
	var y1: float = c.y + hy
	var z0: float = c.z - hz
	var z1: float = c.z + hz
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), color)
	_quad(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), color)
	_quad(st, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), color)
	_quad(st, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), color)
	_quad(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), color)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), color)

static func _land_material() -> StandardMaterial3D:
	if _land_ink == null:
		_land_ink = StandardMaterial3D.new()
		_land_ink.vertex_color_use_as_albedo = true
		_land_ink.roughness = 0.92
		_land_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _land_ink

static func _ground(stem: String, tint: bool, fade: bool = false) -> ShaderMaterial:
	var key: String = "ground:%s:%s:%s" % [stem, str(tint), str(fade)]
	if _prop_cache.has(key):
		return _prop_cache[key] as ShaderMaterial
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/ground_fade.gdshader" if fade else "res://game/shaders/ground_tile.gdshader")
	if fade:
		mat.render_priority = 2
	var tex: Texture2D = _terrain_tex(stem)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("use_tex", 1.0)
	if stem == "mud":
		mat.set_shader_parameter("contrast", 0.28)
		mat.set_shader_parameter("tone_mid", Color(0.32, 0.24, 0.15))
	_prop_cache[key] = mat
	return mat

static func _water_material() -> ShaderMaterial:
	if _water_ink == null:
		_water_ink = ShaderMaterial.new()
		_water_ink.shader = WATER_SHADER
	var shallow: Texture2D = _terrain_tex("shallow_water")
	var deep: Texture2D = _terrain_tex("deep_water")
	if shallow != null and deep != null:
		_water_ink.set_shader_parameter("shallow_tex", shallow)
		_water_ink.set_shader_parameter("deep_tex", deep)
		_water_ink.set_shader_parameter("use_tex", 1.0)
	return _water_ink

static func _site_material() -> StandardMaterial3D:
	if _site_ink == null:
		_site_ink = StandardMaterial3D.new()
		_site_ink.vertex_color_use_as_albedo = true
		_site_ink.roughness = 0.7
		_site_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _site_ink

static func _terrain_tex(stem: String) -> Texture2D:
	var rel: String = "res://game/terrain/%s.webp" % stem
	if ResourceLoader.exists(rel):
		var loaded: Resource = load(rel)
		if loaded is Texture2D:
			return loaded as Texture2D
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(rel)
	if bytes.is_empty():
		return Art.texture("terrain/%s.webp" % stem)
	var image := Image.new()
	if image.load_webp_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

static func _prop(kind: String, profile: String) -> Mesh:
	var key: String = "%s:%s" % [kind, profile]
	var env_id: String = ""
	if kind == "palm":
		env_id = Env.palm_id(profile)
	elif kind == "house":
		env_id = Env.house_id(profile)
	elif kind == "stilt":
		env_id = "mekong_stilt_house" if profile == "mekong" or profile == "atolls" else "shan_stilt_house"
	else:
		env_id = Env.tree_id(profile)
	var taken: Mesh = Env.mesh_of(env_id) if env_id != "" else null
	if taken != null:
		_prop_cache[key] = taken
		return taken
	if _prop_cache.has(key):
		return _prop_cache[key] as Mesh
	var st: SurfaceTool = _begin(_land_material())
	if kind == "palm":
		_palm(st)
	elif kind == "house":
		_house(st)
	elif kind == "stilt":
		_stilt(st)
	else:
		_tree(st)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_prop_cache[key] = mesh
	return mesh

## Used when the teak glb is not on disk yet. A tapered trunk and a crown of
## small clumps, so the stand-in is not one green cube.
static func fallback_tree() -> Mesh:
	var st: SurfaceTool = _begin(_land_material())
	_tree(st)
	st.generate_normals()
	return st.commit()

static func _tree(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.28, 0.0), Vector3(0.42, 0.16, 0.42), Color(0.28, 0.2, 0.1))
	_box(st, Vector3(0.0, 0.55, 0.0), Vector3(0.32, 0.5, 0.32), WOOD)
	_box(st, Vector3(0.02, 1.05, 0.0), Vector3(0.22, 0.55, 0.22), WOOD)
	_box(st, Vector3(0.04, 1.5, -0.02), Vector3(0.14, 0.42, 0.14), Color(0.32, 0.22, 0.12))
	_box(st, Vector3(0.28, 1.55, 0.05), Vector3(0.46, 0.08, 0.1), WOOD)
	_box(st, Vector3(-0.22, 1.48, -0.08), Vector3(0.4, 0.08, 0.1), WOOD)
	_box(st, Vector3(0.0, 1.85, 0.0), Vector3(0.55, 0.42, 0.5), LEAF)
	_box(st, Vector3(0.38, 1.72, 0.12), Vector3(0.42, 0.36, 0.38), Color(0.16, 0.36, 0.14))
	_box(st, Vector3(-0.34, 1.78, -0.1), Vector3(0.4, 0.34, 0.36), Color(0.2, 0.42, 0.16))
	_box(st, Vector3(0.08, 2.15, -0.28), Vector3(0.38, 0.32, 0.34), LEAF)
	_box(st, Vector3(-0.1, 2.18, 0.26), Vector3(0.36, 0.3, 0.32), Color(0.14, 0.38, 0.15))
	_box(st, Vector3(0.22, 2.28, 0.02), Vector3(0.32, 0.28, 0.3), Color(0.22, 0.46, 0.18))
	_box(st, Vector3(-0.16, 2.42, -0.04), Vector3(0.28, 0.26, 0.26), LEAF)
	_box(st, Vector3(0.02, 2.62, 0.0), Vector3(0.22, 0.22, 0.2), Color(0.26, 0.5, 0.2))

static func _palm(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.5, 0.0), Vector3(0.18, 1.0, 0.18), WOOD)
	_box(st, Vector3(0.12, 1.35, 0.0), Vector3(0.16, 0.9, 0.16), WOOD)
	_box(st, Vector3(0.2, 2.05, 0.0), Vector3(1.6, 0.08, 0.22), LEAF)
	_box(st, Vector3(0.2, 2.05, 0.0), Vector3(0.22, 0.08, 1.6), LEAF)

static func _house(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.55, 0.0), Vector3(1.5, 1.0, 1.2), Color(0.62, 0.5, 0.36))
	_box(st, Vector3(0.0, 1.15, 0.0), Vector3(1.7, 0.28, 1.4), Color(0.55, 0.22, 0.16))
	_box(st, Vector3(0.0, 0.4, -0.62), Vector3(0.35, 0.6, 0.06), WOOD)

static func _stilt(st: SurfaceTool) -> void:
	_box(st, Vector3(-0.45, 0.45, -0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(0.45, 0.45, -0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(-0.45, 0.45, 0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(0.45, 0.45, 0.35), Vector3(0.1, 0.9, 0.1), WOOD)
	_box(st, Vector3(0.0, 1.0, 0.0), Vector3(1.3, 0.12, 1.05), WOOD)
	_box(st, Vector3(0.0, 1.4, 0.0), Vector3(1.15, 0.6, 0.9), Color(0.55, 0.42, 0.28))
	_box(st, Vector3(0.0, 1.8, 0.0), Vector3(1.35, 0.16, 1.1), Color(0.45, 0.2, 0.14))

static func _site(form: String, accent: Color) -> ArrayMesh:
	var key: String = "%s|%s" % [form, accent.to_html(false)]
	if _prop_cache.has(key):
		return _prop_cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_site_material())
	if form == "cyber":
		_box(st, Vector3(0.0, 0.45, 0.0), Vector3(1.5, 0.9, 1.2), Color(0.22, 0.2, 0.28))
		_box(st, Vector3(0.0, 0.7, -0.62), Vector3(0.7, 0.4, 0.06), accent)
		_box(st, Vector3(0.45, 1.15, 0.0), Vector3(0.08, 0.7, 0.08), Color(0.7, 0.72, 0.75))
	elif form == "bazaar":
		_box(st, Vector3(0.0, 0.35, 0.0), Vector3(1.6, 0.7, 1.1), WOOD)
		_box(st, Vector3(0.0, 0.95, -0.15), Vector3(2.3, 0.1, 1.5), accent)
		_box(st, Vector3(-0.7, 0.5, -0.7), Vector3(0.08, 1.0, 0.08), WOOD)
		_box(st, Vector3(0.7, 0.5, -0.7), Vector3(0.08, 1.0, 0.08), WOOD)
	elif form == "garrison":
		_box(st, Vector3(0.0, 0.35, 0.0), Vector3(1.8, 0.7, 1.5), Color(0.55, 0.5, 0.42))
		_box(st, Vector3(0.0, 0.9, -0.7), Vector3(1.8, 0.45, 0.16), WOOD)
		_box(st, Vector3(-0.7, 1.15, 0.2), Vector3(0.08, 0.9, 0.08), WOOD)
		_box(st, Vector3(-0.7, 1.55, 0.2), Vector3(0.4, 0.22, 0.08), accent)
	elif form == "bridge":
		_box(st, Vector3(0.0, 0.0, 0.0), Vector3(2.4, 0.16, 1.0), WOOD)
		_box(st, Vector3(-1.05, 0.16, 0.0), Vector3(0.1, 0.18, 1.05), Color(0.3, 0.22, 0.14))
		_box(st, Vector3(1.05, 0.16, 0.0), Vector3(0.1, 0.18, 1.05), Color(0.3, 0.22, 0.14))
	elif form == "radar":
		_box(st, Vector3(0.0, 0.7, 0.0), Vector3(0.16, 1.4, 0.16), Color(0.35, 0.38, 0.42))
		_box(st, Vector3(0.0, 1.45, 0.1), Vector3(0.9, 0.08, 0.9), accent)
	elif form == "derrick":
		_box(st, Vector3(0.0, 1.0, 0.0), Vector3(0.22, 2.0, 0.22), Color(0.32, 0.3, 0.28))
		_box(st, Vector3(0.35, 1.7, 0.0), Vector3(0.7, 0.12, 0.12), accent)
	elif form == "salvage":
		_box(st, Vector3(-0.3, 0.25, 0.0), Vector3(0.7, 0.35, 1.2), Color(0.28, 0.26, 0.24))
		_box(st, Vector3(0.35, 0.4, 0.2), Vector3(0.5, 0.5, 0.7), accent)
	elif form == "clinic":
		_box(st, Vector3(0.0, 0.45, 0.0), Vector3(1.4, 0.8, 1.1), Color(0.82, 0.84, 0.86))
		_box(st, Vector3(0.0, 0.7, -0.56), Vector3(0.4, 0.4, 0.06), Color(0.7, 0.15, 0.18))
	else:
		_box(st, Vector3(0.0, 0.2, 0.0), Vector3(1.15, 0.28, 1.15), Color(0.34, 0.3, 0.24))
		_box(st, Vector3(0.0, 0.5, 0.0), Vector3(0.45, 0.45, 0.45), accent)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_prop_cache[key] = mesh
	return mesh

static func _rain(sight: SMSight) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Rain"
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = _rain_ink
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = RAIN_SHADER
		_rain_ink = mat
	var st: SurfaceTool = _begin(mat)
	var origin: Vector3 = Vector3(-40.0, 0.0, -30.0)
	var span: Vector3 = Vector3(80.0, 0.0, 60.0)
	if sight.grid != null:
		origin = sight.grid.origin
		span = Vector3(float(sight.grid.cols) * sight.grid.cell_size, 0.0, float(sight.grid.rows) * sight.grid.cell_size)
	for i: int in RAIN_CAP:
		var rx: float = float(_hash(i, 2) % 1000) / 1000.0
		var rz: float = float(_hash(3, i) % 1000) / 1000.0
		var at: Vector3 = origin + Vector3(rx * span.x, 12.0, rz * span.z)
		_box(st, at, Vector3(0.06, 7.0, 0.02), Color.WHITE)
	st.generate_normals()
	mi.mesh = st.commit()
	return mi

static var _cull_ms: int = 0
static var _cull_at: Vector3 = Vector3(99999.0, 0.0, 99999.0)
static var _cull_low: bool = false

static func cull_props(host: Node3D, cam: RTSCamera) -> void:
	if host == null:
		return
	var low: bool = Settings.low()
	var focus: Vector3 = cam.focus if cam != null else Vector3.ZERO
	var now: int = Time.get_ticks_msec()
	var moved: bool = Vector2(focus.x - _cull_at.x, focus.z - _cull_at.z).length() > 6.0
	var flipped: bool = low != _cull_low
	if flipped or low or moved or now - _cull_ms >= 300:
		_cull_ms = now
		_cull_at = focus
		_cull_low = low
		_cull_named(host, "JungleTrees", focus, low)
		_cull_named(host, "Palms", focus, low)
		_cull_named(host, "Houses", focus, low)
		_cull_named(host, "Stilts", focus, low)
		for child: Node in host.get_children():
			var mname: String = String(child.name)
			if mname.begins_with("Town_") or mname.begins_with("Orchard_"):
				_cull_named(host, mname, focus, low)
	if cam != null and not low:
		fade_occluders(host, cam)

## 0 is solid. 1 hides a tall prop whose crown crosses the segment from the camera to the ground.
## A camera sitting above the crown leaves the prop alone. Short props stay put.
static func view_fade(origin: Vector3, height: float, radius: float, eye: Vector3, aim: Vector3) -> float:
	if height < CANOPY_MIN:
		return 0.0
	if eye.y >= origin.y + height + 1.25:
		return 0.0
	var a: Vector2 = Vector2(eye.x, eye.z)
	var b: Vector2 = Vector2(aim.x, aim.z)
	var p: Vector2 = Vector2(origin.x, origin.z)
	var ab: Vector2 = b - a
	var denom: float = ab.length_squared()
	var t: float = 0.0
	if denom > 0.01:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	var dist: float = p.distance_to(closest)
	var reach: float = maxf(radius, 1.2)
	if dist >= reach:
		return 0.0
	var ray_y: float = lerpf(eye.y, aim.y, t)
	var top: float = origin.y + height
	if ray_y > top + 0.35:
		return 0.0
	var radial: float = clampf(1.0 - dist / reach, 0.0, 1.0)
	var climb: float = clampf((top + 0.35 - ray_y) / 3.0, 0.0, 1.0)
	return radial * radial * climb

static func fade_occluders(host: Node3D, cam: RTSCamera) -> void:
	if host == null or cam == null:
		return
	var eye: Vector3 = cam.global_position
	var aim: Vector3 = cam.focus
	for node_name: String in ["JungleTrees", "Palms", "Houses", "Stilts"]:
		_fade_multi(host.get_node_or_null(node_name) as MultiMeshInstance3D, eye, aim)
	for child: Node in host.get_children():
		var multi: MultiMeshInstance3D = child as MultiMeshInstance3D
		if multi != null:
			var mname: String = String(multi.name)
			if mname.begins_with("Town_") or mname.begins_with("Orchard_"):
				_fade_multi(multi, eye, aim)
				continue
		var node: Node3D = child as Node3D
		if node == null:
			continue
		var label: String = String(node.name)
		if label.begins_with("Landmark_") or label.begins_with("Scenery_"):
			_fade_placed(node, eye, aim)

static func _fade_mesh(mesh: Mesh) -> Mesh:
	var copy: Mesh = mesh.duplicate(true) as Mesh
	if copy == null:
		return mesh
	for surface: int in copy.get_surface_count():
		var mat: Material = copy.surface_get_material(surface)
		if mat is StandardMaterial3D:
			var ink: StandardMaterial3D = (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			ink.vertex_color_use_as_albedo = true
			ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			copy.surface_set_material(surface, ink)
	return copy

static func _fade_multi(node: MultiMeshInstance3D, eye: Vector3, aim: Vector3) -> void:
	if node == null or node.multimesh == null or node.multimesh.mesh == null:
		return
	var mm: MultiMesh = node.multimesh
	var shown: Array = node.get_meta("shown", [])
	if shown.is_empty():
		shown = node.get_meta("all_spots", [])
	if shown.is_empty():
		return
	var aabb: AABB = mm.mesh.get_aabb()
	var count: int = mini(mm.instance_count, shown.size())
	var fades: PackedFloat32Array = PackedFloat32Array()
	fades.resize(count)
	for i: int in count:
		var base: Transform3D = shown[i] as Transform3D
		var sc: Vector3 = base.basis.get_scale()
		var base_y: float = base.origin.y + aabb.position.y * sc.y
		var height: float = aabb.size.y * sc.y
		var radius: float = maxf(aabb.size.x * sc.x, aabb.size.z * sc.z) * 0.5
		var fade: float = view_fade(Vector3(base.origin.x, base_y, base.origin.z), height, radius, eye, aim)
		fades[i] = fade
		var keep: float = 1.0 - fade
		if keep < 0.04:
			keep = 0.001
		mm.set_instance_transform(i, Transform3D(base.basis.scaled(Vector3(keep, keep, keep)), base.origin))
		if mm.use_colors:
			mm.set_instance_color(i, Color(1.0, 1.0, 1.0, keep))
	node.set_meta("canopy_fade", fades)

static func _fade_placed(node: Node3D, eye: Vector3, aim: Vector3) -> void:
	var bounds: Vector3 = _canopy_bounds(node)
	var fade: float = view_fade(Vector3(node.global_position.x, bounds.z, node.global_position.z), bounds.y, bounds.x, eye, aim)
	if fade >= 0.95:
		if node.visible:
			node.visible = false
			node.set_meta("canopy_hold", true)
		return
	if node.has_meta("canopy_hold") and bool(node.get_meta("canopy_hold")):
		node.visible = true
		node.set_meta("canopy_hold", false)
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for item: Node in meshes:
		var mi: MeshInstance3D = item as MeshInstance3D
		if mi != null:
			mi.transparency = fade

static func _canopy_bounds(node: Node3D) -> Vector3:
	if node.has_meta("canopy_bounds"):
		return node.get_meta("canopy_bounds") as Vector3
	var top: float = node.global_position.y
	var bottom: float = node.global_position.y
	var radius: float = 0.0
	var found: bool = false
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for item: Node in meshes:
		var mi: MeshInstance3D = item as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf: Transform3D = mi.global_transform
		for corner: Vector3 in _aabb_corners(mi.mesh.get_aabb()):
			var world: Vector3 = xf * corner
			if not found:
				top = world.y
				bottom = world.y
				found = true
			else:
				top = maxf(top, world.y)
				bottom = minf(bottom, world.y)
			radius = maxf(radius, Vector2(world.x - node.global_position.x, world.z - node.global_position.z).length())
	var bounds: Vector3 = Vector3(radius, maxf(0.0, top - bottom), bottom)
	node.set_meta("canopy_bounds", bounds)
	return bounds

static func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	var out: Array[Vector3] = []
	out.append(p)
	out.append(p + Vector3(s.x, 0.0, 0.0))
	out.append(p + Vector3(0.0, s.y, 0.0))
	out.append(p + Vector3(0.0, 0.0, s.z))
	out.append(p + Vector3(s.x, s.y, 0.0))
	out.append(p + Vector3(s.x, 0.0, s.z))
	out.append(p + Vector3(0.0, s.y, s.z))
	out.append(p + s)
	return out

static func _cull_named(host: Node3D, node_name: String, focus: Vector3, hide: bool) -> void:
	var node: MultiMeshInstance3D = host.get_node_or_null(node_name) as MultiMeshInstance3D
	if node == null or node.multimesh == null:
		return
	if hide or bool(node.get_meta("standin_held", false)):
		node.visible = false
		return
	node.visible = true
	var all: Array = node.get_meta("all_spots", [])
	if all.is_empty():
		for i: int in node.multimesh.instance_count:
			all.append(node.multimesh.get_instance_transform(i))
		node.set_meta("all_spots", all)
	var keep: Array[Transform3D] = []
	for item: Variant in all:
		var xf: Transform3D = item as Transform3D
		if Vector2(xf.origin.x - focus.x, xf.origin.z - focus.z).length() <= TREE_REACH:
			keep.append(xf)
	node.multimesh.instance_count = keep.size()
	node.set_meta("shown", keep)
	for i: int in keep.size():
		node.multimesh.set_instance_transform(i, keep[i])
		if node.multimesh.use_colors:
			node.multimesh.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))
