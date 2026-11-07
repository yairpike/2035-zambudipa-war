class_name SMBasePlan
extends RefCounted
## Building footprints in grid cells, read from res://data/model_scale.json, and a deterministic base layout.
## Plots ring out from the yard. Every plot is dry, unheld land, inside the yard radius, with one clear cell between buildings.

const CHART: String = "res://data/model_scale.json"
const YARD: Vector2i = Vector2i(4, 4)

static var _chart: Dictionary = {}

var grid: SMDomainGrid
var center: Vector3 = Vector3.ZERO
var radius: float = 48.0
var plots: Dictionary[StringName, Rect2i] = {}
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

func _init(p_grid: SMDomainGrid = null, p_center: Vector3 = Vector3.ZERO, p_radius: float = 48.0) -> void:
	grid = p_grid
	center = p_center
	radius = p_radius

## World centre of the plot for `id`. The same id keeps its plot. Returns `center` when nothing fits.
func plot(id: StringName, role: String, wet: bool = false) -> Vector3:
	if plots.has(id):
		return rect_center(plots[id])
	var size: Vector2i = YARD if role == "yard" else footprint(str(id), role)
	if grid == null:
		return center
	var hub: Vector2i = grid.cell_at(center)
	var reach: int = int(ceil(radius / grid.cell_size)) + 1
	var best: Rect2i = Rect2i()
	var found: bool = false
	for ring: int in reach + 1:
		for spot: Vector2i in _ring(hub, ring):
			var rect := Rect2i(spot - size / 2, size)
			if not _fits(rect, wet):
				continue
			if not found or _better(rect, best, hub):
				best = rect
				found = true
		if found:
			break
	if not found and wet:
		return plot(id, role, false)
	if not found:
		return center
	plots[id] = best
	return rect_center(best)

func release(id: StringName) -> void:
	plots.erase(id)

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

func _fits(rect: Rect2i, wet: bool) -> bool:
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > grid.cols or rect.end.y > grid.rows:
		return false
	var mid: Vector3 = rect_center(rect)
	if Vector2(mid.x - center.x, mid.z - center.z).length() > radius:
		return false
	var gap: Rect2i = rect.grow(1)
	for other: Rect2i in plots.values():
		if gap.intersects(other):
			return false
	for spot: Vector2i in keep:
		if gap.has_point(spot):
			return false
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if grid.domain_at_cell(c) != SMDomainGrid.Domain.LAND or grid.holding(c):
				return false
	if wet:
		return _shore(gap)
	return true

func _shore(rect: Rect2i) -> bool:
	var ring: Rect2i = rect.grow(1)
	for y: int in range(ring.position.y, ring.end.y):
		for x: int in range(ring.position.x, ring.end.x):
			var domain: int = grid.domain_at_cell(Vector2i(x, y))
			if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP:
				return true
	return false
