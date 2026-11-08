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
## One building per lot, squared to its street: {"id" (model), "rect", "yaw", "street" (the cell it fronts), "kind", "town" (-1 off the town grids), "side", "solid"}.
## "kind" is home, shop or civic in a town, building for a standalone one, landmark for the plan's landmark.
var lots: Array[Dictionary] = []
## Town street lines as laid, before cells off the land, on plateaus or under buildings are dropped.
var streets: Array[Rect2i] = []
## Every paved cell: town streets, roads, avenues, building fronts and the links routed between them.
var paved: Dictionary = {}
## Cells paved by the avenue lattice and the router, in order.
var avenues: Array[Vector2i] = []
## Rects kept free of lots but open to streets: base build zones and action ground on campaign maps.
var opens: Array[Rect2i] = []
## Terrain with no holds, from "paint" or a built-in "layout".
var ground: SMDomainGrid
## Planted rows: {"id" (model), "cell", "side"}.
var groves: Array[Dictionary] = []
var orchards: Array[Rect2i] = []
var _pending: Array[Dictionary] = []
var _taken: Dictionary = {}
var _spots: Dictionary = {}

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

## Dressing for a map with no skirmish plan, from res://data/maps/missions/<id>.json: no symmetry, and lots are solid once hold_lots runs on the scene grid.
## "phillips" is the Phillips Channel dressing.
static func dressing(mission_id: String) -> SMMapPlan:
	if mission_id == "phillips":
		mission_id = "phillips_channel"
	var key: String = "missions/" + mission_id
	if _cache.has(key):
		return _cache[key] as SMMapPlan
	var path: String = DIR % key
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if mission_id != "" and FileAccess.file_exists(path) else null
	var plan: SMMapPlan = null
	if parsed is Dictionary:
		var d: Dictionary = (parsed as Dictionary).duplicate()
		d["symmetry"] = "none"
		if not d.has("cols"):
			d["cols"] = 36
			d["rows"] = 24
		plan = SMMapPlan.new()
		plan._read(mission_id, d)
	_cache[key] = plan
	return plan

## Local yaw of a building model's facade from "fronts" in res://data/model_scale.json: 0 is +Z, 90 +X, 180 -Z, 270 -X.
## Procedural meshes and unlisted models face -Z.
static func front_yaw(model: String) -> float:
	var axis: String = str((SMBasePlan.chart().get("fronts", {}) as Dictionary).get(model, "-Z"))
	if axis == "+Z":
		return 0.0
	if axis == "+X":
		return 90.0
	if axis == "-X":
		return 270.0
	return 180.0

static func is_building(model: String) -> bool:
	return (SMBasePlan.chart().get("fronts", {}) as Dictionary).has(model)

## Turn that brings a model's facade round to face `yaw`.
static func turn_for(model: String, yaw: float) -> float:
	return fposmod(yaw - front_yaw(model), 360.0)

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
	g.cells = ground.cells.duplicate()
	hold_lots(g)
	return g

## Holds and solid lots block ground movement on `g`. Streets in front of them stay open.
func hold_lots(g: SMDomainGrid) -> void:
	for r: Rect2i in holds:
		g.hold(r)
	for lot: Dictionary in lots:
		if bool(lot["solid"]) and not holds.has(lot["rect"] as Rect2i):
			g.hold(lot["rect"] as Rect2i)

func in_town(c: Vector2i) -> bool:
	for town: Dictionary in towns:
		if (town["rect"] as Rect2i).has_point(c):
			return true
	return false

func on_street(c: Vector2i) -> bool:
	return paved.has(c)

## The lot that covers a cell, or an empty dictionary.
func lot_at(c: Vector2i) -> Dictionary:
	for lot: Dictionary in lots:
		if (lot["rect"] as Rect2i).has_point(c):
			return lot
	return {}

## A free cell outside the open ground near `near` with a paved cell beside it, and the yaw that faces that street. Used to seat mission structures.
func frontage_near(near: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	for y: int in range(maxi(0, near.y - 9), mini(rows, near.y + 10)):
		for x: int in range(maxi(0, near.x - 9), mini(cols, near.x + 10)):
			var c := Vector2i(x, y)
			if paved.has(c) or not _free(c) or _in_any(opens, c):
				continue
			var d: int = absi(c.x - near.x) + absi(c.y - near.y)
			if d >= best_d:
				continue
			for i: int in 4:
				if paved.has(front_of(Rect2i(c, Vector2i.ONE), float(i) * 90.0)):
					best = {"cell": c, "yaw": float(i) * 90.0}
					best_d = d
					break
	return best

## The street cell in front of a lot: one step out of the lot's facing edge, from its middle.
## A side-B twin keeps the twin of its side-A cell, which may sit one cell off the middle.
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
	if symmetry == "none":
		return StringName(stem)
	return StringName("%s_%s" % [stem, "a" if seat_side == 0 else "b"])

func bot(key: String, fallback: String = "") -> String:
	return str((data.get("bot", {}) as Dictionary).get(key, fallback))

func _sides() -> int:
	return 1 if symmetry == "none" else 2

func _read(map_id: String, d: Dictionary) -> void:
	id = map_id
	data = d
	cols = int(d.get("cols", 48))
	rows = int(d.get("rows", 48))
	cell_size = float(d.get("cell", 4.0))
	symmetry = str(d.get("symmetry", "rot180"))
	origin = Vector3(-float(cols) * cell_size * 0.5, 0.0, -float(rows) * cell_size * 0.5)
	ground = _terrain(d)
	var side_b: Array[Vector2i] = []
	for raw: Variant in d.get("starts", []):
		var c: Vector2i = _cell(raw)
		starts.append(c)
		if symmetry != "none":
			side_b.append(twin_cell(c))
	starts.append_array(side_b)
	for raw: Variant in d.get("plateaus", []):
		_both(plateaus, _rect(raw))
	for raw: Variant in d.get("roads", []):
		_both(roads, _rect(raw))
	for raw: Variant in d.get("open", []):
		_both(opens, _rect(raw))
	for raw: Variant in d.get("holds", []):
		_both(holds, _rect(raw))
	for raw: Variant in d.get("nodes", []):
		var row: Dictionary = raw as Dictionary
		for s: int in _sides():
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
		for s: int in _sides():
			var c: Vector2i = _cell(row.get("cell", []))
			var span: Rect2i = _rect(row.get("span", []))
			sites.append({
				"id": StringName(str(named[s])) if named.size() == 2 else node_id(str(row.get("id", "site")), s),
				"kind": StringName(str(row.get("kind", "radar"))),
				"cell": c if s == 0 else twin_cell(c),
				"span": span if s == 0 or span.size == Vector2i.ZERO else twin_rect(span),
				"face": str(row.get("face", "")),
				"yaw": 180.0,
				"street": c,
				"side": s,
			})
	for raw: Variant in d.get("props", []):
		var row: Dictionary = raw as Dictionary
		var c: Vector2i = _cell(row.get("cell", []))
		var prop_id: String = str(row.get("id", ""))
		props.append({"id": prop_id, "cell": c, "yaw": float(row.get("yaw", 0.0))})
		if symmetry != "none":
			props.append({"id": prop_id, "cell": twin_cell(c), "yaw": float(row.get("yaw", 0.0)) + (180.0 if symmetry == "rot180" else 0.0)})
	var mark: Variant = d.get("landmark", {})
	if mark is Dictionary and not (mark as Dictionary).is_empty():
		var rect: Rect2i = _rect((mark as Dictionary).get("rect", []))
		landmark = {"id": str((mark as Dictionary).get("id", "")), "rect": rect, "twin": twin_rect(rect)}
		_both(holds, rect)
		_pending.append({"id": landmark["id"], "rect": rect, "face": str((mark as Dictionary).get("face", "")), "kind": "landmark"})
	for raw: Variant in d.get("buildings", []):
		var row: Dictionary = raw as Dictionary
		_pending.append({"id": str(row.get("id", "")), "rect": _rect(row.get("rect", [])), "face": str(row.get("face", "")), "kind": "building"})
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
	_finish(d)

func _both(into: Array[Rect2i], r: Rect2i) -> void:
	if not into.has(r):
		into.append(r)
	if symmetry != "none" and not into.has(twin_rect(r)):
		into.append(twin_rect(r))

func _terrain(d: Dictionary) -> SMDomainGrid:
	var layout: String = str(d.get("layout", ""))
	var g: SMDomainGrid = null
	if layout == "phillips":
		g = SMDomainGrid.phillips_layout()
	elif layout == "sop_ruak":
		g = SMDomainGrid.sop_ruak_layout()
	elif layout == "showcase":
		g = SMDomainGrid.showcase_layout()
	if g != null:
		cols = g.cols
		rows = g.rows
		cell_size = g.cell_size
		origin = g.origin
		return g
	g = SMDomainGrid.new(cols, rows, cell_size, origin)
	g.cells.fill(_domain(str(d.get("ground", "land"))))
	for raw: Variant in d.get("paint", []):
		var row: Dictionary = raw as Dictionary
		var r: Rect2i = _rect(row.get("rect", []))
		var domain: int = _domain(str(row.get("domain", "land")))
		g.fill_rect(r, domain)
		g.fill_rect(twin_rect(r), domain)
	return g

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
	var town: int = towns.size() - _sides()
	var solid: bool = bool(towns[town]["solid"])
	lots.append({"id": model, "rect": r, "yaw": yaw, "street": front_of(r, yaw), "kind": kind, "town": town, "side": 0, "solid": solid})
	if symmetry == "none":
		return
	var t_rect: Rect2i = twin_rect(r)
	var t_yaw: float = twin_yaw(yaw)
	lots.append({"id": model, "rect": t_rect, "yaw": t_yaw, "street": twin_cell(front_of(r, yaw)), "kind": kind, "town": town + 1, "side": 1, "solid": solid})

func twin_yaw(yaw: float) -> float:
	if symmetry == "none":
		return yaw
	return fposmod(yaw + 180.0, 360.0) if symmetry == "rot180" else fposmod(360.0 - yaw, 360.0)

## Masks the town lots and streets against terrain, seats standalone buildings and sites on a street,
## lays the avenue lattice, then routes links so every street on a piece of land joins one network.
func _finish(d: Dictionary) -> void:
	for c: Vector2i in starts:
		_spots[c] = true
	for row: Dictionary in nodes + sites:
		_spots[row["cell"] as Vector2i] = true
	for row: Dictionary in _pending:
		_take(row["rect"] as Rect2i)
		if symmetry != "none":
			_take(twin_rect(row["rect"] as Rect2i))
	for r: Rect2i in streets:
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if _free(c) and not _in_any(opens, c):
					paved[c] = true
	for r: Rect2i in roads:
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				if ground.in_bounds(Vector2i(x, y)):
					paved[Vector2i(x, y)] = true
	var kept: Array[Dictionary] = []
	for lot: Dictionary in lots:
		if _lot_ok(lot["rect"] as Rect2i) and paved.has(lot["street"] as Vector2i):
			kept.append(lot)
			_take(lot["rect"] as Rect2i)
	lots = kept
	_lattice(d.get("grid", {}) as Dictionary)
	_seat_pending()
	_seat_sites()
	_route()

func _take(r: Rect2i) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			_taken[Vector2i(x, y)] = true

func _in_any(rects: Array[Rect2i], c: Vector2i, grow: int = 0) -> bool:
	for r: Rect2i in rects:
		if r.grow(grow).has_point(c):
			return true
	return false

## Open land a road may cross: not water, cliff, plateau, hold, building, orchard, start, node or site.
func _free(c: Vector2i) -> bool:
	return ground.in_bounds(c) and ground.domain_at_cell(c) == SMDomainGrid.Domain.LAND and not _in_any(plateaus, c) and not _in_any(holds, c) and not _in_any(orchards, c) and not _taken.has(c) and not _spots.has(c)

func _lot_ok(r: Rect2i) -> bool:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not _free(c) or paved.has(c) or _in_any(plateaus, c, 1) or _in_any(opens, c):
				return false
	for spot: Vector2i in _spots:
		if r.grow(1).has_point(spot):
			return false
	return true

## Avenue lines every "pitch" cells from "at", with their twins, wherever the land is free.
func _lattice(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	var pitch: Vector2i = _cell(spec.get("pitch", [10, 10]))
	var at: Vector2i = _cell(spec.get("at", [0, 0]))
	var xs: Dictionary = {}
	var ys: Dictionary = {}
	var x: int = at.x
	while x < cols and pitch.x > 0:
		xs[x] = true
		if symmetry != "none":
			xs[cols - 1 - x] = true
		x += pitch.x
	var y: int = at.y
	while y < rows and pitch.y > 0:
		ys[y] = true
		if symmetry == "rot180":
			ys[rows - 1 - y] = true
		y += pitch.y
	for cy: int in rows:
		for cx: int in cols:
			var c := Vector2i(cx, cy)
			if (xs.has(cx) or ys.has(cy)) and not paved.has(c) and _free(c) and not _in_any(opens, c):
				paved[c] = true
				avenues.append(c)

## Standalone buildings and the landmark face the side named by "face" (n, e, s, w), or the street nearest to them.
func _seat_pending() -> void:
	var near: Dictionary = _reach()
	for row: Dictionary in _pending:
		var r: Rect2i = row["rect"] as Rect2i
		var yaw: float = _face_yaw(str(row["face"]))
		if yaw < 0.0:
			yaw = _best_face(r, near)
		var kind: String = str(row["kind"])
		var lot: Dictionary = {"id": str(row["id"]), "rect": r, "yaw": yaw, "street": front_of(r, yaw), "kind": kind, "town": -1, "side": 0, "solid": true}
		lots.append(lot)
		_pave(lot["street"] as Vector2i)
		var t_rect: Rect2i = twin_rect(r)
		if symmetry == "none" or t_rect == r:
			continue
		var t_yaw: float = twin_yaw(yaw)
		lots.append({"id": str(row["id"]), "rect": t_rect, "yaw": t_yaw, "street": twin_cell(lot["street"] as Vector2i), "kind": kind, "town": -1, "side": 1, "solid": true})
		_pave(twin_cell(lot["street"] as Vector2i))

## Tech sites on land get a street on the side nearest the network. Side B copies side A.
## Bridges and offshore derricks stand in the water and front no street.
func _seat_sites() -> void:
	var near: Dictionary = _reach()
	for row: Dictionary in sites:
		var c: Vector2i = row["cell"] as Vector2i
		if int(row["side"]) != 0 or not fronts_street(row):
			continue
		var yaw: float = _face_yaw(str(row["face"]))
		if yaw < 0.0:
			yaw = _best_face(Rect2i(c, Vector2i.ONE), near)
		row["yaw"] = yaw
		row["street"] = front_of(Rect2i(c, Vector2i.ONE), yaw)
		_pave(row["street"] as Vector2i)
		for other: Dictionary in sites:
			if int(other["side"]) == 1 and other["cell"] == twin_cell(c):
				other["yaw"] = twin_yaw(yaw)
				other["street"] = front_of(Rect2i(other["cell"] as Vector2i, Vector2i.ONE), other["yaw"] as float)
				_pave(other["street"] as Vector2i)

func fronts_street(site: Dictionary) -> bool:
	return site["kind"] != &"bridge" and ground.domain_at_cell(site["cell"] as Vector2i) == SMDomainGrid.Domain.LAND

func _pave(c: Vector2i) -> void:
	if ground.in_bounds(c) and not _taken.has(c):
		paved[c] = true

static func _face_yaw(face: String) -> float:
	if face == "s":
		return 0.0
	if face == "e":
		return 90.0
	if face == "n":
		return 180.0
	if face == "w":
		return 270.0
	return -1.0

func _best_face(r: Rect2i, near: Dictionary) -> float:
	var best: float = 0.0
	var best_d: int = 1 << 20
	for i: int in 4:
		var yaw: float = float(i) * 90.0
		var c: Vector2i = front_of(r, yaw)
		if not (paved.has(c) or _free(c)):
			continue
		var d: int = int(near.get(c, 1 << 19))
		if d < best_d:
			best_d = d
			best = yaw
	return best

## Steps from every free cell to the nearest paved cell.
func _reach() -> Dictionary:
	var dist: Dictionary = {}
	var wave: Array[Vector2i] = []
	for c: Variant in paved:
		dist[c] = 0
		wave.append(c as Vector2i)
	var head: int = 0
	while head < wave.size():
		var c: Vector2i = wave[head]
		head += 1
		for step: Vector2i in STEPS:
			var n: Vector2i = c + step
			if dist.has(n) or not _free(n):
				continue
			dist[n] = int(dist[c]) + 1
			wave.append(n)
	return dist

const STEPS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const TURN_COST: int = 4

## Joins every paved patch, and every plateau with no road yet, to the network with straight runs and square turns.
## Patches on other islands stay apart. Links are mirrored onto the twin side.
func _route() -> void:
	var comp: Dictionary = {}
	var groups: Array = []
	for y: int in rows:
		for x: int in cols:
			var c := Vector2i(x, y)
			if not paved.has(c) or comp.has(c):
				continue
			var cells: Array[Vector2i] = [c]
			comp[c] = groups.size()
			var head: int = 0
			while head < cells.size():
				var at: Vector2i = cells[head]
				head += 1
				for step: Vector2i in STEPS:
					var n: Vector2i = at + step
					if paved.has(n) and not comp.has(n):
						comp[n] = groups.size()
						cells.append(n)
			groups.append({"cells": cells, "goals": cells})
	for p: Rect2i in plateaus:
		var touched: bool = false
		var ring: Array[Vector2i] = []
		for y: int in range(p.position.y - 1, p.end.y + 1):
			for x: int in range(p.position.x - 1, p.end.x + 1):
				var c := Vector2i(x, y)
				if paved.has(c):
					touched = true
				elif not p.has_point(c) and _free(c) and ((x >= p.position.x and x < p.end.x) or (y >= p.position.y and y < p.end.y)):
					ring.append(c)
		if not touched and not ring.is_empty():
			var none: Array[Vector2i] = []
			groups.append({"cells": none, "goals": ring})
	if groups.is_empty():
		return
	var group_of: Dictionary = {}
	for i: int in groups.size():
		for c: Vector2i in (groups[i] as Dictionary)["goals"] as Array[Vector2i]:
			group_of[c] = i
	var left: Dictionary = {}
	for i: int in groups.size():
		left[i] = true
	while not left.is_empty():
		var seed: int = -1
		for i: Variant in left:
			if seed < 0 or ((groups[int(i)] as Dictionary)["cells"] as Array).size() > ((groups[seed] as Dictionary)["cells"] as Array).size():
				seed = int(i)
		var net: Dictionary = {}
		_join(seed, groups, group_of, left, net, false)
		if net.is_empty():
			continue
		while true:
			var goal_of: Dictionary = {}
			for i: Variant in left:
				for c: Vector2i in (groups[int(i)] as Dictionary)["goals"] as Array[Vector2i]:
					goal_of[c] = int(i)
			if goal_of.is_empty():
				break
			var path: Array[Vector2i] = _link(net, goal_of)
			if path.is_empty():
				break
			for c: Vector2i in path:
				for spot: Vector2i in [c, twin_cell(c)]:
					net[spot] = true
					_pave(spot)
			_join(int(goal_of[path[path.size() - 1]]), groups, group_of, left, net)

## Adds a patch, and its twin patch when the link to it was mirrored, to the network being grown.
## A seed leaves its twin out so that a twin on the same land still gets a road to it.
func _join(i: int, groups: Array, group_of: Dictionary, left: Dictionary, net: Dictionary, twinned: bool = true) -> void:
	var picks: Array[int] = [i]
	var goals: Array[Vector2i] = (groups[i] as Dictionary)["goals"] as Array[Vector2i]
	if twinned and symmetry != "none" and not goals.is_empty():
		var t: int = int(group_of.get(twin_cell(goals[0]), i))
		if t != i:
			picks.append(t)
	for g: int in picks:
		left.erase(g)
		for c: Vector2i in (groups[g] as Dictionary)["cells"] as Array[Vector2i]:
			net[c] = true

## Cheapest square-turned run from the network to any goal cell, goal last. Empty when no land joins them.
func _link(net: Dictionary, goal_of: Dictionary) -> Array[Vector2i]:
	var size: int = cols * rows * 4
	var cost := PackedInt32Array()
	cost.resize(size)
	cost.fill(-1)
	var prev := PackedInt32Array()
	prev.resize(size)
	prev.fill(-1)
	var buckets: Array[PackedInt32Array] = [PackedInt32Array()]
	for c: Variant in net:
		var at: Vector2i = c as Vector2i
		for dir: int in 4:
			var s: int = ((at.y * cols) + at.x) * 4 + dir
			cost[s] = 0
			buckets[0].append(s)
	var level: int = 0
	while level < buckets.size():
		var bucket: PackedInt32Array = buckets[level]
		var i: int = 0
		while i < bucket.size():
			var s: int = bucket[i]
			i += 1
			if cost[s] != level:
				continue
			var cell_index: int = s / 4
			var at := Vector2i(cell_index % cols, cell_index / cols)
			if goal_of.has(at) and not net.has(at):
				var path: Array[Vector2i] = []
				var walk: int = s
				while walk >= 0 and not net.has(Vector2i((walk / 4) % cols, (walk / 4) / cols)):
					path.push_front(Vector2i((walk / 4) % cols, (walk / 4) / cols))
					walk = prev[walk]
				return path
			var dir: int = s % 4
			for nd: int in 4:
				var n: Vector2i = at + STEPS[nd]
				if not ground.in_bounds(n) or not (paved.has(n) or _free(n)):
					continue
				var step_cost: int = level + 1 + (TURN_COST if nd != dir else 0)
				var ns: int = ((n.y * cols) + n.x) * 4 + nd
				if cost[ns] >= 0 and cost[ns] <= step_cost:
					continue
				cost[ns] = step_cost
				prev[ns] = s
				while buckets.size() <= step_cost:
					buckets.append(PackedInt32Array())
				buckets[step_cost].append(ns)
		buckets[level] = PackedInt32Array()
		level += 1
	return []

func _pick(shops: String, homes: Array, on_high: bool, r: Rect2i) -> String:
	if on_high:
		return shops
	var key: Vector2i = canon(r.position)
	return str(homes[posmod(hash(key), homes.size())])

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

## Cells kept free of scattered scenery: plateaus, roads, holds, streets, buildings, open ground, orchards and a ring round every start, node and site.
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
	if paved.has(c) or _taken.has(c):
		return false
	for r: Rect2i in opens:
		if r.has_point(c):
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
