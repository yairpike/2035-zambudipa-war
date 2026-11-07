class_name SMDomainGrid
extends RefCounted
## Cell flags for land, shallow water, deep water, cliff, and air.
## Amphibious moves emit domain_changed when the occupied flag changes.

signal domain_changed(unit_id: int, from_domain: int, to_domain: int)

enum Domain { LAND, SHALLOW, DEEP, CLIFF, AIR }
enum Loco { GROUND, AMPHIBIOUS, NAVAL, AIR }

var cols: int = 0
var rows: int = 0
var cell_size: float = 2.0
var origin: Vector3 = Vector3.ZERO
var cells: PackedInt32Array = PackedInt32Array()
var holds: Array[Rect2i] = []
var _where: Dictionary[int, int] = {}

func _init(p_cols: int = 8, p_rows: int = 8, p_cell: float = 2.0, p_origin: Vector3 = Vector3.ZERO) -> void:
	cols = p_cols
	rows = p_rows
	cell_size = p_cell
	origin = p_origin
	cells.resize(cols * rows)
	cells.fill(Domain.LAND)

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell_size), floori((p.z - origin.z) / cell_size))

func cell_center(c: Vector2i) -> Vector3:
	return origin + Vector3((float(c.x) + 0.5) * cell_size, 0.0, (float(c.y) + 0.5) * cell_size)

func _index(c: Vector2i) -> int:
	return c.y * cols + c.x

func set_domain(c: Vector2i, domain: int) -> void:
	if in_bounds(c):
		cells[_index(c)] = domain

func fill_rect(r: Rect2i, domain: int) -> void:
	for y: int in range(r.position.y, r.position.y + r.size.y):
		for x: int in range(r.position.x, r.position.x + r.size.x):
			set_domain(Vector2i(x, y), domain)

func domain_at_cell(c: Vector2i) -> int:
	if not in_bounds(c):
		return Domain.CLIFF
	return cells[_index(c)]

func domain_at(p: Vector3) -> int:
	return domain_at_cell(cell_at(p))

func can_enter(domain: int, loco: int) -> bool:
	if domain == Domain.CLIFF:
		return false
	if loco == Loco.AIR:
		return domain != Domain.CLIFF
	if loco == Loco.GROUND:
		return domain == Domain.LAND
	if loco == Loco.NAVAL:
		return domain == Domain.SHALLOW or domain == Domain.DEEP
	if loco == Loco.AMPHIBIOUS:
		return domain == Domain.LAND or domain == Domain.SHALLOW or domain == Domain.DEEP
	return false

## First placement records the flag without a signal. Later changes emit.
func move_unit(unit_id: int, to: Vector3, loco: int) -> bool:
	var next: int = domain_at(to)
	if not can_enter(next, loco):
		return false
	var prev: int = _where.get(unit_id, -1)
	_where[unit_id] = next
	if prev >= 0 and prev != next:
		domain_changed.emit(unit_id, prev, next)
	return true

func unit_domain(unit_id: int) -> int:
	return _where.get(unit_id, -1)

## Indestructible scenery. Ground, boats and amphibious path around it. Air flies over.
func hold(r: Rect2i) -> void:
	holds.append(r)

func holding(c: Vector2i) -> bool:
	for spot: Rect2i in holds:
		if spot.has_point(c):
			return true
	return false

## Extra cells added on every side when the skirmish fields grew.
static func pad_of(map_id: String) -> Vector2i:
	if SMMapPlan.exists(map_id):
		return Vector2i.ZERO
	if map_id == "phillips":
		return Vector2i(8, 5)
	if map_id == "sop_ruak":
		return Vector2i(7, 7)
	if map_id == "burma_road":
		return Vector2i(8, 6)
	if map_id == "ten_degree_atolls":
		return Vector2i(7, 7)
	if map_id == "mekong_delta":
		return Vector2i(8, 7)
	if map_id == "chiang_rai":
		return Vector2i(11, 8)
	if map_id == "showcase":
		return Vector2i(0, 0)
	return Vector2i.ZERO

static func at(map_id: String, c: Vector2i) -> Vector2i:
	return c + pad_of(map_id)

## Phillips Channel: west land, east land, a deep channel, two shallow crossings.
static func phillips_layout() -> SMDomainGrid:
	var p: Vector2i = pad_of("phillips")
	var g: SMDomainGrid = SMDomainGrid.new(56, 34, 4.0, Vector3(-112.0, 0.0, -68.0))
	g.fill_rect(Rect2i(15 + p.x, 0, 10, 34), Domain.DEEP)
	g.fill_rect(Rect2i(15 + p.x, 4 + p.y, 10, 3), Domain.SHALLOW)
	g.fill_rect(Rect2i(15 + p.x, 17 + p.y, 10, 3), Domain.SHALLOW)
	g.fill_rect(Rect2i(4 + p.x, 10 + p.y, 4, 3), Domain.CLIFF)
	g.fill_rect(Rect2i(18 + p.x, 10 + p.y, 4, 2), Domain.AIR)
	return g

## Sop Ruak: three land sectors split by a Y of deep water, with a ford on each arm.
static func sop_ruak_layout() -> SMDomainGrid:
	var p: Vector2i = pad_of("sop_ruak")
	var g: SMDomainGrid = SMDomainGrid.new(50, 50, 4.0, Vector3(-100.0, 0.0, -100.0))
	g.fill_rect(Rect2i(16 + p.x, 16 + p.y, 4, g.rows - (16 + p.y)), Domain.DEEP)
	var i: int = 1
	while i < g.cols:
		var lx: int = 16 - i + p.x
		var ly: int = 16 - i + p.y
		if lx < 0 or ly < 0:
			break
		_deep_block(g, lx, ly)
		var rx: int = 19 + i + p.x
		var ry: int = 16 - i + p.y
		if rx >= g.cols or ry < 0:
			break
		_deep_block(g, rx - 1, ry)
		i += 1
	g.fill_rect(Rect2i(16 + p.x, 24 + p.y, 4, 2), Domain.LAND)
	g.fill_rect(Rect2i(9 + p.x, 9 + p.y, 4, 4), Domain.LAND)
	g.fill_rect(Rect2i(23 + p.x, 9 + p.y, 4, 4), Domain.LAND)
	return g

static func _deep_block(g: SMDomainGrid, x: int, y: int) -> void:
	g.set_domain(Vector2i(x, y), Domain.DEEP)
	g.set_domain(Vector2i(x + 1, y), Domain.DEEP)
	g.set_domain(Vector2i(x, y + 1), Domain.DEEP)
	g.set_domain(Vector2i(x + 1, y + 1), Domain.DEEP)

## Burma Road: two highland plateaus, a cliff massif with a pass split by the Sule landmark, and lanes round both ends.
## Half-turn symmetric, from res://data/maps/burma_road.json.
static func burma_road_layout() -> SMDomainGrid:
	return SMMapPlan.of("burma_road").grid()

## Ten Degree Atolls: home islands, expansion islets and a reef in deep water, linked by three shoal lanes.
## Half-turn symmetric, from res://data/maps/ten_degree_atolls.json.
static func ten_degree_atolls_layout() -> SMDomainGrid:
	return SMMapPlan.of("ten_degree_atolls").grid()

## Mekong Delta: a deep canal in front of each base with a two-span bridge, contested levees between them.
## Mirrored west to east, from res://data/maps/mekong_delta.json.
static func mekong_delta_layout() -> SMDomainGrid:
	return SMMapPlan.of("mekong_delta").grid()

## Siege of Chiang Rai: two plateaus a side for 2v2, a river with three fords, and the Doi Suthep landmark.
## Half-turn symmetric, from res://data/maps/chiang_rai.json.
static func chiang_rai_layout() -> SMDomainGrid:
	return SMMapPlan.of("chiang_rai").grid()

## Golden confluence: city on the north bank, jungle on the south, a river between, one landmark plaza.
static func showcase_layout() -> SMDomainGrid:
	var g: SMDomainGrid = SMDomainGrid.new(72, 52, 4.0, Vector3(-144.0, 0.0, -104.0))
	g.fill_rect(Rect2i(0, 22, 72, 6), Domain.DEEP)
	g.fill_rect(Rect2i(32, 22, 8, 6), Domain.SHALLOW)
	g.fill_rect(Rect2i(0, 0, 18, 8), Domain.CLIFF)
	return g
