class_name SMSight
extends RefCounted
## Fog for a skirmish. Explored ground stays dim. Current sight is clear.

signal match_drawn(host: Node3D, sight: SMSight, cam: RTSCamera)

const UNIT_RADIUS: float = 18.0
const STRUCTURE_RADIUS: float = 24.0
const CYCLE: float = 24.0
const MONSOON_AT: float = 8.0
const HAZE_AT: float = 16.0
const HAZE_SIGHT: float = 0.35
const MUD: float = 0.55
const HIDDEN: int = 0
const DIM: int = 1
const CLEAR: int = 2

var grid: SMDomainGrid
var seers: Array[Vector3] = []
var radii: Array[float] = []
var posts: Array[Vector3] = []
var explored: PackedByteArray = PackedByteArray()
var weather_t: float = 0.0
var hazy: bool = false
var monsoon: bool = false
var weather_name: String = "Clear"
var river_lit: bool = false

func bind(p_grid: SMDomainGrid) -> void:
	grid = p_grid
	explored = PackedByteArray()
	explored.resize(grid.cols * grid.rows)
	explored.fill(0)

func advance_weather(delta: float) -> void:
	weather_t += delta
	var phase: float = fmod(weather_t, CYCLE)
	if phase < 0.0:
		phase += CYCLE
	monsoon = phase >= MONSOON_AT and phase < HAZE_AT
	hazy = phase >= HAZE_AT
	_name_sky()

func force_weather(p_hazy: bool) -> void:
	hazy = p_hazy
	monsoon = false
	weather_name = "Strait Haze" if hazy else "Clear"

func force_monsoon(on: bool) -> void:
	monsoon = on
	hazy = false
	weather_name = "Monsoon" if on else "Clear"

func ground_drag() -> float:
	if monsoon:
		return MUD
	return 1.0

func unit_radius(radar_held: bool) -> float:
	if (hazy or monsoon) and not radar_held:
		return UNIT_RADIUS * HAZE_SIGHT
	return UNIT_RADIUS

func _name_sky() -> void:
	if monsoon:
		weather_name = "Monsoon"
	elif hazy:
		weather_name = "Strait Haze"
	else:
		weather_name = "Clear"

func begin() -> void:
	seers.clear()
	radii.clear()
	posts.clear()
	river_lit = false

func add_seer(at: Vector3, radius: float) -> void:
	seers.append(at)
	radii.append(radius)

func note_post(at: Vector3) -> void:
	posts.append(at)

func commit() -> void:
	if grid == null:
		return
	var cols: int = grid.cols
	var rows: int = grid.rows
	if cols <= 0 or rows <= 0:
		return
	if explored.size() != cols * rows:
		explored.resize(cols * rows)
	if river_lit:
		for y: int in rows:
			for x: int in cols:
				if explored[y * cols + x] == 0 and _on_corridor(grid.cell_center(Vector2i(x, y))):
					explored[y * cols + x] = 1
	var cs: float = grid.cell_size
	var ox: float = grid.origin.x
	var oz: float = grid.origin.z
	for i: int in mini(seers.size(), radii.size()):
		var at: Vector3 = seers[i]
		var r: float = radii[i]
		var y0: int = maxi(0, ceili((at.z - r - oz) / cs - 0.5))
		var y1: int = mini(rows - 1, floori((at.z + r - oz) / cs - 0.5))
		for y: int in range(y0, y1 + 1):
			var dz: float = oz + (float(y) + 0.5) * cs - at.z
			var reach: float = r * r - dz * dz
			if reach < 0.0:
				continue
			var half: float = sqrt(reach)
			var x0: int = maxi(0, ceili((at.x - half - ox) / cs - 0.5))
			var x1: int = mini(cols - 1, floori((at.x + half - ox) / cs - 0.5))
			var row_base: int = y * cols
			for x: int in range(x0, x1 + 1):
				explored[row_base + x] = 1

func sees(at: Vector3) -> bool:
	if river_lit and _on_corridor(at):
		return true
	var ax: float = at.x
	var az: float = at.z
	for i: int in seers.size():
		var s: Vector3 = seers[i]
		var dx: float = ax - s.x
		var dz: float = az - s.z
		var r: float = radii[i]
		if dx * dx + dz * dz <= r * r:
			return true
	return false

func _on_corridor(at: Vector3) -> bool:
	if grid == null:
		return false
	var cell: Vector2i = grid.cell_at(at)
	if not grid.in_bounds(cell):
		return false
	if _wet(grid.domain_at_cell(cell)):
		return true
	var east: Vector2i = cell + Vector2i(1, 0)
	var west: Vector2i = cell + Vector2i(-1, 0)
	var south: Vector2i = cell + Vector2i(0, 1)
	var north: Vector2i = cell + Vector2i(0, -1)
	if grid.in_bounds(east) and _wet(grid.domain_at_cell(east)):
		return true
	if grid.in_bounds(west) and _wet(grid.domain_at_cell(west)):
		return true
	if grid.in_bounds(south) and _wet(grid.domain_at_cell(south)):
		return true
	if grid.in_bounds(north) and _wet(grid.domain_at_cell(north)):
		return true
	return false

func _wet(domain: int) -> bool:
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP

func cell_state(cell: Vector2i) -> int:
	if grid == null or not grid.in_bounds(cell):
		return HIDDEN
	if sees(grid.cell_center(cell)):
		return CLEAR
	if explored[_index(cell)] == 1:
		return DIM
	return HIDDEN

func conceal(field: SMPointer, host: Node3D) -> void:
	if field != null:
		var hawks: Array[Vector3] = []
		for spotter: RTSUnit in field.units:
			if is_instance_valid(spotter) and spotter.is_alive() and spotter.unit_type == &"mekong_uav" and field.teams.are_allies(SMPointer.PLAYER, spotter.team):
				hawks.append(spotter.global_position)
		for u: RTSUnit in field.units:
			if not is_instance_valid(u):
				continue
			if field.teams.are_allies(SMPointer.PLAYER, u.team):
				u.visible = true
			else:
				var shown: bool = sees(u.global_position)
				if not shown:
					for hawk: Vector3 in hawks:
						if Vector2(hawk.x, hawk.z).distance_to(Vector2(u.global_position.x, u.global_position.z)) <= 22.0:
							shown = true
							break
				u.visible = shown
	_hide_marker(host, "EnemyYard")
	_hide_marker(host, "EnemyClaim")

## `own` is the player's build yard. Its living structures see like units, so a spread-out base is not fogged.
static func update_match(sight: SMSight, field: SMPointer, host: Node3D, tech: SMTechNet, raider: SMRaider, own: SMBuildYard = null) -> void:
	if sight == null or field == null:
		return
	sight.begin()
	var radar_held: bool = tech != null and tech.reveals_water(SMPointer.PLAYER)
	var reach: float = sight.unit_radius(radar_held)
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and field.teams.are_allies(SMPointer.PLAYER, u.team):
			sight.add_seer(u.global_position, reach)
	if own != null:
		for id: StringName in own.finished:
			if own.structure_alive(id):
				sight.add_seer(own.position_of(id), STRUCTURE_RADIUS)
		if own.scaffold_active:
			sight.add_seer(own.scaffold_pos, STRUCTURE_RADIUS)
	if radar_held:
		sight.river_lit = true
		for at: Vector3 in tech.vision_points(SMPointer.PLAYER):
			sight.add_seer(at, SMTechNet.VISION_RADIUS)
	if raider != null and raider.yard != null and raider.yard.living_count() > 0:
		sight.note_post(raider.yard.center)
	sight.commit()
	sight.conceal(field, host)
	apply_drag(sight, field)
	sight.match_drawn.emit(host, sight, field.cam)

static func apply_drag(sight: SMSight, field: SMPointer) -> void:
	if sight == null or field == null:
		return
	var drag: float = sight.ground_drag()
	for u: RTSUnit in field.units:
		if not is_instance_valid(u):
			continue
		var loco: String = str(u.get_meta("locomotion", "ground"))
		u.set_meta("weather_drag", drag if loco == "ground" else 1.0)

func _hide_marker(host: Node3D, node_name: String) -> void:
	if host == null:
		return
	var node: Node3D = host.get_node_or_null(node_name) as Node3D
	if node == null:
		return
	node.visible = sees(node.global_position)

func _index(cell: Vector2i) -> int:
	return cell.y * grid.cols + cell.x

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
