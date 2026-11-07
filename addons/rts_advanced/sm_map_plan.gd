class_name SMMapPlan
extends RefCounted
## A skirmish map from res://data/maps/<id>.json. Meshes are not created here.
## Every listed rect, start, node, site and prop is also stamped at its symmetric twin, so both sides get the same map.
## "rot180" turns a cell half a turn about the map centre. "mirror_x" flips it west to east.
## Listed entries are side A (the player's half). Twins are side B. Starts list side A seats first, then side B.

const DIR: String = "res://data/maps/%s.json"

static var _cache: Dictionary = {}
static var _found: Dictionary = {}

var id: String = ""
var cols: int = 0
var rows: int = 0
var cell_size: float = 4.0
var origin: Vector3 = Vector3.ZERO
var symmetry: String = "rot180"
var data: Dictionary = {}
var starts: Array[Vector2i] = []
var plateaus: Array[Rect2i] = []
var roads: Array[Rect2i] = []
var holds: Array[Rect2i] = []
var nodes: Array[Dictionary] = []
var sites: Array[Dictionary] = []
var props: Array[Dictionary] = []
var landmark: Dictionary = {}
## Street-grid settlements: {"id", "place", "rect", "solid", "side"}.
var towns: Array[Dictionary] = []
## One building per lot, squared to its street: {"id" (model), "rect", "yaw", "street" (the cell it fronts), "kind", "town", "side"}.
var lots: Array[Dictionary] = []
var streets: Array[Rect2i] = []
## Planted rows: {"id" (model), "cell", "side"}.
var groves: Array[Dictionary] = []
var orchards: Array[Rect2i] = []

static func exists(map_id: String) -> bool:
	if not _found.has(map_id):
		_found[map_id] = map_id != "" and not map_id.contains("/") and FileAccess.file_exists(DIR % map_id)
	return bool(_found[map_id])

static func of(map_id: String) -> SMMapPlan:
	if _cache.has(map_id):
		return _cache[map_id] as SMMapPlan
	if not exists(map_id):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR % map_id))
	if not (parsed is Dictionary):
		return null
	var plan := SMMapPlan.new()
	plan._read(map_id, parsed as Dictionary)
	_cache[map_id] = plan
	return plan

## Campaign dressing from res://data/maps/missions/<id>.json: towns and groves only, no symmetry, never solid.
static func dressing(mission_id: String) -> SMMapPlan:
	var key: String = "missions/" + mission_id
	if _cache.has(key):
		return _cache[key] as SMMapPlan
	var path: String = DIR % key
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if mission_id != "" and FileAccess.file_exists(path) else null
	var plan: SMMapPlan = null
	if parsed is Dictionary:
		var d: Dictionary = (parsed as Dictionary).duplicate()
		d["symmetry"] = "none"
		plan = SMMapPlan.new()
		plan._read(mission_id, d)
		for town: Dictionary in plan.towns:
			town["solid"] = false
	_cache[key] = plan
	return plan

func twin_cell(c: Vector2i) -> Vector2i:
	if symmetry == "none":
		return c
	if symmetry == "mirror_x":
		return Vector2i(cols - 1 - c.x, c.y)
	return Vector2i(cols - 1 - c.x, rows - 1 - c.y)

func twin_rect(r: Rect2i) -> Rect2i:
	if symmetry == "none":
		return r
	if symmetry == "mirror_x":
		return Rect2i(cols - r.position.x - r.size.x, r.position.y, r.size.x, r.size.y)
	return Rect2i(cols - r.position.x - r.size.x, rows - r.position.y - r.size.y, r.size.x, r.size.y)

func grid() -> SMDomainGrid:
	var g := SMDomainGrid.new(cols, rows, cell_size, origin)
	g.cells.fill(_domain(str(data.get("ground", "land"))))
	for raw: Variant in data.get("paint", []):
		var row: Dictionary = raw as Dictionary
		var r: Rect2i = _rect(row.get("rect", []))
		var domain: int = _domain(str(row.get("domain", "land")))
		g.fill_rect(r, domain)
		g.fill_rect(twin_rect(r), domain)
	for r: Rect2i in holds:
		g.hold(r)
	for lot: Dictionary in lots:
		if not bool(towns[int(lot["town"])]["solid"]):
			continue
		var r: Rect2i = lot["rect"] as Rect2i
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				if g.domain_at_cell(Vector2i(x, y)) == SMDomainGrid.Domain.LAND:
					g.hold(Rect2i(x, y, 1, 1))
	return g

func in_town(c: Vector2i) -> bool:
	for town: Dictionary in towns:
		if (town["rect"] as Rect2i).has_point(c):
			return true
	return false

func on_street(c: Vector2i) -> bool:
	for r: Rect2i in streets:
		if r.has_point(c):
			return true
	return false

## The street cell in front of a lot: one step out of the lot's facing edge, from its middle.
static func front_of(r: Rect2i, yaw: float) -> Vector2i:
	var turn: int = posmod(roundi(yaw / 90.0), 4)
	var mid: Vector2i = r.position + Vector2i(r.size.x / 2, r.size.y / 2)
	if turn == 0:
		return Vector2i(mid.x, r.end.y)
	if turn == 1:
		return Vector2i(r.end.x, mid.y)
	if turn == 2:
		return Vector2i(mid.x, r.position.y - 1)
	return Vector2i(r.position.x - 1, mid.y)

func cell_center(c: Vector2i) -> Vector3:
	return origin + Vector3((float(c.x) + 0.5) * cell_size, 0.0, (float(c.y) + 0.5) * cell_size)

func rect_center(r: Rect2i) -> Vector3:
	return origin + Vector3((float(r.position.x) + float(r.size.x) * 0.5) * cell_size, 0.0, (float(r.position.y) + float(r.size.y) * 0.5) * cell_size)

## Seat 0 is the player. Seats alternate sides only through the starts list order.
func start(seat: int) -> Vector2i:
	if seat < 0 or seat >= starts.size():
		return Vector2i(cols / 2, rows / 2)
	return starts[seat]

func site_span(site_id: StringName) -> Rect2i:
	for row: Dictionary in sites:
		if row["id"] == site_id:
			return row["span"] as Rect2i
	return Rect2i()

## Six spawn cells beside a start, on the side facing the map centre.
func spawn_cells(seat: int, count: int = 6) -> Array[Vector2i]:
	var home: Vector2i = start(seat)
	var toward: Vector2 = Vector2(float(cols) * 0.5 - float(home.x), float(rows) * 0.5 - float(home.y))
	var step: Vector2i = Vector2i(0, -1 if toward.y < 0.0 else 1)
	var side: Vector2i = Vector2i(1, 0)
	if absf(toward.x) > absf(toward.y):
		step = Vector2i(-1 if toward.x < 0.0 else 1, 0)
		side = Vector2i(0, 1)
	var out: Array[Vector2i] = []
	for i: int in count:
		var lane: int = i % 3
		var row: int = i / 3
		out.append(home + step * (4 + row * 2) + side * ((lane - 1) * 2))
	return out

func node_id(stem: String, seat_side: int) -> StringName:
	return StringName("%s_%s" % [stem, "a" if seat_side == 0 else "b"])

func bot(key: String, fallback: String = "") -> String:
	return str((data.get("bot", {}) as Dictionary).get(key, fallback))

func _read(map_id: String, d: Dictionary) -> void:
	id = map_id
	data = d
	cols = int(d.get("cols", 48))
	rows = int(d.get("rows", 48))
	cell_size = float(d.get("cell", 4.0))
	symmetry = str(d.get("symmetry", "rot180"))
	origin = Vector3(-float(cols) * cell_size * 0.5, 0.0, -float(rows) * cell_size * 0.5)
	var side_b: Array[Vector2i] = []
	for raw: Variant in d.get("starts", []):
		var c: Vector2i = _cell(raw)
		starts.append(c)
		side_b.append(twin_cell(c))
	starts.append_array(side_b)
	for raw: Variant in d.get("plateaus", []):
		var r: Rect2i = _rect(raw)
		plateaus.append(r)
		plateaus.append(twin_rect(r))
	for raw: Variant in d.get("roads", []):
		var r: Rect2i = _rect(raw)
		roads.append(r)
		roads.append(twin_rect(r))
	for raw: Variant in d.get("holds", []):
		var r: Rect2i = _rect(raw)
		holds.append(r)
		if twin_rect(r) != r:
			holds.append(twin_rect(r))
	for raw: Variant in d.get("nodes", []):
		var row: Dictionary = raw as Dictionary
		for s: int in 2:
			var c: Vector2i = _cell(row.get("cell", []))
			nodes.append({
				"id": node_id(str(row.get("id", "node")), s),
				"kind": StringName(str(row.get("kind", "slag"))),
				"cell": c if s == 0 else twin_cell(c),
				"rate": int(row.get("rate", 12)),
				"water": bool(row.get("water", false)),
				"side": s,
			})
	for raw: Variant in d.get("sites", []):
		var row: Dictionary = raw as Dictionary
		var named: Array = row.get("ids", []) as Array
		for s: int in 2:
			var c: Vector2i = _cell(row.get("cell", []))
			var span: Rect2i = _rect(row.get("span", []))
			sites.append({
				"id": StringName(str(named[s])) if named.size() == 2 else node_id(str(row.get("id", "site")), s),
				"kind": StringName(str(row.get("kind", "radar"))),
				"cell": c if s == 0 else twin_cell(c),
				"span": span if s == 0 or span.size == Vector2i.ZERO else twin_rect(span),
				"side": s,
			})
	for raw: Variant in d.get("props", []):
		var row: Dictionary = raw as Dictionary
		var c: Vector2i = _cell(row.get("cell", []))
		var prop_id: String = str(row.get("id", ""))
		props.append({"id": prop_id, "cell": c, "yaw": float(row.get("yaw", 0.0))})
		props.append({"id": prop_id, "cell": twin_cell(c), "yaw": float(row.get("yaw", 0.0)) + (180.0 if symmetry == "rot180" else 0.0)})
	var mark: Variant = d.get("landmark", {})
	if mark is Dictionary and not (mark as Dictionary).is_empty():
		var rect: Rect2i = _rect((mark as Dictionary).get("rect", []))
		landmark = {"id": str((mark as Dictionary).get("id", "")), "rect": rect, "twin": twin_rect(rect)}
	for raw: Variant in d.get("towns", []):
		_lay_town(raw as Dictionary)
	for raw: Variant in d.get("orchards", []):
		var row: Dictionary = raw as Dictionary
		var r: Rect2i = _rect(row.get("rect", []))
		var pitch: Vector2i = _cell(row.get("pitch", [1, 2]))
		orchards.append(r)
		if symmetry != "none":
			orchards.append(twin_rect(r))
		pitch = Vector2i(maxi(1, pitch.x), maxi(1, pitch.y))
		for y: int in range(r.position.y, r.end.y, pitch.y):
			for x: int in range(r.position.x, r.end.x, pitch.x):
				groves.append({"id": str(row.get("tree", "rubber_tree")), "cell": Vector2i(x, y), "side": 0})
				if symmetry != "none":
					groves.append({"id": str(row.get("tree", "rubber_tree")), "cell": twin_cell(Vector2i(x, y)), "side": 1})

## Blocks of 2x2-cell lots between one-cell streets, a street ring round the outside.
## "axis" "x" runs blocks west to east so lots face north and south; "z" turns them to face west and east.
## Lots on the "high" street lines get the "shops" model. A "civic" block holds one hall instead of lots.
func _lay_town(spec: Dictionary) -> void:
	var r: Rect2i = _rect(spec.get("rect", []))
	var block: Vector2i = _cell(spec.get("block", [4, 4]))
	var along_x: bool = str(spec.get("axis", "x")) != "z"
	var pitch: Vector2i = block + Vector2i.ONE
	var count: Vector2i = Vector2i(maxi(1, (r.size.x - 1) / pitch.x), maxi(1, (r.size.y - 1) / pitch.y))
	var high: Array = spec.get("high", []) as Array
	var homes: Array = spec.get("homes", ["shan_stilt_house"]) as Array
	var shops: String = str(spec.get("shops", homes[0]))
	var civic: Dictionary = {}
	for raw: Variant in spec.get("civic", []):
		var row: Dictionary = raw as Dictionary
		civic[_cell(row.get("block", []))] = str(row.get("id", "wet_market"))
	var sides: int = 1 if symmetry == "none" else 2
	for s: int in sides:
		var index: int = towns.size()
		var town_rect: Rect2i = r if s == 0 else twin_rect(r)
		towns.append({"id": StringName("%s_%s" % [spec.get("id", "town"), "a" if s == 0 else "b"]) if sides == 2 else StringName(str(spec.get("id", "town"))), "place": str(spec.get("place", "")), "rect": town_rect, "solid": bool(spec.get("solid", true)), "side": s})
		for i: int in count.x + 1:
			var col := Rect2i(r.position.x + i * pitch.x, r.position.y, 1, count.y * pitch.y + 1)
			streets.append(col if s == 0 else twin_rect(col))
		for j: int in count.y + 1:
			var line := Rect2i(r.position.x, r.position.y + j * pitch.y, count.x * pitch.x + 1, 1)
			streets.append(line if s == 0 else twin_rect(line))
	for j: int in count.y:
		for i: int in count.x:
			var at: Vector2i = r.position + Vector2i(1 + i * pitch.x, 1 + j * pitch.y)
			if civic.has(Vector2i(i, j)):
				_add_lot(str(civic[Vector2i(i, j)]), Rect2i(at, block), 0.0 if along_x else 90.0, "civic")
				continue
			if along_x:
				var deep: int = block.y / 2 if block.y >= 4 else block.y
				for k: int in block.x / 2:
					var n_lot := Rect2i(at + Vector2i(k * 2, 0), Vector2i(2, deep))
					_add_lot(_pick(shops, homes, high.has(j), n_lot), n_lot, 180.0, "shop" if high.has(j) else "home")
					if block.y >= 4:
						var s_lot := Rect2i(at + Vector2i(k * 2, block.y - deep), Vector2i(2, deep))
						_add_lot(_pick(shops, homes, high.has(j + 1), s_lot), s_lot, 0.0, "shop" if high.has(j + 1) else "home")
			else:
				var wide: int = block.x / 2 if block.x >= 4 else block.x
				for k: int in block.y / 2:
					var w_lot := Rect2i(at + Vector2i(0, k * 2), Vector2i(wide, 2))
					_add_lot(_pick(shops, homes, high.has(i), w_lot), w_lot, 270.0, "shop" if high.has(i) else "home")
					if block.x >= 4:
						var e_lot := Rect2i(at + Vector2i(block.x - wide, k * 2), Vector2i(wide, 2))
						_add_lot(_pick(shops, homes, high.has(i + 1), e_lot), e_lot, 90.0, "shop" if high.has(i + 1) else "home")

func _add_lot(model: String, r: Rect2i, yaw: float, kind: String) -> void:
	var town: int = towns.size() - (1 if symmetry == "none" else 2)
	lots.append({"id": model, "rect": r, "yaw": yaw, "street": front_of(r, yaw), "kind": kind, "town": town, "side": 0})
	if symmetry == "none":
		return
	var t_rect: Rect2i = twin_rect(r)
	var t_yaw: float = fposmod(yaw + 180.0, 360.0) if symmetry == "rot180" else fposmod(360.0 - yaw, 360.0)
	lots.append({"id": model, "rect": t_rect, "yaw": t_yaw, "street": front_of(t_rect, t_yaw), "kind": kind, "town": town + 1, "side": 1})

func _pick(shops: String, homes: Array, on_high: bool, r: Rect2i) -> String:
	if on_high:
		return shops
	var key: Vector2i = canon(r.position)
	return str(homes[posmod(key.x * 7 + key.y * 13, homes.size())])

func _cell(raw: Variant) -> Vector2i:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	return Vector2i.ZERO

func _rect(raw: Variant) -> Rect2i:
	if raw is Array and (raw as Array).size() >= 4:
		var a: Array = raw as Array
		return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	return Rect2i()

static func goods_kind(name: StringName) -> StringName:
	if name == &"rare":
		return SMCommodityNet.KIND_RARE
	if name == &"ruby":
		return SMCommodityNet.KIND_RUBY
	if name == &"jade":
		return SMCommodityNet.KIND_JADE
	if name == &"bullion":
		return SMCommodityNet.KIND_BULLION
	return SMCommodityNet.KIND_SLAG

static func site_kind(name: StringName) -> StringName:
	if name == &"cyber":
		return SMTechNet.CYBER
	if name == &"bazaar":
		return SMTechNet.BAZAAR
	if name == &"clinic":
		return SMTechNet.CLINIC
	if name == &"salvage":
		return SMTechNet.SALVAGE
	if name == &"derrick":
		return SMTechNet.DERRICK
	if name == &"bridge":
		return SMTechNet.BRIDGE
	if name == &"garrison":
		return SMTechNet.GARRISON
	return SMTechNet.RADAR

## Cells kept free of scattered scenery: plateaus, roads, holds, towns, orchards and a ring round every start, node and site.
func clear_of_props(c: Vector2i) -> bool:
	for r: Rect2i in plateaus:
		if r.grow(1).has_point(c):
			return false
	for r: Rect2i in roads:
		if r.grow(1).has_point(c):
			return false
	for r: Rect2i in holds:
		if r.grow(1).has_point(c):
			return false
	for town: Dictionary in towns:
		if (town["rect"] as Rect2i).grow(1).has_point(c):
			return false
	for r: Rect2i in orchards:
		if r.grow(1).has_point(c):
			return false
	var spots: Array[Vector2i] = starts.duplicate()
	for row: Dictionary in nodes:
		spots.append(row["cell"] as Vector2i)
	for row: Dictionary in sites:
		spots.append(row["cell"] as Vector2i)
	for spot: Vector2i in spots:
		if absi(spot.x - c.x) <= 3 and absi(spot.y - c.y) <= 3:
			return false
	return true

## The same roll for a cell and its twin, so scatter is symmetric too.
func canon(c: Vector2i) -> Vector2i:
	var t: Vector2i = twin_cell(c)
	if t.y < c.y or (t.y == c.y and t.x < c.x):
		return t
	return c

static func _domain(name: String) -> int:
	if name == "shallow":
		return SMDomainGrid.Domain.SHALLOW
	if name == "deep":
		return SMDomainGrid.Domain.DEEP
	if name == "cliff":
		return SMDomainGrid.Domain.CLIFF
	if name == "air":
		return SMDomainGrid.Domain.AIR
	return SMDomainGrid.Domain.LAND
