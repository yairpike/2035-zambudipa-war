class_name SMBasePlan
extends RefCounted
## Building footprints in grid cells, read from res://data/model_scale.json, and a deterministic base layout.
## Plots ring out from the yard. Every land plot is dry, unheld land, inside the yard radius, with one clear cell between buildings.
## A wet (naval) plot sits wholly on open water within the yard radius plus NAVAL_REACH, and its front bay faces navigable water.
## Yaw 0 points a building's front (its exit bay) at +Z. Quarter turns swap the footprint's width and depth.

const CHART: String = "res://data/model_scale.json"
const YARD: Vector2i = Vector2i(4, 4)
const NAVAL_REACH: float = 24.0

static var _chart: Dictionary = {}

var grid: SMDomainGrid
var center: Vector3 = Vector3.ZERO
var radius: float = 48.0
var plots: Dictionary[StringName, Rect2i] = {}
var yaws: Dictionary[StringName, float] = {}
var keep: Array[Vector2i] = []

static func chart() -> Dictionary:
	if _chart.is_empty() and FileAccess.file_exists(CHART):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHART))
		if parsed is Dictionary:
			_chart = parsed
	return _chart

static func cell_m() -> float:
	return float(chart().get("cell_m", 4.0))

## Cells wide (x) and deep (z). An id entry wins over its role.
static func footprint(id: String, role: String = "") -> Vector2i:
	var data: Dictionary = chart()
	var by_id: Dictionary = data.get("buildings", {}) as Dictionary
	var by_role: Dictionary = data.get("building_roles", {}) as Dictionary
	var raw: Variant = by_id.get(id, by_role.get(role, null))
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i(2, 2)

static func footprint_m(id: String, role: String = "") -> Vector2:
	return Vector2(footprint(id, role)) * cell_m()

static func size_of(id: String, role: String) -> Vector2i:
	return YARD if role == "yard" else footprint(id, role)

## Footprint after turning by `yaw` degrees.
static func turned(size: Vector2i, yaw: float) -> Vector2i:
	return Vector2i(size.y, size.x) if quarter(yaw) % 2 == 1 else size

## 0..3 quarter turns for `yaw` degrees.
static func quarter(yaw: float) -> int:
	return posmod(int(roundf(yaw / 90.0)), 4)

## Flat unit vector the front of a building turned by `yaw` faces.
static func front_dir(yaw: float) -> Vector3:
	var r: float = deg_to_rad(yaw)
	return Vector3(sin(r), 0.0, cos(r))

## Yaw (degrees) whose front points along `dir`, snapped to `step` degrees.
static func yaw_toward(dir: Vector3, step: float = 90.0) -> float:
	if Vector2(dir.x, dir.z).length() < 0.0001:
		return 0.0
	var raw: float = rad_to_deg(atan2(dir.x, dir.z))
	return fposmod(roundf(raw / step) * step, 360.0)

static func is_water(domain: int) -> bool:
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP

func _init(p_grid: SMDomainGrid = null, p_center: Vector3 = Vector3.ZERO, p_radius: float = 48.0) -> void:
	grid = p_grid
	center = p_center
	radius = p_radius

## Naval yards and water defenses must float. Other water-marked buildings prefer the shore.
static func must_float(role: String, water_marked: bool) -> bool:
	return role == "naval" or (water_marked and role == "defense")

## World centre of the plot for `id`. The same id keeps its plot.
## A land plot returns `center` when nothing fits; `shore` prefers land beside water first.
## A wet plot returns Vector3.INF when no water with an open bay is in reach.
func plot(id: StringName, role: String, wet: bool = false, shore: bool = false) -> Vector3:
	if plots.has(id):
		return rect_center(plots[id])
	var size: Vector2i = size_of(str(id), role)
	if grid == null:
		return Vector3.INF if wet else center
	if shore and not wet:
		var coast: Vector3 = _search(id, size, false, true)
		if coast != Vector3.INF:
			return coast
	var at: Vector3 = _search(id, size, wet, false)
	if at == Vector3.INF and not wet:
		return center
	return at

func _search(id: StringName, size: Vector2i, wet: bool, shore: bool) -> Vector3:
	var hub: Vector2i = grid.cell_at(center)
	var reach_m: float = radius + (NAVAL_REACH if wet else 0.0)
	var reach: int = int(ceil(reach_m / grid.cell_size)) + 1
	var best: Rect2i = Rect2i()
	var best_yaw: float = 0.0
	var found: bool = false
	for ring: int in reach + 1:
		for spot: Vector2i in _ring(hub, ring):
			var rect := Rect2i(spot - size / 2, size)
			if fit_reason(rect, wet) != "":
				continue
			if shore and not _shore(rect.grow(1)):
				continue
			var yaw: float = _open_yaw(rect, wet, size)
			if yaw < 0.0:
				continue
			if not found or _better(rect, best, hub):
				best = rect
				best_yaw = yaw
				found = true
		if found:
			break
	if not found:
		return Vector3.INF
	plots[id] = best
	yaws[id] = best_yaw
	return rect_center(best)

## Facing chosen for `id` (degrees). 0 when it was never plotted.
func yaw_of(id: StringName) -> float:
	return float(yaws.get(id, 0.0))

## Reserves `rect` facing `yaw` for `id`, replacing any earlier plot.
func claim(id: StringName, rect: Rect2i, yaw: float) -> void:
	plots[id] = rect
	yaws[id] = fposmod(yaw, 360.0)

func release(id: StringName) -> void:
	plots.erase(id)
	yaws.erase(id)

## Cell-aligned rect of `size` centred as near `pos` as the grid allows.
func rect_at(pos: Vector3, size: Vector2i) -> Rect2i:
	if grid == null:
		return Rect2i(Vector2i.ZERO, size)
	var fx: float = (pos.x - grid.origin.x) / grid.cell_size - float(size.x) * 0.5
	var fz: float = (pos.z - grid.origin.z) / grid.cell_size - float(size.y) * 0.5
	return Rect2i(Vector2i(roundi(fx), roundi(fz)), size)

## Why `id` cannot stand at `pos` facing `yaw`, or "" when it can. `id`'s own plot is ignored.
func check_at(id: StringName, role: String, pos: Vector3, yaw: float, wet: bool) -> String:
	if grid == null:
		return ""
	var rect: Rect2i = rect_at(pos, turned(size_of(str(id), role), yaw))
	var why: String = fit_reason(rect, wet, id)
	if why != "":
		return why
	if not exit_open(rect, yaw, wet, id):
		return "the bay must face open water" if wet else "the exit is blocked"
	return ""

## Resource nodes and tech sites stay outside every plot and its gap.
func keep_nets(goods: SMCommodityNet, tech: SMTechNet) -> void:
	if grid == null:
		return
	if goods != null:
		for node: Dictionary in goods.nodes:
			keep.append(grid.cell_at(node.get("pos", Vector3.ZERO) as Vector3))
	if tech != null:
		for site: Dictionary in tech.sites:
			keep.append(grid.cell_at(site.get("pos", Vector3.ZERO) as Vector3))

func rect_center(rect: Rect2i) -> Vector3:
	if grid == null:
		return center
	return grid.origin + Vector3((float(rect.position.x) + float(rect.size.x) * 0.5) * grid.cell_size, 0.0, (float(rect.position.y) + float(rect.size.y) * 0.5) * grid.cell_size)

func overlaps() -> int:
	var hits: int = 0
	var keys: Array[StringName] = plots.keys()
	for i: int in keys.size():
		for j: int in range(i + 1, keys.size()):
			if plots[keys[i]].intersects(plots[keys[j]]):
				hits += 1
	return hits

## Cells directly in front of `rect` turned by `yaw`: the middle of the front edge, two deep on water.
func exit_cells(rect: Rect2i, yaw: float, wet: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var q: int = quarter(yaw)
	var along: int = rect.size.x if q % 2 == 0 else rect.size.y
	var span: int = 2 if along >= 3 else along
	var start: int = (along - span) / 2
	var depth: int = 2 if wet else 1
	for d: int in depth:
		for i: int in range(start, start + span):
			match q:
				0:
					out.append(Vector2i(rect.position.x + i, rect.end.y + d))
				1:
					out.append(Vector2i(rect.end.x + d, rect.position.y + i))
				2:
					out.append(Vector2i(rect.position.x + i, rect.position.y - 1 - d))
				_:
					out.append(Vector2i(rect.position.x - 1 - d, rect.position.y + i))
	return out

func exit_open(rect: Rect2i, yaw: float, wet: bool, ignore: StringName = &"") -> bool:
	for c: Vector2i in exit_cells(rect, yaw, wet):
		if not grid.in_bounds(c) or grid.holding(c):
			return false
		var domain: int = grid.domain_at_cell(c)
		if wet and not is_water(domain):
			return false
		if not wet and domain != SMDomainGrid.Domain.LAND:
			return false
		for key: StringName in plots:
			if key != ignore and plots[key].has_point(c):
				return false
	return true

func fit_reason(rect: Rect2i, wet: bool, ignore: StringName = &"") -> String:
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > grid.cols or rect.end.y > grid.rows:
		return "off the map"
	var mid: Vector3 = rect_center(rect)
	if Vector2(mid.x - center.x, mid.z - center.z).length() > radius + (NAVAL_REACH if wet else 0.0):
		return "outside the build radius"
	var gap: Rect2i = rect.grow(1)
	for key: StringName in plots:
		if key != ignore and gap.intersects(plots[key]):
			return "too close to another building"
	for spot: Vector2i in keep:
		if gap.has_point(spot):
			return "blocks a resource site"
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if grid.holding(c):
				return "the ground is taken"
			var domain: int = grid.domain_at_cell(c)
			if wet and not is_water(domain):
				return "naval structures go on water"
			if not wet and domain != SMDomainGrid.Domain.LAND:
				return "needs dry ground"
	return ""

func _fits(rect: Rect2i, wet: bool) -> bool:
	return fit_reason(rect, wet) == ""

## First facing whose bay is open: away from the hub, then +Z, +X, -Z, -X. -1 when every bay is shut.
func _open_yaw(rect: Rect2i, wet: bool, size: Vector2i) -> float:
	var mid: Vector3 = rect_center(rect)
	var tries: Array[float] = [yaw_toward(mid - center), 0.0, 90.0, 180.0, 270.0]
	for yaw: float in tries:
		if turned(size, yaw) != rect.size:
			continue
		if exit_open(rect, yaw, wet):
			return yaw
	return -1.0

func _shore(rect: Rect2i) -> bool:
	var ring: Rect2i = rect.grow(1)
	for y: int in range(ring.position.y, ring.end.y):
		for x: int in range(ring.position.x, ring.end.x):
			if is_water(grid.domain_at_cell(Vector2i(x, y))):
				return true
	return false

func _ring(hub: Vector2i, ring: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ring == 0:
		out.append(hub)
		return out
	for x: int in range(-ring, ring + 1):
		out.append(hub + Vector2i(x, -ring))
		out.append(hub + Vector2i(x, ring))
	for y: int in range(-ring + 1, ring):
		out.append(hub + Vector2i(-ring, y))
		out.append(hub + Vector2i(ring, y))
	return out

func _better(a: Rect2i, b: Rect2i, hub: Vector2i) -> bool:
	var da: float = Vector2(rect_center(a).x - center.x, rect_center(a).z - center.z).length()
	var db: float = Vector2(rect_center(b).x - center.x, rect_center(b).z - center.z).length()
	if absf(da - db) > 0.01:
		return da < db
	if a.position.y != b.position.y:
		return a.position.y < b.position.y
	return a.position.x < b.position.x
