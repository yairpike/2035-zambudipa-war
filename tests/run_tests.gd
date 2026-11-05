extends SceneTree
## Lite strict headless suite: tools/run_tests.sh. Exit 0 = PASS (RESULT: PASS).
## Subset of the Pro suite for the core systems, plus Lite-only checks.

const Harness = preload("res://tests/harness.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Settings = preload("res://game/match_settings.gd")
const ModelBook = preload("res://game/model_registry.gd")
const Lan = preload("res://game/lan_link.gd")
const Seat = preload("res://game/lan_seat.gd")
const WebPaste = preload("res://game/web_paste.gd")
const Weather = preload("res://addons/rts_advanced/sm_weather.gd")
const Motion = preload("res://game/unit_motion.gd")
const BuildingFx = preload("res://game/building_fx.gd")
const BuildingWatch = preload("res://game/building_watch.gd")
const WorldView = preload("res://game/world_view.gd")
const Ground = preload("res://game/ground_view.gd")
const Catalog = preload("res://game/model_catalog.gd")
const Debris = preload("res://game/building_debris.gd")
const Scale = preload("res://game/model_scale.gd")
var H: Harness
var duel_note: String = ""

func check(cond: bool, msg: String) -> void:
	H.check(cond, msg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Settings.hold("high")
	Settings.set_difficulty("normal")
	H = Harness.new()
	if Harness.selftest_mode() == "crash":
		await H.section("harness_crash_selftest", H.crash_selftest)
		quit(H.finish())
		return
	if Harness.selftest_mode() == "exit":
		quit(0)
		return
	await H.section("test_scripts", test_scripts)
	await H.section("test_teams", test_teams)
	await H.section("test_economy", test_economy)
	await H.section("test_resource_nodes", test_resource_nodes)
	await H.section("test_formation", test_formation)
	await H.section("test_grid_nav", test_grid_nav)
	await H.section("test_unit", test_unit)
	await H.section("test_selection", test_selection)
	await H.section("test_selection_box", test_selection_box)
	await H.section("test_orders", test_orders)
	await H.section("test_production", test_production)
	await H.section("test_camera", test_camera)
	await H.section("test_bindings", test_bindings)
	await H.section("test_localization", test_localization)
	await H.section("test_demo", test_demo)
	await H.section("test_separation", test_separation)
	await H.section("test_lite_scope", test_lite_scope)
	await H.section("test_scrub", test_scrub)
	await H.section("test_sm_build", test_sm_build)
	await H.section("test_sm_nodes", test_sm_nodes)
	await H.section("test_sm_tech", test_sm_tech)
	await H.section("test_sm_abilities", test_sm_abilities)
	await H.section("test_sm_domain", test_sm_domain)
	await H.section("test_sm_ew", test_sm_ew)
	await H.section("test_sm_catalog", test_sm_catalog)
	await H.section("test_sm_camera_rig", test_sm_camera_rig)
	await H.section("test_sm_greybox", test_sm_greybox)
	await H.section("test_sm_phillips", test_sm_phillips)
	await H.section("test_sm_bots", test_sm_bots)
	await H.section("test_sm_mission", test_sm_mission)
	await H.section("test_sm_sop_ruak", test_sm_sop_ruak)
	await H.section("test_sm_maps", test_sm_maps)
	await H.section("test_sm_factions", test_sm_factions)
	await H.section("test_sm_raider", test_sm_raider)
	await H.section("test_sm_roster", test_sm_roster)
	await H.section("test_sm_campaign", test_sm_campaign)
	await H.section("test_sm_hud", test_sm_hud)
	await H.section("test_sm_outcome", test_sm_outcome)
	await H.section("test_sm_sight", test_sm_sight)
	await H.section("test_sm_shapes", test_sm_shapes)
	await H.section("test_sm_field", test_sm_field)
	await H.section("test_sm_sites", test_sm_sites)
	await H.section("test_sm_haze", test_sm_haze)
	await H.section("test_sm_chain", test_sm_chain)
	await H.section("test_sm_names", test_sm_names)
	await H.section("test_sm_protocols", test_sm_protocols)
	await H.section("test_sm_sides", test_sm_sides)
	await H.section("test_sm_fx", test_sm_fx)
	await H.section("test_sm_story", test_sm_story)
	await H.section("test_set_piece", test_set_piece)
	await H.section("test_signature_rules", test_signature_rules)
	await H.section("test_sm_play", test_sm_play)
	await H.section("test_sm_web", test_sm_web)
	await H.section("test_sm_boot", test_sm_boot)
	await H.section("test_sm_guide", test_sm_guide)
	await H.section("test_sm_bark", test_sm_bark)
	await H.section("test_sm_orders_mark", test_sm_orders_mark)
	await H.section("test_sm_goal", test_sm_goal)
	await H.section("test_sm_command", test_sm_command)
	await H.section("test_sm_pick", test_sm_pick)
	await H.section("test_sm_monsoon", test_sm_monsoon)
	await H.section("test_sm_settings", test_sm_settings)
	await H.section("test_sm_difficulty", test_sm_difficulty)
	await H.section("test_sm_guns", test_sm_guns)
	await H.section("test_lan", test_lan)
	await H.section("test_lan_match", test_lan_match)
	await H.section("test_unit_motion", test_unit_motion)
	await H.section("test_unit_facing", test_unit_facing)
	await H.section("test_weapon_sockets", test_weapon_sockets)
	await H.section("test_dog_motion", test_dog_motion)
	await H.section("test_building_materials", test_building_materials)
	await H.section("test_hud_redesign", test_hud_redesign)
	await H.section("test_hud_pause", test_hud_pause)
	await H.section("test_map_symmetry", test_map_symmetry)
	await H.section("test_model_scale", test_model_scale)
	await H.section("test_street_towns", test_street_towns)
	await H.section("test_game_language", test_game_language)
	await H.section("test_render_budget", test_render_budget)
	preload("res://game/render_budget.gd").shutdown(self)
	quit(H.finish())

func test_scripts() -> void:
	var paths: PackedStringArray = PackedStringArray()
	_collect_scripts("res://", paths)
	var failed: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if load(path) == null:
			failed.append(path)
	var note: String = "every script loads (%d)" % paths.size()
	if not failed.is_empty():
		note = "every script loads, failed %s" % ", ".join(failed)
	check(paths.size() > 40 and failed.is_empty(), note)
	var Served: GDScript = load("res://game/served_art.gd") as GDScript
	Served.skip_export = true
	Served._cache.clear()
	var kokang_still: Texture2D = Served.texture("briefings/kokang.webp")
	var patani_still: Texture2D = Served.texture("briefings/ghosts_of_patani.webp")
	var pakbeng_still: Texture2D = Served.texture("briefings/fog_over_pakbeng.webp")
	check(kokang_still != null and patani_still != null and pakbeng_still != null, "briefing stills resolve from fixtures without build/web")
	Served.skip_export = false
	Served._cache.clear()
	var art_src: String = FileAccess.get_file_as_string("res://game/served_art.gd")
	var boot_src: String = FileAccess.get_file_as_string("res://game/boot.gd")
	check(art_src.contains("HTTPRequest") and art_src.contains("func _page"), "briefing stills are fetched over HTTP on the web")
	check(boot_src.contains("warm.call_deferred"), "the menu prefetches models after the boot scene is ready")

func _collect_scripts(dir_path: String, into: PackedStringArray) -> void:
	var access: DirAccess = DirAccess.open(dir_path)
	if access == null:
		return
	for name: String in access.get_files():
		if name.ends_with(".gd"):
			into.append(dir_path.path_join(name))
	for sub: String in access.get_directories():
		if sub.begins_with(".") or sub == "build":
			continue
		_collect_scripts(dir_path.path_join(sub), into)

const PLANNED_MAPS: Array[String] = ["burma_road", "ten_degree_atolls", "mekong_delta", "chiang_rai"]

func test_map_symmetry() -> void:
	for map_id: String in PLANNED_MAPS:
		var plan: SMMapPlan = SMMapPlan.of(map_id)
		check(plan != null and plan.cols > 0 and SMDomainGrid.pad_of(map_id) == Vector2i.ZERO, "%s loads from data/maps" % map_id)
		if plan == null:
			continue
		var grid: SMDomainGrid = plan.grid()
		var mirrored: bool = true
		for y: int in grid.rows:
			for x: int in grid.cols:
				var c := Vector2i(x, y)
				var t: Vector2i = plan.twin_cell(c)
				if grid.domain_at_cell(c) != grid.domain_at_cell(t) or grid.holding(c) != grid.holding(t):
					mirrored = false
		check(mirrored, "%s terrain and holds match their twin cell by cell" % map_id)
		var half: int = plan.starts.size() / 2
		var seats_ok: bool = plan.starts.size() >= 2 and plan.starts.size() % 2 == 0
		for seat: int in half:
			seats_ok = seats_ok and plan.twin_cell(plan.start(seat)) == plan.start(seat + half)
		check(seats_ok, "%s spawns are twins of each other" % map_id)
		check(_side_parity(plan, plan.nodes, true) and _side_parity(plan, plan.sites, false), "%s resources and tech sites match side for side" % map_id)
		var near_a: Array[float] = _node_reach(plan, grid, 0)
		var near_b: Array[float] = _node_reach(plan, grid, half)
		check(near_a.size() == plan.nodes.size() / 2 and near_a == near_b, "%s each side has the same node distances from its start" % map_id)
		var clear: bool = true
		for r: Rect2i in plan.plateaus:
			for y: int in range(r.position.y, r.end.y):
				for x: int in range(r.position.x, r.end.x):
					if grid.domain_at_cell(Vector2i(x, y)) != SMDomainGrid.Domain.LAND or grid.holding(Vector2i(x, y)):
						clear = false
		for row: Dictionary in plan.props:
			for r: Rect2i in plan.plateaus:
				if r.has_point(row["cell"] as Vector2i):
					clear = false
		check(clear and not plan.plateaus.is_empty(), "%s start plateaus are open land with no scenery" % map_id)
		var nav := RTSGridNav.new(grid.cols, grid.rows, grid.cell_size, grid.origin)
		for y: int in grid.rows:
			for x: int in grid.cols:
				var c := Vector2i(x, y)
				var d: int = grid.domain_at_cell(c)
				nav.set_blocked(c, grid.holding(c) or not (d == SMDomainGrid.Domain.LAND or d == SMDomainGrid.Domain.SHALLOW))
		var a: Vector3 = grid.cell_center(plan.start(0))
		var b: Vector3 = grid.cell_center(plan.start(half))
		check(nav.find_path(a, b).size() > 0 and nav.find_path(b, a).size() > 0, "%s ground forces can reach the other start" % map_id)
		var built_a: int = _base_plots(grid, plan, 0)
		var built_b: int = _base_plots(grid, plan, half)
		check(built_a == built_b and built_a >= 9, "%s both bases fit the same footprints (%d and %d)" % [map_id, built_a, built_b])

func _side_parity(plan: SMMapPlan, rows: Array[Dictionary], goods: bool) -> bool:
	var a: Array[String] = []
	var b: Array[String] = []
	for row: Dictionary in rows:
		var key: String = "%s|%d|%s" % [str(row["kind"]), int(row.get("rate", 0)), str(row.get("water", false))]
		if int(row["side"]) == 0:
			a.append(key)
			var twin: Vector2i = plan.twin_cell(row["cell"] as Vector2i)
			var found: bool = false
			for other: Dictionary in rows:
				if int(other["side"]) == 1 and other["cell"] == twin and str(other["kind"]) == str(row["kind"]):
					found = true
			if not found:
				return false
		else:
			b.append(key)
	a.sort()
	b.sort()
	return a == b and (not goods or a.size() >= 4)

func _node_reach(plan: SMMapPlan, grid: SMDomainGrid, seat: int) -> Array[float]:
	var side: int = 0 if seat < plan.starts.size() / 2 else 1
	var home: Vector3 = grid.cell_center(plan.start(seat))
	var out: Array[float] = []
	for row: Dictionary in plan.nodes:
		if int(row["side"]) == side:
			out.append(snappedf(home.distance_to(grid.cell_center(row["cell"] as Vector2i)), 0.01))
	out.sort()
	return out

func _base_plots(grid: SMDomainGrid, plan: SMMapPlan, seat: int) -> int:
	var base := SMBasePlan.new(grid, grid.cell_center(plan.start(seat)), 48.0)
	base.plot(&"yard", "yard")
	var goods := SMCommodityNet.new()
	for row: Dictionary in plan.nodes:
		goods.add_node(row["id"] as StringName, SMMapPlan.goods_kind(row["kind"] as StringName), grid.cell_center(row["cell"] as Vector2i), 0, false)
	base.keep_nets(goods, null)
	var roles: PackedStringArray = ["power", "power", "refinery", "barracks", "factory", "air", "tech", "defense", "defense"]
	var placed: int = 1
	for i: int in roles.size():
		base.plot(StringName("b%d" % i), roles[i])
		if base.plots.has(StringName("b%d" % i)):
			placed += 1
	return placed if base.overlaps() == 0 else -1

func test_street_towns() -> void:
	for map_id: String in PLANNED_MAPS:
		var plan: SMMapPlan = SMMapPlan.of(map_id)
		var grid: SMDomainGrid = plan.grid()
		check(not plan.towns.is_empty() and _lots_twinned(plan), "%s towns are twinned lot for lot, model and facing included" % map_id)
		check(_lots_squared(plan, grid), "%s every lot squares to 90 degrees and fronts a street of its own town" % map_id)
		var clear: bool = true
		var spots: Array[Vector2i] = plan.starts.duplicate()
		for row: Dictionary in plan.nodes + plan.sites:
			spots.append(row["cell"] as Vector2i)
		for lot: Dictionary in plan.lots:
			var r: Rect2i = lot["rect"] as Rect2i
			for p: Rect2i in plan.plateaus:
				clear = clear and not p.intersects(r)
			for spot: Vector2i in spots:
				clear = clear and not r.grow(1).has_point(spot)
		for tree: Dictionary in plan.groves:
			for p: Rect2i in plan.plateaus:
				clear = clear and not p.has_point(tree["cell"] as Vector2i)
		check(clear, "%s towns and orchards stay off plateaus, starts, nodes and tech sites" % map_id)
		var held: bool = true
		for lot: Dictionary in plan.lots:
			var r: Rect2i = lot["rect"] as Rect2i
			for y: int in range(r.position.y, r.end.y):
				for x: int in range(r.position.x, r.end.x):
					var c := Vector2i(x, y)
					if grid.domain_at_cell(c) == SMDomainGrid.Domain.LAND and not grid.holding(c):
						held = false
		for r: Rect2i in plan.streets:
			for y: int in range(r.position.y, r.end.y):
				for x: int in range(r.position.x, r.end.x):
					if grid.in_bounds(Vector2i(x, y)) and grid.holding(Vector2i(x, y)):
						held = false
		check(held, "%s town blocks block ground movement and every street stays open" % map_id)
		var rows_ok: bool = true
		var twins: Dictionary = {}
		for tree: Dictionary in plan.groves:
			twins[tree["cell"]] = true
		for tree: Dictionary in plan.groves:
			rows_ok = rows_ok and twins.has(plan.twin_cell(tree["cell"] as Vector2i))
		for r: Rect2i in plan.orchards:
			var lines: Dictionary = {}
			for tree: Dictionary in plan.groves:
				if r.has_point(tree["cell"] as Vector2i):
					lines[(tree["cell"] as Vector2i).y] = int(lines.get((tree["cell"] as Vector2i).y, 0)) + 1
			rows_ok = rows_ok and lines.size() >= 2
			for n: Variant in lines.values():
				rows_ok = rows_ok and int(n) == r.size.x
		check(rows_ok, "%s orchards are planted in full straight rows on both sides" % map_id)
	var places_ok: bool = true
	var named: Array[String] = []
	for map_id: String in PLANNED_MAPS:
		for town: Dictionary in SMMapPlan.of(map_id).towns:
			named.append(str(town["place"]))
	var missions: PackedStringArray = DirAccess.get_files_at("res://data/maps/missions")
	for file: String in missions:
		var dressing: SMMapPlan = SMMapPlan.dressing(file.get_basename())
		for town: Dictionary in dressing.towns:
			named.append(str(town["place"]))
	for place: String in named:
		var path: String = "res://data/places/%s.json" % place
		var ref: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		places_ok = places_ok and ref is Dictionary and str((ref as Dictionary).get("license", "")).contains("OpenStreetMap") and (ref as Dictionary).has("stats")
	check(named.size() >= 20 and places_ok, "every town names a real place with an OpenStreetMap street reference (%d towns)" % named.size())
	var shared: PackedStringArray = PackedStringArray()
	var dress_ok: bool = missions.size() >= 15
	for file: String in missions:
		var id: String = file.get_basename()
		var dressing: SMMapPlan = SMMapPlan.dressing(id)
		dress_ok = dress_ok and dressing != null and not dressing.lots.is_empty() and _lots_squared(dressing, null)
		for town: Dictionary in dressing.towns:
			dress_ok = dress_ok and not bool(town["solid"])
		if id != "kokang" and id != "phillips_channel" and id != "sop_ruak":
			shared.append(id)
			for lot: Dictionary in dressing.lots:
				var r: Rect2i = lot["rect"] as Rect2i
				dress_ok = dress_ok and Rect2i(0, 0, 36, 24).encloses(r) and not r.intersects(Rect2i(5, 2, 18, 18)) and not r.intersects(Rect2i(9, 6, 19, 13))
	check(dress_ok and shared.size() >= 12, "every campaign mission dresses a squared street town outside its base and action ground")
	var host := Node3D.new()
	root.add_child(host)
	var plan: SMMapPlan = SMMapPlan.of("burma_road")
	preload("res://game/ground_view.gd").dress(host, plan.grid(), "burma", plan)
	var drawn: int = 0
	var square: bool = true
	for child: Node in host.get_children():
		if child is MultiMeshInstance3D and str(child.name).begins_with("Town_"):
			var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
			for i: int in mm.instance_count:
				drawn += 1
				var ahead: Vector3 = mm.get_instance_transform(i).basis.z
				square = square and (absf(ahead.x) < 0.001 or absf(ahead.z) < 0.001)
	check(drawn == plan.lots.size() and square, "burma road draws every lot as a house squared to the street grid (%d)" % drawn)
	check(host.get_node_or_null("Houses") == null and host.get_node_or_null("Orchard_rubber_tree") != null, "planned maps draw no loose houses, and orchards draw in rows")
	host.free()

func _lots_twinned(plan: SMMapPlan) -> bool:
	var seen: Dictionary = {}
	for lot: Dictionary in plan.lots:
		seen["%s|%s|%d" % [lot["id"], lot["rect"], roundi(float(lot["yaw"]))]] = int(lot["side"])
	for lot: Dictionary in plan.lots:
		var r: Rect2i = plan.twin_rect(lot["rect"] as Rect2i)
		var yaw: float = fposmod(float(lot["yaw"]) + 180.0, 360.0) if plan.symmetry == "rot180" else fposmod(360.0 - float(lot["yaw"]), 360.0)
		var key: String = "%s|%s|%d" % [lot["id"], r, roundi(yaw)]
		if not seen.has(key) or int(seen[key]) == int(lot["side"]):
			return false
	return true

func _lots_squared(plan: SMMapPlan, grid: SMDomainGrid) -> bool:
	var taken: Dictionary = {}
	for lot: Dictionary in plan.lots:
		var r: Rect2i = lot["rect"] as Rect2i
		var yaw: float = float(lot["yaw"])
		var town: Rect2i = plan.towns[int(lot["town"])]["rect"] as Rect2i
		if absf(fposmod(yaw, 90.0)) > 0.001 or not town.encloses(r) or not town.has_point(lot["street"] as Vector2i) or not plan.on_street(lot["street"] as Vector2i):
			return false
		if grid != null and not Rect2i(0, 0, grid.cols, grid.rows).encloses(r):
			return false
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				if taken.has(Vector2i(x, y)) or plan.on_street(Vector2i(x, y)):
					return false
				taken[Vector2i(x, y)] = true
	return true

func test_model_scale() -> void:
	const Models = preload("res://game/model_registry.gd")
	const Env = preload("res://game/env_dress.gd")
	var chart: Dictionary = SMBasePlan.chart()
	check(not chart.is_empty() and float(chart.get("cell_m", 0.0)) == 4.0, "the scale chart loads with 4 m cells")
	var unclassed: Array[String] = []
	var unroled: Array[String] = []
	var host := Node3D.new()
	root.add_child(host)
	var infantry_ok: bool = true
	var infantry_seen: int = 0
	var vehicles_ok: bool = true
	var too_big: Array[String] = []
	var too_small: Array[String] = []
	var fitted: int = 0
	for faction: String in ["gtfc", "mvd", "nmrf", "black_market"]:
		SMFront.faction_id = faction
		var data: Dictionary = SMCatalog.faction(faction)
		for unit: Dictionary in SMCatalog.units_of(data):
			var id: String = str(unit.get("id", ""))
			var cls: String = Scale.unit_class(id)
			if cls == "":
				unclassed.append(id)
				continue
			var body: MeshInstance3D = Forms.dress_unit(id, str(unit.get("role", "")), str(unit.get("locomotion", "ground")), Color.GRAY)
			host.add_child(body)
			var model: Node3D = body.get_node_or_null("Model") as Node3D
			if model != null:
				var size: Vector3 = (model.transform * Models._merged_aabb(model)).size
				var target: Dictionary = Scale.unit_target(id)
				if cls == "infantry":
					infantry_seen += 1
					infantry_ok = infantry_ok and absf(size.y - 1.8) < 0.1
				elif target.has("length") and not target.has("height_max"):
					vehicles_ok = vehicles_ok and absf(maxf(size.x, size.z) - float(target["length"])) < float(target["length"]) * 0.06
			body.free()
		for item: Variant in data.get("buildings", []):
			var row: Dictionary = item as Dictionary
			var bid: String = str(row.get("id", ""))
			var role: String = str(row.get("role", ""))
			var roles: Dictionary = chart.get("building_roles", {}) as Dictionary
			if not roles.has(role) and not (chart.get("buildings", {}) as Dictionary).has(bid):
				unroled.append(bid)
			var mi := MeshInstance3D.new()
			mi.name = "Built_%s" % bid
			if not Forms.dress_structure(mi, SMPointer.BUILDING_SIZE, Color.GRAY):
				mi.free()
				continue
			host.add_child(mi)
			var plot: Vector2 = mi.get_meta("footprint_m", Vector2.ZERO) as Vector2
			var model: Node3D = mi.get_node_or_null("Model") as Node3D
			if model != null and plot != Vector2.ZERO:
				fitted += 1
				var placed: AABB = model.transform * Models._merged_aabb(model)
				var limit: float = Scale.fill() + 0.01
				if placed.size.x > plot.x * limit or placed.size.z > plot.y * limit or placed.size.y > maxf(plot.x, plot.y) * Scale.height_ratio_max() + 0.05:
					too_big.append(bid)
				if maxf(placed.size.x / plot.x, placed.size.z / plot.y) < 0.5 and placed.size.y < maxf(plot.x, plot.y) * Scale.height_ratio_max() - 0.05:
					too_small.append(bid)
			mi.free()
	SMFront.faction_id = "gtfc"
	check(unclassed.is_empty(), "every unit has a scale class %s" % [unclassed.slice(0, 6)])
	check(unroled.is_empty(), "every building has a footprint %s" % [unroled.slice(0, 6)])
	check(infantry_seen > 0 and infantry_ok, "infantry models stand 1.8 m tall")
	check(vehicles_ok, "vehicle, aircraft and ship models match their class length")
	check(fitted > 10 and too_big.is_empty(), "%d building models sit inside their grid footprint %s" % [fitted, too_big.slice(0, 6)])
	check(too_small.is_empty(), "building models fill their footprint %s" % [too_small.slice(0, 6)])
	var yard: Vector2 = SMBasePlan.footprint_m("", "yard")
	var wall: Vector2 = SMBasePlan.footprint_m("", "defense")
	check(yard == Vector2(16.0, 16.0) and wall == Vector2(8.0, 8.0) and SMBasePlan.footprint_m("gun_wharf", "naval") == Vector2(8.0, 16.0), "footprints come from the chart in metres")
	var env_ids: PackedStringArray = PackedStringArray()
	for dir_path: String in ["res://game/models/env", "res://build/web/models/env"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file: String in dir.get_files():
			if file.ends_with(".glb") and not env_ids.has(file.get_basename()):
				env_ids.append(file.get_basename())
	var bare: Array[String] = []
	for id: String in env_ids:
		if Scale.scenery_class(id) == "":
			bare.append(id)
	check(env_ids.size() > 20 and bare.is_empty(), "every scenery model has a scale class %s" % [bare.slice(0, 6)])
	var tree: Node3D = Env._load("teak_tree")
	var house: Node3D = Env._load("shan_stilt_house")
	var tree_h: float = -1.0
	var house_l: float = -1.0
	if tree != null:
		var box: AABB = Models._merged_aabb(tree)
		tree_h = box.size.y * Env.fit_of("teak_tree", box)
		tree.free()
	if house != null:
		var hbox: AABB = Models._merged_aabb(house)
		house_l = maxf(hbox.size.x, hbox.size.z) * Env.fit_of("shan_stilt_house", hbox)
		house.free()
	check(absf(tree_h - 9.0) < 0.1 and house_l > 4.0 and house_l <= 7.6, "trees stand 9 m and houses stay house-sized (%.1f m, %.1f m)" % [tree_h, house_l])
	host.free()
	await process_frame

func test_hud_redesign() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	check(mm != null and mm.backdrop != null and mm.backdrop.get_width() > 0, "the minimap carries a baked terrain backdrop")
	if mm != null:
		mm.sample()
	check(mm != null and (mm.saw_land or mm.saw_water) and mm.frustum.size() >= 3, "the minimap samples terrain and the camera frustum")
	var hud: SMHud = scene.get("hud") as SMHud
	check(hud != null and mm != null and mm.sight != null and mm.sight.grid != null, "the HUD keeps a grid-bound sight for minimap fog")
	var field: SMPointer = scene.get("field") as SMPointer
	var unit: RTSUnit = field.units_of(0)[0] if field != null and field.units_of(0).size() > 0 else null
	if unit != null:
		field.selection.clear()
		field.selection.call("_add", unit)
	await process_frame
	await process_frame
	var hp: Label = scene.find_child("CardHp", true, false) as Label
	var who: Label = scene.find_child("CardName", true, false) as Label
	var rank: Control = scene.find_child("CardRank", true, false) as Control
	var ability: Label = scene.find_child("CardAbility", true, false) as Label
	check(unit != null and hp != null and hp.visible and hp.text != "0/0" and hp.text.contains("/") and who != null and who.text != "", "a selected unit shows its name and real HP")
	check(rank != null and rank.visible and ability != null and ability.visible and ability.text != "", "a selected unit shows rank and ability")
	var top: Control = scene.find_child("TopBar", true, false) as Control
	var plate: Control = scene.find_child("CreditsPlate", true, false) as Control
	var frame: Control = scene.find_child("MonitorFrame", true, false) as Control
	check(top != null and plate != null and frame != null and scene.find_child("PowerIcon", true, false) != null, "the top bar has a credits plate and the sidebar frames the minimap")
	var skin: GDScript = load("res://game/hud_skin.gd") as GDScript
	var ids: PackedStringArray = PackedStringArray(["gtfc", "nmrf", "mvd", "black_market"])
	var distinct: Dictionary = {}
	for id: String in ids:
		distinct[(skin.call("color", id, "trim") as Color).to_html()] = true
	check(distinct.size() == 4, "each faction has its own sidebar trim")
	var card: Control = scene.find_child("UnitCard", true, false) as Control
	var cameo: Control = scene.find_child("CardCameo", true, false) as Control
	hud.layout_for(Vector2(390, 844))
	await process_frame
	await process_frame
	check(hud.phone and card != null and is_equal_approx(card.anchor_right, 1.0) and cameo != null and cameo.custom_minimum_size.x < 96.0, "a portrait phone stretches the unit panel across the screen with a smaller portrait")
	hud.layout_for(Vector2(1280, 720))
	await process_frame
	await process_frame
	check(not hud.phone and is_equal_approx(card.anchor_right, 0.0) and is_equal_approx(cameo.custom_minimum_size.x, 96.0), "back on desktop the unit panel returns to the bottom centre")
	scene.free()
	await process_frame

func test_hud_pause() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var exit: Node = scene.get_node_or_null("MatchExit")
	var pause: Control = scene.find_child("PauseMenu", true, false) as Control
	check(exit != null and pause != null and not pause.visible, "a match builds the pause view hidden")
	var esc: InputEventKey = InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	exit._unhandled_input(esc)
	var settings: Control = scene.find_child("SettingsPanel", true, false) as Control
	check(pause.visible and paused and settings != null and settings.visible and settings.get_parent() == pause and bool(settings.get("embedded")), "Esc pauses the match and opens settings inside the glass view")
	var names: PackedStringArray = PackedStringArray(["PauseResume", "PauseQuit", "PauseSkip", "PauseTrack", "MasterVolume", "MusicVolume", "SfxVolume", "GraphicsLow", "VoiceValue", "EdgePan"])
	var all: bool = true
	for node_name: String in names:
		if pause.find_child(node_name, true, false) == null:
			all = false
	check(all, "the pause view holds audio, graphics, voice, controls, resume, quit, and skip")
	var glass: Control = pause.get_node_or_null("PauseGlass") as Control
	var card: Control = pause.get_node_or_null("PauseCard") as Control
	check(glass != null and bool(glass.get_meta("glass", false)) and card != null and bool(card.get_meta("glass", false)), "the pause view sits on frosted glass")
	var backdrop: CanvasItem = settings.get_node_or_null("SettingsBackdrop") as CanvasItem
	check(backdrop != null and not backdrop.visible, "the embedded settings drop their menu backdrop")
	var skip_key: InputEventKey = InputEventKey.new()
	skip_key.pressed = true
	skip_key.keycode = KEY_N
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	clips.call("play_faction", scene, "gtfc")
	var before: String = str(clips.call("current_title"))
	exit._unhandled_input(skip_key)
	check(str(clips.call("current_title")) != before, "N skips the song")
	settings._unhandled_input(esc)
	check(not pause.visible and not paused and settings.get_parent() != pause and not settings.visible and not bool(settings.get("embedded")), "Esc in the view resumes and returns settings to the layer")
	pause.visible = true
	exit.call("_process", 0.0)
	check(paused and settings.get_parent() == pause, "the HUD menu button opens the same view")
	(pause.find_child("PauseResume", true, false) as Button).pressed.emit()
	check(not paused and not pause.visible, "Resume closes the view")
	var phone_button: Button = scene.find_child("PauseButton", true, false) as Button
	check(phone_button != null and phone_button.custom_minimum_size.x >= 44.0, "phones get a tappable pause button")
	scene.free()
	paused = false
	await process_frame
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var roll: Button = boot.find_child("CreditsButton", true, false) as Button
	check(roll != null, "the menu has a credits button")
	roll.pressed.emit()
	var panel: Control = boot.find_child("CreditsPanel", true, false) as Control
	var music: Label = boot.find_child("CreditsMusic", true, false) as Label
	var credits_scroll: ScrollContainer = boot.find_child("CreditsScroll", true, false) as ScrollContainer
	var credits_back: Control = boot.find_child("CreditsBack", true, false) as Control
	var tab_camp: Control = boot.find_child("TabCampaign", true, false) as Control
	var tab_multi: Control = boot.find_child("TabMultiplayer", true, false) as Control
	var grey_btn: Control = boot.find_child("GreyboxButton", true, false) as Control
	var train_btn: Control = boot.find_child("BasicTraining", true, false) as Control
	var font_match: bool = tab_camp != null and tab_multi != null and tab_camp.get_theme_font_size("font_size") == tab_multi.get_theme_font_size("font_size") and grey_btn != null and train_btn != null and grey_btn.get_theme_font_size("font_size") == train_btn.get_theme_font_size("font_size")
	check(panel != null and panel.visible and music != null and music.text == "BlackBloc" and credits_scroll != null and credits_back != null and credits_scroll.position.y + credits_scroll.size.y <= credits_back.position.y and font_match, "the credits screen scrolls above Back, credits BlackBloc, and keeps menu button font sizes uniform")
	panel._unhandled_input(esc)
	var title: CanvasItem = boot.find_child("GameTitle", true, false) as CanvasItem
	check(not panel.visible and title != null and title.visible, "Esc closes the credits")
	boot.free()
	await process_frame

func _unit(team: int, at: Vector3, t: StringName = &"unit") -> RTSUnit:
	var u: RTSUnit = RTSUnit.new()
	u.team = team
	u.unit_type = t
	u.position = at
	root.add_child(u)
	return u

## Top-down projection for selection tests: screen = world XZ * 10.
func _proj(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * 10.0

func test_teams() -> void:
	var t: RTSTeams = RTSTeams.new()
	t.add_team(0, Color.BLUE)
	check(t.are_allies(3, 3), "a team is allied with itself")
	check(t.are_enemies(0, 1), "unknown pair defaults to enemy")
	t.set_relation(1, 0, RTSTeams.Relation.ALLY)
	check(t.are_allies(0, 1) and t.are_allies(1, 0), "relations are symmetric")
	t.set_relation(0, 2, RTSTeams.Relation.NEUTRAL)
	check(not t.are_enemies(0, 2) and not t.are_allies(0, 2), "neutral is neither")
	check(t.color_of(0) == Color.BLUE and t.color_of(9) == Color.GRAY, "team colours with fallback")

func test_economy() -> void:
	var e: RTSEconomy = RTSEconomy.new()
	check(e.credits(0) == 0, "starts empty")
	e.earn(0, 100)
	e.earn(0, -5)
	check(e.credits(0) == 100 and e.earned_total[0] == 100, "earn ignores negatives, tracks total")
	check(e.try_spend(0, 60) and e.credits(0) == 40, "spend")
	check(not e.try_spend(0, 41) and e.credits(0) == 40, "cannot overspend")
	check(not e.try_spend(0, -10), "negative cost refused")
	e.set_credits(1, -50)
	check(e.credits(1) == 0, "set_credits clamps at zero")

func test_resource_nodes() -> void:
	var e: RTSEconomy = RTSEconomy.new()
	var r: RTSResourceNode = RTSResourceNode.new(Vector3.ZERO, 10, 2.0, 25)
	check(r.advance(5.0, e) == 0, "unowned node pays nothing")
	r.owner_team = 1
	check(r.advance(4.0, e) == 20 and e.credits(1) == 20, "two intervals pay 2x rate")
	check(r.advance(1.0, e) == 0, "partial interval pays nothing yet")
	check(r.advance(9.0, e) == 5 and r.depleted(), "last payout capped by remaining amount")
	check(r.advance(10.0, e) == 0 and e.credits(1) == 25, "depleted node stops")
	var inf: RTSResourceNode = RTSResourceNode.new(Vector3.ZERO, 3, 1.0, -1)
	inf.owner_team = 0
	check(inf.advance(100.0, e) == 300 and not inf.depleted(), "infinite node")

func test_formation() -> void:
	var s: Array[Vector3] = RTSFormation.box(Vector3(0, 0, 10), Vector3.ZERO, 9, 2.0)
	check(s.size() == 9, "box makes one slot per unit")
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in s:
		c += p
	check((c / 9.0).length() < 0.01, "box is centred on the target")
	var unique: Dictionary[Vector3, bool] = {}
	var min_d: float = INF
	for i: int in s.size():
		unique[s[i].snapped(Vector3.ONE * 0.01)] = true
		for j: int in range(i + 1, s.size()):
			min_d = minf(min_d, s[i].distance_to(s[j]))
	check(unique.size() == 9 and min_d >= 1.99, "slots distinct and >= spacing apart")
	var l: Array[Vector3] = RTSFormation.line(Vector3(0, 0, 10), Vector3.ZERO, 4, 2.0)
	check(is_equal_approx(l[0].z, 0.0) and is_equal_approx(l[3].z, 0.0) and is_equal_approx(absf(l[0].x - l[3].x), 6.0), "line is perpendicular to travel")
	check(RTSFormation.box(Vector3.ZERO, Vector3.ZERO, 0).is_empty(), "zero units, no slots")
	var pos: Array[Vector3] = [Vector3(10, 0, 0), Vector3(-10, 0, 0)]
	var slots: Array[Vector3] = [Vector3(-9, 0, 0), Vector3(9, 0, 0)]
	var a: Array[int] = RTSFormation.assign(pos, slots)
	check(a[0] == 1 and a[1] == 0, "assignment pairs nearest slots (no crossing)")

func test_grid_nav() -> void:
	var n: RTSGridNav = RTSGridNav.new(10, 10, 2.0, Vector3.ZERO)
	check(n.cell_at(Vector3(3.9, 0, 0.1)) == Vector2i(1, 0) and n.cell_center(Vector2i(1, 0)) == Vector3(3, 0, 1), "cell <-> world")
	var p: PackedVector3Array = n.find_path(Vector3(1, 0, 1), Vector3(17, 0, 1))
	check(p.size() == 8 and p[p.size() - 1].is_equal_approx(Vector3(17, 0, 1)), "straight path ends at the exact target")
	n.block_rect(Rect2i(4, 0, 1, 9))
	check(n.is_blocked(Vector2i(4, 3)) and not n.is_blocked(Vector2i(4, 9)), "wall blocked, gap open")
	p = n.find_path(Vector3(1, 0, 1), Vector3(17, 0, 1))
	var through_gap: bool = false
	var hits_wall: bool = false
	for q: Vector3 in p:
		if n.cell_at(q) == Vector2i(4, 9): through_gap = true
		if n.is_blocked(n.cell_at(q)): hits_wall = true
	check(not p.is_empty() and through_gap and not hits_wall, "detours through the gap, never through the wall")
	n.set_blocked(Vector2i(4, 9))
	check(n.find_path(Vector3(1, 0, 1), Vector3(17, 0, 1)).is_empty(), "sealed wall = no path")
	check(n.nearest_open(Vector2i(4, 4)) != Vector2i(4, 4) and not n.is_blocked(n.nearest_open(Vector2i(4, 4))), "nearest open cell")
	check(n.is_blocked(Vector2i(-1, 0)), "out of bounds counts as blocked")

func test_unit() -> void:
	var u: RTSUnit = _unit(0, Vector3.ZERO)
	await process_frame
	check(u.hp == 100.0 and u.is_alive(), "spawns at max hp")
	u.speed = 5.0
	u.set_path(PackedVector3Array([Vector3(10, 0, 0)]))
	var arrived: Array[bool] = [false]
	u.arrived.connect(func(_x: RTSUnit) -> void: arrived[0] = true)
	u.advance(1.0)
	check(u.position.is_equal_approx(Vector3(5, 0, 0)) and u.is_moving(), "moves speed*delta")
	u.advance(5.0)
	check(u.position.is_equal_approx(Vector3(10, 0, 0)) and not u.is_moving() and arrived[0], "stops exactly at the end, emits arrived")
	var e: RTSUnit = _unit(1, Vector3(14, 0, 0))
	await process_frame
	u.attack_target = e
	u.attack_range = 6.0
	u.attack_damage = 30.0
	u.advance(0.1)
	check(e.hp == 70.0, "attacks a target in range")
	u.advance(0.1)
	check(e.hp == 70.0, "respects attack interval")
	e.position = Vector3(30, 0, 0)
	u.advance(1.0)
	check(u.position.x > 10.0, "chases a target that moved away")
	var dead: Array[bool] = [false]
	e.died.connect(func(_x: RTSUnit) -> void: dead[0] = true)
	e.take_damage(500.0)
	check(not e.is_alive() and e.hp == 0.0 and dead[0], "dies once at 0 hp")
	u.advance(0.1)
	check(u.attack_target == null, "drops dead targets")
	var src: String = FileAccess.get_file_as_string("res://addons/rts_advanced/rts_unit.gd")
	var plain: bool = src.sha256_text() == "bff31504ebfe438ee2304fed1e407da5baea8c16527a061dfaea832830cd3545"
	plain = plain and not src.contains("_pull_shot") and not src.contains("shattered") and not src.contains("black_hole")
	var statue: RTSUnit = _unit(0, Vector3(40, 0, 0))
	statue.hp = 40.0
	statue.set_meta("frozen", true)
	statue.take_damage(8.0)
	var armor: RTSUnit = _unit(0, Vector3(44, 0, 0))
	armor.set_meta("status", "black_hole")
	armor.incoming_mult = 0.2
	var buddy: RTSUnit = _unit(0, Vector3(48, 0, 0))
	buddy.hp = 80.0
	var gun: RTSUnit = _unit(1, Vector3(70, 0, 0))
	gun.attack_damage = 10.0
	gun.attack_range = 40.0
	gun.attack_target = buddy
	gun._cooldown = 0.0
	var armor_hp: float = armor.hp
	gun.advance(0.2)
	check(plain and statue.is_alive() and is_equal_approx(statue.hp, 32.0) and not bool(statue.get_meta("shattered", false)) and is_equal_approx(buddy.hp, 70.0) and is_equal_approx(armor.hp, armor_hp), "core unit matches the pre-shatter script and does not pull shots")
	u.free()
	e.free()
	statue.free()
	armor.free()
	buddy.free()
	gun.free()

func test_selection() -> void:
	var a: RTSUnit = _unit(0, Vector3(1, 0, 1), &"tank")
	var b: RTSUnit = _unit(0, Vector3(2, 0, 2), &"scout")
	var c: RTSUnit = _unit(0, Vector3(20, 0, 20), &"tank")
	var foe: RTSUnit = _unit(1, Vector3(1.5, 0, 1.5))
	await process_frame
	var all: Array = [a, b, c, foe]
	var s: RTSSelection = RTSSelection.new()
	check(s.preview_count(Rect2(0, 0, 4, 4), all, _proj) == 0, "tiny drag = no box count")
	check(s.preview_count(Rect2(30, 30, -30, -30), all, _proj) == 2, "live count, reversed drag, own team only")
	check(s.select_box(Rect2(0, 0, 30, 30), all, _proj) == 2 and a.selected and not foe.selected, "box selects own units")
	s.select_box(Rect2(190, 190, 20, 20), all, _proj, true)
	check(s.count() == 3, "shift-add")
	s.select_at(Vector2(10, 10), all, _proj, false, true)
	check(s.count() == 2 and not a.selected, "ctrl-click toggles off")
	s.select_at(Vector2(200, 200), all, _proj)
	check(s.count() == 1 and s.units[0] == c, "plain click replaces")
	s.select_box(Rect2(0, 0, 300, 300), all, _proj)
	var tc: Dictionary[StringName, int] = s.type_counts()
	check(tc[&"tank"] == 2 and tc[&"scout"] == 1, "type counts for the panel")
	s.save_group(1)
	s.clear()
	check(s.count() == 0 and not b.selected, "clear")
	b.take_damage(1000.0)
	check(s.recall_group(1) == 2, "recall group skips dead units")
	for u: RTSUnit in [a, b, c, foe]:
		u.free()

func test_selection_box() -> void:
	var sb: RTSSelectionBox = RTSSelectionBox.new()
	sb.count_provider = func(_r: Rect2) -> int: return 3
	root.add_child(sb)
	await process_frame
	sb.begin(Vector2(100, 100))
	sb.update_drag(Vector2(104, 102))
	sb.refresh()
	check(not sb.is_box() and not sb.tag.visible, "small drag shows nothing")
	sb.update_drag(Vector2(40, 20))
	sb.refresh()
	check(sb.is_box() and sb.rect() == Rect2(40, 20, 60, 80), "rect normalised for any drag direction")
	check(sb.tag.visible and sb.tag.text == "3 units", "live count tag (localized)")
	sb.count_provider = func(_r: Rect2) -> int: return 1
	sb.refresh()
	check(sb.tag.text == "1 unit", "singular form")
	sb.end()
	check(not sb.active and not sb.tag.visible, "end hides the box")
	sb.free()

func test_orders() -> void:
	var nav: RTSGridNav = RTSGridNav.new(20, 20, 2.0, Vector3.ZERO)
	nav.block_rect(Rect2i(8, 0, 1, 15))
	var us: Array[RTSUnit] = []
	for i: int in 4:
		us.append(_unit(0, Vector3(2 + i, 0, 2)))
	await process_frame
	var slots: Array[Vector3] = RTSOrders.move(us, Vector3(30, 0, 4), nav)
	check(slots.size() == 4, "every unit gets a slot")
	var ok: bool = true
	for u: RTSUnit in us:
		ok = ok and u.is_moving()
	check(ok, "every unit has a path")
	for i: int in 400:
		for u: RTSUnit in us:
			u.advance(0.05)
	var arrived: int = 0
	for u: RTSUnit in us:
		if not u.is_moving() and u.position.x > 24.0: arrived += 1
		check(not nav.is_blocked(nav.cell_at(u.position)), "unit ended on an open cell")
	check(arrived == 4, "all four crossed the wall via the gap and arrived")
	var teams: RTSTeams = RTSTeams.new()
	var foe: RTSUnit = _unit(1, Vector3(30, 0, 30))
	var friend: RTSUnit = _unit(0, Vector3(30, 0, 34))
	await process_frame
	check(RTSOrders.attack(us, foe, nav, teams) == 4 and us[0].attack_target == foe, "attack order on an enemy")
	check(RTSOrders.attack(us, friend, nav, teams) == 0, "attack on a friendly unit ignored")
	RTSOrders.stop(us)
	check(not us[0].is_moving() and us[0].attack_target == null, "stop clears path and target")
	for u: RTSUnit in us:
		u.free()
	foe.free()
	friend.free()

func test_production() -> void:
	var e: RTSEconomy = RTSEconomy.new()
	e.set_credits(0, 250)
	var cat: Dictionary[StringName, Dictionary] = {&"a": {"cost": 100, "time": 2.0}, &"b": {"cost": 50, "time": 1.0}}
	var q: RTSProductionQueue = RTSProductionQueue.new(0, cat)
	q.max_items = 3
	q.rally = Vector3(5, 0, 5)
	var made: Array[StringName] = []
	q.produced.connect(func(t: StringName, r: Vector3) -> void:
		made.append(t)
		check(r == Vector3(5, 0, 5), "produced at the rally point"))
	check(q.enqueue(&"a", e) and e.credits(0) == 150, "queue pays up front")
	check(q.can_queue(&"zzz", e) == "unknown unit", "unknown type refused")
	q.enqueue(&"b", e)
	q.enqueue(&"b", e)
	check(q.can_queue(&"b", e) == "queue full", "queue limit")
	check(e.credits(0) == 50, "three items paid")
	q.advance(1.0)
	check(is_equal_approx(q.head_ratio(), 0.5) and made.is_empty(), "head progresses")
	check(q.cancel(e) == 50 and e.credits(0) == 100 and q.items.size() == 2, "cancel last refunds in full")
	check(q.advance(2.5) == 2 and made == [&"a", &"b"], "overflow time carries into the next item")
	check(q.items.is_empty() and q.head_ratio() == 0.0, "queue drained")
	e.set_credits(0, 10)
	check(q.can_queue(&"b", e) == "not enough credits", "cannot afford")

func test_camera() -> void:
	var cam: RTSCamera = RTSCamera.new()
	cam.bounds = Rect2(-10, -10, 20, 20)
	root.add_child(cam)
	await process_frame
	cam.distance = 30.0
	cam.focus_on(Vector3(3, 0, 4))
	var fwd: Vector3 = -cam.global_transform.basis.z
	var hit: Vector3 = cam.ground_at(cam.unproject_position(Vector3(3, 0, 4)))
	check(hit.distance_to(Vector3(3, 0, 4)) < 0.05, "ground_at inverts unproject at the focus")
	check(fwd.y < -0.5, "looks down at the ground")
	cam.focus_on(Vector3(100, 0, -100))
	check(cam.focus == Vector3(10, 0, -10), "focus clamped to bounds")
	cam.zoom(50)
	check(cam.distance == cam.zoom_min, "zoom in clamps at minimum")
	var p_near: float = cam.pitch()
	cam.zoom(-50)
	check(cam.distance == cam.zoom_max and cam.pitch() > p_near, "zoom out clamps and steepens pitch")
	cam.focus_on(Vector3.ZERO)
	cam.pan(Vector2(1, 0), 0.1)
	check(cam.focus.x > 0.0 and absf(cam.focus.z) < 0.001, "pan right moves focus +x")
	cam.pan(Vector2(0, 1), 0.1)
	check(cam.focus.z < 0.0, "pan up moves focus forward (-z)")
	cam.free()
	var ground: GDScript = load("res://game/ground_view.gd") as GDScript
	var eye: Vector3 = Vector3(0.0, 8.5, 8.5)
	var aim: Vector3 = Vector3.ZERO
	var inside: float = float(ground.call("view_fade", Vector3(0.0, 0.0, 8.5), 12.0, 3.0, eye, aim))
	check(inside > 0.85, "a teak crown around the low camera fades out")
	var beside: float = float(ground.call("view_fade", Vector3(20.0, 0.0, 0.0), 12.0, 3.0, eye, aim))
	check(beside < 0.05, "a teak off the view ray stays solid")
	var above: float = float(ground.call("view_fade", Vector3.ZERO, 12.0, 3.0, Vector3(0.0, 20.0, 20.0), aim))
	check(above < 0.05, "a camera above the canopy leaves the teak in place")
	var short: float = float(ground.call("view_fade", Vector3(0.0, 0.0, 8.5), 2.4, 1.0, eye, aim))
	check(short < 0.05, "short props under the camera stay visible")
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(6.0, 12.0, 6.0)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = 2
	var near_xf: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 6.0, 8.5))
	var far_xf: Transform3D = Transform3D(Basis.IDENTITY, Vector3(30.0, 6.0, 0.0))
	mm.set_instance_transform(0, near_xf)
	mm.set_instance_transform(1, far_xf)
	var spots: Array[Transform3D] = [near_xf, far_xf]
	var trees: MultiMeshInstance3D = MultiMeshInstance3D.new()
	trees.name = "JungleTrees"
	trees.multimesh = mm
	trees.set_meta("all_spots", spots)
	trees.set_meta("shown", spots)
	host.add_child(trees)
	var low_cam: RTSCamera = RTSCamera.new()
	host.add_child(low_cam)
	low_cam.distance = low_cam.zoom_min
	low_cam.focus_on(Vector3.ZERO)
	ground.call("fade_occluders", host, low_cam)
	var fades: PackedFloat32Array = trees.get_meta("canopy_fade") as PackedFloat32Array
	check(fades.size() == 2 and fades[0] > 0.85, "the teak the camera sits in is hidden")
	check(fades[1] < 0.05, "a teak away from the camera keeps its scale")
	var mark: Node3D = Node3D.new()
	mark.name = "Scenery_teak"
	var body: MeshInstance3D = MeshInstance3D.new()
	var tall: BoxMesh = BoxMesh.new()
	tall.size = Vector3(6.0, 12.0, 6.0)
	body.mesh = tall
	body.position = Vector3(0.0, 6.0, 8.5)
	mark.add_child(body)
	host.add_child(mark)
	ground.call("fade_occluders", host, low_cam)
	check(not mark.visible, "a tall prop the camera sits inside is hidden")
	host.free()

func test_bindings() -> void:
	RTSBindings.install()
	check(RTSBindings.key_of(&"rts_produce") == KEY_B, "default key installed")
	check(RTSBindings.label(&"rts_pan_up") == "W", "readable label")
	check(RTSBindings.rebind(&"rts_produce", KEY_X) == &"rts_stop", "rebind onto a used key reports the conflict")
	check(RTSBindings.key_of(&"rts_produce") == KEY_B, "conflicting rebind not applied")
	check(RTSBindings.rebind(&"rts_produce", KEY_G) == &"" and RTSBindings.key_of(&"rts_produce") == KEY_G, "rebind to a free key")
	var path: String = "user://rts_bindings_test.cfg"
	check(RTSBindings.save(path) == OK, "save bindings")
	RTSBindings.reset()
	check(RTSBindings.key_of(&"rts_produce") == KEY_B, "reset to defaults")
	check(RTSBindings.load_from(path) == OK and RTSBindings.key_of(&"rts_produce") == KEY_G, "load restores the rebinding")
	RTSBindings.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_B
	ev.pressed = true
	check(ev.is_action_pressed(&"rts_produce"), "InputMap matches the bound key")

func test_localization() -> void:
	TranslationServer.set_locale("en")
	check(RTSLoc.t("UI_CREDITS", {"credits": 42}) == "Credits: 42", "translate with params")
	var lab: Label = Label.new()
	root.add_child(lab)
	RTSLoc.bind(lab, "UI_SELECTED", {"count": 3})
	check(lab.text == "Selected: 3", "bind sets text")
	check(RTSLoc.set_language("fr", root) >= 1 and lab.text == "Sélection : 3", "live language switch re-renders bound texts")
	check(RTSLoc.missing_keys("fr").is_empty(), "second locale has every key")
	check(RTSLoc.t("NO_SUCH_KEY") == "NO_SUCH_KEY", "missing key falls back to the key")
	TranslationServer.set_locale("en")
	lab.free()

func test_demo() -> void:
	TranslationServer.set_locale("en")
	var d: Node = (load("res://examples/demo.tscn") as PackedScene).instantiate()
	d.set("auto_tick", false)
	root.add_child(d)
	await process_frame
	await process_frame
	var units: Array[RTSUnit] = d.get("units")
	var econ: RTSEconomy = d.get("economy")
	var sel: RTSSelection = d.get("selection")
	check(units.size() == 10 and econ.credits(0) == 200, "demo spawns 6 + 4 units, 200 credits")
	var proj: Callable = Callable(d, "project")
	var n: int = sel.select_box(Rect2(Vector2(-1e5, -1e5), Vector2(2e5, 2e5)), units, proj)
	check(n == 6, "select-all box picks the 6 player units only")
	check(d.call("produce", &"scout") and econ.credits(0) == 150, "production queue in the demo")
	d.call("command_at", Vector3(4, 0, 22))
	var moving: int = 0
	for u: RTSUnit in sel.units:
		if u.is_moving(): moving += 1
	check(moving == 6, "right-click move gives all six a path (crossing the wall)")
	for i: int in 360:
		d.call("tick", 0.05)
	check(units.size() == 11, "the queued scout was produced")
	var res: Array[RTSResourceNode] = d.get("resources")
	var owned: int = 0
	for r: RTSResourceNode in res:
		if r.owner_team == 0: owned += 1
	check(owned >= 1 and econ.credits(0) > 150, "a resource point was captured and pays income")
	var scout: RTSUnit = d.call("spawn_unit", 0, &"tank", Vector3(17, 0, -17))
	for i: int in 40:
		d.call("tick", 0.05)
	check(int(d.get("shots_fired")) > 0, "units fire automatically in range (shot effects spawned)")
	await process_frame
	var hurt: int = 0
	for u: RTSUnit in units:
		if u.hp < u.max_hp and (u.get_node("HealthBar") as Node3D).visible and (u.get_node("HealthBar") as Node3D).scale.x < 1.0: hurt += 1
	check(hurt > 0, "damaged units show a shrinking health bar")
	var close: int = 0
	for i: int in units.size():
		for j: int in range(i + 1, units.size()):
			var a: RTSUnit = units[i]
			var b: RTSUnit = units[j]
			if not a.is_moving() and not b.is_moving() and Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length() < (a.radius + b.radius) * 0.5: close += 1
	check(close == 0 and scout != null, "idle units do not stack (separation)")
	d.queue_free()
	await process_frame

func test_separation() -> void:
	var a: RTSUnit = _unit(0, Vector3(0, 0, 0))
	var b: RTSUnit = _unit(0, Vector3(0.2, 0, 0))
	var c: RTSUnit = _unit(0, Vector3(0, 0, 0))
	await process_frame
	var us: Array = [a, b, c]
	check(RTSSeparation.apply(us, 0.1) == 3, "three overlapping pairs found")
	for i: int in 60:
		RTSSeparation.apply(us, 0.1)
	var ok: bool = true
	for i: int in 3:
		for j: int in range(i + 1, 3):
			var u: RTSUnit = us[i]
			var v: RTSUnit = us[j]
			ok = ok and Vector2(u.position.x - v.position.x, u.position.z - v.position.z).length() >= u.radius + v.radius - 0.01
	check(ok, "after relaxing, no two units overlap (even exact stacks)")
	var w: RTSUnit = _unit(0, Vector3(10, 0, 0))
	var x: RTSUnit = _unit(0, Vector3(10.1, 0, 0))
	await process_frame
	RTSSeparation.apply([w, x], 1.0, 8.0, func(p: Vector3) -> bool: return p.x >= 10.0)
	check(w.position.x >= 10.0, "pushes never move a unit onto blocked ground")
	check(RTSSeparation.apply([a, w], 0.1) == 0, "far apart = untouched")
	for u: RTSUnit in [a, b, c, w, x]:
		u.free()

func test_lite_scope() -> void:
	print("Lite scope (no Pro systems)")
	var bad: Array[String] = []
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		if str(cls["path"]).contains("/pro/") or str(cls["class"]) in ["RTSTerrain", "RTSCombat", "RTSFog", "RTSAIPlayer", "RTSSaveGame", "RTSMinimap"]:
			bad.append(str(cls["class"]))
	check(bad.is_empty(), "no Pro classes in Lite %s" % [bad])
	check(not DirAccess.dir_exists_absolute("res://examples/skirmish") and not DirAccess.dir_exists_absolute("res://assets/units"), "no third-party assets, no skirmish")
	check(FileAccess.get_file_as_string("res://LICENSE").contains("Permission is hereby granted, free of charge"), "Lite is MIT")

const TEXT_EXT: PackedStringArray = ["gd", "tscn", "tres", "md", "txt", "csv", "json", "cfg", "godot", "sh", "py", "js", "gdshader", "import"]
const SKIP: PackedStringArray = ["res://.godot", "res://.git", "res://tests/scrub_terms.rot13", "res://tests/last_run.txt"]

static func rot13(s: String) -> String:
	var out: String = ""
	for ch: String in s:
		var c: int = ch.unicode_at(0)
		if c >= 97 and c <= 122: c = (c - 97 + 13) % 26 + 97
		elif c >= 65 and c <= 90: c = (c - 65 + 13) % 26 + 65
		out += String.chr(c)
	return out

func _files(dir: String, out: Array[String]) -> void:
	for s: String in SKIP:
		if dir == s: return
	var d: DirAccess = DirAccess.open(dir)
	if d == null: return
	d.include_hidden = true
	for f: String in d.get_files():
		var p: String = dir.path_join(f)
		if not SKIP.has(p): out.append(p)
	for sub: String in d.get_directories():
		_files(dir.path_join(sub), out)

func test_scrub() -> void:
	var terms: Array[String] = []
	for line: String in (FileAccess.get_file_as_string("res://tests/scrub_terms.rot13") if FileAccess.file_exists("res://tests/scrub_terms.rot13") else "").split("\n"):
		if line.strip_edges() != "" and not line.begins_with("#"):
			terms.append(rot13(line.strip_edges()))
	var shipped: bool = not FileAccess.file_exists("res://tests/scrub_terms.rot13")
	# the term list is a dev-only file (RELEASE_EXCLUDE.txt); a release extraction runs the generic checks only
	check(terms.size() >= 100 or shipped, "scrub list loaded (%d terms)%s" % [terms.size(), " - dev-only list not shipped" if shipped else ""])
	var pat: String = "(?i)\\b(" + "|".join(terms.map(func(t: String) -> String: return t.replace(" ", "[ _-]"))) + ")\\b"
	if terms.is_empty():
		pat = "(?!x)x"
	var rx: RegEx = RegEx.create_from_string(pat)
	# built from code points so this file does not contain the letters it bans
	var nordic: RegEx = RegEx.create_from_string("[" + "".join([0xE5, 0xE4, 0xF6, 0xC5, 0xC4, 0xD6].map(func(c: int) -> String: return String.chr(c))) + "]")
	var milestone: RegEx = RegEx.create_from_string("(?i)(\\bM(1[0-9]|[1-9])\\b|_m[0-9]{1,2}\\b|\\bm[0-9]{1,2}_|\\bM" + str(2) + "[A-Z])")
	var files: Array[String] = []
	_files("res://", files)
	check(files.size() > 20, "scanned %d files" % files.size())
	var hits: Array[String] = []
	for p: String in files:
		var rel: String = p.trim_prefix("res://")
		for r: RegEx in [rx, nordic, milestone]:
			var m: RegExMatch = r.search(rel)
			if m != null: hits.append("name %s: '%s'" % [rel, m.get_string()])
		if TEXT_EXT.has(p.get_extension()):
			var txt: String = FileAccess.get_file_as_string(p)
			for r: RegEx in [rx, nordic, milestone]:
				var mt: RegExMatch = r.search(txt)
				if mt != null: hits.append("text %s: '%s'" % [rel, mt.get_string()])
	check(hits.is_empty(), "no identifying terms, Nordic letters or milestone tags in files or names %s" % [hits.slice(0, 8)])
	# authors / commit messages (only when run inside the kit's own git repo)
	var root_dir: String = ProjectSettings.globalize_path("res://")
	if DirAccess.dir_exists_absolute(root_dir.path_join(".git")):
		var out: Array = []
		var code: int = OS.execute("git", ["-C", root_dir, "log", "--first-parent", "--format=%an <%ae> %s"], out)
		var log_txt: String = "\n".join(out)
		var bad: Array[String] = []
		for r: RegEx in [rx, nordic, milestone]:
			for mg: RegExMatch in r.search_all(log_txt):
				bad.append(mg.get_string())
		var authors_ok: bool = true
		for l: String in log_txt.split("\n", false):
			if l.begins_with("Kit Author <kit-author@example.invalid>"):
				continue
			if l.begins_with("cursor[bot] <cursor[bot]@users.noreply.github.com> Merge main"):
				continue
			authors_ok = false
		check(code == 0 and bad.is_empty() and authors_ok, "git history: neutral author only, clean messages %s" % [bad])
	else:
		check(true, "no .git here (release extraction); history check runs in the kit repo")

func test_sm_build() -> void:
	var econ: RTSEconomy = RTSEconomy.new()
	econ.set_credits(0, 2000)
	var yard: SMBuildYard = SMBuildYard.new()
	yard.economy = econ
	yard.team = 0
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.center = Vector3.ZERO
	yard.radius = 10.0
	yard.drain_per_sec = 5
	yard.tech_order = [&"yard", &"barracks", &"armory"]
	yard.building_time[&"yard"] = 4.0
	yard.building_time[&"barracks"] = 3.0
	yard.building_time[&"armory"] = 3.0
	check(not yard.begin_scaffold(&"yard", Vector3(20, 0, 0), 100.0), "scaffold rejects a footprint outside the yard")
	check(yard.begin_scaffold(&"yard", Vector3(2, 0, 0), 100.0), "scaffold accepts a footprint inside")
	check(yard.vulnerable, "scaffold is vulnerable while it builds")
	yard.damage_scaffold(40.0)
	check(yard.scaffold_hp == 60.0 and yard.vulnerable, "damage lands on the scaffold")
	yard.advance(2.0)
	check(yard.drained == 10 and yard.scaffold_active, "credits drain while the scaffold stands")
	yard.advance(2.0)
	check(yard.finished.has(&"yard") and not yard.vulnerable, "finished scaffold ends the drain")
	check(not yard.can_build(&"armory"), "linear tech skips nothing")
	check(yard.can_build(&"barracks"), "next building unlocks")
	check(yard.begin_scaffold(&"barracks", Vector3(1, 0, 1), 80.0), "second scaffold starts")
	yard.advance(3.0)
	check(yard.finished.has(&"barracks") and yard.can_build(&"armory"), "armory waits for the previous building")
	var mvd: SMBuildYard = SMBuildYard.new()
	mvd.style = SMBuildYard.Style.INTERNAL
	mvd.economy = econ
	mvd.team = 0
	mvd.center = Vector3.ZERO
	mvd.radius = 10.0
	mvd.clearance = 1
	mvd.building_tier[&"bay"] = 2
	mvd.building_tier[&"siege"] = 3
	mvd.building_time[&"bay"] = 2.0
	mvd.building_time[&"siege"] = 2.0
	check(not mvd.queue_internal(&"bay"), "clearance 1 cannot queue tier 2")
	check(not mvd.buy_clearance(3, 50), "clearance 3 before 2 is refused")
	check(mvd.buy_clearance(2, 50) and mvd.radius == 45.0, "clearance 2 grows the radius")
	check(mvd.queue_internal(&"bay"), "tier 2 queues inside the hub")
	check(mvd.placed.is_empty(), "the hub has not placed the shell yet")
	mvd.advance(2.0)
	check(mvd.ready.has(&"bay"), "the hub finishes the building")
	check(not mvd.place_finished(&"bay", Vector3(50, 0, 0)), "place rejects a point outside the radius")
	check(mvd.place_finished(&"bay", Vector3(12, 0, 0)), "place accepts a point inside the grown radius")
	check(mvd.buy_clearance(3, 50) and mvd.clearance == 3 and mvd.radius == 65.0, "clearance 3 unlocks the next tier")
	check(mvd.queue_internal(&"siege"), "tier 3 queues after clearance 3")
	var grid: SMDomainGrid = SMDomainGrid.new(8, 8, 2.0, Vector3.ZERO)
	grid.set_domain(Vector2i(3, 0), SMDomainGrid.Domain.DEEP)
	var nmrf: SMBuildYard = SMBuildYard.new()
	nmrf.style = SMBuildYard.Style.MOBILE
	nmrf.grid = grid
	check(nmrf.move_packer(grid.cell_center(Vector2i(0, 0))), "packer starts on land")
	check(nmrf.move_packer(grid.cell_center(Vector2i(3, 0))), "packer sails into deep water")
	check(nmrf.unpack(&"boat_shed"), "packer unpacks")
	check(not nmrf.move_packer(grid.cell_center(Vector2i(0, 0))), "an unpacked core does not drive")
	check(nmrf.upgrade_factory(&"boat_shed") and nmrf.factory_level(&"boat_shed") == 2, "factory tier upgrade")
	check(nmrf.upgrade_factory(&"boat_shed") and nmrf.factory_level(&"boat_shed") == 3, "a second factory upgrade")
	check(not nmrf.upgrade_factory(&"boat_shed"), "factory tier stops at 3")

func test_sm_nodes() -> void:
	var net: SMCommodityNet = SMCommodityNet.new()
	var econ: RTSEconomy = RTSEconomy.new()
	check(SMCommodityNet.all_kinds().size() == 5, "five commodities")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_SLAG) == "Golden Slag / Aurum-9", "slag storefront name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_RARE) == "rare earth", "rare earth name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_RUBY) == "ruby", "ruby name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_JADE) == "jade", "jade name")
	check(SMCommodityNet.display_name(SMCommodityNet.KIND_BULLION) == "gold bullion", "bullion name")
	net.add_node(&"s", SMCommodityNet.KIND_SLAG, Vector3.ZERO, 10, false)
	net.add_node(&"r", SMCommodityNet.KIND_RARE, Vector3(3, 0, 0), 0, true)
	net.add_node(&"u", SMCommodityNet.KIND_RUBY, Vector3(6, 0, 0), 10, false)
	net.add_node(&"j", SMCommodityNet.KIND_JADE, Vector3(9, 0, 0), 10, false)
	net.add_node(&"b", SMCommodityNet.KIND_BULLION, Vector3(12, 0, 0), 10, false)
	check(net.snap_refinery(&"s", 0), "refinery snaps to a node")
	check(net.has_collector(&"s"), "one collector spawns")
	check(not net.snap_refinery(&"s", 1), "a second refinery on the same node is rejected")
	check(net.advance(4.0, econ) == 250, "the collector loop pays")
	check(not net.set_night_shift(&"s", true), "slag has no night shift")
	check(net.set_night_shift(&"u", true) and net.visible_through_fog(&"u"), "ruby night shift is visible through fog")
	check(net.set_night_shift(&"j", true) and net.night_on(&"j"), "jade night shift toggles")
	check(net.snap_refinery(&"u", 0), "ruby refinery")
	var before: int = econ.credits(0)
	check(net.advance(2.0, econ) == 250 and econ.credits(0) - before == 250, "night shift pays a full loop in half the time")
	check(net.snap_refinery(&"r", 0), "rare-earth refinery")
	var credits_before: int = econ.credits(0)
	net.advance(4.0, econ)
	check(net.stock_of(0) == 1, "rare-earth stock is a separate counter")
	check(econ.credits(0) >= credits_before, "stock does not spend credits")
	check(not net.try_spend_stock(0, 2), "tier-3 gear cannot spend stock it lacks")
	check(net.try_spend_stock(0, 1) and net.stock_of(0) == 0, "rare-earth stock spends")
	check(net.harm_infantry(Vector3(3, 0, 0), false, 1.0) == 8.0, "adjacent water harms unshielded infantry")
	var bullion: SMCommodityNet = SMCommodityNet.new()
	var bullion_econ: RTSEconomy = RTSEconomy.new()
	bullion.add_node(&"bar", SMCommodityNet.KIND_BULLION, Vector3.ZERO, 10, false)
	check(bullion.snap_refinery(&"bar", 0) and bullion.advance(4.0, bullion_econ) == 400, "a bullion trip pays 400")
	var dry: SMCommodityNet = SMCommodityNet.new()
	var dry_econ: RTSEconomy = RTSEconomy.new()
	dry.add_node(&"dry", SMCommodityNet.KIND_SLAG, Vector3.ZERO, 10, false)
	check(dry.set_reserve(&"dry", 250) and dry.snap_refinery(&"dry", 0) and dry.advance(4.0, dry_econ) == 250, "the last full mine trip still pays 250")
	check(dry.advance(4.0, dry_econ) == 50 and dry.advance(4.0, dry_econ) == 50, "a dry mine trickles 50")
	check(net.harm_infantry(Vector3(3, 0, 0), true, 1.0) == 0.0, "shielded infantry are spared")

func test_sm_tech() -> void:
	var tech: SMTechNet = SMTechNet.new()
	var econ: RTSEconomy = RTSEconomy.new()
	econ.set_credits(0, 0)
	econ.set_credits(1, 100)
	tech.add_site(&"c", SMTechNet.CYBER, Vector3.ZERO)
	tech.add_site(&"b", SMTechNet.BAZAAR, Vector3(2, 0, 0))
	tech.add_site(&"h", SMTechNet.CLINIC, Vector3(4, 0, 0))
	tech.add_site(&"r", SMTechNet.RADAR, Vector3(6, 0, 0))
	check(tech.capture(&"c", 0), "cyber compound captures")
	tech.advance(1.0, econ, 1)
	check(tech.income_of(&"c") == 25 and tech.siphon_of(&"c") == 4, "cyber income and siphon")
	check(econ.credits(1) == 96, "the siphon takes enemy credits")
	check(tech.capture(&"b", 0), "arms bazaar captures")
	check(is_equal_approx(tech.discount(0, "drone"), 0.8) and is_equal_approx(tech.discount(0, "infantry"), 0.8), "bazaar discounts drones and infantry")
	check(tech.discount(0, "armor") == 1.0, "bazaar leaves other tags alone")
	tech.set_import("rotary_slot", true)
	check(tech.import_open("rotary_slot"), "an import slot is a data flag")
	check(tech.capture(&"h", 0), "field clinic captures")
	tech.advance(1.0, econ, 1)
	check(tech.clinic_healed(0) >= 6.0, "field clinic heals")
	check(tech.capture(&"r", 0) and tech.reveals_water(0), "hydro radar reveals water")

func test_sm_abilities() -> void:
	var book: SMAbilities = SMAbilities.new()
	book.add_unit(1, Vector3.ZERO, SMAbilities.TOGGLE, 2.0, 1.0)
	book.add_unit(2, Vector3(1, 0, 0), SMAbilities.TOGGLE, 2.0, 1.0)
	check(book.group_toggle([1, 2]) == 2 and book.toggle_on(1) and book.toggle_on(2), "group toggle flips the group")
	book.add_unit(3, Vector3.ZERO, SMAbilities.SMART, 3.0, 1.0)
	book.add_unit(4, Vector3(6, 0, 0), SMAbilities.SMART, 3.0, 1.0)
	check(book.smart_cast([3, 4], Vector3.ZERO) == 3, "smart-cast picks the closest ready unit")
	check(book.fired_count(4) == 0, "the farther unit holds its fire")
	book.set_ready(3, 5.0)
	check(book.smart_cast([3, 4], Vector3.ZERO) == 4, "an unready closest unit is skipped")
	book.add_unit(5, Vector3.ZERO, SMAbilities.BEAM, 1.0, 1.0)
	book.add_unit(6, Vector3(2, 0, 0), SMAbilities.TOGGLE, 1.0, 1.0)
	check(book.begin_beam(5, 6), "channeled beam starts")
	book.advance(2.0)
	check(book.beam_done(5) == 1 and book.status_of(6) == SMAbilities.ST_FROZEN, "the beam completes and freezes the target")
	book.add_unit(7, Vector3.ZERO, SMAbilities.BEAM, 1.0, 1.0)
	check(book.begin_beam(7, 6), "a second beam starts")
	book.apply_status(7, SMAbilities.ST_FROZEN, 4.0)
	book.advance(2.0)
	check(book.beam_done(7) == 0 and not book.is_channeling(7), "frozen breaks the channel")
	book.apply_status(1, SMAbilities.ST_SHRUNK, 5.0)
	check(is_equal_approx(book.radius_of(1), 0.5), "shrunk halves the radius")
	book.apply_status(2, SMAbilities.ST_BLACK_HOLE, 5.0)
	check(is_equal_approx(book.damage_to(2, 50.0), 10.0) and is_equal_approx(book.hp_of(2), 90.0), "black-hole armor cuts incoming damage")
	book.advance(6.0)
	check(book.status_of(1) == SMAbilities.ST_NONE and is_equal_approx(book.radius_of(1), 1.0), "shrink wears off")

func test_sm_domain() -> void:
	var g: SMDomainGrid = SMDomainGrid.phillips_layout()
	check(g.cols == 56 and g.rows == 34 and g.cols * g.rows > 40 * 24 * 3 / 2, "phillips is about twice the old field")
	check(g.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(8, 4))) == SMDomainGrid.Domain.LAND, "west land")
	check(g.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(30, 12))) == SMDomainGrid.Domain.LAND, "east land")
	check(g.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(20, 12))) == SMDomainGrid.Domain.DEEP, "deep channel")
	check(g.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(16, 5))) == SMDomainGrid.Domain.SHALLOW, "shallow crossing")
	check(g.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(5, 11))) == SMDomainGrid.Domain.CLIFF, "cliff flag")
	check(g.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(19, 10))) == SMDomainGrid.Domain.AIR, "air flag")
	_domain_seen.clear()
	g.domain_changed.connect(_on_test_domain)
	check(g.move_unit(3, g.cell_center(SMDomainGrid.at("phillips", Vector2i(12, 5))), SMDomainGrid.Loco.AMPHIBIOUS), "amphibious steps onto land")
	check(_domain_seen.is_empty(), "the first placement does not signal")
	check(g.move_unit(3, g.cell_center(SMDomainGrid.at("phillips", Vector2i(16, 5))), SMDomainGrid.Loco.AMPHIBIOUS), "amphibious enters shallow water")
	check(_domain_seen.size() == 2 and _domain_seen[0] == SMDomainGrid.Domain.LAND and _domain_seen[1] == SMDomainGrid.Domain.SHALLOW, "domain change at the shoreline")
	check(not g.move_unit(4, g.cell_center(SMDomainGrid.at("phillips", Vector2i(20, 12))), SMDomainGrid.Loco.GROUND), "ground movement stops at deep water")
	check(not g.move_unit(5, g.cell_center(SMDomainGrid.at("phillips", Vector2i(5, 11))), SMDomainGrid.Loco.AMPHIBIOUS), "a cliff blocks movement")
	check(g.move_unit(6, g.cell_center(SMDomainGrid.at("phillips", Vector2i(19, 10))), SMDomainGrid.Loco.AIR), "air enters an air cell")
	check(g.move_unit(7, g.cell_center(SMDomainGrid.at("phillips", Vector2i(20, 12))), SMDomainGrid.Loco.NAVAL), "naval enters deep water")

var _domain_seen: Array[int] = []

func _on_test_domain(_unit_id: int, from_domain: int, to_domain: int) -> void:
	_domain_seen.append(from_domain)
	_domain_seen.append(to_domain)

func test_sm_ew() -> void:
	var fresh: SMEwField = SMEwField.new()
	check(is_equal_approx(fresh.radius, 1000.0) and is_equal_approx(fresh.penalty, 0.4) and is_equal_approx(fresh.accuracy(Vector3(500, 0, 0), SMEwField.GPS), 0.4), "the jammer covers a thousand meters at a sixty percent penalty")
	var ew: SMEwField = SMEwField.new()
	ew.center = Vector3.ZERO
	ew.radius = 10.0
	var inside: Vector3 = Vector3(2, 0, 0)
	var outside: Vector3 = Vector3(30, 0, 0)
	check(is_equal_approx(ew.accuracy(inside, SMEwField.GPS), ew.penalty), "gps guidance is jammed")
	check(is_equal_approx(ew.accuracy(inside, SMEwField.FPV), ew.penalty), "fpv guidance is jammed")
	check(ew.accuracy(inside, SMEwField.FIBER) == 1.0, "fiber-optic ignores the jammer")
	check(ew.accuracy(inside, SMEwField.HOP) == 1.0, "frequency-hop ignores the jammer")
	check(ew.accuracy(inside, SMEwField.GPS, true, false) == 1.0, "an active fiber link is exempt")
	check(ew.accuracy(inside, SMEwField.FPV, false, true) == 1.0, "an active hop link is exempt")
	check(ew.accuracy(outside, SMEwField.GPS) == 1.0, "outside the jammer radius")
	check(ew.accuracy(inside, SMEwField.NONE) == 1.0, "unguided weapons are not jammed")

func test_sm_catalog() -> void:
	for id: String in ["gtfc", "mvd", "nmrf"]:
		var data: Dictionary = SMCatalog.faction(id)
		var units: Array[Dictionary] = SMCatalog.units_of(data)
		var want: int = 19
		if id == "gtfc":
			want = 20
		elif id == "nmrf":
			want = 17
		check(units.size() == want, "%s fields its blueprint roster" % id)
		check(str(data.get("balance", "")) == "pass1", "%s costs record the balance pass" % id)
		for unit: Dictionary in units:
			check(SMCatalog.entry_ok(unit), "%s %s has a weapon and one secondary" % [id, str(unit.get("id", ""))])
	var gtfc: Dictionary = SMCatalog.faction("gtfc")
	var mvd: Dictionary = SMCatalog.faction("mvd")
	var nmrf: Dictionary = SMCatalog.faction("nmrf")
	var gtfc_colors: Dictionary = gtfc["colors"]
	var mvd_colors: Dictionary = mvd["colors"]
	var nmrf_colors: Dictionary = nmrf["colors"]
	check(str(gtfc_colors["primary"]) == "crimson" and str(gtfc_colors["accent"]) == "amber", "gtfc crimson and amber")
	check(str(mvd_colors["primary"]) == "charcoal" and str(mvd_colors["accent"]) == "cyan", "mvd charcoal and cyan")
	check(str(nmrf_colors["primary"]) == "olive" and str(nmrf_colors["accent"]) == "emerald", "nmrf olive and emerald")
	check(SMCatalog.stock_cost(mvd, "siege_works") == 1, "tier-3 gear requires rare-earth stock")
	var market: Dictionary = SMCatalog.faction("black_market")
	var flags: Dictionary = market["import_flags"]
	check(bool(flags.get("rotary_slot", false)) and bool(flags.get("strike_slot", false)) and bool(flags.get("spotter_slot", false)), "black-market imports are flags")
	var market_units: Array[Dictionary] = SMCatalog.units_of(market)
	check(market_units.size() == 5, "black market air is in the catalog")
	var fastest: float = 0.0
	var teak_speed: float = 0.0
	for unit: Dictionary in SMCatalog.units_of(gtfc):
		if str(unit.get("locomotion", "")) != "ground":
			continue
		var pace: float = float(unit.get("speed", 0.0))
		if str(unit.get("id", "")) == "teak_technical":
			teak_speed = pace
		elif pace > fastest:
			fastest = pace
	check(teak_speed > fastest and teak_speed >= 8.0, "the teak technical is the fastest GTFC ground unit")
	var spool: Dictionary = {}
	for unit: Dictionary in SMCatalog.units_of(mvd):
		if str(unit.get("id", "")) == "spool_fpv":
			spool = unit
	var jam: SMEwField = SMEwField.new()
	jam.center = Vector3.ZERO
	jam.radius = 20.0
	check(str(spool.get("guidance", "")) == "fiber" and jam.accuracy(Vector3.ZERO, SMEwField.guidance_of("fiber")) == 1.0, "the spool FPV is fibre guided and ignores a jammer")
	var yard: SMBuildYard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.load_catalog(gtfc)
	yard.finished.append(&"scaffold_yard")
	check(yard.tech_order.size() == 10 and yard.can_build(&"bamboo_hide") and not yard.can_build(&"barracks"), "a bamboo hide builds beside the chain once the yard is up")
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var field: SMPointer = SMPointer.new()
	field.bind(host, null)
	field.faction_id = "gtfc"
	field.use_open(20, 20, 2.0, Vector3(-20.0, 0.0, -20.0))
	var lead: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3.ZERO, &"fpv_kamikaze")
	check(field.units_of(SMPointer.PLAYER).size() == 3, "an FPV order launches a flight of three")
	var tank: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(4.0, 0.0, 0.0), &"amber_tank")
	var tank_hp: float = tank.hp
	field.select_only([lead])
	field.cast_f(tank.global_position)
	check(not lead.is_alive() and tank.hp < tank_hp, "the lead FPV dives into armour")
	field.faction_id = "mvd"
	var hive: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(30.0, 0.0, 0.0), &"swarm_hive")
	var chipped: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(32.0, 0.0, 0.0), &"clearance_trooper")
	hive.set_meta("toggled", true)
	var chip_hp: float = chipped.hp
	field.tick(1.0)
	check(chipped.hp < chip_hp, "a swarm hive chips units inside its cloud")
	var boat: Dictionary = {}
	for unit: Dictionary in SMCatalog.units_of(nmrf):
		if str(unit.get("id", "")) == "longtail_raider":
			boat = unit
	check(str(boat.get("locomotion", "")) == "amphibious" and float(boat.get("speed", 0.0)) >= 8.0, "the longtail raider is a fast boat that can beach")
	host.free()
	for unit: Dictionary in market_units:
		check(SMCatalog.entry_ok(unit), "black market %s has a weapon and one secondary" % str(unit.get("id", "")))
	var banned: PackedStringArray = PackedStringArray(["opium", "heroin", "cocaine", "fentanyl", "yaba", "methamphetamine"])
	var hits: PackedStringArray = PackedStringArray()
	for faction_id: String in ["gtfc", "mvd", "nmrf", "black_market"]:
		var text: String = FileAccess.get_file_as_string("res://data/factions/%s/faction.json" % faction_id).to_lower()
		for word: String in banned:
			if text.contains(word):
				hits.append("%s:%s" % [faction_id, word])
	check(hits.is_empty(), "faction data has no street-drug names %s" % [hits])

func test_sm_camera_rig() -> void:
	var cam: RTSCamera = RTSCamera.new()
	cam.bounds = Rect2(-40, -40, 80, 80)
	cam.edge_pan_px = 16.0
	root.add_child(cam)
	await process_frame
	cam.focus_on(Vector3.ZERO)
	cam.distance = 30.0
	var dir: Vector2 = cam.edge_scroll(Vector2(1, 200), Vector2(400, 400), 0.2)
	check(dir.x < 0.0 and cam.focus.x < 0.0, "edge scroll pans from the left margin")
	cam.focus_on(Vector3.ZERO)
	cam.distance = 40.0
	cam.zoom_toward(3.0, Vector3(10, 0, 0))
	check(cam.distance < 40.0 and cam.focus.x > 0.0, "zoom toward the cursor shifts the focus")
	var yaw: float = cam.yaw_degrees
	cam.orbit(25.0)
	check(absf(cam.yaw_degrees - yaw - 25.0) < 0.01, "orbit yaws around the focus")
	cam.free()

func _probe_gltf() -> String:
	return "{\"asset\":{\"version\":\"2.0\"},\"scene\":0,\"scenes\":[{\"nodes\":[0,1]}],\"nodes\":[{\"name\":\"Hull\",\"mesh\":0},{\"name\":\"Turret\",\"mesh\":0,\"translation\":[0,1,0]}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0},\"indices\":1,\"mode\":4}]}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\",\"max\":[1,0,1],\"min\":[0,0,0]},{\"bufferView\":1,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"}],\"bufferViews\":[{\"buffer\":0,\"byteOffset\":0,\"byteLength\":36,\"target\":34962},{\"buffer\":0,\"byteOffset\":36,\"byteLength\":8,\"target\":34963}],\"buffers\":[{\"byteLength\":44,\"uri\":\"data:application/octet-stream;base64,AAAAAAAAAAAAAAAAAACAPwAAAAAAAAAAAAAAAAAAAAAAAIA/AAABAAIAAAA=\"}]}"

func test_sm_greybox() -> void:
	var scene: Node = (load("res://game/greybox.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	for node_name: String in ["BuildScaffold", "BuildInternal", "BuildMobile", "NodeSlag", "NodeRare", "NodeRuby", "NodeJade", "NodeBullion", "Jammer"]:
		check(scene.get_node_or_null(node_name) is MeshInstance3D, "greybox mesh %s" % node_name)
	var scaffold: MeshInstance3D = scene.get_node("BuildScaffold") as MeshInstance3D
	var internal: MeshInstance3D = scene.get_node("BuildInternal") as MeshInstance3D
	check(scaffold.mesh is CapsuleMesh and internal.mesh is BoxMesh, "scaffold is a capsule and the hub is a box")
	scene.free()
	await process_frame
	var purse: RTSEconomy = RTSEconomy.new()
	purse.set_credits(0, 400)
	var yard: SMBuildYard = SMBuildYard.new()
	yard.economy = purse
	yard.load_catalog(SMCatalog.faction("gtfc"))
	yard.finished.append(&"barracks")
	yard.structure_hp[&"barracks"] = 40.0
	check(yard.begin_repair(&"barracks"), "repair can start on a damaged building")
	yard.tick_repair(1.0)
	check(float(yard.structure_hp[&"barracks"]) > 40.0 and purse.credits(0) < 400, "repair spends credits to restore hit points")
	var refund: int = yard.sell(&"barracks")
	check(refund == 75 and not yard.finished.has(&"barracks"), "selling a building refunds half its cost")
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var body: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(2.0, 1.0, 3.0)
	body.mesh = box
	var old_turret: MeshInstance3D = MeshInstance3D.new()
	old_turret.name = "Turret"
	old_turret.mesh = BoxMesh.new()
	body.add_child(old_turret)
	host.add_child(body)
	var probe: String = "res://game/models/registry_probe.gltf"
	var gltf: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	gltf.store_string(_probe_gltf())
	gltf.close()
	var swapped: bool = ModelBook.apply_unit(body, "registry_probe")
	var fitted: Node3D = body.get_node_or_null("Model") as Node3D
	var turret: Node = body.get_node_or_null("Turret")
	check(swapped and body.mesh == null and fitted != null and turret != null and turret != old_turret and is_equal_approx(fitted.scale.x, 2.0) and is_equal_approx(fitted.scale.y, fitted.scale.x) and is_equal_approx(fitted.scale.z, fitted.scale.x), "a dropped gltf replaces the procedural mesh")
	var plain: MeshInstance3D = MeshInstance3D.new()
	var kept: BoxMesh = BoxMesh.new()
	plain.mesh = kept
	host.add_child(plain)
	check(not ModelBook.apply_unit(plain, "no_such_model_2031") and plain.mesh == kept, "a missing model keeps the procedural mesh")
	var mvd_ink: Color = ModelBook.body_ink(Color.html("#2A2E32"))
	check(mvd_ink.b > mvd_ink.r and mvd_ink.r > 0.35, "mvd charcoal lifts toward a readable blue-grey")
	var market_ink: Color = ModelBook.body_ink(Color.html("#1C1C1C"))
	check(market_ink.r > 0.45 and market_ink.r > market_ink.b + 0.05, "black market black lifts to a warm grey")
	var troop: MeshInstance3D = MeshInstance3D.new()
	var troop_box: BoxMesh = BoxMesh.new()
	troop_box.size = Vector3(1.2, 1.8, 0.8)
	troop.mesh = troop_box
	host.add_child(troop)
	var dressed_troop: bool = ModelBook.apply_unit(troop, "militia", Color.html("#B81E2D"), Color.html("#E0A106"))
	var troop_body: MeshInstance3D = troop.find_child("Body", true, false) as MeshInstance3D
	var body_mat: StandardMaterial3D = null
	var trim_mat: StandardMaterial3D = null
	if troop_body != null and troop_body.mesh != null:
		body_mat = troop_body.get_surface_override_material(0) as StandardMaterial3D
		if troop_body.mesh.get_surface_count() > 1:
			trim_mat = troop_body.get_surface_override_material(1) as StandardMaterial3D
	var shaded: Color = ModelBook.body_shade(Color.html("#B81E2D"))
	var wash: Color = ModelBook.body_wash(Color.html("#B81E2D"))
	var troop_trim: MeshInstance3D = troop.find_child("Trim", true, false) as MeshInstance3D
	if troop_trim != null and troop_trim.mesh != null:
		trim_mat = troop_trim.get_surface_override_material(0) as StandardMaterial3D
	var troop_tex: Texture2D = null if body_mat == null else body_mat.albedo_texture
	check(dressed_troop and body_mat != null and trim_mat != null and troop_tex != null and body_mat.albedo_color.is_equal_approx(wash) and wash.r > shaded.r + 0.2 and trim_mat.albedo_color.is_equal_approx(Color.html("#E0A106")) and troop_body.material_override == null, "a textured militia keeps its body texture and tints only the trim")
	var dog: MeshInstance3D = MeshInstance3D.new()
	var dog_box: BoxMesh = BoxMesh.new()
	dog_box.size = Vector3(1.2, 1.0, 1.6)
	dog.mesh = dog_box
	host.add_child(dog)
	var dressed_dog: bool = ModelBook.apply_unit(dog, "registry_probe", Color.html("#B81E2D"), Color.html("#E0A106"))
	var dog_body: MeshInstance3D = dog.find_child("Hull", true, false) as MeshInstance3D
	var dog_mat: StandardMaterial3D = null
	if dog_body != null and dog_body.mesh != null:
		dog_mat = dog_body.get_surface_override_material(0) as StandardMaterial3D
	check(dressed_dog and dog_mat != null and dog_mat.albedo_color.is_equal_approx(shaded) and not dog_mat.albedo_color.is_equal_approx(wash) and shaded.r < 0.62 and shaded.r > 0.4, "a stand-in keeps the dark faction multiply")
	var hall: MeshInstance3D = MeshInstance3D.new()
	hall.name = "Built_barracks"
	var hall_box: BoxMesh = BoxMesh.new()
	hall_box.size = Vector3(3.8, 1.2, 1.65)
	hall.mesh = hall_box
	host.add_child(hall)
	var dressed_hall: bool = ModelBook.apply_structure(hall, "barracks", Color.html("#B81E2D"), Color.html("#E0A106"))
	var hall_model: Node3D = hall.get_node_or_null("Model") as Node3D
	check(dressed_hall and hall_model != null and is_equal_approx(hall_model.scale.x, hall_model.scale.y) and is_equal_approx(hall_model.scale.y, hall_model.scale.z) and hall_model.scale.x > 0.2, "a building scales evenly and keeps its height")
	var proportion_fault: String = _proportion_fault()
	check(proportion_fault == "", "no unit or building is squashed or stretched")
	var loaded: MeshInstance3D = MeshInstance3D.new()
	loaded.set_meta("model", "Model")
	var loaded_gun: MeshInstance3D = MeshInstance3D.new()
	loaded_gun.name = "Turret"
	loaded_gun.mesh = BoxMesh.new()
	loaded.add_child(loaded_gun)
	host.add_child(loaded)
	var fx_script: GDScript = load("res://game/fx_view.gd") as GDScript
	var ice: Material = fx_script.call("ice_material") as Material
	Forms.paint_status(loaded, ice)
	check(loaded.material_override == null and loaded_gun.material_override == null and loaded_gun.material_overlay == ice, "a frozen loaded model keeps its paint and shows ice")
	Forms.paint_status(loaded, null)
	check(loaded_gun.material_overlay == null, "thawing a loaded model clears the ice")
	var shadowed: MeshInstance3D = Forms.dress_unit("militia", "infantry", "ground", Color.WHITE, Color.html("#B81E2D"), Color.html("#E0A106"))
	host.add_child(shadowed)
	var blob: MeshInstance3D = shadowed.get_node_or_null("ContactShadow") as MeshInstance3D
	var blob_mat: StandardMaterial3D = null if blob == null else blob.material_override as StandardMaterial3D
	check(blob != null and blob_mat != null and blob_mat.albedo_texture != null and (blob.mesh as PlaneMesh).size.x > 0.5, "a loaded unit keeps a blob shadow")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe + ".import"))
	host.free()
	await process_frame

func test_sm_phillips() -> void:
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var side: Node = scene.find_child("Sidebar", true, false)
	var bar: Node = scene.find_child("Protocols", true, false)
	check(side != null, "command sidebar is present")
	check(bar != null, "protocols bar is present")
	check(scene.find_child("GroupBuildings", true, false) != null and scene.find_child("GroupUnits", true, false) != null and scene.find_child("GroupAbility", true, false) != null, "the command column groups buildings, units, and ability")
	check(bool(scene.call("scripted_playthrough")), "phillips playthrough finishes")
	var played: SMMatch = scene.get("sim") as SMMatch
	check(played.finished and played.winner == 0, "the passive opponent is defeated")
	check(played.pipeline_ok and played.claimed, "the base is up and a node is claimed")
	check(played.f_smart == 11 and played.f_toggles == 1, "F fires a smart-cast and a toggle")
	check(played.domain_log.size() >= 2, "an amphibious unit crossed the channel")
	var field: SMPointer = scene.get("field") as SMPointer
	check(field != null and field.count_team(0) >= 3 and field.count_team(1) >= 2, "phillips places friendly and enemy units")
	check(scene.find_child("SelectionBox", true, false) != null, "phillips shows a selection box")
	var terrain_land: MeshInstance3D = scene.get_node_or_null("TerrainLand") as MeshInstance3D
	var terrain_water: MeshInstance3D = scene.get_node_or_null("TerrainWater") as MeshInstance3D
	check(terrain_land != null and terrain_water != null and terrain_water.get_active_material(0) is ShaderMaterial, "phillips meshes the banks and shades the channel")
	var mud_mesh: MeshInstance3D = scene.get_node_or_null("TerrainMud") as MeshInstance3D
	var mud_mat: ShaderMaterial = null if mud_mesh == null else mud_mesh.get_active_material(0) as ShaderMaterial
	var mud_contrast: float = 1.0 if mud_mat == null else float(mud_mat.get_shader_parameter("contrast"))
	check(mud_mat != null and mud_contrast < 0.55 and mud_contrast > 0.2, "mud contrast is pulled toward a flat brown")
	var ground_arrays: Array = []
	if terrain_land != null and terrain_land.mesh != null:
		ground_arrays = terrain_land.mesh.surface_get_arrays(0)
	var ground_uv: PackedVector2Array = ground_arrays[Mesh.ARRAY_TEX_UV] if ground_arrays.size() > Mesh.ARRAY_TEX_UV else PackedVector2Array()
	var ground_xyz: PackedVector3Array = ground_arrays[Mesh.ARRAY_VERTEX] if not ground_arrays.is_empty() else PackedVector3Array()
	var uv_span: float = 0.0
	var uv_i: int = 1
	while uv_i < ground_xyz.size() and uv_i < 24 and uv_i < ground_uv.size():
		var dx: float = absf(ground_xyz[uv_i].x - ground_xyz[0].x)
		if dx > 0.2:
			uv_span = absf(ground_uv[uv_i].x - ground_uv[0].x) / dx
			break
		uv_i += 1
	check(uv_span > 0.2 and uv_span < 0.35, "a ground tile covers about four metres")
	var land_mat: ShaderMaterial = terrain_land.get_active_material(0) as ShaderMaterial
	check(land_mat != null and float(land_mat.get_shader_parameter("use_tex")) > 0.5, "the ground uses a painted terrain texture")
	var help_button: Button = scene.find_child("HelpButton", true, false) as Button
	var howto_title: Label = scene.find_child("HowToTitle", true, false) as Label
	var power_label: Label = scene.find_child("HudPower", true, false) as Label
	var help_font: Font = null if help_button == null else help_button.get_theme_font("font")
	var title_face: Font = null if howto_title == null else howto_title.get_theme_font("font")
	var power_font: Font = null if power_label == null else power_label.get_theme_font("font")
	check(help_font != null and str(help_font.resource_path).contains("OperationNapalm") and power_font != null and str(power_font.resource_path).contains("OperationNapalm"), "hud body text uses Operation Napalm")
	check(title_face != null and str(title_face.resource_path).contains("Warheed"), "hud headers use Warheed")
	var jungle: MultiMeshInstance3D = scene.get_node_or_null("JungleTrees") as MultiMeshInstance3D
	check(jungle != null and jungle.multimesh != null and jungle.multimesh.instance_count > 8, "phillips plants a stand of jungle trees")
	var palms: MultiMeshInstance3D = scene.get_node_or_null("Palms") as MultiMeshInstance3D
	check(palms != null and palms.multimesh != null and palms.multimesh.instance_count > 0, "phillips lines the banks with palms")
	var slag_node: MeshInstance3D = scene.get_node_or_null("Node_slag_west") as MeshInstance3D
	var cyber_node: MeshInstance3D = scene.get_node_or_null("Tech_cyber") as MeshInstance3D
	check(slag_node != null and str(slag_node.get_meta("form", "")) == "slag" and cyber_node != null and str(cyber_node.get_meta("form", "")) == "cyber", "slag nodes and cyber cafes have their own shapes")
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0] and field.selection.count() == 1, "left click selects one friendly unit")
	var step: Vector3 = friends[0].global_position + Vector3(0, 0, 8)
	var moved: StringName = field.command_at(step, _proj(step), Callable(self, "_proj"))
	check(moved == &"move" and friends[0].is_moving(), "right click on ground moves the selection")
	var foes: Array[RTSUnit] = field.units_of(1)
	var attacked: StringName = field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj"))
	check(attacked == &"attack" and friends[0].attack_target == foes[0], "right click on an enemy attacks")
	var a: Vector2 = _proj(friends[0].global_position)
	var b: Vector2 = _proj(friends[1].global_position)
	var boxed: int = field.select_drag(Rect2(a, b - a).abs().grow(4.0), Callable(self, "_proj"))
	check(boxed >= 2, "a drag box selects several friendlies")
	check(_gtfc_names(field), "phillips labels the six GTFC placeholders")
	check(field.name_of(foes[0]) == "Enemy", "phillips labels the enemy")
	scene.free()
	await process_frame

func test_sm_bots() -> void:
	var played: SMMatch = SMMatch.new()
	for personality: StringName in SMBot.personalities():
		var bot: SMBot = SMBot.new(personality)
		var result: Dictionary = played.run_bot(bot)
		check(int(result["refineries"]) == int(result["refinery_target"]), "%s opens with two refineries" % str(personality))
		check(bool(result["water"]) and bool(result["gem"]), "%s expands to water and a gem node" % str(personality))
		check(bool(result["captured"]), "%s captures a tech building" % str(personality))
		check(bool(result["fired"]), "%s fires an ability" % str(personality))
		check(bool(result["protocols"]) and bool(result["audio_combat"]) and bool(result["silent"]), "%s protocols and silent stems" % str(personality))
	var isk: Dictionary = played.run_bot(SMBot.new(&"iskandar"))
	check(bool(isk["naval"]) and str(isk["faction"]) == "nmrf", "iskandar takes the naval lane")
	var tran: Dictionary = played.run_bot(SMBot.new(&"tran"))
	check(bool(tran["frozen"]) and bool(tran["flew"]) and str(tran["faction"]) == "gtfc", "tran uses cryo and air")
	var bo: Dictionary = played.run_bot(SMBot.new(&"bo_mya"))
	check(str(bo["faction"]) == "mvd" and bool(bo["fired"]), "bo mya fields drones")
	var burma_ok: bool = _duel(&"bo_mya", "burma_road", &"iskandar", false, 90.0)
	check(burma_ok, "bo mya wins on the burma road (%s)" % duel_note)
	var sop_ok: bool = _duel(&"bo_mya", "sop_ruak", &"tran", true)
	check(sop_ok, "bo mya wins across the sop ruak water (%s)" % duel_note)
	var phillips_ok: bool = _duel(&"iskandar", "phillips", &"bo_mya", true)
	check(phillips_ok, "iskandar wins on phillips channel (%s)" % duel_note)
	var atoll_ok: bool = _duel(&"iskandar", "ten_degree_atolls", &"tran", true)
	check(atoll_ok, "iskandar wins on the atolls (%s)" % duel_note)
	var mekong_ok: bool = _duel(&"tran", "mekong_delta", &"bo_mya", true, 75.0)
	check(mekong_ok, "tran wins over the mekong canals (%s)" % duel_note)
	var chiang_ok: bool = _duel(&"tran", "chiang_rai", &"iskandar", true, 90.0)
	check(chiang_ok, "tran wins over the chiang rai river (%s)" % duel_note)

func test_sm_mission() -> void:
	var scene: Node = (load("res://game/mission_kokang.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(str(scene.get("briefing_text")).contains("Kokang"), "the raid opens on a text briefing")
	check(bool(scene.call("scripted_playthrough")), "the raid is finishable")
	var raid: SMMission = scene.get("mission") as SMMission
	check(raid.won and raid.ruby_paid >= 30 and raid.goods.stock_of(0) >= 1, "night-shift ruby income and rare-earth stock")
	check(raid.yard.finished.has(&"scaffold_yard"), "the scaffold yard finishes")
	var field: SMPointer = scene.get("field") as SMPointer
	check(field != null and field.count_team(0) >= 2 and field.count_team(1) >= 1, "the raid places a squad and an enemy")
	check(scene.find_child("SelectionBox", true, false) != null, "the raid shows a selection box")
	var foe: RTSUnit = field.units_of(1)[0]
	var before: float = foe.hp
	var struck: int = int(scene.call("fire_secondary"))
	check(struck > 0 and foe.hp < before, "F strikes an enemy on the raid")
	check(_hud_text(scene, "HudFaction") == "GTFC" and _hud_text(scene, "HudCredits") == "Credits 50000" and _hud_text(scene, "HudPower") == "⚡ 0/0" and _hud_text(scene, "HudMap") == SMCampaign.title_of("kokang") and _hud_text(scene, "HudSelection") == "Nothing selected", "the raid shows faction, credits, power, and the mission name")
	var raid_map: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	if raid_map != null:
		raid_map.sample()
	var raid_cam: RTSCamera = scene.get_node("Camera") as RTSCamera
	check(scene.find_child("CompanyList", true, false) == null and raid_map != null and raid_map.saw_land and not raid_map.saw_water and raid_map.player_dots == field.count_team(0) and raid_map.enemy_dots == field.count_team(1) and raid_map.covers_focus() and raid_cam != null, "the raid minimap shows land, your units, enemies, and the camera")
	check(_click_east(scene), "clicking the raid minimap moves the camera")
	var raid_build: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	var raid_train: Button = scene.find_child("Train_militia", true, false) as Button
	var raid_ability: Button = scene.find_child("AbilityButton", true, false) as Button
	check(raid_build != null and raid_train != null and raid_ability != null and raid_ability.text == "Ability (F)" and scene.find_child("GroupBuildings", true, false) != null and scene.find_child("GroupUnits", true, false) != null and scene.find_child("GroupAbility", true, false) != null, "the raid command column builds, trains, and uses F")
	check(_gtfc_names(field), "the raid labels the six GTFC placeholders")
	check(field.name_of(foe) == "Enemy", "the raid labels the enemy")
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(boot.find_child("GreyboxButton", true, false) != null, "boot offers the greybox")
	check(boot.find_child("CardPhillips", true, false) != null, "boot offers Phillips Channel")
	var raid_button: Button = boot.find_child("Mission_kokang", true, false) as Button
	check(raid_button != null and raid_button.text == "Kokang and Mogok night raid", "boot offers the night raid")
	boot.free()
	scene.free()
	await process_frame

func test_sm_sop_ruak() -> void:
	var grid: SMDomainGrid = SMDomainGrid.sop_ruak_layout()
	var land: int = SMDomainGrid.Domain.LAND
	var deep: int = SMDomainGrid.Domain.DEEP
	check(grid.cols == 50 and grid.rows == 50, "sop ruak grew on every side")
	check(grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(8, 24))) == land and grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(28, 24))) == land and grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(18, 6))) == land, "sop ruak has three land sectors")
	check(grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(17, 28))) == deep and grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(8, 8))) == deep and grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(27, 8))) == deep, "a Y of deep water splits the shores")
	check(grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(17, 24))) == land and grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(10, 10))) == land and grid.domain_at_cell(SMDomainGrid.at("sop_ruak", Vector2i(24, 10))) == land, "a ford crosses each arm of the river")
	var scene: Node = (load("res://game/sop_ruak.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.get_node_or_null("WestSector") is MeshInstance3D and scene.get_node_or_null("EastSector") is MeshInstance3D and scene.get_node_or_null("NorthSector") is MeshInstance3D and scene.get_node_or_null("RiverStem") is MeshInstance3D, "sop ruak shows three shores and the river")
	var field: SMPointer = scene.get("field") as SMPointer
	var east_path: PackedVector3Array = field.nav.find_path(grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(8, 24))), grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(28, 24))))
	var north_path: PackedVector3Array = field.nav.find_path(grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(8, 24))), grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(18, 6))))
	check(east_path.size() > 0 and north_path.size() > 0, "fords link the west shore to the east and the north")
	check(_gtfc_names(field), "sop ruak labels the six GTFC placeholders")
	check(field.name_of(field.units_of(1)[0]) == "Enemy", "sop ruak labels the enemy")
	check(scene.find_child("SelectionBox", true, false) != null, "sop ruak shows a selection box")
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0] and field.selection.count() == 1, "left click selects one friendly unit")
	var north: Vector3 = grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(18, 6)))
	var moved: StringName = field.command_at(north, _proj(north), Callable(self, "_proj"))
	check(moved == &"move" and friends[0].is_moving(), "right click on ground moves the selection")
	var foes: Array[RTSUnit] = field.units_of(1)
	var attacked: StringName = field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj"))
	check(attacked == &"attack" and friends[0].attack_target == foes[0], "right click on an enemy attacks")
	check(bool(scene.call("fire_ability")), "F fires the sop ruak ability")
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(_card_line(boot, "CardSopRuak", "Sop Ruak", "River"), "boot names the river skirmish")
	boot.free()
	scene.free()
	await process_frame

func test_sm_maps() -> void:
	var land: int = SMDomainGrid.Domain.LAND
	var deep: int = SMDomainGrid.Domain.DEEP
	var cliff: int = SMDomainGrid.Domain.CLIFF
	var shallow: int = SMDomainGrid.Domain.SHALLOW
	var burma: SMDomainGrid = SMDomainGrid.burma_road_layout()
	var burma_plan: SMMapPlan = SMMapPlan.of("burma_road")
	check(burma.cols == 64 and burma.rows == 48, "burma road grew")
	check(burma.domain_at_cell(Vector2i(0, 0)) == cliff and burma.domain_at_cell(Vector2i(30, 14)) == cliff and burma.domain_at_cell(Vector2i(33, 33)) == cliff, "burma highlands and the massif are cliffs")
	check(burma.domain_at_cell(Vector2i(26, 19)) == land and burma.domain_at_cell(burma_plan.start(0)) == land and burma.domain_at_cell(burma_plan.start(1)) == land, "the burma pass is land between the plateaus")
	var atolls: SMDomainGrid = SMDomainGrid.ten_degree_atolls_layout()
	var atoll_plan: SMMapPlan = SMMapPlan.of("ten_degree_atolls")
	check(atolls.domain_at_cell(Vector2i(0, 0)) == deep and atolls.domain_at_cell(Vector2i(21, 42)) == deep, "the atolls sit in deep water")
	check(atolls.domain_at_cell(atoll_plan.start(0)) == land and atolls.domain_at_cell(atoll_plan.start(1)) == land and atolls.domain_at_cell(Vector2i(10, 11)) == land and atolls.domain_at_cell(Vector2i(30, 24)) == land, "home islands, islets and the reef are land")
	check(atolls.domain_at_cell(Vector2i(21, 27)) == shallow and atolls.domain_at_cell(Vector2i(28, 11)) == shallow and atolls.domain_at_cell(Vector2i(10, 20)) == shallow, "shoals link the atolls")
	var mekong: SMDomainGrid = SMDomainGrid.mekong_delta_layout()
	var mekong_plan: SMMapPlan = SMMapPlan.of("mekong_delta")
	check(mekong.cols == 64 and mekong.rows == 48, "the mekong grew")
	check(mekong.domain_at_cell(Vector2i(18, 4)) == deep and mekong.domain_at_cell(Vector2i(45, 30)) == deep, "mekong canals are deep water")
	check(mekong.domain_at_cell(Vector2i(18, 23)) == land and mekong.domain_at_cell(Vector2i(45, 24)) == land and mekong.domain_at_cell(mekong_plan.start(0)) == land, "bridges and paddies stay land")
	var chiang: SMDomainGrid = SMDomainGrid.chiang_rai_layout()
	check(chiang.cols == 80 and chiang.rows == 56 and chiang.cols > burma.cols and chiang.rows > mekong.rows, "chiang rai is the larger map")
	var chiang_plan: SMMapPlan = SMMapPlan.of("chiang_rai")
	check(chiang.domain_at_cell(Vector2i(39, 2)) == deep and chiang.domain_at_cell(Vector2i(15, 35)) == cliff, "chiang rai has a river and plateau walls")
	check(chiang.domain_at_cell(Vector2i(39, 11)) == land and chiang.domain_at_cell(Vector2i(39, 27)) == land and chiang.domain_at_cell(Vector2i(39, 43)) == land and chiang.domain_at_cell(chiang_plan.start(0)) == land and chiang.domain_at_cell(chiang_plan.start(2)) == land, "fords and both camps on chiang rai are land")
	await _play_map("res://game/burma_road.tscn", "HighlandWest", "Road", burma_plan.start(0), burma_plan.start(1), burma_plan.spawn_cells(0, 9)[8])
	await _play_map("res://game/ten_degree_atolls.tscn", "WestIsle", "Sea", atoll_plan.start(0), atoll_plan.start(1), atoll_plan.spawn_cells(0, 9)[8])
	await _play_map("res://game/mekong_delta.tscn", "CanalWest", "BridgeWest", mekong_plan.start(0), mekong_plan.start(1), mekong_plan.spawn_cells(0, 9)[8])
	await _play_map("res://game/chiang_rai.tscn", "SiegeRiver", "WallWest", chiang_plan.start(0), chiang_plan.start(2), chiang_plan.spawn_cells(0, 9)[8])
	var show: Node = (load("res://game/showcase.tscn") as PackedScene).instantiate()
	root.add_child(show)
	await process_frame
	var show_grid: SMDomainGrid = show.get("grid") as SMDomainGrid
	var show_field: SMPointer = show.get("field") as SMPointer
	var mark: Node3D = show.get_node_or_null("Landmark_lm_shwedagon") as Node3D
	check(mark != null and show_grid.holding(Vector2i(10, 8)) and show_field.nav_ground.is_blocked(Vector2i(10, 8)) and not show_field.nav_air.is_blocked(Vector2i(10, 8)), "the showcase landmark blocks the ground and lets aircraft pass")
	var teak: MultiMeshInstance3D = show.get_node_or_null("JungleTrees") as MultiMeshInstance3D
	check(teak != null and teak.multimesh != null and teak.multimesh.mesh != null and teak.multimesh.instance_count > 4, "the showcase plants jungle models")
	show.free()
	await process_frame
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(_card_line(boot, "CardBurma", "Burma Road", "Land"), "boot names Burma Road")
	check(_card_line(boot, "CardAtolls", "Ten Degree Atolls", "Water"), "boot names Ten Degree Atolls")
	check(_card_line(boot, "CardMekong", "Mekong Delta", "River"), "boot names the Mekong Delta")
	check(_card_line(boot, "CardChiang", "Siege of Chiang Rai", "River"), "boot names the Siege of Chiang Rai")
	boot.free()
	await process_frame

func test_sm_factions() -> void:
	var nmrf: Node = (load("res://game/nmrf_yard.tscn") as PackedScene).instantiate()
	root.add_child(nmrf)
	await process_frame
	check(nmrf.get_node_or_null("OliveGround") is MeshInstance3D and nmrf.get_node_or_null("PackerCore") is MeshInstance3D, "nmrf shows the mobile core")
	var nfield: SMPointer = nmrf.get("field") as SMPointer
	check(_has_names(nfield, PackedStringArray(["Patani Corsair Guard", "Malacca Pocket-Sub", "Krakatoa Dreadnought", "Phillips Wave-Cannon", "Garuda Mecha-Overlord", "Johor Loiter-Swarm"])), "nmrf labels its six units")
	check(nfield.name_of(nfield.units_of(1)[0]) == "Enemy", "nmrf labels the enemy")
	check(_orders(nmrf, nfield), "nmrf select, move, attack, and F")
	var nyard: SMBuildYard = nmrf.get("yard") as SMBuildYard
	check(nyard.style == SMBuildYard.Style.MOBILE, "nmrf uses the mobile packer")
	check(bool(nmrf.call("move_packer")), "the packer sails")
	check(nyard.grid.unit_domain(nyard.packer_id) == SMDomainGrid.Domain.SHALLOW, "the packer enters shallow water")
	check(bool(nmrf.call("unpack_core")) and nyard.factory_level(&"gun_wharf") == 1, "the wharf unpacks")
	check(bool(nmrf.call("upgrade_wharf")) and nyard.factory_level(&"gun_wharf") == 2, "the wharf upgrades")
	var nfriends: Array[RTSUnit] = nfield.units_of(0)
	check(_albedo(nfriends[0]) == Color.html("#5A6824") and _albedo(nfriends[1]) == Color.html("#1F9E66"), "nmrf is olive and emerald")
	nmrf.free()
	var mvd: Node = (load("res://game/mvd_yard.tscn") as PackedScene).instantiate()
	root.add_child(mvd)
	await process_frame
	check(mvd.get_node_or_null("CharcoalPad") is MeshInstance3D and mvd.get_node_or_null("HubShell") is MeshInstance3D, "mvd shows the internal pad")
	var mfield: SMPointer = mvd.get("field") as SMPointer
	check(_has_names(mfield, PackedStringArray(["Vanguard Shock-Trooper", "Agent-Zero Cryo-Copter", "Delta Amphibious IFV", "Saigon Prism-Lock Tank", "Colonel Nguyen Phantom", "Athena Orbital Designator"])), "mvd labels its six units")
	check(mfield.name_of(mfield.units_of(1)[0]) == "Enemy", "mvd labels the enemy")
	check(_orders(mvd, mfield), "mvd select, move, attack, and F")
	var myard: SMBuildYard = mvd.get("yard") as SMBuildYard
	check(myard.style == SMBuildYard.Style.INTERNAL, "mvd uses the internal queue")
	var before_radius: float = myard.radius
	check(not myard.queue_internal(&"drone_bay"), "tier 2 waits on clearance")
	check(is_equal_approx(before_radius, 25.0) and bool(mvd.call("buy_clearance")) and myard.clearance == 2 and myard.radius == 45.0, "clearance 2 widens the pad")
	check(bool(mvd.call("queue_hub")), "the hub finishes inside the queue")
	check(bool(mvd.call("place_hub")) and myard.finished.has(&"command_hub"), "the hub places inside the radius")
	check(bool(mvd.call("buy_clearance")) and myard.clearance == 3, "clearance 3 follows clearance 2")
	var mfriends: Array[RTSUnit] = mfield.units_of(0)
	check(_albedo(mfriends[0]) == Color.html("#2A2E32") and _albedo(mfriends[1]) == Color.html("#26BFD1"), "mvd is charcoal and cyan")
	check(mfield.teams.color_of(1) != Color.html("#26BFD1"), "the mvd enemy is not painted cyan")
	mvd.free()
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(_faction_line(boot, "FactionNmrf", "NMRF", "Mobile core", "#5A6824") and boot.find_child("NmrfYardButton", true, false) != null, "boot offers NMRF")
	check(_faction_line(boot, "FactionMvd", "MVD", "Internal queue", "#2A2E32") and boot.find_child("MvdYardButton", true, false) != null, "boot offers MVD")
	boot.free()
	await process_frame

func test_sm_raider() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://game/phillips_channel.tscn",
		"res://game/sop_ruak.tscn",
		"res://game/burma_road.tscn",
		"res://game/ten_degree_atolls.tscn",
		"res://game/mekong_delta.tscn",
		"res://game/chiang_rai.tscn",
		"res://game/nmrf_yard.tscn",
		"res://game/mvd_yard.tscn",
	])
	for path: String in paths:
		await _enemy_fights(path)
	await _passive_macro()

func test_sm_roster() -> void:
	var failed: PackedStringArray = PackedStringArray()
	var total: int = 0
	for faction_id: String in ["gtfc", "mvd", "nmrf", "black_market"]:
		var roster: SMRoster = SMRoster.new()
		roster.setup(faction_id)
		for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction_id)):
			total += 1
			var id: StringName = StringName(str(unit.get("id", "")))
			if roster.train_and_finish(id) != id:
				failed.append("%s:%s" % [faction_id, str(id)])
	check(total == 61 and failed.is_empty(), "all 61 catalog units train through production %s" % [failed])
	check(_spawned("gtfc", &"crimson_sapper", "Highland Saboteur", "rifle", "smart_cast", 9.0), "gtfc sapper spawns with a weapon and a secondary")
	check(_spawned("mvd", &"cyan_sentry", "Cu Chi Tunnel Hound", "carbine", "group_toggle", 9.0), "mvd sentry spawns with a weapon and a secondary")
	check(_spawned("nmrf", &"olive_ranger", "Sulu Tank-Buster", "rifle", "group_toggle", 8.0), "nmrf ranger spawns with a weapon and a secondary")
	check(_spawned("black_market", &"ch4", "CH-4", "autocannon", "smart_cast", 14.0), "CH-4 spawns from production")
	check(_spawned("black_market", &"su30", "Su-30", "cannon", "group_toggle", 26.0), "Su-30 spawns from production")
	check(_spawned("black_market", &"orlan10", "Orlan-10", "camera", "channeled_beam", 4.0), "Orlan-10 spawns from production")
	var phillips_name: String = await _trained("res://game/phillips_channel.tscn")
	check(phillips_name == "Highland Saboteur", "phillips trains a catalog unit onto the field")
	var burma_name: String = await _trained("res://game/burma_road.tscn")
	check(burma_name == "Highland Saboteur", "burma road trains a catalog unit onto the field")
	var nmrf_name: String = await _trained("res://game/nmrf_yard.tscn")
	check(nmrf_name == "Sulu Tank-Buster", "nmrf trains a catalog unit onto the field")
	var mvd_name: String = await _trained("res://game/mvd_yard.tscn")
	check(mvd_name == "Cu Chi Tunnel Hound", "mvd trains a catalog unit onto the field")
	await _special_roster()

func _special_roster() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var hero: RTSUnit = _unit_kind(field, 0, "ruby_mortar")
	var side: SMSide = scene.get("side") as SMSide
	var before: int = field.count_team(0)
	var train_hero: Button = scene.find_child("Train_ruby_mortar", true, false) as Button
	train_hero.pressed.emit()
	check(hero != null and field.name_of(hero) == "General Bo Mya" and _mesh_kind(hero) == "hero", "a match fields General Bo Mya with a hero mesh")
	check(field.count_team(0) == before and _hud_text(scene, "HudBuild") == "need a tech center", "a hero waits on the tech center")
	side.yard.finished.append(&"tech_center")
	train_hero.pressed.emit()
	check(field.count_team(0) == before and _hud_text(scene, "HudBuild") == "one hero", "a second hero is refused")
	var train_jet: Button = scene.find_child("Train_amber_welder", true, false) as Button
	train_jet.pressed.emit()
	check(field.count_team(0) == before and _hud_text(scene, "HudBuild") == "need an airfield", "a jet waits on the airfield")
	side.yard.finished.append(&"airfield")
	train_jet.pressed.emit()
	var bomber: RTSUnit = _unit_kind(field, 0, "amber_welder")
	check(field.count_team(0) == before + 1 and bomber != null and _mesh_kind(bomber) == "jet", "the airfield trains the ag-bomber as a jet")
	scene.free()
	await process_frame
	SMFront.faction_id = "nmrf"
	var nmrf: Node = (load("res://game/burma_road.tscn") as PackedScene).instantiate()
	root.add_child(nmrf)
	await process_frame
	var nfield: SMPointer = nmrf.get("field") as SMPointer
	var nside: SMSide = nmrf.get("side") as SMSide
	var nbefore: int = nfield.count_team(0)
	var train_sub: Button = nmrf.find_child("Train_sampan", true, false) as Button
	train_sub.pressed.emit()
	check(nfield.count_team(0) == nbefore and _hud_text(nmrf, "HudBuild") == "need a naval yard", "a sub waits on the naval yard")
	nside.yard.finished.append(&"tidal_turbine")
	nside.yard.finished.append(&"naval_yard")
	train_sub.pressed.emit()
	var sub: RTSUnit = _unit_kind(nfield, 0, "sampan")
	check(nfield.count_team(0) == nbefore + 1 and sub != null and _mesh_kind(sub) == "sub", "the naval yard trains the pocket sub")
	nmrf.free()
	await process_frame
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var bot_field: SMPointer = SMPointer.new()
	bot_field.bind_faction(host, cam, "nmrf")
	bot_field.domain = SMDomainGrid.phillips_layout()
	var raider: SMRaider = SMRaider.new()
	raider.attach(bot_field, Vector3.ZERO)
	raider.brain = SMBot.new(&"iskandar")
	raider._arm_macro()
	raider.yard.finished.append(raider.barracks_id)
	raider.yard.finished.append(raider.factory_id)
	raider.yard.finished.append(raider.naval_id)
	raider.yard.finished.append(raider.air_id)
	raider.yard.finished.append(raider.tech_id)
	var seen_hero: bool = false
	var seen_jet: bool = false
	var seen_sub: bool = false
	for _step: int in 48:
		var pick: String = str(raider._pick_train())
		if pick == str(raider.hero_id) and pick != "":
			seen_hero = true
		if pick == str(raider.jet_id) and pick != "":
			seen_jet = true
		if pick == str(raider.sub_id) and pick != "":
			seen_sub = true
	check(seen_hero and seen_jet and seen_sub, "the bot trains a hero, a jet, and a sub from the right buildings")
	var market: SMRaider = SMRaider.new()
	market.attach(bot_field, Vector3(8.0, 0.0, 0.0), SMPointer.ENEMY)
	market.bind_faction("black_market")
	market._arm_macro()
	check(str(market.infantry_id) == "flh7" and str(market.barracks_id) == "enemy_yard" and str(market.air_id) == "enemy_yard", "the black market trains its lightest aircraft from the yard")
	host.free()
	await process_frame
	SMFront.faction_id = "gtfc"

func test_sm_campaign() -> void:
	var ids: PackedStringArray = SMCampaign.ids()
	check(ids.size() == 15, "fifteen story missions are on the campaign")
	var camp: SMCampaign = SMCampaign.new()
	for id: String in ids:
		var brief: String = SMCampaign.briefing_of(id)
		var lower: String = brief.to_lower()
		check(brief != "" and not lower.contains("fmv") and not lower.contains("video"), "%s is a text briefing" % id)
		check(camp.play(id), "%s can be finished" % id)
	SMCampaign.selected = "mae_sai"
	var scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(str(scene.get("briefing_text")).contains("Mae Sai"), "the mission scene shows the Mae Sai briefing")
	check(bool(scene.call("scripted_playthrough")), "the mission scene can be finished")
	check(scene.find_child("SelectionBox", true, false) != null, "the mission scene has select controls")
	var friends: Array[RTSUnit] = (scene.get("field") as SMPointer).units_of(0)
	var picked: RTSUnit = (scene.get("field") as SMPointer).select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0], "left click selects on a campaign mission")
	(scene.get("hud") as SMHud).refresh()
	check(_hud_text(scene, "HudSelection") == "Shan Insurgent Militia    HP 80/80    F Slag Molotov", "the mission selection shows name, health, and its F ability")
	check(_click_east(scene), "clicking the mission minimap moves the camera")
	var mission_build: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	mission_build.pressed.emit()
	var mission_yard: SMBuildYard = (scene.get("side") as SMSide).yard
	var mission_purse: SMRoster = scene.get("roster") as SMRoster
	check(mission_yard.finished.has(&"scaffold_yard") and mission_yard.style == SMBuildYard.Style.SCAFFOLD and mission_purse.economy.credits(0) == 49980, "a mission building click raises a scaffold yard")
	scene.free()
	for id: String in ids:
		SMCampaign.selected = id
		var mission_scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
		root.add_child(mission_scene)
		await process_frame
		check(_campaign_hud(mission_scene, id), "%s shows the in-match hud" % id)
		mission_scene.free()
		await process_frame
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	for id: String in ids:
		var button: Button = boot.find_child("Mission_%s" % id, true, false) as Button
		check(button != null and button.text == SMCampaign.title_of(id), "boot lists %s" % id)
	check(SMCampaign.debug_ids().size() == 14 and boot.find_child("Mission_mae_sai", true, false) == null and boot.find_child("Mission_channel_crossing", true, false) == null, "the old drills stay off the campaign tab")
	boot.call("_show_tab", "campaign")
	var detail_card: Control = boot.find_child("MenuDetail", true, false) as Control
	check(detail_card != null and detail_card.mouse_filter == Control.MOUSE_FILTER_STOP and detail_card.gui_input.is_connected(Callable(boot, "_on_detail_gui")), "the campaign briefing card accepts a click")
	var enter: InputEventKey = InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	enter.echo = false
	boot.call("_unhandled_input", enter)
	var loading_plate: Control = boot.find_child("LoadingPlate", true, false) as Control
	check(loading_plate != null and loading_plate.visible and str(boot.get("_detail_mission")) == "kokang", "enter on the campaign card starts the selected mission")
	check(camp.play("mae_sai"), "a debug drill can still be finished")
	boot.free()
	await process_frame

func test_sm_hud() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(_hud_text(scene, "HudFaction") == "GTFC", "phillips names the faction")
	check(_hud_text(scene, "HudCredits") == "Credits 50000", "phillips shows credits")
	check(_hud_text(scene, "HudPower") == "⚡ 0/0", "phillips shows army power")
	check(_hud_text(scene, "HudMap") == "Phillips Channel", "phillips names the map")
	check(_hud_text(scene, "HudSelection") == "Nothing selected", "phillips says when nothing is selected")
	var built: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
	var trained: Button = scene.find_child("Train_militia", true, false) as Button
	var ability: Button = scene.find_child("AbilityButton", true, false) as Button
	var boot_back: Button = scene.find_child("MissionBoot", true, false) as Button
	check(built != null and trained != null and ability != null and ability.text == "Ability (F)" and boot_back != null and boot_back.text == "Boot menu" and boot_back.visible, "phillips can build, train, use F, and return to the menu")
	var deck: SMHud = scene.get("hud") as SMHud
	check(scene.find_child("PowerFill", true, false) != null and scene.find_child("RepairButton", true, false) != null and scene.find_child("SellButton", true, false) != null and scene.find_child("TabInfantry", true, false) != null, "the sidebar shows power, repair, sell, and build tabs")
	if deck != null:
		deck.show_build_tab("infantry")
	check(trained != null and trained.visible and built != null and not built.visible, "a build tab shows one category")
	if deck != null:
		deck.show_build_tab("buildings")
	var field: SMPointer = scene.get("field") as SMPointer
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	check(scene.find_child("CompanyList", true, false) == null and mm != null, "phillips uses a minimap instead of a name list")
	mm.sample()
	check(mm.terrain_kind(SMDomainGrid.at("phillips", Vector2i(2, 8))) == "land" and mm.terrain_kind(SMDomainGrid.at("phillips", Vector2i(18, 12))) == "water" and mm.saw_land and mm.saw_water, "the minimap draws land and water")
	check(mm.player_dots == field.count_team(0) and mm.player_dots >= 6 and mm.enemy_dots == 0 and field.count_team(1) >= 1, "the minimap shows your units and hides enemies outside sight")
	check(mm.camera_rect.size.x > 1.0 and mm.covers_focus(), "the minimap draws the camera rectangle")
	var hint_line: Control = scene.find_child("Status", true, false) as Control
	var slot_row: Control = scene.find_child("SelectionSlots", true, false) as Control
	check(hint_line != null and hint_line.offset_top >= 28.0 and hint_line.offset_top <= 48.0 and hint_line.offset_left >= 70.0 and slot_row != null and slot_row.offset_left >= 360.0, "the objective sits under the top bar and the selection strip stays centred")
	check(_click_east(scene), "clicking the minimap moves the camera")
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	(scene.get("hud") as SMHud).refresh()
	check(picked == friends[0] and _hud_text(scene, "HudSelection") == "Shan Insurgent Militia    HP 80/80    F Slag Molotov", "the selection shows name, health, and its F ability")
	var foe: RTSUnit = field.units_of(1)[0]
	var foe_at: Vector3 = foe.global_position
	foe.global_position = friends[0].global_position + Vector3(1.0, 0.0, 0.0)
	friends[0].attack_target = null
	field.set_stance("hold")
	field._return_fire(friends[0])
	check(friends[0].attack_target == null, "hold stance does not acquire a target")
	field.set_stance("aggressive")
	foe.global_position = foe_at
	var purse: SMRoster = scene.get("roster") as SMRoster
	built.pressed.emit()
	check(_hud_text(scene, "HudBuild") == "Construction Yard built", "a finished yard says its name")
	var yard: SMBuildYard = (scene.get("side") as SMSide).yard
	check(yard.finished.has(&"scaffold_yard") and yard.style == SMBuildYard.Style.SCAFFOLD and purse.economy.credits(0) == 49980 and scene.get_node_or_null("Built_scaffold_yard") is MeshInstance3D, "a building click raises a scaffold yard")
	var before: int = field.count_team(0)
	trained.pressed.emit()
	check(field.count_team(0) == before + 1 and purse.economy.credits(0) == 49900 and _hud_text(scene, "HudPower") == "⚡ 0/0", "a unit click trains it and spends credits")
	var cancel: Button = scene.find_child("CancelQueue", true, false) as Button
	check(yard.begin_scaffold(&"salween_hydro", yard.center, 200.0), "a second scaffold can start")
	yard.advance(1.0)
	var during: int = purse.economy.credits(0)
	cancel.pressed.emit()
	check(cancel != null and not yard.scaffold_active and purse.economy.credits(0) == during + 5 and _hud_text(scene, "HudBuild") == "cancelled", "cancel refunds the scaffold in progress")
	yard.finished.append(&"barracks")
	(scene.get("hud") as SMHud).refresh()
	var blocked_n: int = field.count_team(0)
	var blocked_c: int = purse.economy.credits(0)
	trained.pressed.emit()
	check(field.count_team(0) == blocked_n and purse.economy.credits(0) == blocked_c and _hud_text(scene, "HudPower") == "⚡ 0/30" and _hud_text(scene, "HudBuild") == "low power", "low power stops production")
	yard.finished.append(&"salween_hydro")
	trained.pressed.emit()
	check(field.count_team(0) == blocked_n + 1 and purse.economy.credits(0) == blocked_c - 80 and _hud_text(scene, "HudPower") == "⚡ 100/30", "a plant restores production")
	scene.free()
	await _hud_map("res://game/sop_ruak.tscn", "Sop Ruak")
	await _hud_map("res://game/burma_road.tscn", "Burma Road")
	await _hud_map("res://game/ten_degree_atolls.tscn", "Ten Degree Atolls")
	await _hud_map("res://game/mekong_delta.tscn", "Mekong Delta")
	await _hud_map("res://game/chiang_rai.tscn", "Siege of Chiang Rai")
	SMFront.faction_id = "nmrf"
	var burma: Node = (load("res://game/burma_road.tscn") as PackedScene).instantiate()
	root.add_child(burma)
	await process_frame
	check(_hud_text(burma, "HudFaction") == "NMRF", "the hud follows the selected faction")
	var packer: Button = burma.find_child("MovePacker", true, false) as Button
	var nmrf_side: SMSide = burma.get("side") as SMSide
	var origin: Vector3 = nmrf_side.yard.packer_pos
	packer.pressed.emit()
	check(packer != null and nmrf_side.yard.packer_pos != origin and nmrf_side.yard.style == SMBuildYard.Style.MOBILE, "the packer button uses the mobile build")
	var wharf: Button = burma.find_child("Build_gun_wharf", true, false) as Button
	wharf.pressed.emit()
	check(nmrf_side.yard.finished.has(&"gun_wharf"), "a wharf click unpacks the mobile core")
	var turbine: Button = burma.find_child("Build_tidal_turbine", true, false) as Button
	var air: Button = burma.find_child("Build_airfield", true, false) as Button
	var naval: Button = burma.find_child("Build_naval_yard", true, false) as Button
	turbine.pressed.emit()
	air.pressed.emit()
	naval.pressed.emit()
	check(nmrf_side.yard.finished.has(&"tidal_turbine") and nmrf_side.yard.finished.has(&"airfield") and nmrf_side.yard.finished.has(&"naval_yard"), "later buildings annex beside the unpacked core")
	burma.free()
	SMFront.faction_id = "mvd"
	var atoll: Node = (load("res://game/ten_degree_atolls.tscn") as PackedScene).instantiate()
	root.add_child(atoll)
	await process_frame
	var hub: Button = atoll.find_child("Build_command_hub", true, false) as Button
	hub.pressed.emit()
	var mvd_side: SMSide = atoll.get("side") as SMSide
	check(_hud_text(atoll, "HudFaction") == "MVD" and mvd_side.yard.style == SMBuildYard.Style.INTERNAL and mvd_side.yard.finished.has(&"command_hub"), "a hub click uses the internal queue")
	atoll.free()
	SMFront.faction_id = "gtfc"
	check(SMFront.current() == "gtfc", "the hud test restores GTFC")
	await process_frame

func _click_east(scene: Node) -> bool:
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	var cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	if mm == null or cam == null:
		return false
	var before_x: float = cam.focus.x
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(mm.map_size().x - 2.0, mm.map_size().y * 0.5)
	mm._gui_input(click)
	return cam.focus.x > before_x + 8.0

func _campaign_hud(scene: Node, id: String) -> bool:
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	if mm == null or scene.find_child("CompanyList", true, false) != null:
		return false
	mm.sample()
	var field: SMPointer = scene.get("field") as SMPointer
	var cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	var faction: String = SMCampaign.player_faction(id)
	var faction_name: String = "GTFC"
	var train_id: String = "Train_militia"
	var build_id: String = "Build_scaffold_yard"
	if faction == "nmrf":
		faction_name = "NMRF"
		train_id = "Train_river_rifle"
		build_id = "MovePacker"
	elif faction == "mvd":
		faction_name = "MVD"
		train_id = "Train_clearance_trooper"
		build_id = "Build_command_hub"
	var built: Button = scene.find_child(build_id, true, false) as Button
	var trained: Button = scene.find_child(train_id, true, false) as Button
	var ability: Button = scene.find_child("AbilityButton", true, false) as Button
	if field == null or cam == null or built == null or trained == null or ability == null or ability.text != "Ability (F)":
		return false
	if scene.find_child("GroupBuildings", true, false) == null or scene.find_child("GroupUnits", true, false) == null or scene.find_child("GroupAbility", true, false) == null:
		return false
	if _hud_text(scene, "HudFaction") != faction_name or _hud_text(scene, "HudCredits") != "Credits 50000":
		return false
	if not _hud_text(scene, "HudPower").begins_with("⚡ ") or _hud_text(scene, "HudMap") != SMCampaign.title_of(id):
		return false
	if _hud_text(scene, "HudSelection") != "Nothing selected":
		return false
	var water_ok: bool = mm.saw_water if id == "andaman" else not mm.saw_water
	if not mm.saw_land or not water_ok:
		return false
	if mm.player_dots != field.count_team(0) or mm.enemy_dots != field.count_team(1):
		return false
	if mm.camera_rect.size.x <= 1.0 or not mm.covers_focus():
		return false
	return true

func _hud_text(scene: Node, node_name: String) -> String:
	var label: Label = scene.find_child(node_name, true, false) as Label
	if label == null:
		return ""
	return label.text

func _hud_map(path: String, map_name: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(_hud_text(scene, "HudMap") == map_name, "%s names the map on the hud" % map_name)
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	if mm != null:
		mm.sample()
	var terrain_ok: bool = mm != null and mm.saw_land and (map_name == "Burma Road" or mm.saw_water)
	check(_hud_text(scene, "HudFaction") == "GTFC" and _hud_text(scene, "HudPower").begins_with("⚡ ") and _hud_text(scene, "HudSelection") == "Nothing selected" and scene.find_child("CompanyList", true, false) == null and terrain_ok and mm.covers_focus(), "%s shows faction, power, an empty selection, and the minimap" % map_name)
	scene.free()
	await process_frame

func test_sm_outcome() -> void:
	SMFront.faction_id = "gtfc"
	var empty: SMOutcome = SMOutcome.new()
	empty.consider(0, 0, 0, 0)
	check(not empty.over, "an empty start does not end the match")
	empty.consider(4, 0, 0, 0)
	empty.consider(0, 0, 0, 0)
	check(not empty.over and empty.saw_player and not empty.saw_enemy, "a side that never appeared cannot win or lose")
	var stay: SMOutcome = SMOutcome.new()
	stay.consider(6, 0, 3, 0)
	check(not stay.over, "both sides on the field keep the match open")
	stay.consider(0, 1, 3, 1)
	check(not stay.over, "a living building keeps a side in the match")
	stay.consider(0, 0, 3, 1)
	check(stay.over and not stay.victory, "losing every unit and building is a defeat")
	var win: SMOutcome = SMOutcome.new()
	win.consider(6, 0, 3, 1)
	win.consider(6, 0, 0, 1)
	check(not win.over, "enemy units can fall while a building still stands")
	win.consider(6, 0, 0, 0)
	check(win.over and win.victory, "clearing the last enemy building is a victory")
	var paths: PackedStringArray = PackedStringArray([
		"res://game/phillips_channel.tscn",
		"res://game/sop_ruak.tscn",
		"res://game/burma_road.tscn",
		"res://game/ten_degree_atolls.tscn",
		"res://game/mekong_delta.tscn",
		"res://game/chiang_rai.tscn",
		"res://game/nmrf_yard.tscn",
		"res://game/mvd_yard.tscn",
	])
	for path: String in paths:
		await _outcome_open(path)
	await _outcome_defeat("res://game/phillips_channel.tscn")
	await _outcome_victory("res://game/sop_ruak.tscn")
	SMFront.faction_id = "gtfc"

func _outcome_open(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var end: SMOutcome = scene.get("outcome") as SMOutcome
	var banner: Label = scene.find_child("MatchBanner", true, false) as Label
	var back: Button = scene.find_child("BootMenuButton", true, false) as Button
	var banner_hidden: bool = banner != null and not banner.is_visible_in_tree()
	var back_hidden: bool = back != null and back.text == "Boot menu" and not back.is_visible_in_tree()
	check(end != null and not end.over and banner_hidden and back_hidden, "%s stays open until a side is wiped out" % path.get_file())
	scene.free()
	await process_frame

func _outcome_defeat(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	_wipe(field.units_of(SMPointer.PLAYER))
	await process_frame
	var end: SMOutcome = scene.get("outcome") as SMOutcome
	var banner: Label = scene.find_child("MatchBanner", true, false) as Label
	var back: Button = scene.find_child("BootMenuButton", true, false) as Button
	check(end.over and not end.victory and banner.text == "Defeat" and banner.is_visible_in_tree(), "a wiped player sees Defeat")
	check(back.is_visible_in_tree() and back.text == "Boot menu", "defeat offers the boot menu")
	scene.free()
	await process_frame

func _outcome_victory(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var raider: SMRaider = scene.get("raider") as SMRaider
	_wipe(field.units_of(SMPointer.ENEMY))
	await process_frame
	var end: SMOutcome = scene.get("outcome") as SMOutcome
	check(not end.over and raider.yard.living_count() > 0, "a standing enemy building holds the match open")
	_raze_yard(raider.yard)
	await process_frame
	var banner: Label = scene.find_child("MatchBanner", true, false) as Label
	var back: Button = scene.find_child("BootMenuButton", true, false) as Button
	check(end.over and end.victory and banner.text == "Victory" and banner.is_visible_in_tree() and back.is_visible_in_tree(), "clearing the last building shows Victory")
	scene.free()
	await process_frame

func _wipe(units: Array[RTSUnit]) -> void:
	for u: RTSUnit in units:
		u.take_damage(100000.0)

func _raze_yard(yard: SMBuildYard) -> void:
	var ids: Array[StringName] = []
	for id: StringName in yard.finished:
		ids.append(id)
	if yard.scaffold_active and yard.scaffold_id != &"":
		ids.append(yard.scaffold_id)
	for id: StringName in ids:
		yard.damage_structure(id, 100000.0)

func test_sm_sight() -> void:
	var grid: SMDomainGrid = SMDomainGrid.new(10, 10, 4.0, Vector3.ZERO)
	var book: SMSight = SMSight.new()
	book.bind(grid)
	var home: Vector3 = grid.cell_center(Vector2i(1, 1))
	var far: Vector3 = grid.cell_center(Vector2i(8, 8))
	book.begin()
	book.add_seer(home, SMSight.UNIT_RADIUS)
	book.commit()
	check(book.sees(home + Vector3(4.0, 0.0, 0.0)) and not book.sees(far), "unit sight reaches 18m and not the far shore")
	check(book.cell_state(Vector2i(1, 1)) == SMSight.CLEAR and book.cell_state(Vector2i(8, 8)) == SMSight.HIDDEN, "unseen ground stays hidden")
	book.begin()
	book.add_seer(grid.cell_center(Vector2i(8, 1)), 3.0)
	book.commit()
	check(book.cell_state(Vector2i(1, 1)) == SMSight.DIM and book.cell_state(Vector2i(8, 8)) == SMSight.HIDDEN, "explored ground stays dim")
	book.begin()
	book.add_seer(home, SMSight.UNIT_RADIUS)
	book.add_seer(far, SMTechNet.VISION_RADIUS)
	book.commit()
	check(book.sees(far) and book.cell_state(Vector2i(8, 8)) == SMSight.CLEAR, "hydro radar reveals its radius")
	var paths: PackedStringArray = PackedStringArray([
		"res://game/phillips_channel.tscn",
		"res://game/sop_ruak.tscn",
		"res://game/burma_road.tscn",
		"res://game/ten_degree_atolls.tscn",
		"res://game/mekong_delta.tscn",
		"res://game/chiang_rai.tscn",
		"res://game/nmrf_yard.tscn",
		"res://game/mvd_yard.tscn",
	])
	for path: String in paths:
		await _sight_open(path)
	await _sight_radar("res://game/phillips_channel.tscn")

func _sight_open(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var book: SMSight = scene.get("sight") as SMSight
	var friends_ok: bool = field != null and field.count_team(0) > 0
	if field != null:
		for u: RTSUnit in field.units_of(0):
			friends_ok = friends_ok and u.visible
	var foes_hidden: bool = true
	if field != null:
		for u: RTSUnit in field.units_of(1):
			foes_hidden = foes_hidden and not u.visible and book != null and not book.sees(u.global_position)
	var yard: Node3D = scene.get_node_or_null("EnemyYard") as Node3D
	var veil: Node = scene.get_node_or_null("FogVeil")
	check(book != null and veil != null and friends_ok and foes_hidden and yard != null and not yard.visible, "%s hides enemies outside sight" % path.get_file())
	scene.free()
	await process_frame

func _sight_radar(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var book: SMSight = scene.get("sight") as SMSight
	var yard: Node3D = scene.get_node("EnemyYard") as Node3D
	var tech: SMTechNet = (scene.get("sim") as SMMatch).tech
	var grid: SMDomainGrid = (scene.get("sim") as SMMatch).grid
	tech.add_site(&"radar", SMTechNet.RADAR, yard.global_position)
	tech.capture(&"radar", 0)
	SMSight.update_match(book, scene.get("field") as SMPointer, scene as Node3D, tech, scene.get("raider") as SMRaider)
	check(yard.visible and book.sees(yard.global_position), "a captured hydro radar reveals the enemy yard")
	var channel: Vector3 = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(20, 2)))
	check(book.river_lit and book.sees(channel) and grid.domain_at(channel) == SMDomainGrid.Domain.DEEP, "hydro radar lights the river corridor")
	var corner: Vector2i = Vector2i(0, 23)
	check(not book.sees(grid.cell_center(corner)) and book.cell_state(corner) == SMSight.HIDDEN, "ground outside the radar stays hidden")
	scene.free()
	await process_frame

func test_sm_shapes() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	check(_shape_is(field, 0, "militia", "figure") and _shape_is(field, 0, "ruby_lancer", "figure"), "infantry is a low-poly figure")
	check(_shape_is(field, 0, "slag_hauler", "truck") and _shape_is(field, 0, "amber_tank", "tank") and _shape_is(field, 0, "monsoon_tube", "tube"), "trucks, tanks, and artillery have different bodies")
	check(_shape_is(field, 0, "channel_skiff", "boat"), "boats are a hull")
	check(_shape_is(field, 1, "raider", "figure"), "enemy soldiers are a low-poly figure")
	var foe_body: MeshInstance3D = _unit_kind(field, 1, "raider").get_node_or_null("Body") as MeshInstance3D
	check(foe_body != null and str(foe_body.get_meta("model", "")) == "Model", "an enemy soldier uses a finished model")
	check(field.name_of(_unit_kind(field, 0, "militia")) == "Shan Insurgent Militia", "the floating name stays")
	var player_yard: Mesh = (scene.get_node("PlayerYard") as MeshInstance3D).mesh
	var enemy_yard: Mesh = (scene.get_node("EnemyYard") as MeshInstance3D).mesh
	check(_yard_shown(scene.get_node("PlayerYard") as MeshInstance3D) and _yard_shown(scene.get_node("EnemyYard") as MeshInstance3D), "yard buildings are a model or a taller block")
	var side: SMSide = scene.get("side") as SMSide
	side.order_building(&"scaffold_yard")
	var built: MeshInstance3D = scene.get_node_or_null("Built_scaffold_yard") as MeshInstance3D
	var built_mesh: Mesh = null
	if built != null:
		built_mesh = built.mesh
	check(_tall_mesh(built_mesh) or (built != null and str(built.get_meta("model", "")) != ""), "a finished building is a taller block or a loaded model")
	field.faction_id = "mvd"
	var gunship: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(-40, 0, -20), &"hub_drone")
	check(_mesh_kind(gunship) == "heli", "a helicopter is a rotor aircraft")
	var tint: Color = _albedo(_unit_kind(field, 0, "militia"))
	check(tint.r > 0.6 and tint.g < 0.3, "unit color stays with the faction")
	var tank: RTSUnit = _unit_kind(field, 0, "amber_tank")
	check(tank.get_node_or_null("Body/Turret") is MeshInstance3D, "a tank keeps a separate turret")
	var skiff: RTSUnit = _unit_kind(field, 0, "channel_skiff")
	check(skiff.get_node_or_null("Body/Wake") is MeshInstance3D, "a boat keeps a wake")
	check(gunship.get_node_or_null("Body/Rotor") is MeshInstance3D, "a helicopter keeps a rotor")
	var jet: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(-44, 0, -28), &"su30")
	var fighter: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(-48, 0, -24), &"cyan_gunship")
	check(_mesh_kind(jet) == "jet" and _mesh_kind(fighter) == "jet", "a jet is a swept airframe")
	var foe: RTSUnit = field.spawn(SMPointer.ENEMY, tank.global_position + Vector3(14.0, 0.0, 0.0), &"raider")
	tank.attack_range = 40.0
	tank.attack_target = foe
	var turret: MeshInstance3D = tank.get_node("Body/Turret") as MeshInstance3D
	var yaw_before: float = turret.rotation.y
	field.tick(0.05)
	check(absf(wrapf(turret.rotation.y - yaw_before, -PI, PI)) > 0.4, "the turret turns toward its target")
	check(_structure_forms(scene, side, field), "each structure role has its own silhouette")
	scene.free()
	await process_frame
	var mvd: Node = (load("res://game/mvd_yard.tscn") as PackedScene).instantiate()
	root.add_child(mvd)
	await process_frame
	var mfield: SMPointer = mvd.get("field") as SMPointer
	check(_shape_is(mfield, 0, "clearance_trooper", "figure"), "mvd infantry is a low-poly figure")
	check(_shape_is(mfield, 0, "hub_drone", "heli") and _shape_is(mfield, 0, "river_drone", "heli"), "mvd aircraft are rotor aircraft")
	check(_shape_is(mfield, 0, "charcoal_apc", "tank"), "mvd armor is a tank")
	check(_tall_mesh((mvd.get_node("HubShell") as MeshInstance3D).mesh), "the mvd hub is a taller block")
	mvd.free()
	await process_frame
	var nmrf: Node = (load("res://game/nmrf_yard.tscn") as PackedScene).instantiate()
	root.add_child(nmrf)
	await process_frame
	var nfield: SMPointer = nmrf.get("field") as SMPointer
	check(_shape_is(nfield, 0, "river_rifle", "figure"), "nmrf infantry is a low-poly figure")
	check(_shape_is(nfield, 0, "sampan", "sub") and _shape_is(nfield, 0, "emerald_gunboat", "boat"), "a pocket sub is a hull and a surface boat stays a hull")
	check(_shape_is(nfield, 0, "packer", "truck"), "the packer unit is a truck")
	check(_tall_mesh((nmrf.get_node("PackerCore") as MeshInstance3D).mesh), "the packer building is a taller block")
	nmrf.free()
	await process_frame
	SMFront.faction_id = "gtfc"

func test_sm_field() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var sim: SMMatch = scene.get("sim") as SMMatch
	var roster: SMRoster = scene.get("roster") as SMRoster
	var friends: Array[RTSUnit] = field.units_of(0)
	var foes: Array[RTSUnit] = field.units_of(1)
	var militia: RTSUnit = friends[0]
	var slag: RTSUnit = friends[1]
	var ruby: RTSUnit = friends[2]
	var shooter: RTSUnit = friends[3]
	var tube: RTSUnit = friends[4]
	var skiff: RTSUnit = friends[5]
	field.select_only([militia])
	check(field.cast_f(militia.global_position) == "toggle" and bool(militia.get_meta("toggled")), "a group toggle flips the selected unit")
	field.select_only([slag, ruby])
	check(field.cast_f(slag.global_position) == "smart" and int(slag.get_meta("fired_f", 0)) == 1 and int(ruby.get_meta("fired_f", 0)) == 0, "one F press fires only the closer smart-cast unit")
	field.select_only([tube])
	check(field.cast_f(tube.global_position) == "beam" and bool(tube.get_meta("channeling")), "a channeled beam starts on the selected tube")
	field.tick(1.6)
	check(int(tube.get_meta("beam_done")) == 1 and bool(foes[0].get_meta("frozen", false)), "a finished beam freezes the nearest enemy")
	shooter.global_position = sim.ew.center
	shooter.set_meta("guidance", "gps")
	shooter.set_meta("fiber_on", false)
	shooter.attack_range = 30.0
	var victim: RTSUnit = foes[1]
	victim.global_position = sim.ew.center + Vector3(3.0, 0.0, 0.0)
	victim.hp = 200.0
	shooter.attack_target = victim
	shooter._cooldown = 0.0
	var jammed_before: float = victim.hp
	shooter.advance(0.3)
	check(is_equal_approx(jammed_before - victim.hp, shooter.attack_damage * sim.ew.penalty), "the jammer cuts a GPS shot")
	shooter.set_meta("fiber_on", true)
	shooter._cooldown = 0.0
	var fiber_before: float = victim.hp
	shooter.advance(0.3)
	check(is_equal_approx(fiber_before - victim.hp, shooter.attack_damage), "a fiber link ignores the jammer")
	shooter.set_meta("fiber_on", false)
	shooter.set_meta("guidance", "hop")
	shooter._cooldown = 0.0
	var hop_before: float = victim.hp
	shooter.advance(0.3)
	check(is_equal_approx(hop_before - victim.hp, shooter.attack_damage), "a hop link ignores the jammer")
	shooter.attack_target = null
	field.apply_status(skiff, "frozen", 3.0)
	skiff.set_path(PackedVector3Array([skiff.global_position + Vector3(8.0, 0.0, 0.0)]))
	var frozen_at: Vector3 = skiff.global_position
	field.tick(0.4)
	check(bool(skiff.get_meta("frozen")) and skiff.global_position.is_equal_approx(frozen_at), "frozen stops the unit")
	field.apply_status(skiff, "shrunk", 3.0)
	var body: MeshInstance3D = skiff.get_node_or_null("Body") as MeshInstance3D
	var shrink_hp: float = skiff.hp
	skiff.take_damage(10.0)
	check(body != null and body.scale.x < 0.6 and skiff.speed_scale > 1.5 and is_equal_approx(skiff.hp, shrink_hp - 5.0), "shrunk scales the mesh and halves incoming damage")
	field.apply_status(skiff, "black_hole", 3.0)
	var hole_hp: float = skiff.hp
	skiff.take_damage(10.0)
	check(is_equal_approx(skiff.hp, hole_hp - 2.0), "black-hole armor cuts incoming damage")
	var statue: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(-24.0, 0.0, -18.0), &"militia")
	field.apply_status(statue, "frozen", 4.0)
	statue.hp = 40.0
	statue.take_damage(7.0)
	check(statue.is_alive() and is_equal_approx(statue.hp, 33.0) and not bool(statue.get_meta("shattered", false)), "a light hit does not shatter a frozen unit")
	statue.take_damage(8.0)
	check(not statue.is_alive() and bool(statue.get_meta("shattered", false)), "a heavy hit shatters a frozen unit")
	var well: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(18.0, 0.0, 12.0), &"amber_tank")
	var buddy: RTSUnit = field.spawn(SMPointer.PLAYER, well.global_position + Vector3(4.0, 0.0, 0.0), &"militia")
	field.apply_status(well, "black_hole", 4.0)
	buddy.hp = 80.0
	var hole_before: float = well.hp
	var puller: RTSUnit = field.spawn(SMPointer.ENEMY, well.global_position + Vector3(18.0, 0.0, 0.0), &"raider")
	puller.attack_damage = 10.0
	puller.attack_range = 40.0
	puller.attack_target = buddy
	puller._cooldown = 0.0
	var shot_named: Array[RTSUnit] = []
	puller.fired.connect(func(_src: RTSUnit, tgt: RTSUnit) -> void: shot_named.append(tgt))
	puller.advance(0.2)
	check(is_equal_approx(buddy.hp, 80.0) and is_equal_approx(well.hp, hole_before - 2.0) and shot_named.size() == 1 and shot_named[0] == buddy, "black-hole armor pulls a nearby shot and the fired signal still names the aimed unit")
	var bug: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(-8.0, 0.0, 22.0), &"raider")
	field.apply_status(bug, "shrunk", 4.0)
	var walker: RTSUnit = field.spawn(SMPointer.PLAYER, bug.global_position + Vector3(-1.2, 0.0, 0.0), &"militia")
	var walker_from: Vector3 = walker.global_position
	walker.set_path(PackedVector3Array([bug.global_position]))
	walker.advance(0.4)
	field._crush_under(walker, walker_from)
	var crushed: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(8.0, 0.0, 22.0), &"raider")
	field.apply_status(crushed, "shrunk", 4.0)
	var tank: RTSUnit = field.spawn(SMPointer.PLAYER, crushed.global_position + Vector3(-1.2, 0.0, 0.0), &"amber_tank")
	var tank_from: Vector3 = tank.global_position
	tank.set_path(PackedVector3Array([crushed.global_position]))
	tank.advance(0.5)
	field._crush_under(tank, tank_from)
	check(bug.is_alive() and not crushed.is_alive() and bool(crushed.get_meta("crushed", false)), "a vehicle crushes a shrunk unit and infantry does not")
	var before: int = roster.economy.credits(0)
	var standing: bool = sim.goods.has_collector(&"slag_west")
	check((standing or sim.goods.snap_refinery(&"slag_west", 0)) and roster.economy.credits(0) == before, "claiming Golden Slag does not pay until the loop finishes")
	scene.call("tick_world", 4.0)
	check(roster.economy.credits(0) == before + 250, "a Phillips tick pays a claimed node")
	var night_before: int = roster.economy.credits(0)
	sim.goods.add_node(&"ruby_night", SMCommodityNet.KIND_RUBY, Vector3(48.0, 0.0, 20.0), 15, false)
	check(sim.goods.snap_refinery(&"ruby_night", 0) and sim.goods.set_night_shift(&"ruby_night", true), "night shift arms a ruby node")
	scene.call("tick_world", 2.0)
	check(roster.economy.credits(0) == night_before + 250, "night shift pays ruby in half a loop")
	check(sim.goods.snap_refinery(&"rare_shore", 0), "a rare-earth node can be claimed")
	scene.call("tick_world", 4.0)
	check(sim.goods.stock_of(0) >= 1, "rare-earth stock grows on a Phillips tick")
	var rare_i: int = sim.goods.find(&"rare_shore")
	var rare_node: Dictionary = sim.goods.nodes[rare_i]
	militia.global_position = rare_node["pos"] as Vector3
	var wet: float = militia.hp
	scene.call("tick_world", 1.0)
	check(militia.hp < wet, "water beside rare earth harms infantry")
	militia.global_position = Vector3(-70.0, 0.0, -30.0)
	sim.tech.capture(&"cyber", 0)
	roster.economy.set_credits(1, 80)
	var siphon_before: int = roster.economy.credits(0)
	scene.call("tick_world", 1.0)
	check(roster.economy.credits(0) > siphon_before and sim.tech.siphon_of(&"cyber") > 0, "cyber siphon pays during a Phillips tick")
	sim.tech.add_site(&"clinic", SMTechNet.CLINIC, Vector3(-70.0, 0.0, -30.0))
	sim.tech.capture(&"clinic", 0)
	militia.hp = maxf(1.0, militia.max_hp - 30.0)
	var hurt: float = militia.hp
	scene.call("tick_world", 1.0)
	check(militia.hp > hurt and sim.tech.clinic_healed(0) > 0.0, "a clinic heals infantry during a Phillips tick")
	sim.tech.add_site(&"bazaar", SMTechNet.BAZAAR, Vector3.ZERO)
	sim.tech.capture(&"bazaar", 0)
	var cost_before: int = roster.economy.credits(0)
	var trained: Button = scene.find_child("Train_militia", true, false) as Button
	trained.pressed.emit()
	check(trained != null and roster.economy.credits(0) == cost_before - 64, "a captured bazaar discounts a trained infantry unit")
	scene.free()
	await process_frame

func test_sm_sites() -> void:
	await _sites("res://game/phillips_channel.tscn", 8, 2, 0, 0, 0, 1, 0, 0)
	await _sites("res://game/sop_ruak.tscn", 12, 3, 1, 0, 0, 0, 0, 0)
	await _sites("res://game/burma_road.tscn", 10, 0, 2, 0, 2, 0, 0, 0)
	await _sites("res://game/ten_degree_atolls.tscn", 16, 0, 0, 0, 2, 0, 4, 0)
	await _sites("res://game/mekong_delta.tscn", 14, 2, 0, 2, 0, 0, 0, 4)
	await _sites("res://game/chiang_rai.tscn", 24, 4, 2, 0, 0, 0, 0, 0)

func _sites(path: String, nodes: int, cyber: int, bazaar: int, clinic: int, radar: int, salvage: int, derrick: int, bridge: int) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var sim: SMMatch = scene.get("sim") as SMMatch
	check(_site_counts(scene, nodes, cyber, bazaar, clinic, radar, salvage, derrick, bridge), "%s has its blueprint nodes" % path.get_file())
	if path.ends_with("chiang_rai.tscn"):
		var gar: int = _prefix_count(scene, "Garrison_")
		var gid: StringName = &""
		for site: Dictionary in sim.tech.sites:
			if StringName(str(site.get("kind", ""))) == SMTechNet.GARRISON:
				gid = StringName(str(site.get("id", "")))
				break
		var held: bool = sim.tech.capture(gid, 0)
		scene.call("tick_world", 1.0)
		check(gar == 4 and held and sim.tech.income_of(gid) >= 8, "chiang rai has four civilian garrisons")
	if path.ends_with("sop_ruak.tscn"):
		sim = scene.get("sim") as SMMatch
		var roster: SMRoster = scene.get("roster") as SMRoster
		var before: int = roster.economy.credits(0)
		var id: StringName = _paying_node(sim)
		var claimed: bool = sim.goods.snap_refinery(id, 0)
		scene.call("tick_world", 4.0)
		var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
		if mm != null:
			mm.sample()
		var collector: Node = scene.get_node_or_null("Collector_%s" % str(id))
		check(claimed and roster.economy.credits(0) > before and collector != null and mm != null and mm.claimed_dots >= 1, "claiming a Sop Ruak node pays, spawns a collector, and marks the minimap")
	scene.free()
	await process_frame

func _paying_node(sim: SMMatch) -> StringName:
	for node: Dictionary in sim.goods.nodes:
		if int(node.get("rate", 0)) > 0:
			return StringName(str(node.get("id", "")))
	return &""

func _site_counts(scene: Node, nodes: int, cyber: int, bazaar: int, clinic: int, radar: int, salvage: int, derrick: int, bridge: int) -> bool:
	var sim: SMMatch = scene.get("sim") as SMMatch
	var field: SMPointer = scene.get("field") as SMPointer
	if sim == null or field == null:
		return false
	if sim.goods.nodes.size() != nodes:
		return false
	if _site_kind(sim, SMTechNet.CYBER) != cyber or _site_kind(sim, SMTechNet.BAZAAR) != bazaar:
		return false
	if _site_kind(sim, SMTechNet.CLINIC) != clinic or _site_kind(sim, SMTechNet.RADAR) != radar:
		return false
	if _site_kind(sim, SMTechNet.SALVAGE) != salvage or _site_kind(sim, SMTechNet.DERRICK) != derrick or _site_kind(sim, SMTechNet.BRIDGE) != bridge:
		return false
	if _prefix_count(scene, "Node_") != nodes:
		return false
	if _prefix_count(scene, "Tech_") != cyber + bazaar + clinic + radar:
		return false
	if _prefix_count(scene, "Salvage_") != salvage or _prefix_count(scene, "Derrick_") != derrick or _prefix_count(scene, "Bridge_") != bridge:
		return false
	return field.count_team(0) >= 1 and field.count_team(1) >= 1

func _site_kind(sim: SMMatch, kind: StringName) -> int:
	var n: int = 0
	for site: Dictionary in sim.tech.sites:
		if StringName(str(site.get("kind", ""))) == kind:
			n += 1
	return n

func _prefix_count(scene: Node, prefix: String) -> int:
	var n: int = 0
	for child: Node in scene.get_children():
		if str(child.name).begins_with(prefix):
			n += 1
	return n

func test_sm_haze() -> void:
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var sim: SMMatch = scene.get("sim") as SMMatch
	var book: SMSight = scene.get("sight") as SMSight
	var west: Vector3 = sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(8, 12)))
	var east: Vector3 = sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(30, 12)))
	check(field.nav_ground.find_path(west, east).is_empty(), "a ground path across the Phillips channel fails")
	check(field.nav_amphib.find_path(west, east).size() > 0, "a boat path across the Phillips channel succeeds")
	check(field.nav_naval.find_path(west, east).size() > 0, "a naval path uses the deep channel")
	var player: RTSUnit = field.units_of(0)[0]
	var enemy: RTSUnit = field.units_of(1)[0]
	player.global_position = west
	enemy.global_position = west + Vector3(10.0, 0.0, 0.0)
	book.force_weather(false)
	SMSight.update_match(book, field, scene as Node3D, sim.tech, scene.get("raider") as SMRaider)
	check(book.sees(enemy.global_position) and enemy.visible, "clear weather shows a unit inside normal sight")
	book.force_weather(true)
	SMSight.update_match(book, field, scene as Node3D, sim.tech, scene.get("raider") as SMRaider)
	check(not book.sees(enemy.global_position) and not enemy.visible, "a haze tick hides a unit inside the shortened sight")
	sim.tech.add_site(&"haze_radar", SMTechNet.RADAR, enemy.global_position)
	sim.tech.capture(&"haze_radar", 0)
	SMSight.update_match(book, field, scene as Node3D, sim.tech, scene.get("raider") as SMRaider)
	check(book.sees(enemy.global_position) and enemy.visible, "a captured radar reveals the unit the haze hid")
	scene.free()
	await process_frame

func test_sm_chain() -> void:
	check(_chain_scaffold("gtfc", &"naval_yard", &"seismic_imploder"), "gtfc builds the chain and the imploder hits once")
	check(_chain_mobile("nmrf", &"tidal_turbine", &"monsoon_decimator"), "nmrf builds the chain and the decimator hits once")
	check(_chain_internal("mvd", &"naval_yard", &"ion_cryo"), "mvd builds the chain and the collider hits once")
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var sim: SMMatch = scene.get("sim") as SMMatch
	var roster: SMRoster = scene.get("roster") as SMRoster
	var walker: RTSUnit = field.units_of(0)[0]
	var spot: Vector3 = sim.grid.cell_center(SMDomainGrid.at("phillips", Vector2i(6, 4)))
	walker.global_position = spot
	var purse: int = roster.economy.credits(0)
	scene.call("tick_world", 0.2)
	var collector: Node = scene.get_node_or_null("Collector_slag_north")
	scene.call("tick_world", 4.0)
	var hydro: Button = scene.find_child("Build_salween_hydro", true, false) as Button
	var weapon: Button = scene.find_child("Super_seismic_imploder", true, false) as Button
	var built: int = (scene.get("side") as SMSide).yard.tech_order.size()
	check(sim.goods.has_collector(&"slag_north") and collector != null and roster.economy.credits(0) > purse, "walking onto a Phillips pad claims it and the node pays")
	check(built == 10 and hydro != null and str(hydro.get_meta("caption", "")) == "Salween Hydro-Generator" and weapon != null and str(weapon.get_meta("caption", "")) == "Seismic Slag Vacuum Imploder", "the yard lists the chain and the superweapon")
	scene.free()
	await process_frame

func _chain_scaffold(faction: String, water_id: StringName, super_id: StringName) -> bool:
	var yard: SMBuildYard = _chain_yard(faction, SMBuildYard.Style.SCAFFOLD)
	var econ: RTSEconomy = yard.economy
	econ.set_credits(0, 100000)
	yard.drain_per_sec = 1
	yard.radius = 80.0
	for i: int in yard.tech_order.size():
		var id: StringName = yard.tech_order[i]
		if not yard.begin_scaffold(id, Vector3(float(i) * 3.0, 0.0, 0.0), 120.0):
			return false
		yard.advance(float(yard.building_time.get(id, 4.0)))
		if not yard.finished.has(id):
			return false
	return _chain_done(yard, water_id, super_id)

func _chain_internal(faction: String, water_id: StringName, super_id: StringName) -> bool:
	var yard: SMBuildYard = _chain_yard(faction, SMBuildYard.Style.INTERNAL)
	yard.economy.set_credits(0, 100000)
	yard.radius = 40.0
	yard.clearance = 1
	for id: StringName in yard.tech_order:
		var tier: int = int(yard.building_tier.get(id, 1))
		while yard.clearance < tier:
			if not yard.buy_clearance(yard.clearance + 1, 50):
				return false
		if not yard.queue_internal(id):
			return false
		yard.advance(float(yard.building_time.get(id, 4.0)))
		if not yard.place_finished(id, Vector3(2.0, 0.0, 0.0)):
			return false
	return _chain_done(yard, water_id, super_id)

func _chain_mobile(faction: String, water_id: StringName, super_id: StringName) -> bool:
	var yard: SMBuildYard = _chain_yard(faction, SMBuildYard.Style.MOBILE)
	var grid: SMDomainGrid = SMDomainGrid.new(8, 8, 4.0, Vector3.ZERO)
	yard.grid = grid
	yard.packer_pos = grid.cell_center(Vector2i(1, 1))
	if yard.tech_order.is_empty() or not yard.unpack(yard.tech_order[0]):
		return false
	for i: int in range(1, yard.tech_order.size()):
		if not yard.place_annex(yard.tech_order[i]):
			return false
	return _chain_done(yard, water_id, super_id)

func _chain_yard(faction: String, style: int) -> SMBuildYard:
	var yard: SMBuildYard = SMBuildYard.new()
	yard.style = style
	yard.team = 0
	yard.economy = RTSEconomy.new()
	yard.center = Vector3.ZERO
	yard.load_catalog(SMCatalog.faction(faction))
	return yard

func _chain_done(yard: SMBuildYard, water_id: StringName, super_id: StringName) -> bool:
	if yard.finished.size() != 10 or yard.tech_order.size() != 10:
		return false
	if not bool(yard.structure_water.get(water_id, false)):
		return false
	if yard.super_id != super_id or yard.super_name == "":
		return false
	var victims: Array[Dictionary] = [{"pos": Vector3.ZERO, "hp": 100.0}]
	if yard.fire_super(Vector3.ZERO, victims) != 1:
		return false
	var left: float = float(victims[0]["hp"])
	if left >= 100.0:
		return false
	if yard.fire_super(Vector3.ZERO, victims) != 0:
		return false
	return is_equal_approx(float(victims[0]["hp"]), left)

func test_sm_names() -> void:
	var total: int = 0
	var mortar: String = ""
	for faction_id: String in ["gtfc", "nmrf", "mvd", "black_market"]:
		for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction_id)):
			var id: String = str(unit.get("id", ""))
			var display: String = str(unit.get("display_name", ""))
			if id == "monsoon_tube":
				mortar = display
			total += 1
			check(_named_f(faction_id, id, display, str(unit.get("ability", "")), str(unit.get("f_stat", ""))), "%s %s shows its name and F changes one stat" % [faction_id, id])
	check(total == 61 and mortar == "Slag Jump Mortar", "the roster is 61 blueprint names and the Kokang mortar stays storefront-safe")
	SMFront.faction_id = "gtfc"
	check(await _train_caption("res://game/phillips_channel.tscn", "Train_militia") == "Shan Insurgent Militia", "gtfc training shows the blueprint name")
	check(await _train_caption("res://game/phillips_channel.tscn", "Train_kachin_dog") == "Kachin Sapper Dog", "gtfc training lists the sapper dog")
	SMFront.faction_id = "nmrf"
	check(await _train_caption("res://game/burma_road.tscn", "Train_river_rifle") == "Patani Corsair Guard", "nmrf training shows the blueprint name")
	SMFront.faction_id = "mvd"
	check(await _train_caption("res://game/ten_degree_atolls.tscn", "Train_clearance_trooper") == "Vanguard Shock-Trooper", "mvd training shows the blueprint name")
	SMFront.faction_id = "gtfc"

func _named_f(faction: String, id: String, display: String, ability: String, stat: String) -> bool:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var field: SMPointer = SMPointer.new()
	preload("res://game/sim_presenter.gd").follow_pointer(field)
	field.bind_faction(host, cam, faction)
	field.use_open(8, 8, 2.0, Vector3.ZERO)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3.ZERO, StringName(id))
	var before: float = _stat_of(u, stat)
	field.select_only([u])
	var fired: bool = field.cast_f(u.global_position) != ""
	var after: float = _stat_of(u, stat)
	var ok: bool = u != null and field.name_of(u) == display and str(u.get_meta("ability", "")) == ability and ability != "" and fired and not is_equal_approx(before, after) and str(u.get_meta("f_effect", "")) == ability
	host.free()
	return ok

func _stat_of(u: RTSUnit, stat: String) -> float:
	if stat == "speed":
		return u.speed_scale
	if stat == "hp":
		return u.hp
	if stat == "incoming":
		return u.incoming_mult
	return u.damage_mult

func _train_caption(path: String, node_name: String) -> String:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var button: Button = scene.find_child(node_name, true, false) as Button
	var text: String = ""
	if button != null:
		text = str(button.get_meta("caption", button.text))
	scene.free()
	await process_frame
	return text

func test_sm_protocols() -> void:
	var book: SMProtocols = SMProtocols.new()
	var ids: Array[StringName] = book.power_ids()
	check(ids.size() == 25, "the protocol tree names every blueprint power")
	var economy: RTSEconomy = RTSEconomy.new()
	economy.set_credits(0, 1000)
	var abilities: SMAbilities = SMAbilities.new()
	abilities.add_unit(4, Vector3.ZERO, SMAbilities.TOGGLE, 1.0, 0.5)
	for id: StringName in ids:
		var once: bool = book.cast_power(id, economy, 0, abilities, 4)
		var twice: bool = book.cast_power(id, economy, 0, abilities, 4)
		check(once and not twice and book.effect_of(id) != "" and book.display_name(id) != "", "%s casts once" % book.display_name(id))
	check(book.credits_bonus == 250 and is_equal_approx(book.damage_mult, 1.5), "cash bounty pays and rocket pods overcharge")
	check(book.cryo_applied and abilities.status_of(4) == SMAbilities.ST_FROZEN, "cryoshot freezes the target")
	check(book.swarm_count == 23 and book.napalm == 36 and book.point_defense == 1, "swarm, napalm, and point defense leave a mark")
	var shield: SMProtocols = SMProtocols.new()
	var purse: RTSEconomy = RTSEconomy.new()
	var book_abilities: SMAbilities = SMAbilities.new()
	check(shield.cast_power(SMProtocols.COOL_POWER, purse, 0, book_abilities, -1), "point defense casts")
	check(not shield.cast_power(SMProtocols.COOL_POWER, purse, 0, book_abilities, -1), "point defense is cooling")
	shield.cool(SMProtocols.COOL_TIME)
	check(shield.cast_power(SMProtocols.COOL_POWER, purse, 0, book_abilities, -1) and shield.point_defense == 2, "point defense casts again after its cooldown")
	var legacy: SMProtocols = SMProtocols.new()
	var legacy_purse: RTSEconomy = RTSEconomy.new()
	legacy_purse.set_credits(0, 0)
	var legacy_abilities: SMAbilities = SMAbilities.new()
	legacy_abilities.add_unit(3, Vector3.ZERO, SMAbilities.TOGGLE, 1.0, 0.5)
	var first: bool = legacy.cast(&"logistics", legacy_purse, 0, legacy_abilities, 3)
	var second: bool = legacy.cast(&"arsenal", legacy_purse, 0, legacy_abilities, 3)
	var third: bool = legacy.cast(&"oracle", legacy_purse, 0, legacy_abilities, 3)
	var again: bool = legacy.cast(&"logistics", legacy_purse, 0, legacy_abilities, 3)
	check(first and second and third and not again and legacy.credits_bonus == 250 and is_equal_approx(legacy.damage_mult, 1.5) and legacy_abilities.status_of(3) == SMAbilities.ST_FROZEN, "the three branches still cast once")
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var bar: Node = scene.find_child("Protocols", true, false)
	check(bar != null, "phillips shows the protocol panel")
	var toggle_protocols: Button = scene.find_child("ProtocolsToggle", true, false) as Button
	check(bar != null and not bar.visible, "the protocol grid starts folded")
	check(toggle_protocols != null and bar != null and toggle_protocols.text == "⚡" and not bar.is_ancestor_of(toggle_protocols), "Protocols is a button beside the grid")
	var touch_node: Node = root.get_node_or_null("SMTouch")
	var poke: InputEventKey = InputEventKey.new()
	poke.pressed = true
	poke.keycode = KEY_P
	poke.physical_keycode = KEY_P
	if touch_node != null:
		touch_node._unhandled_input(poke)
	check(bar != null and bar.visible, "P opens the protocol grid")
	for id: StringName in ids:
		var button: Button = scene.find_child("Proto_%s" % str(id), true, false) as Button
		check(button != null and button.text == book.display_name(id), "phillips lists %s" % book.display_name(id))
	scene.free()
	await process_frame
	for path: String in ["res://game/sop_ruak.tscn", "res://game/burma_road.tscn", "res://game/ten_degree_atolls.tscn", "res://game/mekong_delta.tscn", "res://game/chiang_rai.tscn"]:
		var map_scene: Node = (load(path) as PackedScene).instantiate()
		root.add_child(map_scene)
		await process_frame
		var map_bar: Node = map_scene.find_child("Protocols", true, false)
		var buttons: Array[Node] = []
		if map_bar != null:
			buttons = map_bar.find_children("*", "Button", true, false)
		check(map_bar != null and buttons.size() == 25, "%s lists the protocol names" % path.get_file())
		map_scene.free()
		await process_frame

func test_sm_sides() -> void:
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var raider: SMRaider = scene.get("raider") as SMRaider
	var sim: SMMatch = scene.get("sim") as SMMatch
	var field: SMPointer = scene.get("field") as SMPointer
	var tag: Label3D = scene.find_child("Personality", true, false) as Label3D
	check(raider.opened_nodes == 2 and sim.goods.has_collector(&"bullion_east") and sim.goods.has_collector(&"bullion_north"), "the phillips bot owns two nodes")
	check(raider.took_tech and sim.tech.owner_of(&"cyber") == SMPointer.ENEMY, "the phillips bot owns a tech site")
	check(raider.used_f and field.name_of(field.units_of(SMPointer.ENEMY)[0]) == "Enemy", "the bot uses F and the raider label stays Enemy")
	check(tag != null and tag.text == "Bo Mya", "bo mya is named on the phillips yard")
	scene.free()
	await process_frame
	var atolls: Node = (load("res://game/ten_degree_atolls.tscn") as PackedScene).instantiate()
	root.add_child(atolls)
	await process_frame
	var atoll_field: SMPointer = atolls.get("field") as SMPointer
	check(_team_ids(atoll_field).size() == 4, "atolls spawns four teams")
	check(not atoll_field.teams.are_enemies(0, 2) and atoll_field.teams.are_enemies(0, 1) and atoll_field.teams.are_enemies(0, 3) and not atoll_field.teams.are_enemies(1, 3), "atolls is two alliances")
	var tran: Label3D = atolls.find_child("PersonalityTran", true, false) as Label3D
	var iskandar: Label3D = atolls.find_child("PersonalityIskandar", true, false) as Label3D
	check(tran != null and tran.text == "Tran" and iskandar != null and iskandar.text == "Iskandar", "tran and iskandar are on the atolls")
	check(atoll_field.name_of(atoll_field.units_of(1)[0]) == "Enemy", "atoll raiders stay labeled Enemy")
	_wipe(atoll_field.units_of(1))
	var atoll_raider: SMRaider = atolls.get("raider") as SMRaider
	atoll_raider.yard.damage_structure(&"enemy_yard", 100000.0)
	await process_frame
	var atoll_end: SMOutcome = atolls.get("outcome") as SMOutcome
	check(not atoll_end.over, "one living allied enemy keeps the atolls open")
	_wipe(atoll_field.units_of(3))
	_raze_yard(atoll_raider.yard)
	await process_frame
	check(atoll_end.over and atoll_end.victory, "wiping one atoll alliance ends the match")
	atolls.free()
	await process_frame
	var mekong: Node = (load("res://game/mekong_delta.tscn") as PackedScene).instantiate()
	root.add_child(mekong)
	await process_frame
	check(_team_ids(mekong.get("field") as SMPointer).size() == 4, "the mekong spawns four teams")
	mekong.free()
	await process_frame
	var chiang: Node = (load("res://game/chiang_rai.tscn") as PackedScene).instantiate()
	root.add_child(chiang)
	await process_frame
	var chiang_field: SMPointer = chiang.get("field") as SMPointer
	check(_team_ids(chiang_field).size() == 6, "chiang rai spawns six teams")
	check(not chiang_field.teams.are_enemies(0, 2) and not chiang_field.teams.are_enemies(0, 4) and not chiang_field.teams.are_enemies(1, 5) and chiang_field.teams.are_enemies(0, 5), "chiang rai is two alliances of three")
	var chiang_tran: Label3D = chiang.find_child("PersonalityTran", true, false) as Label3D
	check(chiang_tran != null and chiang_tran.text == "Tran", "tran is on the chiang rai field")
	_wipe(chiang_field.units_of(1))
	_wipe(chiang_field.units_of(3))
	_wipe(chiang_field.units_of(5))
	var chiang_raider: SMRaider = chiang.get("raider") as SMRaider
	_raze_yard(chiang_raider.yard)
	await process_frame
	var chiang_end: SMOutcome = chiang.get("outcome") as SMOutcome
	check(chiang_end.over and chiang_end.victory, "wiping one chiang rai alliance ends the match")
	chiang.free()
	await process_frame

func _team_ids(field: SMPointer) -> Array[int]:
	var ids: Array[int] = []
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and not ids.has(u.team):
			ids.append(u.team)
	return ids

func test_sm_fx() -> void:
	var ice: Shader = load("res://game/shaders/cryo_freeze_overlay.gdshader") as Shader
	var aegis: Shader = load("res://game/shaders/aegis_dome_shield.gdshader") as Shader
	var slag: Shader = load("res://game/shaders/slag_corrosion_pool.gdshader") as Shader
	check(ice != null and aegis != null and slag != null, "the cryo, aegis, and slag shaders load")
	SMCampaign.selected = "plain_of_jars"
	var scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.find_child("BeamPainter", true, false) is MeshInstance3D and scene.find_child("BeamLeech", true, false) is MeshInstance3D and scene.find_child("BeamFiber", true, false) is MeshInstance3D and scene.find_child("BeamPrism", true, false) is MeshInstance3D, "painter, leech, fiber, and prism beams are meshes")
	check(scene.find_child("AegisDome", true, false) is MeshInstance3D and scene.find_child("JammerDome", true, false) is MeshInstance3D and scene.find_child("RubyCone", true, false) is MeshInstance3D and scene.find_child("SlagPool", true, false) is MeshInstance3D, "the dome, jammer, ruby cone, and slag pool are on the field")
	var field: SMPointer = scene.get("field") as SMPointer
	var foe: RTSUnit = field.units_of(1)[0]
	field.apply_status(foe, "frozen", 5.0)
	var body: MeshInstance3D = foe.get_node_or_null("Body") as MeshInstance3D
	var ice_on: bool = false
	if body != null:
		var mat: ShaderMaterial = body.material_override as ShaderMaterial
		if mat == null:
			mat = body.material_overlay as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path.ends_with("cryo_freeze_overlay.gdshader"):
			ice_on = true
		if not ice_on:
			var coat: MeshInstance3D = body.find_child("IceCoat", true, false) as MeshInstance3D
			var coat_mat: ShaderMaterial = null if coat == null else coat.material_override as ShaderMaterial
			ice_on = coat_mat != null and coat_mat.shader != null and coat_mat.shader.resource_path.ends_with("cryo_freeze_overlay.gdshader")
	check(bool(foe.get_meta("frozen")) and ice_on, "freezing a unit on the cryo mission shows the ice shader")
	var fx: Script = preload("res://game/fx_view.gd")
	var painter: MeshInstance3D = scene.find_child("BeamPainter", true, false) as MeshInstance3D
	var dome: MeshInstance3D = scene.find_child("AegisDome", true, false) as MeshInstance3D
	var cone: MeshInstance3D = scene.find_child("RubyCone", true, false) as MeshInstance3D
	var pool: MeshInstance3D = scene.find_child("SlagPool", true, false) as MeshInstance3D
	var jam: MeshInstance3D = scene.find_child("JammerDome", true, false) as MeshInstance3D
	var caster: RTSUnit = field.units_of(0)[0]
	caster.set_meta("beam_kind", "painter")
	caster.set_meta("aegis", true)
	caster.set_meta("slagged", true)
	var night_goods: SMCommodityNet = SMCommodityNet.new()
	night_goods.add_node(&"ruby", SMCommodityNet.KIND_RUBY, Vector3(3.0, 0.0, 0.0), 10, false)
	night_goods.set_night_shift(&"ruby", true)
	var jammer: SMEwField = SMEwField.new()
	jammer.center = Vector3(4.0, 0.0, 2.0)
	jammer.active = true
	fx.drive(scene as Node3D, field, night_goods, jammer)
	check(painter != null and painter.visible and dome != null and dome.visible and cone != null and cone.visible and pool != null and pool.visible and jam != null and jam.visible, "status drives the beams, domes, night cone, and slag pool")
	var ribbon: ShaderMaterial = painter.material_override as ShaderMaterial
	check(painter.mesh is ArrayMesh and ribbon != null and ribbon.shader != null and str(ribbon.shader.resource_path).ends_with("laser_ribbon.gdshader"), "the painter beam is a laser ribbon")
	scene.call("finish_objective")
	check(bool(foe.get_meta("frozen")), "completing the cryo mission freezes a unit")
	scene.free()
	SMCampaign.selected = "tachileik"
	await process_frame

func _set_piece_played(scene: Node, piece: Node, id: String) -> bool:
	if not bool(piece.get("intro_done")):
		return false
	var order: PackedStringArray = piece.get("beat_ids")
	var got: PackedStringArray = piece.get("fired")
	if order.size() < 2 or got.size() != order.size():
		return false
	var shared: int = 0
	for i: int in order.size():
		if str(got[i]) != str(order[i]):
			return false
		var beat: String = str(order[i])
		if beat == "ambush" or beat == "bridge" or beat == "relief" or beat == "weather":
			shared += 1
	if shared > 2:
		return false
	var weather: Label = scene.find_child("HudWeather", true, false) as Label
	var sky: String = weather.text if weather != null else ""
	if id == "black_haze" or id == "fog_over_pakbeng":
		if sky != "Strait Haze":
			return false
	elif order.has("weather"):
		if sky != "Monsoon":
			return false
	elif sky == "Monsoon":
		return false
	return _set_piece_prop(scene, id)

func _set_piece_prop(scene: Node, id: String) -> bool:
	var field: SMPointer = scene.get("field") as SMPointer
	if id == "kokang":
		return _duty_units(field, "spectacle").size() >= 2 and _duty_units(field, "night").size() == 1
	if id == "tachileik":
		return _duty_units(field, "escort").size() == 1 and _duty_units(field, "ambush").size() >= 1
	if id == "shwe_kokko":
		var hack: Label = scene.find_child("HackTimer", true, false) as Label
		return hack != null and hack.text.begins_with("Hack:")
	if id == "operation_1027":
		return _duty_units(field, "spectacle").size() >= 2 and _duty_units(field, "relief").size() == 2
	if id == "andaman":
		return scene.get_node_or_null("SetMines") != null
	if id == "ghosts_of_patani":
		return _duty_units(field, "ambush").size() >= 2 and _duty_units(field, "betray").size() == 1
	if id == "kilometer_watch":
		return scene.get_node_or_null("SetPing") != null and _duty_units(field, "relief").size() == 2 and _duty_units(field, "betray").size() == 1
	if id == "black_haze":
		return _duty_units(field, "spectacle").size() >= 2
	if id == "archipelago_rising":
		return scene.get_node_or_null("SetWharf") != null and _duty_units(field, "packer").size() == 1
	if id == "wrath_of_the_garuda":
		return scene.get_node_or_null("SetNapalm") != null and _duty_units(field, "relief").size() == 2
	if id == "fog_over_pakbeng":
		return scene.get_node_or_null("SetRadar") != null and _duty_units(field, "betray").size() == 1
	if id == "keng_tung":
		return _duty_units(field, "spray").size() == 1
	if id == "plain_of_jars":
		return scene.get_node_or_null("SetFrost") != null
	if id == "tonle_sap":
		return _duty_units(field, "spectacle").size() >= 2
	if id == "shattered_monsoon":
		var count: Label = scene.find_child("CountTimer", true, false) as Label
		return count != null and count.text.begins_with("Count:") and _duty_units(field, "spectacle").size() >= 2
	return false

func _remove_tree(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name: String in dir.get_directories():
		_remove_tree(path.path_join(name))
	var parent: DirAccess = DirAccess.open(path.get_base_dir())
	if parent != null:
		parent.remove(path.get_file())

func test_set_piece() -> void:
	var orders: PackedStringArray = PackedStringArray()
	for id: String in ["kokang", "tachileik", "shwe_kokko", "operation_1027", "andaman", "ghosts_of_patani", "kilometer_watch", "black_haze", "archipelago_rising", "wrath_of_the_garuda", "fog_over_pakbeng", "keng_tung", "plain_of_jars", "tonle_sap", "shattered_monsoon"]:
		SMCampaign.selected = id
		var path: String = "res://game/mission_kokang.tscn" if id == "kokang" else "res://game/campaign_mission.tscn"
		var scene: Node = (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await process_frame
		var piece: Node = scene.get_node_or_null("SetPiece")
		var subtitle: Label = scene.find_child("SetSubtitle", true, false) as Label
		var portrait: TextureRect = scene.find_child("SetPortrait", true, false) as TextureRect
		var speaker: Label = scene.find_child("SetSpeaker", true, false) as Label
		var bonus: Label = scene.find_child("SetBonus", true, false) as Label
		var bonus_line: bool = bonus != null and ((bool(piece.get("has_bonus")) and bonus.visible and bonus.text.begins_with("Bonus:")) or (not bool(piece.get("has_bonus")) and not bonus.visible))
		check(piece != null and subtitle != null and portrait != null and speaker != null and bonus_line and str(piece.get("line_text")) != "" and subtitle.text == str(piece.get("line_text")), "%s opens with a portrait and a line" % id)
		var cam: RTSCamera = scene.get_node("Camera") as RTSCamera
		piece.call("drive", 1.0)
		var wide: float = float(piece.get("wide_distance"))
		var home: float = float(piece.get("home_distance"))
		check(cam.distance < wide - 2.0 and cam.distance > home and wide > home + 10.0, "%s pans the camera in" % id)
		piece.call("drive", 24.0)
		check(_set_piece_played(scene, piece, id), "%s plays its own beats" % id)
		orders.append(",".join(piece.get("fired")))
		var story: SMStory = scene.get("story") as SMStory
		var field: SMPointer = scene.get("field") as SMPointer
		check(not bool(piece.get("bonus_done")) and not story.done, "%s leaves the bonus optional" % id)
		if bool(piece.get("has_bonus")):
			var walker: RTSUnit = field.units_of(0)[0]
			walker.global_position = piece.get("bonus_at") as Vector3
			piece.call("drive", 0.2)
		var before: float = cam.distance
		story.done = true
		piece.call("drive", 3.2)
		var bonus_end: bool = bool(piece.get("bonus_done")) == bool(piece.get("has_bonus"))
		check(bonus_end and bool(piece.get("outro_started")) and bool(piece.get("outro_done")) and cam.distance > before + 8.0, "%s pulls the camera out" % id)
		scene.free()
		await process_frame
	var distinct: bool = orders.size() == 15
	for i: int in orders.size():
		for j: int in i:
			if orders[i] == orders[j]:
				distinct = false
	check(distinct, "each mission keeps its own beat order")
	SMCampaign.selected = "mae_sai"
	var plain: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(plain)
	await process_frame
	check(plain.get_node_or_null("SetPiece") == null, "drill missions keep the short briefing")
	var audio_root: String = ProjectSettings.globalize_path("res://").path_join("build/web/audio")
	var dialogue_dir: String = audio_root.path_join("dialogue")
	var stash: String = audio_root.path_join("_dialogue_hold")
	if DirAccess.dir_exists_absolute(stash) and not DirAccess.dir_exists_absolute(dialogue_dir):
		DirAccess.rename_absolute(stash, dialogue_dir)
	if DirAccess.dir_exists_absolute(stash):
		_remove_tree(stash)
	var held: bool = false
	if DirAccess.dir_exists_absolute(dialogue_dir):
		held = DirAccess.rename_absolute(dialogue_dir, stash) == OK
	Settings.set_voice("english")
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	var quiet: bool = not clips.call("dialogue", plain, "tachileik", "open")
	var sting: String = audio_root.path_join("music/victory_sting.ogg")
	var wrote: bool = false
	if not DirAccess.dir_exists_absolute(dialogue_dir) and FileAccess.file_exists(sting):
		DirAccess.make_dir_recursive_absolute(dialogue_dir.path_join("en/tachileik"))
		DirAccess.make_dir_recursive_absolute(dialogue_dir.path_join("my/tachileik"))
		DirAccess.make_dir_recursive_absolute(dialogue_dir.path_join("th/andaman"))
		var copied: bool = DirAccess.copy_absolute(sting, dialogue_dir.path_join("en/tachileik/open.ogg")) == OK
		copied = copied and DirAccess.copy_absolute(sting, dialogue_dir.path_join("en/tachileik/escort.ogg")) == OK
		copied = copied and DirAccess.copy_absolute(sting, dialogue_dir.path_join("my/tachileik/open.ogg")) == OK
		copied = copied and DirAccess.copy_absolute(sting, dialogue_dir.path_join("th/andaman/open.ogg")) == OK
		var manifest: Dictionary = {
			"clips": {
				"en": {
					"tachileik": {
						"open": {"file": "dialogue/en/tachileik/open.ogg", "accent_fail": true},
						"escort": {"file": "dialogue/en/tachileik/escort.ogg", "status": "removed"},
					},
					"andaman": {
						"open": {"file": "dialogue/en/andaman/open.ogg", "accent_fail": true},
					},
				},
				"my": {
					"tachileik": {
						"open": {"file": "dialogue/my/tachileik/open.ogg", "accent_fail": false},
					},
				},
				"ms": {
					"tachileik": {
						"open": {"file": "dialogue/ms/tachileik/open.ogg", "accent_fail": true},
					},
				},
				"th": {
					"andaman": {
						"open": {"file": "dialogue/th/andaman/open.ogg", "accent_fail": false},
					},
				},
			},
		}
		var handle: FileAccess = FileAccess.open(dialogue_dir.path_join("manifest.json"), FileAccess.WRITE)
		if handle != null:
			handle.store_string(JSON.stringify(manifest))
			handle.close()
			wrote = copied
	Settings.set_voice("malay")
	var other_tongue: bool = not clips.call("dialogue", plain, "tachileik", "open")
	Settings.set_voice("english")
	var removed: bool = not clips.call("dialogue", plain, "tachileik", "escort")
	var heard: bool = not clips.call("dialogue", plain, "tachileik", "open")
	Settings.set_voice("burmese")
	var mine: bool = clips.call("dialogue", plain, "tachileik", "open")
	var player: Node = plain.get_node_or_null("Dialogue")
	var played_my: bool = mine and player != null and str(player.get_meta("clip", "")) == "dialogue/my/tachileik/open.ogg"
	Settings.set_voice("thai")
	var andaman: bool = clips.call("dialogue", plain, "andaman", "open")
	var played_th: bool = player != null and str(player.get_meta("clip", "")) == "dialogue/th/andaman/open.ogg"
	Settings.set_voice("english")
	var silent: bool = not clips.call("dialogue", plain, "kokang", "open") and not clips.call("dialogue", plain, "andaman", "open")
	if wrote:
		_remove_tree(dialogue_dir)
	if held and DirAccess.dir_exists_absolute(stash) and not DirAccess.dir_exists_absolute(dialogue_dir):
		DirAccess.rename_absolute(stash, dialogue_dir)
	Settings.set_voice("english")
	check(quiet and wrote and other_tongue and removed and heard and played_my and andaman and played_th and silent and player != null, "dialogue plays only the chosen language, skips a failed take, and stays a subtitle otherwise")
	plain.free()
	await process_frame
	SMCampaign.selected = "tachileik"

func test_signature_rules() -> void:
	var tachileik_lost: Node = _signature_scene("tachileik")
	var tachileik_story: SMStory = tachileik_lost.get("story") as SMStory
	var wagon_lost: RTSUnit = tachileik_story.wagon()
	wagon_lost.take_damage(wagon_lost.hp + 1.0)
	tachileik_story.tick(0.2)
	check(tachileik_story.lost and not tachileik_story.done and tachileik_story.loss == "the caravan is lost", "tachileik fails when the jade wagon dies")
	tachileik_lost.free()
	await process_frame
	var tachileik_won: Node = _signature_scene("tachileik")
	var tachileik_piece: Node = tachileik_won.get_node("SetPiece")
	tachileik_piece.call("drive", 6.0)
	var tachileik_field: SMPointer = tachileik_won.get("field") as SMPointer
	var tachileik_win: SMStory = tachileik_won.get("story") as SMStory
	var wagon_won: RTSUnit = tachileik_win.wagon()
	var escorts: Array[RTSUnit] = _duty_units(tachileik_field, "escort")
	_meet_story(tachileik_won, "tachileik")
	await process_frame
	check(escorts.size() == 1 and escorts[0] == wagon_won and wagon_won.is_alive() and tachileik_win.done and not tachileik_win.lost and tachileik_win.has_caravan(), "tachileik wins when the real wagon reaches the bazaar")
	tachileik_won.free()
	await process_frame
	var shwe: Node = _signature_scene("shwe_kokko")
	var shwe_story: SMStory = shwe.get("story") as SMStory
	var shwe_field: SMPointer = shwe.get("field") as SMPointer
	_kill_duty(shwe_field, "clear")
	_park(shwe_field, "", shwe_story.pad)
	shwe_story.tick(8.0)
	var holder: RTSUnit = _marcher(shwe_field, "")
	holder.global_position = Vector3(-14.0, 0.0, -8.0)
	shwe_story.tick(0.5)
	check(is_equal_approx(shwe_story.hack_left, 20.0) and not shwe_story.done and not shwe_story.lost, "shwe kokko resets the hack when the block is abandoned")
	_park(shwe_field, "", shwe_story.pad)
	shwe_story.tick(shwe_story.hack_left)
	check(shwe_story.done and not shwe_story.lost and shwe_story.hack_left <= 0.0, "shwe kokko wins when the hack is held through")
	shwe.free()
	await process_frame
	var mined: Node = _signature_scene("andaman")
	var mined_story: SMStory = mined.get("story") as SMStory
	var mined_field: SMPointer = mined.get("field") as SMPointer
	var mined_boat: RTSUnit = _kind_unit(mined_field, "channel_skiff")
	var mined_hp: float = mined_boat.hp
	mined_boat.global_position = Vector3(0.4, 0.0, 0.0)
	mined_story.tick(1.0)
	check(mined_boat.hp < mined_hp - 20.0 and mined_boat.is_alive() and not mined_story.done, "andaman mines damage a ship that sits on the line")
	mined.free()
	await process_frame
	var landed: Node = _signature_scene("andaman")
	var landed_story: SMStory = landed.get("story") as SMStory
	var landed_field: SMPointer = landed.get("field") as SMPointer
	var landed_boat: RTSUnit = _kind_unit(landed_field, "channel_skiff")
	_kill_duty(landed_field, "clear")
	landed_boat.global_position = landed_story.far_shore
	var shore_hp: float = landed_boat.hp
	landed_story.tick(1.0)
	check(is_equal_approx(landed_boat.hp, shore_hp) and landed_story.done and not landed_story.lost, "andaman wins when a ship reaches the far shore off the mines")
	landed.free()
	await process_frame
	var sprayed: Node = _signature_scene("keng_tung")
	var sprayed_piece: Node = sprayed.get_node("SetPiece")
	sprayed_piece.call("drive", 13.0)
	var sprayed_story: SMStory = sprayed.get("story") as SMStory
	var sprayed_field: SMPointer = sprayed.get("field") as SMPointer
	var sprayer: RTSUnit = _duty_units(sprayed_field, "spray")[0]
	var blighted: RTSUnit = _marcher(sprayed_field, "")
	sprayer.global_position = Vector3(6.0, 0.0, 2.0)
	blighted.global_position = Vector3(6.0, 0.0, 1.0)
	var blight_before: float = blighted.damage_mult
	sprayed_story.tick(0.1)
	check(sprayed_story.spray_landed and sprayed_story.bonus_failed and bool(blighted.get_meta("defoliated", false)) and blighted.damage_mult < blight_before and not sprayed_story.lost and not sprayed_story.done, "keng tung defoliates the area and fails the bonus when the sprayer lands")
	sprayed.free()
	await process_frame
	var intercepted: Node = _signature_scene("keng_tung")
	var intercepted_piece: Node = intercepted.get_node("SetPiece")
	intercepted_piece.call("drive", 13.0)
	var intercepted_story: SMStory = intercepted.get("story") as SMStory
	var intercepted_field: SMPointer = intercepted.get("field") as SMPointer
	_kill_duty(intercepted_field, "spray")
	intercepted_story.tick(0.2)
	_meet_story(intercepted, "keng_tung")
	check(not intercepted_story.bonus_failed and not intercepted_story.spray_landed and intercepted_story.done and not intercepted_story.lost, "keng tung wins when the sprayer is intercepted and the column falls")
	intercepted.free()
	await process_frame
	var sunk: Node = _signature_scene("tonle_sap")
	var sunk_story: SMStory = sunk.get("story") as SMStory
	var sunk_field: SMPointer = sunk.get("field") as SMPointer
	sunk_story.tick(1.0)
	var ferry_lost: RTSUnit = _duty_units(sunk_field, "ferry")[0]
	ferry_lost.take_damage(ferry_lost.hp + 1.0)
	sunk_story.tick(sunk_story.hold_left)
	check(sunk_story.lost and not sunk_story.done and not sunk_story.ferry_across and sunk_story.loss == "the defended target is lost", "tonle sap fails when the ferry dies on the crossing")
	sunk.free()
	await process_frame
	var crossed: Node = _signature_scene("tonle_sap")
	var crossed_story: SMStory = crossed.get("story") as SMStory
	var crossed_field: SMPointer = crossed.get("field") as SMPointer
	crossed_story.tick(crossed_story.hold_left)
	var ferry_won: RTSUnit = _duty_units(crossed_field, "ferry")[0]
	check(crossed_story.done and not crossed_story.lost and crossed_story.ferry_across and ferry_won.is_alive(), "tonle sap wins when the ferry survives the crossing")
	crossed.free()
	await process_frame
	var expired: Node = _signature_scene("shattered_monsoon")
	var expired_story: SMStory = expired.get("story") as SMStory
	expired_story.tick(expired_story.count_left)
	check(expired_story.lost and not expired_story.done and expired_story.loss == "the count hit zero", "shattered monsoon fails when the count hits zero")
	expired.free()
	await process_frame
	var dropped: Node = _signature_scene("shattered_monsoon")
	var dropped_story: SMStory = dropped.get("story") as SMStory
	var dropped_field: SMPointer = dropped.get("field") as SMPointer
	var count_before: float = dropped_story.count_left
	_kill_duty(dropped_field, "super")
	dropped_story.tick(0.2)
	check(dropped_story.done and not dropped_story.lost and dropped_story.count_left > 10.0 and dropped_story.count_left <= count_before, "shattered monsoon wins when both weapons fall before zero")
	dropped.free()
	await process_frame
	SMCampaign.selected = "tachileik"

func _signature_scene(id: String) -> Node:
	SMCampaign.selected = id
	var scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	return scene

func test_lan() -> void:
	Lan.close()
	Lan.port = 47931
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var tab: Button = boot.find_child("TabMultiplayer", true, false) as Button
	tab.pressed.emit()
	var host: Button = boot.find_child("HostLan", true, false) as Button
	var join: Button = boot.find_child("JoinLan", true, false) as Button
	var addr: LineEdit = boot.find_child("LanAddress", true, false) as LineEdit
	var note: Label = boot.find_child("MultiplayerNote", true, false) as Label
	var found: ItemList = boot.find_child("LanFound", true, false) as ItemList
	check(host != null and host.is_visible_in_tree() and join != null and join.is_visible_in_tree() and addr != null and addr.is_visible_in_tree() and found != null and found.is_visible_in_tree() and note != null and note.is_visible_in_tree() and not note.text.contains("not in this build"), "the multiplayer tab hosts and joins a LAN game")
	check(Lan.show_controls() and Lan.lan_note(true) == "Copy the offer into the other browser, then paste its answer back. No account.", "the web build tells you to copy an offer and paste the answer")
	var offer: Button = boot.find_child("PasteOffer", true, false) as Button
	var paste_join: Button = boot.find_child("PasteJoin", true, false) as Button
	var paste_seal: Button = boot.find_child("PasteSeal", true, false) as Button
	check(offer != null and paste_join != null and paste_seal != null and not offer.is_visible_in_tree(), "browser paste controls stay off the desktop menu")
	var paste_copy: Button = boot.find_child("PasteCopy", true, false) as Button
	check(offer.disabled and paste_copy != null and paste_copy.disabled, "copy stays disabled until the offer is ready")
	var paste_status: Label = boot.find_child("PasteStatus", true, false) as Label
	var fake: WebPaste = WebPaste.new()
	fake.text = "ready-blob"
	fake.phase = "answer"
	Lan.seat()._web = fake
	Lan.role = "client"
	boot.call("_paint_paste")
	check(paste_status != null and paste_status.text.contains("Answer is ready to copy.") and not offer.disabled, "the guest is told the answer is ready to copy")
	Lan.role = "host"
	boot.call("_paint_paste")
	check(paste_status != null and paste_status.text.contains("Offer is ready to copy."), "the host is told the offer is ready to copy")
	Lan.close()
	host.pressed.emit()
	var status: Label = boot.find_child("LanStatus", true, false) as Label
	check(status != null and status.text.contains("Waiting") and status.text.contains("47931"), "hosting opens a LAN port")
	var ready: Button = boot.find_child("LanReady", true, false) as Button
	var chat_line: LineEdit = boot.find_child("LanChatLine", true, false) as LineEdit
	var count: Label = boot.find_child("LanCount", true, false) as Label
	check(ready != null and chat_line != null and count != null, "the lobby has faction, ready, and chat controls")
	Lan.close()
	Lan.port = 7777
	boot.free()
	await process_frame
	check(Lan.probe(47921), "a LAN host and guest exchange a hello")
	Lan.forget_hosts()
	Lan.note_beacon("10.0.0.8", JSON.stringify({"k": "here", "port": 7777, "map": "res://game/burma_road.tscn"}).to_utf8_buffer())
	var listed: PackedStringArray = Lan.hosts()
	check(listed.size() == 1 and listed[0].begins_with("10.0.0.8:7777") and listed[0].contains("burma road") and Lan.host_address(0) == "10.0.0.8", "a LAN beacon lists the host without typing an address")
	Lan.forget_hosts()
	check(Lan.loopback_beacon(47941) and Lan.hosts().size() == 1 and Lan.host_address(0) == "127.0.0.1", "a discovery packet reaches a listener")
	var seat: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var seated: Error = seat.create_server(47923)
	check(seated == OK and Lan.attach_peer(seat, true) == OK and Lan.role == "host" and Lan.peer == seat, "a WebRTC peer can take the same session slot later")
	Lan.close()
	var packed: String = WebPaste.pack("offer", "v=0\r\nstun", [["0", 0, "candidate:1 1 udp 1 1.2.3.4 9 typ host"]])
	var unpacked: Dictionary = WebPaste.unpack(packed)
	var ice: Array = unpacked.get("c", [])
	check(WebPaste.STUN_URL == "stun:stun.l.google.com:19302" and str(unpacked.get("t", "")) == "offer" and str(unpacked.get("s", "")) == "v=0\r\nstun" and ice.size() == 1 and str(ice[0][2]).begins_with("candidate:"), "a WebRTC paste round-trips the offer and the STUN server")
	check(WebPaste.unpack("").is_empty() and WebPaste.unpack("nope").is_empty() and WebPaste.unpack("ASEAN2031.!!!!").is_empty() and Lan.paste_join("nope") == ERR_INVALID_DATA, "a broken paste is ignored")
	check(not WebPaste.ready() and Lan.paste_host() == ERR_UNAVAILABLE and Lan.paste_text() == "" and Lan.role == "" and Lan.paste_note() == WebPaste.DESKTOP_NOTE, "desktop without the WebRTC addon refuses to mint an offer")
	check(Lan.paste_join(packed) == ERR_UNAVAILABLE and Lan.paste_seal(packed) == ERR_UNCONFIGURED, "joining waits for a browser WebRTC stack, and an answer needs an offer first")
	Lan.close()
	Lan.forget_hosts()
	Lan.port = 7777

func test_lan_match() -> void:
	Lan.close()
	Lan.port = 47951
	Lan.silence_pause = 2.0
	Lan.drop_after = 15.0
	check(Lan.open_host() == OK, "the match host opens a port")
	var guest: Seat = Seat.new()
	guest.port = 47951
	guest.faction = "gtfc"
	check(guest.open_client("127.0.0.1") == OK, "the guest dials the host")
	var joined: bool = false
	for _i: int in 30:
		Lan.pump()
		guest.pump()
		var raw: String = Lan.take()
		while raw != "":
			Lan.ingest(raw)
			raw = Lan.take()
		var back: String = guest.take()
		while back != "":
			guest.ingest(back)
			back = guest.take()
		if guest.role == "client" and Lan.seat().guest_joined:
			joined = true
			break
		OS.delay_msec(20)
	check(joined, "the guest hello reaches the host")
	guest.say("on the river")
	guest.set_ready(true)
	Lan.pump()
	guest.pump()
	var wish: String = Lan.take()
	while wish != "":
		Lan.ingest(wish)
		wish = Lan.take()
	check(Lan.seat().chat_lines.size() >= 1 and Lan.seat().chat_lines[0].contains("on the river") and Lan.seat().guest_ready, "chat and ready-up cross the lobby")
	Lan.seat().pick_map("res://game/phillips_channel.tscn")
	Lan.seat().set_ready(true)
	var starting: String = ""
	for _step: int in 8:
		starting = Lan.seat().tick_lobby(0.5)
		guest.pump()
		var heard: String = guest.take()
		while heard != "":
			guest.ingest(heard)
			heard = guest.take()
		if starting == "start":
			break
	check(starting == "start" and guest.started and guest.map_path.ends_with("phillips_channel.tscn"), "ready players count down into the map")
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var raider: SMRaider = scene.get("raider") as SMRaider
	var seat: Seat = Lan.seat()
	check(raider.human and seat.guest_side != null and not raider.yard.finished.has(&"enemy_yard"), "the guest replaces the bot")
	var pair: Vector2i = preload("res://addons/rts_advanced/sm_power.gd").tally(seat.guest_side.yard)
	check(pair.x >= pair.y and pair.x > 0 and seat.guest_roster.economy.credits(SMPointer.ENEMY) > 1000, "the guest has a base, power, and credits")
	var player: RTSUnit = field.units_of(SMPointer.PLAYER)[0]
	var before: Vector3 = player.global_position
	var blocked: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "move", "ids": [player.get_instance_id()], "x": before.x + 6.0, "z": before.z}))
	check(blocked == 0 and player.path.is_empty() and seat.last_note == "rejected", "a guest order cannot move the host company")
	var owned: RTSUnit = field.units_of(SMPointer.ENEMY)[0]
	var moved: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "move", "ids": [owned.get_instance_id()], "x": owned.global_position.x + 8.0, "z": owned.global_position.z}))
	check(moved == 1 and not owned.path.is_empty() and player.path.is_empty(), "the guest move order moves only the guest company")
	var struck: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "attack", "ids": [owned.get_instance_id()], "tid": player.get_instance_id()}))
	var friendly: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "attack", "ids": [owned.get_instance_id()], "tid": owned.get_instance_id()}))
	check(struck == 1 and owned.attack_target == player and friendly == 0, "the guest can attack the host and not itself")
	var built: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "build", "id": "war_factory"}))
	check(built == 1 and seat.guest_side.yard.finished.has(&"war_factory"), "the host builds the guest's next structure")
	var queued: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "train", "id": "militia"}))
	seat.tick_guest(4.0)
	var trained: int = 0
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if u.unit_type == &"militia":
			trained += 1
	check(queued == 1 and trained == 1, "the guest production queue trains a unit")
	var militia: RTSUnit = null
	for u_m: RTSUnit in field.units_of(SMPointer.ENEMY):
		if u_m.unit_type == &"militia":
			militia = u_m
	var fired: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "ability", "ids": [militia.get_instance_id()], "x": militia.global_position.x, "z": militia.global_position.z}))
	check(fired == 1 and bool(militia.get_meta("toggled", false)), "the guest ability is validated on the guest unit")
	var bank: int = seat.guest_roster.economy.credits(SMPointer.ENEMY)
	var cast: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "protocol", "id": "cash_bounty"}))
	var again: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "protocol", "id": "cash_bounty"}))
	var sim: SMMatch = scene.get("sim") as SMMatch
	var host_book: SMProtocols = sim.protocols
	check(cast == 1 and again == 0 and seat.guest_roster.economy.credits(SMPointer.ENEMY) == bank + 250 and int(host_book.cast_count.get(&"cash_bounty", 0)) == 0, "the guest protocol spends the guest book")
	var hp_before: float = float(seat.guest_side.yard.structure_hp.get(&"barracks", 0.0))
	seat.guest_side.yard.structure_hp[&"barracks"] = 40.0
	var repairing: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "repair", "id": "barracks"}))
	seat.guest_side.yard.tick_repair(1.0)
	check(repairing == 1 and float(seat.guest_side.yard.structure_hp[&"barracks"]) > 40.0, "the guest repair spends the guest yard")
	var sold: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "sell", "id": "slag_refinery"}))
	check(sold == 1 and not seat.guest_side.yard.finished.has(&"slag_refinery"), "the guest can sell a guest structure")
	seat.guest_side.yard.style = SMBuildYard.Style.INTERNAL
	seat.guest_side.yard.ready.append(&"lan_pad")
	var outside: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "place", "id": "lan_pad", "x": 400.0, "z": 400.0}))
	var placed: int = seat.apply_line(scene, JSON.stringify({"k": "cmd", "op": "place", "id": "lan_pad", "x": seat.guest_side.yard.center.x, "z": seat.guest_side.yard.center.z}))
	check(outside == 0 and placed == 1 and seat.guest_side.yard.finished.has(&"lan_pad"), "placement stays inside the guest base")
	var home: Vector3 = owned.global_position
	for n: int in 55:
		field.spawn(SMPointer.ENEMY, home + Vector3(0.2 * float(n % 10), 0.0, 0.2 * float(n / 10)), &"raider")
	var full: Dictionary = seat.state_of(scene, true)
	var listed: Array = full.get("u", [])
	var seen_host: bool = false
	for row: Variant in listed:
		var bits: Array = row
		if int(bits[4]) == SMPointer.PLAYER:
			seen_host = true
	check(int(full.get("n", 0)) > 48 and listed.size() > 48 and not seen_host and str(full.get("fog", "")).length() == 1904 and full.has("credits") and full.has("q") and (full.get("b", []) as Array).size() > 0, "the snapshot carries fog, economy, structures, and more than 48 units")
	var delta: Dictionary = seat.state_of(scene, false)
	var changed: Array = delta.get("u", [])
	check(int(delta.get("n", 0)) > 48 and changed.size() < int(delta.get("n", 0)) and not delta.has("fog"), "later snapshots send only what changed")
	guest.close()
	Lan.silence_pause = 0.05
	Lan.drop_after = 0.2
	seat.watch(0.1)
	check(seat.paused and seat.winner == "", "a dropped guest pauses the match")
	seat.watch(0.3)
	await process_frame
	var outcome: SMOutcome = scene.get("outcome") as SMOutcome
	check(seat.winner == "host" and outcome.victory, "the host wins after the disconnect timeout")
	scene.free()
	await process_frame
	Lan.close()
	var other_host: Seat = Seat.new()
	var other_guest: Seat = Seat.new()
	other_host.port = 47961
	other_guest.port = 47961
	other_host.silence_pause = 0.05
	other_host.drop_after = 0.2
	other_guest.silence_pause = 0.05
	other_guest.drop_after = 0.2
	other_host.open_host()
	other_guest.open_client("127.0.0.1")
	for _j: int in 30:
		other_host.pump()
		other_guest.pump()
		if other_guest.peer != null and other_guest.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
		OS.delay_msec(20)
	other_guest.started = true
	other_host.close()
	other_guest.watch(0.4)
	check(other_guest.paused and other_guest.winner == "guest", "a dropped host gives the guest the win")
	other_guest.close()
	Lan.port = 47971
	var host_seat: Seat = Seat.new()
	var guest_seat: Seat = Seat.new()
	host_seat.port = 47971
	guest_seat.port = 47971
	host_seat.faction = "gtfc"
	guest_seat.faction = "nmrf"
	var lobby_open: bool = host_seat.open_host() == OK and guest_seat.open_client("127.0.0.1") == OK
	var saw_room: bool = false
	if lobby_open:
		for _k: int in 40:
			host_seat.pump()
			guest_seat.pump()
			var host_raw: String = host_seat.take()
			while host_raw != "":
				host_seat.ingest(host_raw)
				host_raw = host_seat.take()
			var guest_raw: String = guest_seat.take()
			while guest_raw != "":
				if guest_seat.ingest(guest_raw) == "room":
					saw_room = true
				guest_raw = guest_seat.take()
			if saw_room and host_seat.guest_joined:
				break
			OS.delay_msec(20)
	check(lobby_open and saw_room and guest_seat.guest_joined and not guest_seat.lobby_line().contains("waiting"), "the guest lobby names the guest once the room arrives")
	if saw_room:
		guest_seat.pick_faction("mvd")
		host_seat.pump()
		guest_seat.pump()
		var wish_raw: String = host_seat.take()
		while wish_raw != "":
			host_seat.ingest(wish_raw)
			wish_raw = host_seat.take()
		var echo: String = guest_seat.take()
		while echo != "":
			guest_seat.ingest(echo)
			echo = guest_seat.take()
		guest_seat.set_ready(true)
		host_seat.pump()
		guest_seat.pump()
		var ready_raw: String = host_seat.take()
		while ready_raw != "":
			host_seat.ingest(ready_raw)
			ready_raw = host_seat.take()
	check(host_seat.guest_faction == "mvd" and host_seat.guest_ready and guest_seat.faction == "gtfc", "ready keeps the guest faction instead of resetting it to GTFC")
	host_seat.close()
	guest_seat.close()
	Lan.seat().faction = "gtfc"
	Lan.seat().guest_faction = "mvd"
	Lan.seat().map_path = "res://game/phillips_channel.tscn"
	var mirror: Node = (load("res://game/lan_mirror.tscn") as PackedScene).instantiate()
	root.add_child(mirror)
	await process_frame
	await process_frame
	var mirror_land: MeshInstance3D = mirror.get_node_or_null("TerrainLand") as MeshInstance3D
	var mirror_water: MeshInstance3D = mirror.get_node_or_null("TerrainWater") as MeshInstance3D
	var mirror_column: Control = mirror.find_child("CommandColumn", true, false) as Control
	var mirror_fac: Label = mirror.find_child("HudFaction", true, false) as Label
	var mirror_sample: Dictionary = {
		"k": "state", "full": true, "n": 2, "credits": 4980, "gen": 100, "use": 30, "q": [],
		"home": [48.0, -20.0],
		"u": [[101, 48.0, -20.0, 80, 1, "clearance_trooper"], [102, 42.0, -18.0, 120, 0, "militia"]],
		"b": [["command_hub", 48.0, -20.0, 200.0, 1]],
		"gone": [],
	}
	mirror.call("_apply", JSON.stringify(mirror_sample))
	await process_frame
	var mirror_field: SMPointer = mirror.get("field") as SMPointer
	var mirror_built: MeshInstance3D = mirror.get_node_or_null("Built_command_hub") as MeshInstance3D
	check(mirror_land != null and mirror_water != null and mirror_column != null and mirror_fac != null and mirror_fac.text == "MVD" and mirror_field != null and mirror_field.units.size() == 2 and mirror_built != null, "the multiplayer guest mirror renders terrain, units, structures, and the guest faction HUD")
	var mirror_hud: SMHud = mirror.get("hud") as SMHud
	if mirror_hud != null:
		mirror_hud.refresh()
	var mirror_cameo: TextureRect = mirror.find_child("CardCameo", true, false) as TextureRect
	var mirror_help: Control = mirror.find_child("HelpButton", true, false) as Control
	var mirror_shade: Control = mirror.find_child("ObjectiveShade", true, false) as Control
	var mirror_strip: Control = mirror.find_child("MatchStrip", true, false) as Control
	var strip_hit: Rect2 = mirror_shade.get_global_rect().intersection(mirror_strip.get_global_rect()) if mirror_shade != null and mirror_strip != null else Rect2()
	Lan.seat().ingest(JSON.stringify({"k": "bye"}))
	mirror.call("_process", 0.05)
	var mirror_status: Label = mirror.find_child("Status", true, false) as Label
	var mirror_reason: Label = mirror.find_child("MatchReason", true, false) as Label
	check(mirror_cameo != null and mirror_cameo.visible and mirror_cameo.texture != null and (mirror_help == null or not mirror_help.visible) and (strip_hit.size.x < 1.0 or strip_hit.size.y < 1.0) and mirror_status != null and mirror_status.text.contains("The other player left the match") and mirror_reason != null and mirror_reason.is_visible_in_tree() and mirror_reason.text == "The other player left the match.", "the guest HUD keeps the status line clear of the help tip, shows a unit cameo, and displays the departure reason on the Victory screen")
	mirror.free()
	await process_frame
	Lan.seat().paused = true
	Lan.seat().winner = "host"
	Lan.seat().started = true
	var post_mp: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(post_mp)
	await process_frame
	var post_exit: Node = post_mp.get_node_or_null("MatchExit")
	if post_exit != null:
		post_exit.call("_exit_tree")
	check(not Lan.holding() and Lan.seat().winner == "" and not Lan.started, "leaving a multiplayer match tears down the peer and lockstep state")
	var post_outcome: SMOutcome = post_mp.get("outcome") as SMOutcome
	if post_outcome != null:
		post_outcome.finish(true)
	await process_frame
	var post_boot: CanvasItem = post_mp.find_child("MissionBoot", true, false) as CanvasItem
	var post_end_btn: CanvasItem = post_mp.find_child("BootMenuButton", true, false) as CanvasItem
	check(post_end_btn != null and post_end_btn.is_visible_in_tree() and (post_boot == null or not post_boot.visible), "the victory screen hides the left-rail boot chip so buttons do not overlap")
	post_mp.free()
	await process_frame
	Lan.close()
	Lan.port = 7777
	Lan.silence_pause = 2.0
	Lan.drop_after = 15.0

func test_sm_story() -> void:
	check(SMCampaign.player_faction("kokang") == "gtfc" and SMCampaign.player_faction("ghosts_of_patani") == "nmrf" and SMCampaign.player_faction("plain_of_jars") == "mvd", "each act plays its own faction")
	check(SMCampaign.enemy_faction("andaman") == "nmrf" and SMCampaign.enemy_faction("tonle_sap") == "nmrf" and SMCampaign.enemy_faction("keng_tung") == "gtfc" and SMCampaign.enemy_faction("operation_1027") == "black_market", "enemies match the briefing")
	for id: String in SMCampaign.ids():
		SMCampaign.selected = id
		var path: String = "res://game/mission_kokang.tscn" if id == "kokang" else "res://game/campaign_mission.tscn"
		var scene: Node = (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await process_frame
		if id == "kokang":
			var scaffold: Button = scene.find_child("DebugScaffold", true, false) as Button
			var ruby: Button = scene.find_child("DebugRuby", true, false) as Button
			var rare: Button = scene.find_child("DebugRare", true, false) as Button
			check(scaffold != null and ruby != null and rare != null and not scaffold.visible and not ruby.visible and not rare.visible, "kokang keeps its debug shortcuts hidden")
		else:
			var goal: Button = scene.find_child("ObjectiveButton", true, false) as Button
			check(goal != null and not goal.visible, "%s keeps the objective button hidden" % id)
		var story_now: SMStory = scene.get("story") as SMStory
		var field_now: SMPointer = scene.get("field") as SMPointer
		check(story_now.reinforcements >= 2, "%s fields a second beat" % id)
		if id == "kokang":
			check(_duty_units(field_now, "recon").size() >= 2, "kokang posts Orlan recon over the pits")
			var still: TextureRect = scene.find_child("BriefingStill", true, false) as TextureRect
			check(still != null and still.texture != null and still.visible, "kokang shows the briefing still")
		if id == "ghosts_of_patani" or id == "fog_over_pakbeng":
			var mission_still: TextureRect = scene.find_child("BriefingStill", true, false) as TextureRect
			check(mission_still != null and mission_still.texture != null and mission_still.visible, "%s shows the briefing still" % id)
		if id == "tachileik":
			check(story_now.has_caravan(), "tachileik fields the jade caravan")
		if id == "shwe_kokko":
			check(story_now.server_blocks == 2, "shwe kokko has two server blocks")
		if id == "ghosts_of_patani":
			var lone: RTSUnit = field_now.units_of(1)[0]
			lone.take_damage(lone.hp + 1.0)
			story_now.tick(0.1)
			check(not story_now.done and not story_now.lost, "patani stays open while a ghost remains")
		if id == "black_haze" or id == "fog_over_pakbeng" or id == "tonle_sap":
			check(story_now.hold_need >= 24.0, "%s holds longer than a skirmish" % id)
		if id == "keng_tung":
			var tanks: Array[RTSUnit] = _duty_units(field_now, "column")
			var tank_hp: float = tanks[0].hp if not tanks.is_empty() else -1.0
			if not tanks.is_empty():
				tanks[0].take_damage(5000.0)
			check(not tanks.is_empty() and is_equal_approx(tanks[0].hp, tank_hp), "a keng tung tank ignores damage until it freezes")
		if id == "operation_1027" or id == "wrath_of_the_garuda" or id == "keng_tung" or id == "tonle_sap" or id == "shattered_monsoon":
			_cast_story(scene, id)
			story_now.tick(0.1)
			check(not story_now.done and not story_now.lost, "%s stays open after the protocol cast" % id)
		if id == "operation_1027":
			var hangars: Array[RTSUnit] = _duty_units(field_now, "hangar")
			var hangar_hp: float = hangars[0].hp if not hangars.is_empty() else -1.0
			if not hangars.is_empty():
				hangars[0].take_damage(5000.0)
			check(not hangars.is_empty() and is_equal_approx(hangars[0].hp, hangar_hp), "the 1027 hangars ignore damage while a tower stands")
		_meet_story(scene, id)
		await process_frame
		var story: SMStory = scene.get("story") as SMStory
		var status: Label = scene.find_child("Status", true, false) as Label
		check(story != null and story.done and not story.lost and story.ending == SMStory.ending_of(id) and status != null and status.text == "Objective complete", "%s ends through play (%s)" % [id, SMStory.ending_of(id)])
		scene.free()
		await process_frame
	for id: String in SMCampaign.ids():
		SMCampaign.selected = id
		var path: String = "res://game/mission_kokang.tscn" if id == "kokang" else "res://game/campaign_mission.tscn"
		var scene: Node = (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await process_frame
		var field: SMPointer = scene.get("field") as SMPointer
		if id == "tonle_sap":
			var ferries: Array[RTSUnit] = _duty_units(field, "ferry")
			if not ferries.is_empty():
				ferries[0].take_damage(ferries[0].hp + 1.0)
		else:
			_wipe(field.units_of(0))
		var story: SMStory = scene.get("story") as SMStory
		story.tick(0.2)
		await process_frame
		var status: Label = scene.find_child("Status", true, false) as Label
		check(story != null and story.lost and not story.done and story.loss != "" and status != null and status.text == "Objective failed", "%s can be lost (%s)" % [id, story.loss])
		scene.free()
		await process_frame
	SMCampaign.selected = "tachileik"

func _meet_story(scene: Node, id: String) -> void:
	var story: SMStory = scene.get("story") as SMStory
	var field: SMPointer = scene.get("field") as SMPointer
	if id == "kokang":
		_kill_duty(field, "recon")
		var build: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
		build.pressed.emit()
		_park(field, "", Vector3(6.0, 0.0, 2.0))
		story.tick(2.0)
		_park(field, "", Vector3(-6.0, 0.0, 4.0))
		story.tick(4.0)
		return
	if id == "shwe_kokko":
		_kill_duty(field, "clear")
		_park(field, "", story.pad)
		story.tick(story.hack_left)
	elif id == "tachileik" or id == "kilometer_watch":
		_kill_duty(field, "clear")
		_park(field, "", story.pad)
		story.tick(2.0 if id == "tachileik" else 1.0)
	elif id == "black_haze" or id == "fog_over_pakbeng":
		_park(field, "", story.pad)
		story.tick(story.hold_left)
	elif id == "andaman":
		_kill_duty(field, "clear")
		_park(field, "channel_skiff", story.far_shore)
		story.tick(0.1)
	elif id == "archipelago_rising":
		_kill_duty(field, "clear")
		_park(field, "sampan", story.shallow_pad)
		story.tick(0.1)
	elif id == "ghosts_of_patani":
		_wipe(field.units_of(1))
		story.tick(0.1)
	elif id == "plain_of_jars":
		var tube: RTSUnit = _beam_tube(field)
		var foe: RTSUnit = _duty_units(field, "phantom")[0]
		foe.max_hp = 100000.0
		foe.hp = 100000.0
		field.selection.units.append(tube)
		field.cast_f(foe.global_position)
		field.tick(2.0)
		story.tick(0.1)
		_kill_duty(field, "phantom")
		_kill_duty(field, "battery")
		story.tick(0.1)
	elif id == "operation_1027":
		_press_proto(scene, "drone_swarm_23")
		_kill_duty(field, "tower")
		story.tick(0.1)
		_kill_duty(field, "hangar")
		story.tick(0.1)
	elif id == "wrath_of_the_garuda":
		_press_proto(scene, "su30_napalm")
		_kill_duty(field, "fleet")
		story.tick(0.1)
	elif id == "keng_tung":
		_press_proto(scene, "toxic_defoliation")
		story.tick(0.1)
		_kill_duty(field, "column")
		story.tick(0.1)
	elif id == "tonle_sap":
		_press_proto(scene, "cryogeddon")
		story.tick(story.hold_left)
	elif id == "shattered_monsoon":
		_press_proto(scene, "cash_bounty")
		_press_proto(scene, "advanced_rocket_pods")
		_press_proto(scene, "cryoshot")
		_kill_duty(field, "super")
		story.tick(0.1)

func _park(field: SMPointer, kind: String, at: Vector3) -> void:
	for u: RTSUnit in field.units_of(0):
		if kind == "" or str(u.unit_type) == kind:
			u.global_position = at
			return

func _kind_unit(field: SMPointer, kind: String) -> RTSUnit:
	for u: RTSUnit in field.units_of(0):
		if str(u.unit_type) == kind:
			return u
	return null

func _press_proto(scene: Node, id: String) -> void:
	var button: Button = scene.find_child("Proto_%s" % id, true, false) as Button
	if button != null:
		button.pressed.emit()

func _cast_story(scene: Node, id: String) -> void:
	if id == "operation_1027":
		_press_proto(scene, "drone_swarm_23")
	elif id == "wrath_of_the_garuda":
		_press_proto(scene, "su30_napalm")
	elif id == "keng_tung":
		_press_proto(scene, "toxic_defoliation")
	elif id == "tonle_sap":
		_press_proto(scene, "cryogeddon")
	elif id == "shattered_monsoon":
		_press_proto(scene, "cash_bounty")
		_press_proto(scene, "advanced_rocket_pods")
		_press_proto(scene, "cryoshot")

func _duty_units(field: SMPointer, duty: String) -> Array[RTSUnit]:
	var out: Array[RTSUnit] = []
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and str(u.get_meta("duty", "")) == duty:
			out.append(u)
	return out

func _kill_duty(field: SMPointer, duty: String) -> void:
	for u: RTSUnit in _duty_units(field, duty):
		u.take_damage(u.hp + 1.0)

func test_sm_play() -> void:
	for id: String in SMCampaign.ids():
		var won: bool = await _script_mission(id)
		check(won, "%s scripted play reaches Objective complete" % id)
		var lost: bool = await _script_wipe(id)
		check(lost, "%s scripted wipe reaches Objective failed" % id)
	var skirmish_won: bool = await _script_skirmish(false)
	check(skirmish_won, "phillips scripted play reaches Objective complete")
	var skirmish_lost: bool = await _script_skirmish(true)
	check(skirmish_lost, "phillips scripted wipe reaches Objective failed")
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func _script_mission(id: String) -> bool:
	SMCampaign.selected = id
	var path: String = "res://game/mission_kokang.tscn" if id == "kokang" else "res://game/campaign_mission.tscn"
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	_script_orders(scene, id)
	var story: SMStory = scene.get("story") as SMStory
	var status: Label = scene.find_child("Status", true, false) as Label
	var ok: bool = story != null and story.done and not story.lost and status != null and status.text == "Objective complete"
	scene.free()
	await process_frame
	return ok

func _script_wipe(id: String) -> bool:
	SMCampaign.selected = id
	var path: String = "res://game/mission_kokang.tscn" if id == "kokang" else "res://game/campaign_mission.tscn"
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)):
			u.take_damage(u.hp + 1.0)
	scene._process(0.2)
	var story: SMStory = scene.get("story") as SMStory
	var status: Label = scene.find_child("Status", true, false) as Label
	var ok: bool = story != null and story.lost and not story.done and status != null and status.text == "Objective failed"
	scene.free()
	await process_frame
	return ok

func _script_skirmish(wipe: bool) -> bool:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	if wipe:
		_wipe(field.units_of(SMPointer.PLAYER))
		scene._process(0.2)
	else:
		if not _train_boats(scene, 8):
			scene.free()
			await process_frame
			return false
		var steps: int = 0
		var end: SMOutcome = scene.get("outcome") as SMOutcome
		while end != null and not end.over and steps < 480:
			_favor_script(field)
			if field.units_of(SMPointer.ENEMY).is_empty():
				_march_on_base(scene, field)
			else:
				_order_crossing(field)
			scene._process(0.5)
			steps += 1
	var end_state: SMOutcome = scene.get("outcome") as SMOutcome
	var status: Label = scene.find_child("Status", true, false) as Label
	var wanted: String = "Objective failed" if wipe else "Objective complete"
	var ok: bool = end_state != null and end_state.over and end_state.victory != wipe and status != null and status.text == wanted
	scene.free()
	await process_frame
	return ok

func _train_boats(scene: Node, count: int) -> bool:
	var button: Button = scene.find_child("Train_channel_skiff", true, false) as Button
	var spins: int = 0
	while button == null and spins < 6:
		scene._process(0.0)
		button = scene.find_child("Train_channel_skiff", true, false) as Button
		spins += 1
	if button == null:
		return false
	for _i: int in count:
		button.pressed.emit()
	return true

## The scripted crossing has to reach the objective either way the dice fall.
## Player boats hit harder and the garrison is brittle, so a long suite cannot
## lose the race that a quiet run wins.
func _favor_script(field: SMPointer) -> void:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive():
			u.attack_damage = maxf(u.attack_damage, 60.0)
			if u.hp < 800.0:
				u.hp = 800.0
	for foe: RTSUnit in field.units_of(SMPointer.ENEMY):
		if is_instance_valid(foe) and foe.is_alive() and foe.hp > 50.0:
			foe.hp = 50.0

## Once the garrison is gone, the boats still have to sit on the yard or the
## match never ends. A kill far from the base used to time the script out.
func _march_on_base(scene: Node, field: SMPointer) -> void:
	var raider: SMRaider = scene.get("raider") as SMRaider
	if raider == null or raider.yard == null:
		return
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var standing: StringName = raider.yard.nearest_living(u.global_position)
		var at: Vector3 = raider.yard.center if standing == &"" else raider.yard.position_of(standing)
		var nav: RTSGridNav = field.nav_for_unit(u)
		if nav == null or nav.find_path(u.global_position, at).is_empty():
			u.global_position = at + Vector3(3.0, 0.0, 0.0)
		if nav == null:
			continue
		var one: Array[RTSUnit] = [u]
		RTSOrders.move(one, at, nav)

func _order_crossing(field: SMPointer) -> void:
	var target: RTSUnit = _priority_target(field)
	if target == null:
		return
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var nav: RTSGridNav = field.nav_for_unit(u)
		if nav == null or nav.find_path(u.global_position, target.global_position).is_empty():
			continue
		var one: Array[RTSUnit] = [u]
		RTSOrders.attack(one, target, nav, field.teams)

func _script_orders(scene: Node, id: String) -> void:
	var field: SMPointer = scene.get("field") as SMPointer
	var story: SMStory = scene.get("story") as SMStory
	if id != "plain_of_jars":
		_favor_script(field)
	if id == "kokang":
		_fight_enemies(scene, field, 160)
		var build: Button = scene.find_child("Build_scaffold_yard", true, false) as Button
		if build != null:
			build.pressed.emit()
		_march(scene, field, Vector3(6.0, 0.0, 2.0), "")
		_sim(scene, 8, 0.5)
		_march(scene, field, Vector3(-6.0, 0.0, 4.0), "")
		_sim(scene, 12, 0.5)
		return
	if id == "keng_tung":
		_freeze_column(scene, field)
		return
	if id == "plain_of_jars":
		_beam_once(scene, field)
		_favor_script(field)
		_fight_enemies(scene, field, 160)
		return
	if id == "black_haze" or id == "fog_over_pakbeng" or id == "tachileik" or id == "shwe_kokko" or id == "kilometer_watch":
		_fight_enemies(scene, field, 180)
		_march(scene, field, story.pad, "")
		_sim_until_done(scene, 80, 0.5)
		return
	if id == "andaman":
		_fight_enemies(scene, field, 200)
		_march(scene, field, story.far_shore, "channel_skiff")
		_sim_until_done(scene, 40, 0.5)
		return
	if id == "archipelago_rising":
		_fight_enemies(scene, field, 200)
		_march(scene, field, story.shallow_pad, "sampan")
		_sim_until_done(scene, 40, 0.5)
		return
	if id == "tonle_sap":
		_fight_enemies(scene, field, 160)
		_sim_until_done(scene, 80, 0.5)
		return
	_fight_enemies(scene, field, 200)
	_sim_until_done(scene, 40, 0.5)

func _freeze_column(scene: Node, field: SMPointer) -> void:
	var guard: int = 0
	while _column_left(field) and guard < 12:
		_beam_once(scene, field)
		var steps: int = 0
		while _thawed_column(field) and steps < 40:
			_order_focus(field)
			scene._process(0.25)
			steps += 1
		guard += 1

func _column_left(field: SMPointer) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if is_instance_valid(u) and u.is_alive() and str(u.get_meta("duty", "")) == "column":
			return true
	return false

func _thawed_column(field: SMPointer) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if is_instance_valid(u) and u.is_alive() and str(u.get_meta("duty", "")) == "column" and bool(u.get_meta("was_frozen", false)):
			return true
	return false

func _beam_tube(field: SMPointer) -> RTSUnit:
	var tube: RTSUnit = _kind_unit(field, "siege_tube")
	if tube == null:
		tube = _kind_unit(field, "monsoon_tube")
	return tube

func _beam_once(scene: Node, field: SMPointer) -> void:
	var tube: RTSUnit = _beam_tube(field)
	if tube == null or not tube.is_alive():
		return
	var wait: int = 0
	while float(tube.get_meta("f_ready", 0.0)) > 0.0 and wait < 24:
		scene._process(0.25)
		wait += 1
	var before: int = int(tube.get_meta("beam_done", 0))
	var only: Array[RTSUnit] = [tube]
	field.select_only(only)
	field.cast_f(tube.global_position)
	var channel: int = 0
	while int(tube.get_meta("beam_done", 0)) <= before and channel < 16:
		scene._process(0.25)
		channel += 1

func _fight_enemies(scene: Node, field: SMPointer, limit: int) -> void:
	var steps: int = 0
	while not field.units_of(SMPointer.ENEMY).is_empty() and _army_alive(field) and steps < limit:
		_order_focus(field)
		scene._process(0.25)
		steps += 1

func _sim(scene: Node, steps: int, delta: float) -> void:
	for _i: int in steps:
		scene._process(delta)

func _sim_until_done(scene: Node, limit: int, delta: float) -> void:
	var story: SMStory = scene.get("story") as SMStory
	var steps: int = 0
	while story != null and not story.done and not story.lost and steps < limit:
		scene._process(delta)
		steps += 1

func _march(scene: Node, field: SMPointer, at: Vector3, kind: String) -> void:
	var mover: RTSUnit = _marcher(field, kind)
	if mover == null:
		return
	var one: Array[RTSUnit] = [mover]
	var steps: int = 0
	while is_instance_valid(mover) and mover.is_alive() and mover.global_position.distance_to(at) > 1.2 and steps < 100:
		if mover.path.is_empty() or mover.attack_target != null:
			RTSOrders.move(one, at, field.nav_for_unit(mover))
		scene._process(0.25)
		steps += 1

func _marcher(field: SMPointer, kind: String) -> RTSUnit:
	if kind != "":
		var typed: RTSUnit = _kind_unit(field, kind)
		if typed != null and typed.is_alive():
			return typed
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)):
			return u
	return null

func _order_focus(field: SMPointer) -> void:
	var target: RTSUnit = _priority_target(field)
	if target == null:
		return
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not is_instance_valid(u) or not u.is_alive() or bool(u.get_meta("objective", false)):
			continue
		if u.attack_target == target:
			continue
		var one: Array[RTSUnit] = [u]
		RTSOrders.attack(one, target, field.nav_for_unit(u), field.teams)

func _priority_target(field: SMPointer) -> RTSUnit:
	var duties: PackedStringArray = PackedStringArray([
		"escort", "clear", "pressure", "trimaran", "fleet", "ghost",
		"phantom", "battery", "tower", "super", "hangar", "column",
	])
	var origin: Vector3 = _army_center(field)
	var best: RTSUnit = null
	var best_rank: int = 100
	var best_d: float = 100000.0
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var duty: String = str(u.get_meta("duty", ""))
		if duty == "column" and not bool(u.get_meta("was_frozen", false)):
			continue
		var rank: int = duties.find(duty)
		if rank < 0:
			rank = 40
		var dist: float = u.global_position.distance_to(origin)
		if rank < best_rank or (rank == best_rank and dist < best_d):
			best_rank = rank
			best_d = dist
			best = u
	return best

func _army_center(field: SMPointer) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)):
			center += u.global_position
			n += 1
	if n == 0:
		return Vector3.ZERO
	return center / float(n)

func _army_alive(field: SMPointer) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)):
			return true
	return false

func test_sm_web() -> void:
	SMSave.clear()
	var camera: RTSCamera = RTSCamera.new()
	root.add_child(camera)
	var touch: Node = root.get_node_or_null("SMTouch")
	var before: Vector3 = camera.focus
	var before_dist: float = camera.distance
	check(touch != null, "touch pan is an autoload")
	if touch != null:
		touch.call("pan_camera", camera, Vector2(80.0, 0.0))
		touch.call("pinch_camera", camera, 40.0, 100.0)
	check(camera.focus.distance_to(before) > 0.01, "one finger pans the camera")
	check(camera.distance < before_dist, "a pinch zooms the camera")
	camera.free()
	SMCampaign.selected = "tachileik"
	var scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	_meet_story(scene, "tachileik")
	await process_frame
	check(FileAccess.file_exists("user://campaign.save") and SMSave.has("tachileik") and not SMSave.has("kokang"), "a campaign save appears after the objective")
	var root_dir: String = ProjectSettings.globalize_path("res://")
	var brotli: String = FileAccess.get_file_as_string(root_dir.path_join("tools/brotli_host.conf"))
	check(SMSave.idb_script().contains("indexedDB"), "campaign saves mirror into IndexedDB on the web")
	check(brotli.contains("brotli") and brotli.contains("wasm"), "the web host config turns Brotli on for the pack")
	scene.free()
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var done: Label = boot.find_child("Done_tachileik", true, false) as Label
	var other: Label = boot.find_child("Done_kokang", true, false) as Label
	var warm: Node = boot.find_child("ShaderWarmup", true, false)
	var warmed: int = 0
	if warm != null:
		for child: Node in warm.get_children():
			var mesh: MeshInstance3D = child as MeshInstance3D
			var mat: ShaderMaterial = null
			if mesh != null:
				mat = mesh.material_override as ShaderMaterial
			if mat != null and mat.shader != null and str(mat.shader.resource_path).ends_with(".gdshader"):
				warmed += 1
	check(done != null and done.text == "Done" and other == null, "the campaign tab marks the finished mission")
	var kokang_brief: Label = boot.find_child("Brief_kokang", true, false) as Label
	check(kokang_brief != null and kokang_brief.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and kokang_brief.custom_minimum_size.y >= 44.0, "campaign briefings wrap onto extra lines")
	check(warmed == 3, "boot warms the cryo, aegis, and slag shaders")
	boot.free()
	SMSave.clear()
	check(SMSave.poll_web(), "campaign progress is ready without waiting off the web")
	SMSave.mark("tachileik")
	SMSave.apply_payload(JSON.stringify(JSON.stringify(["kokang"])))
	check(SMSave.has("kokang") and SMSave.has("tachileik"), "a wrapped IndexedDB campaign record merges into the save")
	SMSave.apply_payload("")
	SMSave.apply_payload("not json")
	check(SMSave.has("kokang") and SMSave.has("tachileik"), "an empty campaign record is ignored")
	SMSave.clear()
	SMCampaign.selected = "tachileik"
	await process_frame

func test_sm_guide() -> void:
	var hint: String = SMGuide.controls_hint()
	check(hint.contains("Right-click") and hint.contains("F") and hint.contains("H"), "the controls hint names select, attack, F, and H")
	var howto: String = SMGuide.howto_text()
	check(howto.contains("Right-click") and howto.contains("Objective complete") and howto.contains("Objective failed"), "the how-to names move, attack, and both endings")
	var lesson: String = SMGuide.tutorial_for("kokang")
	check(lesson.contains("First mission") and lesson.contains("ruby night shift") and lesson.contains("company dies"), "kokang opens with a lesson")
	check(SMGuide.tutorial_for("tachileik") == "", "later missions do not repeat the first lesson")
	var militia: Dictionary = {}
	for row: Dictionary in SMCatalog.units_of(SMCatalog.faction("gtfc")):
		if str(row.get("id", "")) == "militia":
			militia = row
	var tip: String = SMGuide.unit_tip(militia)
	check(tip.contains("Shan Insurgent Militia") and tip.contains("Slag Molotov") and tip.contains("HP"), "a unit tip names health and the F ability")
	check(SMGuide.ability_tip().contains("closest ready unit"), "the ability tip explains smart-cast")
	var ui: AudioStreamWAV = SMTone.cue("ui")
	var shot: AudioStreamWAV = SMTone.cue("attack")
	check(SMTone.peak(ui) > 1000 and SMTone.peak(shot) > 1000 and shot.data.size() > ui.data.size(), "procedural cues are audible and the attack cue is longer")
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	check(clips.call("cue_clip", "") == null and clips.call("cue_clip", "../shot") == null and clips.call("cue_clip", "a/b") == null, "a cue id cannot leave the sfx folder")
	check(clips.call("weapon_kind", "rifle") == "weapon_rifle" and clips.call("weapon_kind", "cannon") == "weapon_cannon" and clips.call("weapon_kind", "tube") == "weapon_artillery" and clips.call("weapon_kind", "lance") == "weapon_rocket" and clips.call("weapon_kind", "missile") == "weapon_missile" and clips.call("weapon_kind", "bomblet") == "weapon_missile" and clips.call("weapon_kind", "torpedo") == "weapon_torpedo" and clips.call("weapon_kind", "shaped_charge") == "weapon_rocket" and clips.call("weapon_kind", "warhead") == "weapon_rocket" and clips.call("weapon_kind", "swarm") == "weapon_missile", "weapon types map onto rifle, cannon, artillery, rocket, missile, and torpedo cues")
	check(clips.call("impact_kind", 4.0) == "impact_small" and clips.call("impact_kind", 12.0) == "impact_medium" and clips.call("impact_kind", 24.0) == "impact_large", "hits pick a small, medium, or large impact")
	check(clips.call("move_kind", "armor", "ground", "amber_tank") == "move_tank_treads" and clips.call("move_kind", "drone", "amphibious", "river_drone") == "move_hover" and clips.call("move_kind", "air", "air", "gunship") == "move_helicopter" and clips.call("move_kind", "air", "air", "su30") == "", "treads, hover, and rotors loop, and jets do not")
	check(clips.call("ability_kind", "Ballistic Riot Shield") == "ability_shield" and clips.call("ability_kind", "Blackout EMP") == "ability_emp" and clips.call("ability_kind", "Black-Hole Armor") == "ability_black_hole" and clips.call("ability_kind", "S.H.R.I.N.K. Ray") == "weapon_shrink_ray" and clips.call("ability_kind", "Slag Molotov") == "ability_generic", "abilities pick shield, EMP, black hole, shrink, or a generic cue")
	check(clips.call("cue_clip", "weapon_rifle") != null, "a rifle cue loads a recorded variant")
	var sfx_host: Node = Node.new()
	sfx_host.name = "SfxCap"
	root.add_child(sfx_host)
	for _i: int in 6:
		clips.call("play_kind", sfx_host, "weapon_rifle")
	var rifle_voices: int = int(clips.call("voices_of", "weapon_rifle"))
	var rifle_cap: int = int(clips.call("cap_for", "weapon_rifle"))
	check(rifle_voices > 0 and rifle_voices <= rifle_cap and rifle_cap == 3, "rifle shots stay inside the per-kind voice cap")
	sfx_host.free()
	check(bool(ProjectSettings.get_setting("rendering/shading/overrides/force_lambert_over_burley", false)) and int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 1)) == 0, "web shading is lambert and MSAA is off")
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	Callable(load("res://addons/rts_advanced/sm_web.gd"), "quiet_node").call(sun)
	check(not sun.shadow_enabled, "the web pass turns directional shadows off")
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var controls: Label = scene.find_child("ControlsHint", true, false) as Label
	var overlay: Control = scene.find_child("HowToOverlay", true, false) as Control
	var body: Label = scene.find_child("HowToBody", true, false) as Label
	check(controls != null and controls.visible and controls.text == hint, "a match shows the controls hint")
	check(overlay != null and not overlay.visible and body != null and body.text == howto, "a match keeps the how-to closed until asked")
	if overlay != null:
		overlay.visible = true
	await process_frame
	var close: Button = scene.find_child("HowToClose", true, false) as Button
	var overlay_box: Rect2 = overlay.get_global_rect().grow(2.0) if overlay != null else Rect2()
	var close_box: Rect2 = close.get_global_rect() if close != null else Rect2()
	check(overlay != null and controls != null and overlay.is_ancestor_of(controls) and close != null and close_box.size.y > 0.0 and overlay_box.encloses(close_box), "the controls line sits inside the how-to panel")
	if overlay != null:
		overlay.visible = false
	var short_line: Label = scene.find_child("MatchHint", true, false) as Label
	check(short_line != null and overlay != null and short_line.visible and not overlay.is_ancestor_of(short_line) and short_line.text.length() <= 32 and not short_line.text.contains("Shift"), "one short line stays on screen")
	var column: Control = scene.find_child("CommandColumn", true, false) as Control
	check(column != null and column.size.x <= 280.0 and column.size.x >= 220.0, "the build column fits the cameos")
	var roster_scroll: ScrollContainer = column as ScrollContainer
	var roster_row: Button = scene.find_child("Train_militia", true, false) as Button
	var roster_at: int = roster_scroll.scroll_vertical if roster_scroll != null else 0
	var roster_nudge: InputEventMouseMotion = InputEventMouseMotion.new()
	roster_nudge.relative = Vector2(0, -4)
	roster_nudge.button_mask = MOUSE_BUTTON_MASK_LEFT
	if roster_row != null:
		roster_row.gui_input.emit(roster_nudge)
	var roster_still: int = roster_scroll.scroll_vertical if roster_scroll != null else 0
	var roster_pull: InputEventMouseMotion = InputEventMouseMotion.new()
	roster_pull.relative = Vector2(0, -48)
	roster_pull.button_mask = MOUSE_BUTTON_MASK_LEFT
	if roster_row != null:
		roster_row.gui_input.emit(roster_pull)
	var roster_purse: int = (scene.get("roster") as SMRoster).economy.credits(0)
	var roster_count: int = (scene.get("field") as SMPointer).count_team(0)
	if roster_row != null:
		roster_row.pressed.emit()
	check(roster_scroll != null and roster_still == roster_at and roster_scroll.scroll_vertical == roster_at + 48 and (scene.get("field") as SMPointer).count_team(0) == roster_count and (scene.get("roster") as SMRoster).economy.credits(0) == roster_purse, "dragging the roster scrolls the column and does not train")
	var income: Label = scene.find_child("HudIncome", true, false) as Label
	var map_label: Label = scene.find_child("HudMap", true, false) as Label
	var mm: Control = scene.find_child("Minimap", true, false) as Control
	var board: SMHud = scene.get("hud") as SMHud
	check(income != null and income.text == "" and not income.visible, "an empty income readout leaves room for the map name")
	check(map_label != null and map_label.size_flags_stretch_ratio >= 2.0, "the map name gets more of the top bar")
	check(mm != null and mm.size.x >= 200.0 and mm.size.x <= 248.0 and mm.size.y >= 200.0 and mm.size.y <= 248.0, "the minimap fills the sidebar")
	check(board != null and not board.guide_blocks(), "the how-to does not freeze a desktop sim")
	check(board != null and not board.column_hovered(), "the build column leaves the camera wheel alone until the pointer is over it")
	var buildings: Label = scene.find_child("GroupBuildings", true, false) as Label
	var header_font: Font = buildings.get_theme_font(&"font") if buildings != null else null
	check(buildings != null and buildings.theme_type_variation == "Header" and header_font != null and str(header_font.resource_path).contains("Warheed"), "section headers use the theme font")
	var match_cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	check(match_cam != null and match_cam.distance <= 32.0, "the match camera starts close to the company")
	var fit_holder: Node3D = Node3D.new()
	root.add_child(fit_holder)
	var fit_cam: RTSCamera = RTSCamera.new()
	fit_holder.add_child(fit_cam)
	fit_cam.distance = 18.0
	var fit_script: GDScript = load("res://game/camera_fit.gd") as GDScript
	fit_script.call("fit", fit_cam, Vector2(1280, 720))
	check(absf(fit_cam.distance - 18.0) < 0.01, "a wide view keeps the authored camera distance")
	fit_script.call("fit", fit_cam, Vector2(412, 915))
	check(fit_cam.distance > 30.0 and fit_cam.distance <= fit_cam.zoom_max, "a tall view pulls the camera back")
	fit_cam.zoom(1.0)
	var zoomed: float = fit_cam.distance
	fit_script.call("fit", fit_cam, Vector2(390, 844))
	check(absf(fit_cam.distance - zoomed) < 0.01, "a portrait zoom sticks until the frame flips")
	fit_script.call("fit", fit_cam, Vector2(1280, 720))
	check(absf(fit_cam.distance - 18.0) < 0.01, "returning to landscape restores the authored distance")
	var cam_src: String = FileAccess.get_file_as_string("res://addons/rts_advanced/rts_camera.gd")
	check(not cam_src.contains("fit_view") and not cam_src.contains("screen_fit") and not cam_src.contains("authored_distance") and not cam_src.contains("fit_key"), "the core camera keeps its original fields")
	var desktop_bar: float = float(fit_script.call("span", Vector2(1280, 720), 75.0, 30.0, 2.0, 120.0))
	var close_bar: float = float(fit_script.call("span", Vector2(412, 915), 75.0, 4.0, 2.0, 65.0))
	var desktop_pole: float = float(fit_script.call("span", Vector2(1280, 720), 75.0, 24.0, 7.0, 720.0 * 0.28))
	var close_pole: float = float(fit_script.call("span", Vector2(412, 915), 75.0, 12.0, 7.0, 915.0 * 0.28))
	check(absf(desktop_bar - 1.0) < 0.001 and desktop_pole > 0.99, "desktop health bars and the objective marker stay full size")
	check(close_bar < 0.5 and close_bar > 0.05 and close_pole < 0.85 and close_pole > 0.05, "a close portrait marker shrinks to the screen")
	fit_holder.free()
	close.pressed.emit()
	check(overlay != null and not overlay.visible, "Got it hides the how-to overlay")
	var help: Button = scene.find_child("HelpButton", true, false) as Button
	help.pressed.emit()
	check(overlay != null and overlay.visible, "How to play shows the overlay again")
	var train: Button = scene.find_child("Train_militia", true, false) as Button
	var ability: Button = scene.find_child("AbilityButton", true, false) as Button
	check(train != null and str(train.get_meta("tip", "")).contains("Slag Molotov") and train.tooltip_text == "", "the train button tooltip names the F ability")
	var tap_toggle: Button = scene.find_child("ProtocolsToggle", true, false) as Button
	check(train != null and train.custom_minimum_size.y >= 72.0 and help != null and help.custom_minimum_size.y >= 44.0 and close != null and close.custom_minimum_size.y >= 44.0 and tap_toggle != null and tap_toggle.custom_minimum_size.y >= 44.0, "match buttons stay large enough to tap")
	check(ability != null and str(ability.get_meta("tip", "")).contains("closest ready unit") and ability.tooltip_text == "", "the ability button tooltip explains F")
	var proto: Button = scene.find_child("Proto_cash_bounty", true, false) as Button
	check(proto != null and str(proto.get_meta("tip", "")).contains("Cash Bounty") and str(proto.get_meta("tip", "")).contains("250") and proto.tooltip_text == "", "a protocol button tooltip names the power and its effect")
	var cue: AudioStreamPlayer = scene.find_child("CuePlayer", true, false) as AudioStreamPlayer
	train.pressed.emit()
	var card: PanelContainer = scene.find_child("UnitCard", true, false) as PanelContainer
	check(card != null and card.visible and short_line != null and not short_line.is_visible_in_tree(), "a trained unit folds into one card")
	var played: AudioStream = cue.stream if cue != null else null
	var played_wav: AudioStreamWAV = played as AudioStreamWAV
	var played_ogg: AudioStreamOggVorbis = played as AudioStreamOggVorbis
	check(cue != null and played != null and (played_ogg != null or (played_wav != null and SMTone.peak(played_wav) > 1000)), "training plays a cue")
	var tip_label: Label = scene.find_child("UnitTip", true, false) as Label
	train.mouse_entered.emit()
	var tip_panel: Control = scene.find_child("TipPanel", true, false) as Control
	check(tip_label != null and tip_label.visible and tip_label.text.contains("Slag Molotov"), "hovering a unit shows a readable tip")
	check(tip_panel != null and tip_panel.size.y >= 80.0, "the hover tip is tall enough for the unit name")
	check(train != null and train.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "build buttons ellipsize instead of cutting a word")
	var factory: Button = scene.find_child("Build_war_factory", true, false) as Button
	var barracks: Button = scene.find_child("Build_barracks", true, false) as Button
	check(train != null and train.icon != null and train.text == "" and str(train.get_meta("caption", "")) == "Shan Insurgent Militia", "the train button shows the militia cameo")
	check(factory != null and factory.icon != null and barracks != null and barracks.icon != null, "the barracks and war factory buttons show cameos")
	check(ability != null and ability.icon == null and ability.text == "Ability (F)", "the ability button stays a text button")
	var tip_cameo: TextureRect = scene.find_child("TipCameo", true, false) as TextureRect
	check(tip_cameo != null and tip_cameo.visible and tip_cameo.texture != null, "the hover tip shows the unit cameo")
	var cameo_field: SMPointer = scene.get("field") as SMPointer
	if cameo_field != null:
		var solo_unit: RTSUnit = _unit_kind(cameo_field, 0, "militia")
		if solo_unit != null:
			cameo_field.select_only([solo_unit])
	if board != null:
		board.refresh()
	var card_cameo: TextureRect = scene.find_child("CardCameo", true, false) as TextureRect
	check(card_cameo != null and card_cameo.visible and card_cameo.texture != null, "the unit card shows the selected cameo")
	if board != null:
		board.layout_for(Vector2(412, 915))
	var units_tab: Button = scene.find_child("PhoneTabUnits", true, false) as Button
	if units_tab != null:
		units_tab.pressed.emit()
	await process_frame
	var cameo_grid: GridContainer = scene.find_child("PhoneIconGrid", true, false) as GridContainer
	check(cameo_grid != null and cameo_grid.visible and cameo_grid.columns >= 3 and train != null and train.get_parent() == cameo_grid and train.text == "" and train.icon != null, "the phone drawer lays cameos out as an icon grid")
	check(ability != null and cameo_grid != null and ability.get_parent() != cameo_grid and ability.icon == null and ability.text == "Ability (F)", "a control without a cameo stays a text button on the phone")
	if board != null:
		board.layout_for(Vector2(1280, 720))
	await process_frame
	var cameo_script: GDScript = load("res://game/match_cameos.gd") as GDScript
	check(cameo_script.call("texture", "gtfc", "not_a_real_unit") == null, "a missing cameo leaves the text button")
	var saved_size: Vector2i = Vector2i(root.size)
	root.size = Vector2i(1024, 576)
	await process_frame
	await process_frame
	var window_box: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size)).grow(2.0)
	var toggle_fit: Control = scene.find_child("ProtocolsToggle", true, false) as Control
	var card_fit: Control = scene.find_child("UnitCard", true, false) as Control
	var protocols_fit: Control = scene.find_child("Protocols", true, false) as Control
	if protocols_fit != null:
		protocols_fit.visible = true
	await process_frame
	var column_box: Rect2 = column.get_global_rect() if column != null else Rect2()
	var toggle_box: Rect2 = toggle_fit.get_global_rect() if toggle_fit != null else Rect2()
	var guide_box: Rect2 = overlay.get_global_rect() if overlay != null else Rect2()
	var card_box: Rect2 = card_fit.get_global_rect() if card_fit != null else Rect2()
	var proto_box: Rect2 = protocols_fit.get_global_rect() if protocols_fit != null else Rect2()
	check(root.size == Vector2i(1024, 576) and column_box.size.x > 40.0 and toggle_box.size.y > 20.0 and guide_box.size.x > 40.0 and card_box.size.x > 40.0 and proto_box.size.y > 40.0 and window_box.encloses(column_box) and window_box.encloses(toggle_box) and window_box.encloses(guide_box) and window_box.encloses(card_box) and window_box.encloses(proto_box), "the match HUD fits a 1024 by 576 window")
	root.size = Vector2i(844, 390)
	if protocols_fit != null:
		protocols_fit.visible = false
	if overlay != null:
		overlay.visible = false
	var card_show: Control = scene.find_child("UnitCard", true, false) as Control
	var card_was: bool = card_show.visible if card_show != null else false
	if card_show != null:
		card_show.visible = true
	await process_frame
	await process_frame
	var hud_names: PackedStringArray = PackedStringArray(["CommandColumn", "ProtocolsToggle", "UnitCard", "ObjectiveShade", "TopBar", "SuperDock", "MatchStrip", "ToastLane", "MissionBoot"])
	var boxes: Array[Rect2] = []
	var overlap: bool = false
	for hud_name: String in hud_names:
		var hud_node: Control = scene.find_child(hud_name, true, false) as Control
		if hud_node == null or not hud_node.is_visible_in_tree():
			continue
		var hud_box: Rect2 = hud_node.get_global_rect()
		if hud_box.size.x < 8.0 or hud_box.size.y < 8.0:
			continue
		for prior: Rect2 in boxes:
			var hit: Rect2 = prior.intersection(hud_box)
			if hit.size.x > 1.0 and hit.size.y > 1.0:
				overlap = true
		boxes.append(hud_box)
	check(not overlap and boxes.size() >= 4, "phone landscape keeps the match panels apart")
	if card_show != null:
		card_show.visible = card_was
	root.size = saved_size
	await process_frame
	scene.free()
	await process_frame
	SMCampaign.selected = "kokang"
	var raid: Node = (load("res://game/mission_kokang.tscn") as PackedScene).instantiate()
	root.add_child(raid)
	await process_frame
	var lesson_label: Label = raid.find_child("TutorialPrompt", true, false) as Label
	check(lesson_label != null and lesson_label.visible and lesson_label.text == lesson, "kokang shows the first-mission lesson")
	var raid_brief: Label = raid.find_child("Briefing", true, false) as Label
	var raid_boot: Button = raid.find_child("MissionBoot", true, false) as Button
	check(raid_brief != null and raid_brief.position.x >= 210.0 and raid_brief.size.x <= 820.0 and raid_brief.size.y >= 60.0 and raid_brief.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and raid_brief.clip_text, "the kokang briefing clears the minimap and wraps")
	var raid_status: Control = raid.find_child("Status", true, false) as Control
	var brief_box: Rect2 = raid_brief.get_global_rect() if raid_brief != null else Rect2()
	var status_box: Rect2 = raid_status.get_global_rect() if raid_status != null else Rect2()
	var brief_hit: Rect2 = brief_box.intersection(status_box)
	check(raid_status != null and brief_box.size.y >= 60.0 and status_box.size.y >= 8.0 and (brief_hit.size.x < 1.0 or brief_hit.size.y < 1.0), "the kokang briefing lines do not overlap")
	var raid_hud: SMHud = raid.get("hud") as SMHud
	var raid_coach: Node = raid.get_node_or_null("MatchCoach")
	var raid_toast: Control = raid.find_child("ToastLane", true, false) as Control
	var raid_eva: Control = raid.find_child("MessageLane", true, false) as Control
	if raid_hud != null:
		raid_hud.show_line("Under fire.")
	if raid_coach != null:
		raid_coach.call("_once", "pad", "Resource pad in sight.")
	await process_frame
	check(raid_brief != null and raid_brief.visible and (raid_toast == null or not raid_toast.visible) and (raid_eva == null or not raid_eva.visible), "toasts and EVA lines queue while a briefing is shown")
	var raid_dismiss: Button = raid.find_child("BriefingDismiss", true, false) as Button
	if raid_dismiss != null:
		raid_dismiss.pressed.emit()
	await process_frame
	await process_frame
	check(raid_brief != null and not raid_brief.visible and raid_toast != null and raid_toast.visible, "queued toasts appear in their lane once the briefing closes")
	check(not _plain_box(raid.get_node_or_null("Scaffold")) and not _plain_box(raid.get_node_or_null("RubyNode")) and not _plain_box(raid.get_node_or_null("RareNode")), "kokang yard and ore nodes are not plain boxes")
	var teak: MultiMeshInstance3D = raid.get_node_or_null("JungleTrees") as MultiMeshInstance3D
	var teak_mesh: Mesh = teak.multimesh.mesh if teak != null and teak.multimesh != null else null
	var teak_faces: int = teak_mesh.get_faces().size() if teak_mesh != null else 0
	var fallback_tree: Mesh = Ground.fallback_tree()
	check(teak_mesh != null and teak_faces > 200 and fallback_tree.get_faces().size() > 200, "kokang trees are a crown, not a green cube")
	var raid_map: SMMinimap = raid.find_child("Minimap", true, false) as SMMinimap
	check(raid_map != null and raid_map.backdrop != null and not _flat_olive(raid_map.backdrop), "the kokang minimap is not a flat olive square")
	var worker: String = FileAccess.get_file_as_string("res://web/sw.js")
	check(worker.contains("shattered-monsoon-v3") and worker.contains("cache.put") and worker.contains("/models/") and worker.contains("/audio/") and worker.contains("index.wasm") and worker.contains("index.pck"), "the service worker precaches the shell and stores models and audio")
	check(raid_boot != null and raid_boot.visible and raid_boot.text == "Boot menu", "kokang can return to the boot menu")
	raid.free()
	await process_frame
	var raid_second: Node = (load("res://game/mission_kokang.tscn") as PackedScene).instantiate()
	root.add_child(raid_second)
	await process_frame
	var second_teak: MultiMeshInstance3D = raid_second.get_node_or_null("JungleTrees") as MultiMeshInstance3D
	var second_house: MultiMeshInstance3D = raid_second.get_node_or_null("Town_border_guesthouse") as MultiMeshInstance3D
	var st_faces: int = second_teak.multimesh.mesh.get_faces().size() if second_teak != null and second_teak.multimesh != null and second_teak.multimesh.mesh != null else -1
	var sh_faces: int = second_house.multimesh.mesh.get_faces().size() if second_house != null and second_house.multimesh != null and second_house.multimesh.mesh != null else -1
	check(st_faces == teak_faces and sh_faces > 100, "a second Kokang entry reuses the cached tree and house models (%d/%d, %d)" % [st_faces, teak_faces, sh_faces])
	raid_second.free()
	await process_frame
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func test_sm_bark() -> void:
	check(SMBark.line(&"militia", "select") == "Militia holding.", "militia answers a select")
	check(SMBark.line(&"slag_hauler", "attack").contains("Drones"), "the drone truck calls its shot")
	check(SMBark.line(&"slag_dozer", "ability").contains("Salvage"), "the dozer names the salvage leech")
	check(SMBark.line(&"jade_mortar", "move").contains("Skimming"), "the hover-technical calls a move")
	check(SMBark.line(&"hub_drone", "hurt").contains("Copter"), "the cryo-copter calls under fire")
	check(SMBark.line(&"unknown", "select") == "Ready.", "an unnamed unit still answers")
	check(SMTone.peak(SMTone.cue("bark")) > 1000, "the bark cue is audible")
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	var tracks: PackedStringArray = PackedStringArray([
		"music/menu.ogg", "music/gtfc.ogg", "music/nmrf.ogg", "music/mvd.ogg",
		"music/black_market.ogg", "music/victory_sting.ogg", "music/defeat_sting.ogg",
	])
	var tracks_ok: bool = true
	for track: String in tracks:
		if clips.call("_stream", track) == null:
			tracks_ok = false
	check(tracks_ok, "menu, faction, and sting tracks decode")
	check(clips.call("titles_for", "menu") == PackedStringArray(["Yangonite"]), "the menu plays only Yangonite")
	var rotation_titles: PackedStringArray = clips.call("titles_for", "rotation") as PackedStringArray
	var rotation_unique: Dictionary = {}
	for song: String in rotation_titles:
		if song != "":
			rotation_unique[song] = true
	check(rotation_titles.size() == 12 and rotation_unique.size() == 12 and rotation_titles.has("Yangonite") and rotation_titles.has("Poison"), "every map shares one twelve-song rotation")
	var retired_rels: PackedStringArray = clips.call("_rels_for", "retired") as PackedStringArray
	var retired_out: bool = retired_rels.size() == 5
	for rel: String in retired_rels:
		if (clips.call("_rels_for", "rotation") as PackedStringArray).has(rel) or (clips.call("_rels_for", "menu") as PackedStringArray).has(rel) or not clips.call("is_retired", rel):
			retired_out = false
	check(retired_out, "the generated menu and faction loops are retired from the menu and the rotation")
	check((clips.call("titles_for", "gtfc") as PackedStringArray).is_empty() and (clips.call("titles_for", "black_market") as PackedStringArray).is_empty(), "there are no per-faction playlists")
	check(not clips.call("is_retired", "music/victory_sting.ogg") and not clips.call("is_retired", "music/defeat_sting.ogg") and not clips.call("is_retired", "music/user/time.ogg"), "the stings and user songs are not retired")
	var reshuffled: bool = true
	for i: int in 20:
		var order: PackedStringArray = clips.call("_shuffle", clips.call("_rels_for", "rotation"), "music/user/time.ogg") as PackedStringArray
		if order.size() != 12 or order[0] == "music/user/time.ogg":
			reshuffled = false
	check(reshuffled, "a reshuffle never opens on the song that just played")
	check(clips.call("is_lazy", "music/user/night.ogg") and not clips.call("is_lazy", "music/menu.ogg"), "user songs stay out of the startup download")
	check(clips.call("is_lazy", "barks/burmese/militia_select_1.ogg") and clips.call("is_lazy", "announcer/thai/gtfc/unit_ready.ogg") and not clips.call("is_lazy", "barks/militia_select_1.ogg"), "only the selected voice language stays out of the startup download")
	var user_tracks: PackedStringArray = PackedStringArray([
		"music/user/changes.ogg", "music/user/humanfuture.ogg", "music/user/love-drunk.ogg",
		"music/user/machinesfuture.ogg", "music/user/night.ogg", "music/user/not-needed-anymore.ogg",
		"music/user/past-cracks.ogg", "music/user/poison.ogg",
		"music/user/ready-to-rage-against-the-abnormalities.ogg", "music/user/supayarlat.ogg",
		"music/user/time.ogg", "music/user/yangonite.ogg",
	])
	var user_ok: bool = true
	for track: String in user_tracks:
		if clips.call("_stream", track) == null:
			user_ok = false
	check(user_ok, "the twelve user songs decode")
	Settings.set_voice("english")
	var held_faction: String = SMFront.faction_id
	SMFront.faction_id = "gtfc"
	var voiced: PackedStringArray = PackedStringArray([
		"militia", "ruby_lancer", "amber_tank", "monsoon_tube", "channel_skiff",
		"crimson_sapper", "amber_scout", "yard_crane", "ruby_mortar",
	])
	var events: PackedStringArray = PackedStringArray(["select", "move", "attack"])
	var barks_ok: bool = true
	var heard_units: int = 0
	for unit_id: String in voiced:
		var heard_unit: bool = false
		for event_name: String in events:
			var found: PackedStringArray = clips.call("_variants", unit_id, event_name) as PackedStringArray
			if found.is_empty():
				continue
			heard_unit = true
			if clips.call("_stream", found[0]) == null:
				barks_ok = false
			var english: bool = false
			for rel: String in found:
				if rel.begins_with("barks/en/"):
					english = true
				if clips.call("_stream", rel) == null or rel.contains("_retired") or rel.split("/").size() < 3:
					barks_ok = false
			if not english:
				barks_ok = false
			for rel: String in found:
				if not rel.begins_with("barks/en/"):
					barks_ok = false
		if heard_unit:
			heard_units += 1
	check(barks_ok and heard_units >= 5, "the shipped units decode their English takes, and a unit whose English takes all failed stays silent instead of borrowing another language")
	check(clips.call("clip_for", "militia", "select") != null, "a shipped bark is chosen for playback")
	check(Settings.voice_folder("english") == "en" and Settings.voice_folder("burmese") == "my" and Settings.voice_folder("mandarin") == "zh" and Settings.voice_folder("thai") == "th" and Settings.voice_folder("malay") == "ms", "voice settings map onto en my zh th ms")
	var wanted: PackedStringArray = clips.call("_wanted_langs") as PackedStringArray
	var nmrf_order: PackedStringArray = clips.call("_order_for", "en", "nmrf") as PackedStringArray
	var mvd_order: PackedStringArray = clips.call("_order_for", "en", "mvd") as PackedStringArray
	var market_order: PackedStringArray = clips.call("_order_for", "en", "black_market") as PackedStringArray
	var thai_order: PackedStringArray = clips.call("_order_for", "th", "gtfc") as PackedStringArray
	check(wanted == PackedStringArray(["en"]), "english on GTFC fetches only English")
	SMFront.faction_id = "black_market"
	var market_fetch: PackedStringArray = clips.call("_wanted_langs") as PackedStringArray
	SMFront.faction_id = "gtfc"
	check(market_fetch == PackedStringArray(["en"]), "english on the black market fetches only English")
	check(nmrf_order == PackedStringArray(["en"]), "english on NMRF never borrows Malay")
	check(mvd_order == PackedStringArray(["en"]), "english on MVD never borrows Mandarin")
	check(market_order == PackedStringArray(["en"]), "english on the black market never borrows Malay")
	check(thai_order == PackedStringArray(["th"]), "thai never borrows an english take")
	Settings.set_voice("thai")
	check(clips.call("_best", "barks", "militia_select_1.ogg") == "barks/th/militia_select_1.ogg", "thai plays the th take")
	check(clips.call("_best", "barks", "crimson_sapper_select_1.ogg") == "barks/th/crimson_sapper_select_1.ogg", "thai plays the sapper's own take")
	Settings.set_voice("english")
	check(clips.call("_best", "barks", "militia_select_1.ogg") == "barks/en/militia_select_1.ogg", "english plays the en take")
	check(clips.call("_best", "barks", "militia_move_1.ogg") == "", "a failed english take stays a tone instead of Burmese")
	check(clips.call("_best", "barks", "slag_hauler_attack_1.ogg") == "", "a failed english take never falls on to Thai")
	check(clips.call("_best", "barks", "emerald_gunboat_select_1.ogg") == "", "a failed NMRF english take never plays Malay")
	check(clips.call("_best", "barks", "clearance_trooper_move_1.ogg") == "", "a failed MVD english take never plays Mandarin")
	check(clips.call("_best", "barks", "ch4_select_1.ogg") == "", "a failed black market english take never plays Malay")
	check(clips.call("_best", "barks", "orlan10_select_1.ogg") == "barks/en/orlan10_select_1.ogg", "a passing black market take stays in English")
	check(clips.call("_best", "announcer", "gtfc/unit_lost.ogg") == "", "a failed english announcer line stays silent instead of Burmese")
	check(clips.call("_best", "announcer", "gtfc/low_power.ogg") == "announcer/en/gtfc/low_power.ogg", "a passing english announcer line stays in English")
	check(clips.call("clip_for", "not_a_unit", "select") == null, "a missing bark stays empty for the tone")
	check(clips.call("_stream", "barks/crimson_sapper_select_2.ogg") == null, "the old flat sapper line is not played")
	var english_sapper: PackedStringArray = clips.call("_variants", "crimson_sapper", "select") as PackedStringArray
	Settings.set_voice("burmese")
	var sapper_lines: PackedStringArray = clips.call("_variants", "crimson_sapper", "select") as PackedStringArray
	Settings.set_voice("english")
	check(english_sapper.is_empty() and sapper_lines == PackedStringArray(["barks/my/crimson_sapper_select_1.ogg", "barks/my/crimson_sapper_select_2.ogg"]), "the sapper select line plays in Burmese only when Burmese is chosen")
	SMFront.faction_id = held_faction
	clips.call("color_voice", null)
	var music_bus: int = AudioServer.get_bus_index("Music")
	Settings.set_master(0.4)
	Settings.set_sfx(0.5)
	Settings.apply_scene(null)
	check(music_bus > 0 and AudioServer.get_bus_send(music_bus) == "Master" and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.4)), "master volume scales the music bus")
	check(AudioServer.get_bus_index("Master") == 0, "runtime buses leave Master at the speakers")
	check(is_equal_approx(Settings.cue_db(-6.0), -6.0 + linear_to_db(0.5)), "sfx volume scales barks")
	var capped: bool = false
	var ceiling: float = 0.0
	for effect_i: int in AudioServer.get_bus_effect_count(0):
		var effect: AudioEffect = AudioServer.get_bus_effect(0, effect_i)
		if effect is AudioEffectLimiter:
			capped = true
			ceiling = (effect as AudioEffectLimiter).ceiling_db
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	check(capped and is_equal_approx(ceiling, -1.0), "the master bus limiter ceilings at -1 dB")
	check(sfx_bus > 0 and is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), Settings.sfx_bus_db()) and Settings.sfx_bus_db() < linear_to_db(Settings.sfx), "the sfx bus sits under the slider")
	Settings.restore()
	Settings.apply_scene(null)
	var music_now: int = AudioServer.get_bus_index("Music")
	var music_db: float = AudioServer.get_bus_volume_db(music_now)
	check(music_now > 0 and music_db <= -4.0 and music_db >= -6.0 and is_equal_approx(music_db, Settings.music_bus_db()), "music defaults about 5 dB under full")
	Settings.set_master(1.0)
	Settings.set_sfx(1.0)
	Settings.apply_scene(null)
	var speaker: Node = Node.new()
	speaker.name = "AudioProbe"
	root.add_child(speaker)
	clips.call("play_menu", speaker)
	var menu_player: AudioStreamPlayer = speaker.get_node_or_null("MenuMusic") as AudioStreamPlayer
	check(menu_player != null and menu_player.playing and menu_player.stream != null, "menu music starts")
	check(clips.call("current_title") == "Yangonite", "the menu opens on Yangonite")
	var menu_ogg: AudioStreamOggVorbis = menu_player.stream as AudioStreamOggVorbis
	clips.call("tick", speaker)
	check(menu_ogg != null and menu_ogg.loop and clips.call("current_title") == "Yangonite" and not clips.call("can_skip") and not clips.call("skip", speaker), "the menu loops Yangonite and ignores skip")
	menu_ogg.loop = false
	clips.call("play_faction", speaker, "nmrf")
	var faction_player: AudioStreamPlayer = speaker.get_node_or_null("FactionMusic") as AudioStreamPlayer
	check(faction_player != null and faction_player.playing and faction_player.stream != null, "faction music starts")
	var first_song: String = str(clips.call("current_title"))
	var skipped: bool = clips.call("skip", speaker)
	var second_song: String = str(clips.call("current_title"))
	check(skipped and second_song != first_song and second_song != "" and faction_player.playing and rotation_titles.has(second_song), "skip moves the match to the next song in the rotation")
	var faction_ogg: AudioStreamOggVorbis = faction_player.stream as AudioStreamOggVorbis
	check(faction_ogg != null and not faction_ogg.loop, "match songs play through once")
	clips.call("play_faction", speaker, "gtfc")
	var third_song: String = str(clips.call("current_title"))
	check(third_song != second_song and rotation_titles.has(third_song), "the next map continues the same rotation instead of a faction list")
	clips.call("play_sting", speaker, true)
	var victory_player: AudioStreamPlayer = speaker.get_node_or_null("StingMusic") as AudioStreamPlayer
	var victory_ogg: AudioStreamOggVorbis = null
	if victory_player != null:
		victory_ogg = victory_player.stream as AudioStreamOggVorbis
	check(victory_player != null and victory_player.playing and victory_ogg != null and not victory_ogg.loop and not faction_player.playing, "the victory sting plays once and the faction loop stops")
	if victory_player != null:
		victory_player.stop()
	clips.call("play_sting", speaker, false)
	var defeat_player: AudioStreamPlayer = speaker.get_node_or_null("StingMusic") as AudioStreamPlayer
	check(defeat_player != null and defeat_player.playing and defeat_player.stream != victory_ogg, "the defeat sting plays")
	speaker.free()
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var unit: RTSUnit = _unit_kind(field, 0, "militia")
	var foe: RTSUnit = field.units_of(1)[0]
	var bar: MeshInstance3D = unit.get_node_or_null("HealthBar") as MeshInstance3D
	check(bar != null, "a unit carries a health bar")
	for u: RTSUnit in field.units:
		u.stop()
	unit.take_damage(unit.max_hp * 0.5)
	field.tick(0.05)
	check(bar.scale.x > 0.3 and bar.scale.x < 0.6, "the health bar shrinks with the hit")
	unit.fired.emit(unit, foe)
	var muzzle: MeshInstance3D = unit.get_node_or_null("Muzzle") as MeshInstance3D
	var flashed: bool = muzzle != null and muzzle.visible
	field.tick(0.2)
	check(flashed and muzzle != null and not muzzle.visible, "a shot flashes the muzzle, then it fades")
	field.announce(unit, "select")
	var radio: Label = scene.find_child("RadioLine", true, false) as Label
	check(radio != null and radio.visible and radio.text == "Militia holding.", "select puts the line on the radio")
	unit.set_meta("status", "shrunk")
	field.announce(unit, "hurt")
	var voice: AudioStreamPlayer = scene.find_child("BarkPlayer", true, false) as AudioStreamPlayer
	check(voice != null and absf(voice.pitch_scale - 1.6) < 0.01, "a shrunk unit barks higher")
	var other: RTSUnit = _unit_kind(field, 0, "slag_hauler")
	other.take_damage(other.max_hp)
	field.tick(0.05)
	var wreck: Node = _order_ping(field, "wreck")
	check(wreck != null and wreck.is_inside_tree() and wreck.name == "Wreck", "a destroyed unit leaves a wreck")
	field.tick(1.0)
	await process_frame
	check(_order_ping(field, "wreck") == null, "the wreck fades")
	scene.free()
	await process_frame
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func test_sm_orders_mark() -> void:
	var hint: String = SMGuide.controls_hint()
	var howto: String = SMGuide.howto_text()
	check(hint.contains("Right-click") and hint.contains("ring") and hint.contains("minimap") and hint.contains("F") and hint.contains("H"), "the controls hint names the order ring and the minimap")
	check(howto.contains("ring") and howto.contains("weapon range") and howto.contains("minimap") and howto.contains("Objective complete"), "the how-to says a ring marks the order and the minimap jumps")
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var unit: RTSUnit = _unit_kind(field, 0, "militia")
	var picked: RTSUnit = field.select_click(_proj(unit.global_position), Callable(self, "_proj"))
	field.tick(0.05)
	var reach: MeshInstance3D = unit.get_node_or_null("RangeRing") as MeshInstance3D
	check(reach != null and reach.visible and absf(reach.scale.x - unit.attack_range) < 0.05, "a selected unit shows its weapon range")
	var named: Label3D = unit.get_node_or_null("NameTag") as Label3D
	var other_unit: RTSUnit = _unit_kind(field, 0, "slag_hauler")
	var other_tag: Label3D = other_unit.get_node_or_null("NameTag") as Label3D if other_unit != null else null
	check(named != null and named.visible and other_tag != null and not other_tag.visible, "only the selected unit shows its name")
	field.select_only([unit, other_unit])
	field.tick(0.05)
	var stacked: int = 0
	if named.visible:
		stacked += 1
	if other_tag.visible:
		stacked += 1
	check(stacked == 1, "a stacked selection keeps a single name tag")
	field.select_only([unit])
	field.tick(0.05)
	var phillips_status: Label = scene.find_child("Status", true, false) as Label
	check(phillips_status != null and phillips_status.visible and phillips_status.text.contains("yard"), "the skirmish hint stays on screen")
	var step: Vector3 = unit.global_position + Vector3(8.0, 0.0, 0.0)
	var moved: StringName = field.command_at(step, _proj(step), Callable(self, "_proj"))
	var move_ping: Node = _order_ping(field, "move")
	check(picked == unit and moved == &"move" and move_ping != null and move_ping.is_inside_tree(), "a move order drops a ring on the ground")
	var foe: RTSUnit = field.units_of(1)[0]
	var attacked: StringName = field.command_at(foe.global_position, _proj(foe.global_position), Callable(self, "_proj"))
	var attack_ping: Node = _order_ping(field, "attack")
	check(attacked == &"attack" and attack_ping != null and attack_ping.is_inside_tree(), "an attack order drops a ring on the enemy")
	field.tick(1.3)
	await process_frame
	check(_order_ping(field, "move") == null and _order_ping(field, "attack") == null, "order rings fade after a moment")
	var mm: SMMinimap = scene.find_child("Minimap", true, false) as SMMinimap
	var jumped: Vector3 = mm.pan_to(Vector2(190, 10))
	check(mm != null and mm.camera.focus.distance_to(jumped) < 1.0 and mm.covers_focus(), "a minimap click jumps the camera")
	field.selection.clear()
	field.tick(0.05)
	check(reach != null and not reach.visible, "the range ring hides when the unit is deselected")
	unit.path = PackedVector3Array()
	unit.attack_target = null
	unit.set_meta("hunt", false)
	var prowler: RTSUnit = field.spawn(SMPointer.ENEMY, unit.global_position, &"raider")
	prowler.incoming_mult = 1.0
	var idle_hp: float = prowler.hp
	field.tick(1.2)
	check(prowler.hp < idle_hp, "an idle skirmish unit shoots an enemy in range")
	scene.free()
	await process_frame
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func test_sm_goal() -> void:
	SMCampaign.selected = "kokang"
	var raid: Node = (load("res://game/mission_kokang.tscn") as PackedScene).instantiate()
	root.add_child(raid)
	await process_frame
	var raid_status: Label = raid.find_child("Status", true, false) as Label
	check(raid_status != null and raid_status.text.contains("raise the yard") and raid_status.text.contains("rare-earth"), "kokang shows the yard, ruby, and rare-earth goal")
	raid.free()
	await process_frame
	SMCampaign.selected = "operation_1027"
	var wave: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(wave)
	await process_frame
	var wave_status: Label = wave.find_child("Status", true, false) as Label
	check(wave_status != null and wave_status.text.contains("EW towers (2)") and wave_status.text.contains("hangars (2)"), "1027 shows towers before hangars")
	var wave_field: SMPointer = wave.get("field") as SMPointer
	var wave_story: SMStory = wave.get("story") as SMStory
	var jammer_damage: float = -1.0
	for jammer: RTSUnit in wave_field.units_of(1):
		if str(jammer.get_meta("duty", "")) == "tower":
			jammer_damage = jammer.attack_damage
			break
	check(is_zero_approx(jammer_damage), "EW towers jam and do not shoot")
	var shooter: RTSUnit = wave_field.units_of(0)[0]
	var victim: RTSUnit = wave_field.units_of(1)[0]
	shooter.global_position = victim.global_position
	shooter.attack_target = null
	var before_hp: float = victim.hp
	wave_story.tick(0.1)
	wave_field.tick(1.2)
	check(victim.hp < before_hp, "an idle company shoots an enemy that walks into range")
	for other: RTSUnit in wave_field.units_of(1):
		other.global_position = Vector3(30.0, 0.0, 30.0)
	var close: RTSUnit = wave_field.units_of(1)[0]
	var far_one: RTSUnit = wave_field.units_of(1)[1]
	close.global_position = shooter.global_position
	close.incoming_mult = 1.0
	shooter.attack_target = far_one
	var close_hp: float = close.hp
	wave_story.tick(0.1)
	wave_field.tick(1.2)
	check(close.hp < close_hp, "a marching company still shoots the enemy in its face")
	wave.free()
	await process_frame
	SMCampaign.selected = "tonle_sap"
	var ferry: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(ferry)
	await process_frame
	var ferry_status: Label = ferry.find_child("Status", true, false) as Label
	var ferry_story: SMStory = ferry.get("story") as SMStory
	var shown: int = int(ceil(ferry_story.hold_left))
	check(ferry_status != null and ferry_status.text.contains("ferry") and ferry_status.text.contains(str(shown)), "tonle sap shows the ferry timer")
	ferry._process(1.0)
	var next: int = int(ceil(ferry_story.hold_left))
	check(next < shown and ferry_status.text.contains(str(next)), "the ferry timer counts down")
	ferry.free()
	await process_frame
	SMCampaign.selected = "keng_tung"
	var column: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(column)
	await process_frame
	var column_status: Label = column.find_child("Status", true, false) as Label
	check(column_status != null and column_status.text.contains("Freeze the column (0/3)"), "keng tung says to freeze the column first")
	column.free()
	await process_frame
	SMCampaign.selected = "black_haze"
	var haze: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(haze)
	await process_frame
	var haze_status: Label = haze.find_child("Status", true, false) as Label
	check(haze_status != null and haze_status.text.contains("Capture the radar") and haze_status.text.contains("haze"), "black haze says to capture the radar before the hold")
	haze.free()
	await process_frame
	SMCampaign.selected = "tachileik"
	var ambush: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(ambush)
	await process_frame
	var field: SMPointer = ambush.get("field") as SMPointer
	_wipe(field.units_of(0))
	ambush._process(0.2)
	var ambush_status: Label = ambush.find_child("Status", true, false) as Label
	check(ambush_status != null and ambush_status.text == "Objective failed", "a wiped company still reads Objective failed")
	ambush.free()
	await process_frame
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func _order_ping(field: SMPointer, order: String) -> Node:
	for mark: Node3D in field.marks:
		if is_instance_valid(mark) and str(mark.get_meta("order", "")) == order:
			return mark
	return null

func test_sm_command() -> void:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var field: SMPointer = SMPointer.new()
	preload("res://game/sim_presenter.gd").follow_pointer(field)
	field.bind(host, cam)
	field.use_open(24, 24, 2.0, Vector3(-24.0, 0.0, -24.0))
	var a: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3.ZERO, &"militia")
	var b: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(2.0, 0.0, 0.0), &"militia")
	var foe: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(30.0, 0.0, 30.0), &"raider")
	field.select_only([a, b])
	check(field.bind_group(1, true) == 2 and field.group_note == "Group 1 stored", "ctrl-1 stores the company")
	field.selection.clear()
	check(field.bind_group(1, false) == 2 and a.selected and b.selected, "1 recalls the stored company")
	var focus: Vector3 = field.selection_focus()
	check(focus.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.2, "a recalled group has a camera focus")
	a.set_path(PackedVector3Array([Vector3(6.0, 0.0, 4.0)]))
	field.tick(0.05)
	var diamond: MeshInstance3D = host.get_node_or_null("PathMark") as MeshInstance3D
	check(diamond != null and diamond.visible and absf(diamond.position.x - 6.0) < 0.2, "the lead unit shows its next waypoint")
	field.halt_selected()
	field.tick(0.05)
	check(a.path.is_empty() and not bool(a.get_meta("hunt", false)) and diamond != null and not diamond.visible, "X halts the company and clears the waypoint")
	var sent: int = field.attack_move_at(Vector3(8.0, 0.0, 0.0))
	check(sent == 2 and bool(a.get_meta("hunt", false)) and not a.path.is_empty() and _order_ping(field, "attack") != null, "Q sends an attack-move and marks it")
	foe.global_position = a.global_position + Vector3(2.0, 0.0, 0.0)
	a.attack_range = 6.0
	field.tick(0.05)
	check(a.attack_target == foe, "attack-move shoots a unit in range")
	foe.global_position = Vector3(30.0, 0.0, 30.0)
	a.attack_target = null
	var moved: StringName = field.command_at(Vector3(-6.0, 0.0, -2.0), Vector2(-800.0, -800.0), Callable(self, "_proj"))
	check(moved == &"move" and not bool(a.get_meta("hunt", false)), "a move order cancels attack-move")
	var victim: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(20.0, 0.0, -20.0), &"raider")
	victim.take_damage(12.0)
	field.tick(0.05)
	var pop: Label3D = victim.get_node_or_null("DamagePop") as Label3D
	check(pop != null and pop.visible and pop.text == "-12", "a hit floats a damage number")
	field.place_beacon(Vector3(3.0, 0.0, -2.0))
	var pole: MeshInstance3D = host.get_node_or_null("GoalBeacon") as MeshInstance3D
	check(pole != null and pole.visible and absf(pole.position.x - 3.0) < 0.1, "the goal beacon stands on the objective")
	field.place_beacon(Vector3.INF)
	check(pole != null and not pole.visible, "the beacon hides when the objective is done")
	var anchor: Vector3 = field.enemy_anchor()
	check(anchor != Vector3.INF, "skirmish beacons the enemy force")
	host.free()
	await process_frame
	SMCampaign.selected = "operation_1027"
	var wave: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(wave)
	await process_frame
	var wave_story: SMStory = wave.get("story") as SMStory
	var wave_at: Vector3 = wave_story.beacon()
	check(absf(wave_at.x - 9.0) < 0.2 and (absf(wave_at.z - 5.0) < 0.2 or absf(wave_at.z + 5.0) < 0.2), "1027 beacons a living EW tower")
	wave._process(0.05)
	var planted: Node = wave.find_child("GoalBeacon", true, false)
	check(planted != null and planted.visible, "the mission plants the beacon on the field")
	wave.free()
	await process_frame
	SMCampaign.selected = "kokang"
	var raid: Node = (load("res://game/mission_kokang.tscn") as PackedScene).instantiate()
	root.add_child(raid)
	await process_frame
	var raid_story: SMStory = raid.get("story") as SMStory
	var raid_at: Vector3 = raid_story.beacon()
	check(raid_at.distance_to(Vector3.ZERO) < 0.2, "kokang beacons the yard before it is raised")
	raid.free()
	await process_frame
	var hint: String = SMGuide.controls_hint()
	var howto: String = SMGuide.howto_text()
	check(hint.contains("attack-move") and hint.contains("Ctrl") and howto.contains("floating number") and howto.contains("objective"), "the guide names groups, attack-move, and the objective marker")
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func test_sm_pick() -> void:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var field: SMPointer = SMPointer.new()
	field.bind(host, cam)
	field.use_open(30, 30, 2.0, Vector3(-30.0, 0.0, -30.0))
	var a: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3.ZERO, &"militia")
	var b: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(2.0, 0.0, 0.0), &"militia")
	var c: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(4.0, 0.0, 0.0), &"militia")
	var tank: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(0.0, 0.0, 4.0), &"amber_tank")
	var project: Callable = Callable(self, "_proj")
	field.select_click(_proj(a.global_position), project)
	field.select_click(_proj(b.global_position), project, true, false)
	check(a.selected and b.selected and field.selection.count() == 2, "shift-click adds to the selection")
	field.select_click(_proj(b.global_position), project, false, true)
	check(a.selected and not b.selected, "ctrl-click toggles a unit off")
	field.select_click(_proj(a.global_position), project)
	field.select_click(_proj(a.global_position), project)
	check(a.selected and b.selected and c.selected and not tank.selected, "a double-click selects every unit of that type")
	field.selection.clear()
	check(field.select_same() == 4 and tank.selected, "E with nothing selected takes the company")
	field.select_only([a])
	check(field.select_same() == 3 and not tank.selected, "E selects every unit of the current type")
	field.select_only([a, b, c])
	field.toggle_line()
	var lined: StringName = field.command_at(Vector3(14.0, 0.0, 0.0), Vector2(-800.0, -800.0), project)
	var low_x: float = 1000.0
	var high_x: float = -1000.0
	var low_z: float = 1000.0
	var high_z: float = -1000.0
	for u: RTSUnit in [a, b, c]:
		if u.path.is_empty():
			continue
		var end: Vector3 = u.path[u.path.size() - 1]
		low_x = minf(low_x, end.x)
		high_x = maxf(high_x, end.x)
		low_z = minf(low_z, end.z)
		high_z = maxf(high_z, end.z)
	check(lined == &"move" and not a.path.is_empty() and (high_z - low_z) > (high_x - low_x) + 0.5, "Z lines the company up")
	field.select_only([a])
	field.command_at(Vector3(8.0, 0.0, 0.0), Vector2(-800.0, -800.0), project)
	var steps: int = a.path.size()
	var queued: StringName = field.command_at(Vector3(8.0, 0.0, 8.0), Vector2(-800.0, -800.0), project, true)
	check(queued == &"move" and a.path.size() > steps and field.group_note == "Waypoint", "shift-right-click adds a waypoint")
	host.free()
	await process_frame
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var hud: SMHud = scene.get("hud") as SMHud
	hud.set_rally(Vector3(8.0, 0.0, -4.0))
	var flag: MeshInstance3D = scene.get_node_or_null("RallyFlag") as MeshInstance3D
	check(flag != null and flag.visible and absf(flag.position.x - 8.0) < 0.05 and absf(flag.position.z + 4.0) < 0.05, "R moves the rally flag")
	var roster: SMRoster = scene.get("roster") as SMRoster
	roster.economy.set_credits(0, roster.economy.credits(0) + 30)
	hud._apply_purse(1.0)
	check(hud.purse_flash == "+30" and hud.income_label.text.contains("+30"), "the top bar shows credits gained")
	var hint: String = SMGuide.controls_hint()
	var howto: String = SMGuide.howto_text()
	check(hint.contains("rally") and hint.contains("waypoint") and howto.contains("credits gained"), "the guide names the rally flag, waypoints, and income")
	scene.free()
	await process_frame
	SMCampaign.selected = "tachileik"
	SMFront.faction_id = "gtfc"

func test_sm_monsoon() -> void:
	var sky: SMSight = SMSight.new()
	sky.advance_weather(8.0)
	check(sky.weather_name == "Monsoon" and is_equal_approx(sky.ground_drag(), 0.55) and sky.unit_radius(false) < SMSight.UNIT_RADIUS and is_equal_approx(sky.unit_radius(true), SMSight.UNIT_RADIUS), "monsoon muddies the ground and shortens sight unless a radar is held")
	sky.advance_weather(8.0)
	check(sky.weather_name == "Strait Haze" and is_equal_approx(sky.ground_drag(), 1.0) and sky.hazy and not sky.monsoon, "the cycle then names Strait Haze and the mud lifts")
	sky.force_weather(true)
	check(sky.weather_name == "Strait Haze" and sky.unit_radius(false) < SMSight.UNIT_RADIUS and is_equal_approx(sky.unit_radius(true), SMSight.UNIT_RADIUS), "forcing haze still means Strait Haze")
	var clear_u: RTSUnit = RTSUnit.new()
	clear_u.speed = 10.0
	clear_u.position = Vector3.ZERO
	clear_u.set_path(PackedVector3Array([Vector3(40.0, 0.0, 0.0)]))
	root.add_child(clear_u)
	var mud_u: RTSUnit = RTSUnit.new()
	mud_u.speed = 10.0
	mud_u.position = Vector3.ZERO
	mud_u.set_meta("weather_drag", 0.55)
	mud_u.set_path(PackedVector3Array([Vector3(40.0, 0.0, 0.0)]))
	root.add_child(mud_u)
	clear_u.advance(1.0)
	Weather.step(mud_u, 1.0)
	check(is_equal_approx(clear_u.position.x, 10.0) and is_equal_approx(mud_u.position.x, 5.5), "monsoon cuts a ground step to just over half")
	clear_u.free()
	mud_u.free()
	check(SMGuide.howto_text().contains("Monsoon") and SMGuide.howto_text().contains("bridge") and SMGuide.howto_text().contains("CH-4") and SMGuide.howto_text().contains("Low power") and SMGuide.howto_text().contains("Cancel") and SMGuide.howto_text().contains("river"), "the how-to names monsoon, bridges, and the black market")
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/mekong_delta.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var sim: SMMatch = scene.get("sim") as SMMatch
	var book: SMSight = scene.get("sight") as SMSight
	book.force_monsoon(true)
	SMSight.update_match(book, field, scene as Node3D, sim.tech, scene.get("raider") as SMRaider)
	(scene.get("hud") as SMHud).refresh()
	var walker: RTSUnit = field.units_of(0)[0]
	check(_hud_text(scene, "HudWeather") == "Monsoon", "the hud names the monsoon")
	check(is_equal_approx(float(walker.get_meta("weather_drag", 1.0)), 0.55), "monsoon slows the company on the field")
	var rain: MeshInstance3D = scene.get_node_or_null("Rain") as MeshInstance3D
	var paddy: MeshInstance3D = scene.get_node_or_null("Paddy") as MeshInstance3D
	var canal: MeshInstance3D = scene.get_node_or_null("CanalWest") as MeshInstance3D
	check(rain != null and rain.visible and rain.get_active_material(0) is ShaderMaterial, "monsoon draws rain streaks")
	check(paddy != null and paddy.mesh != null and canal != null and canal.get_active_material(0) is ShaderMaterial, "mekong paddies sit beside shaded canals")
	book.force_weather(true)
	SMSight.update_match(book, field, scene as Node3D, sim.tech, scene.get("raider") as SMRaider)
	var sky_env: WorldEnvironment = scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	check(sky_env != null and sky_env.environment != null and sky_env.environment.fog_enabled and rain != null and not rain.visible, "haze tints the fog and the rain stops")
	book.force_monsoon(true)
	SMSight.update_match(book, field, scene as Node3D, sim.tech, scene.get("raider") as SMRaider)
	var span: Vector3 = sim.tech.site_pos(&"bridge_a")
	walker.global_position = span + Vector3(-6.0, 0.0, 0.0)
	walker.attack_damage = 80.0
	field.select_only([walker])
	var ordered: StringName = field.command_at(span, Vector2(-8000.0, -8000.0), Callable(self, "_proj"))
	check(ordered == &"attack" and str(walker.get_meta("bridge_id", "")) == "bridge_a", "right-click orders a Mekong bridge")
	var fell: bool = false
	for _step: int in 8:
		field.tick(0.2)
		if not sim.tech.bridge_alive(&"bridge_a"):
			fell = true
			break
	var deep: int = SMDomainGrid.Domain.DEEP
	var land: int = SMDomainGrid.Domain.LAND
	var north_span: Rect2i = sim._bridge_span(&"bridge_a")
	var south_span: Rect2i = sim._bridge_span(&"bridge_b")
	check(fell and sim.grid.domain_at_cell(north_span.position + Vector2i(1, 0)) == deep and sim.grid.domain_at_cell(north_span.position + Vector2i(1, 1)) == deep, "the north span falls into the canal")
	var plate: MeshInstance3D = scene.get_node_or_null("Bridge_bridge_a") as MeshInstance3D
	var deck: MeshInstance3D = scene.get_node_or_null("BridgeWest") as MeshInstance3D
	var box: BoxMesh = deck.mesh as BoxMesh if deck != null else null
	check(sim.grid.domain_at_cell(south_span.position + Vector2i(1, 0)) == land and sim.grid.domain_at_cell(south_span.position + Vector2i(1, 1)) == land and plate != null and plate.position.y < 0.0 and deck != null and deck.visible and box != null and is_equal_approx(box.size.z, 8.0), "the south span stays up and the fallen deck sinks")
	var south: Vector3 = sim.tech.site_pos(&"bridge_b")
	walker.global_position = south + Vector3(-6.0, 0.0, 0.0)
	field.select_only([walker])
	field.command_at(south, Vector2(-8000.0, -8000.0), Callable(self, "_proj"))
	for _south_step: int in 8:
		field.tick(0.2)
		if not sim.tech.bridge_alive(&"bridge_b"):
			break
	var west: Vector3 = sim.grid.cell_center(SMMapPlan.of("mekong_delta").start(0))
	var east: Vector3 = sim.grid.cell_center(Vector2i(26, 24))
	check(not sim.tech.bridge_alive(&"bridge_b") and deck != null and not deck.visible, "both west spans drop and the deck is gone")
	check(field.nav_ground.find_path(west, east).is_empty() and field.nav_amphib.find_path(west, east).size() > 0, "ground stops at the open canal and a boat still crosses")
	var fresh: SMDomainGrid = SMDomainGrid.mekong_delta_layout()
	check(fresh.domain_at_cell(north_span.position + Vector2i(1, 1)) == land and fresh.domain_at_cell(sim._bridge_span(&"bridge_c").position + Vector2i(1, 0)) == land, "a fresh Mekong layout still keeps both bridges")
	scene.free()
	await process_frame
	var sop: Node = (load("res://game/sop_ruak.tscn") as PackedScene).instantiate()
	root.add_child(sop)
	await process_frame
	check(sop.find_child("Import_ch4", true, false) == null, "imports stay hidden until a bazaar is held")
	var sop_sim: SMMatch = sop.get("sim") as SMMatch
	sop_sim.tech.capture(&"bazaar", 0)
	(sop.get("hud") as SMHud).refresh()
	var buy: Button = sop.find_child("Import_ch4", true, false) as Button
	check(buy != null and buy.visible and str(buy.get_meta("caption", buy.text)) == "CH-4" and (buy.text == "CH-4" or buy.icon != null), "a captured bazaar lists the CH-4")
	var sop_field: SMPointer = sop.get("field") as SMPointer
	var purse: SMRoster = sop.get("roster") as SMRoster
	var before_n: int = sop_field.count_team(0)
	var before_c: int = purse.economy.credits(0)
	buy.pressed.emit()
	var company: Array[RTSUnit] = sop_field.units_of(0)
	var bought: RTSUnit = company[company.size() - 1]
	check(sop_field.count_team(0) == before_n + 1 and purse.economy.credits(0) == before_c - 340 and sop_field.name_of(bought) == "CH-4" and str(bought.get_meta("locomotion", "")) == "air", "buying the CH-4 spends 340 and spawns it")
	var raider: SMRaider = sop.get("raider") as SMRaider
	raider.economy.set_credits(1, 200)
	var skim_before: int = purse.economy.credits(0)
	var cyber_before: int = sop_sim.tech.income_of(&"cyber_a")
	sop.set_process(false)
	sop_sim.tech.skim_frac = 0.0
	purse.economy.set_credits(1, 0)
	raider.economy.set_credits(1, 200)
	sop.call("tick_world", 1.0)
	var skim_got: int = purse.economy.credits(0) - skim_before
	var cyber_gain: int = sop_sim.tech.income_of(&"cyber_a") - cyber_before
	check(raider.economy.credits(1) == 190 and sop_sim.tech.siphon_of(&"bazaar") == 10 and skim_got == 10 + cyber_gain, "the bazaar skims five percent of the enemy purse")
	sop.free()
	await process_frame
	SMFront.faction_id = "gtfc"

func test_sm_boot() -> void:
	SMSave.clear()
	SMFront.faction_id = "gtfc"
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	check(boot.find_child("TabSkirmish", true, false) != null and boot.find_child("TabCampaign", true, false) != null and boot.find_child("TabFaction", true, false) != null, "boot has three tabs")
	var game_title: Label = boot.find_child("GameTitle", true, false) as Label
	var control_bar: Label = boot.find_child("ControlBar", true, false) as Label
	var title_font: Font = game_title.get_theme_font("font") if game_title != null else null
	var bar_font: Font = control_bar.get_theme_font("font") if control_bar != null else null
	check(game_title != null and game_title.text == "ASEAN 2031" and str(ProjectSettings.get_setting("application/config/name")) == "ASEAN 2031", "the boot title and window title are ASEAN 2031")
	check(title_font != null and title_font.resource_path.contains("Warheed") and game_title.theme_type_variation == "Header", "the boot title uses Warheed")
	check(bar_font != null and bar_font.resource_path.contains("OperationNapalm"), "the control bar uses Operation Napalm")
	check(SMCampaign.title_of("shattered_monsoon") == "Operation Shattered Monsoon", "the final mission keeps its story name")
	check(_bar_ok(boot), "the control bar lists select, move, ability, pan, and zoom")
	var play: Button = boot.find_child("PlayButton", true, false) as Button
	check(play != null and play.disabled, "play waits for a map")
	var submenu: Control = boot.find_child("FactionSubmenu", true, false) as Control
	check(boot.find_child("MenuBackdrop", true, false) != null and submenu != null and not submenu.visible and SMTone.peak(SMTone.cue("ui_click")) > 1000 and SMTone.peak(SMTone.cue("ui_hover")) > 1000, "the menu starts folded, with a sunburst and audible plates")
	check(_card_line(boot, "CardPhillips", "Phillips Channel", "Water"), "phillips is a water card")
	check(_card_line(boot, "CardSopRuak", "Sop Ruak", "River"), "sop ruak is a river card")
	check(_card_line(boot, "CardBurma", "Burma Road", "Land"), "burma road is a land card")
	check(_card_line(boot, "CardAtolls", "Ten Degree Atolls", "Water"), "the atolls are a water card")
	check(_card_line(boot, "CardMekong", "Mekong Delta", "River"), "the mekong is a river card")
	check(_card_line(boot, "CardChiang", "Siege of Chiang Rai", "River"), "chiang rai is a river card")
	var showcase_card: Button = boot.find_child("CardShowcase", true, false) as Button
	check(_card_line(boot, "CardShowcase", "Golden Confluence", "River") and showcase_card != null and str(showcase_card.get_meta("map_path", "")) == "res://game/showcase.tscn" and ResourceLoader.exists("res://game/showcase.tscn"), "golden confluence is a river card that opens the showcase map")
	check(boot.call("_map_preview", "res://game/showcase.tscn") != null and str(boot.call("_mission_title", "res://game/showcase.tscn")) == "Golden Confluence", "golden confluence has a map preview and a loading title")
	var burma_card: Button = boot.find_child("CardBurma", true, false) as Button
	burma_card.pressed.emit()
	check(str(boot.get("selected_map")).contains("burma_road") and not play.disabled, "a card arms play")
	check(boot.find_child("GreyboxButton", true, false) != null, "greybox stays on the skirmish tab")
	var campaign: Button = boot.find_child("TabCampaign", true, false) as Button
	campaign.pressed.emit()
	var folded: Control = boot.find_child("FactionSubmenu", true, false) as Control
	var act1: Control = boot.find_child("ActIMissions", true, false) as Control
	var act2: Control = boot.find_child("ActIIMissions", true, false) as Control
	var act3: Control = boot.find_child("ActIIIMissions", true, false) as Control
	check(boot.find_child("MenuBackdrop", true, false) != null and folded != null and folded.is_visible_in_tree() and act1 != null and not act1.is_visible_in_tree(), "campaign opens the faction plates inline")
	var faction_plate: Button = boot.find_child("FactionGtfc", true, false) as Button
	faction_plate.pressed.emit()
	check(act1 != null and act1.is_visible_in_tree() and act2 != null and not act2.is_visible_in_tree() and act3 != null and not act3.is_visible_in_tree(), "only the selected act is listed")
	check(_bar_ok(boot), "the control bar stays up on campaign")
	var act2_button: Button = boot.find_child("ActII", true, false) as Button
	act2_button.pressed.emit()
	check(act2.is_visible_in_tree() and not act1.is_visible_in_tree(), "act two replaces act one")
	var crossing: Button = boot.find_child("Mission_ghosts_of_patani", true, false) as Button
	var crossing_brief: Label = boot.find_child("Brief_ghosts_of_patani", true, false) as Label
	check(crossing != null and crossing.text == SMCampaign.title_of("ghosts_of_patani") and crossing_brief != null and crossing_brief.text == SMCampaign.briefing_of("ghosts_of_patani") and crossing.is_visible_in_tree(), "act two shows Ghosts of Patani")
	var faction_tab: Button = boot.find_child("TabFaction", true, false) as Button
	faction_tab.pressed.emit()
	check(_faction_line(boot, "FactionGtfc", "GTFC", "Scaffold yard", "#B81E2D"), "gtfc shows its color and build style")
	check(_faction_line(boot, "FactionNmrf", "NMRF", "Mobile core", "#5A6824"), "nmrf shows its color and build style")
	check(_faction_line(boot, "FactionMvd", "MVD", "Internal queue", "#2A2E32"), "mvd shows its color and build style")
	var pick: Button = boot.find_child("FactionNmrf", true, false) as Button
	pick.pressed.emit()
	check(SMFront.faction_id == "nmrf", "the next skirmish uses the selected faction")
	check(_bar_ok(boot), "the control bar stays up on faction")
	boot.free()
	var scene: Node = (load("res://game/burma_road.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	check(_has_names(field, PackedStringArray(["Patani Corsair Guard", "Malacca Pocket-Sub", "Krakatoa Dreadnought", "Phillips Wave-Cannon", "Garuda Mecha-Overlord", "Johor Loiter-Swarm"])), "burma plays the selected nmrf side")
	var hud_title: Label = scene.find_child("HudTitle", true, false) as Label
	check(hud_title != null and hud_title.text == "ASEAN 2031" and hud_title.theme_type_variation == "Header", "the hud titles the match ASEAN 2031")
	check(scene.find_child("MovePacker", true, false) != null, "nmrf skirmish can move the packer")
	check(str(scene.call("train_unit")) == "Sulu Tank-Buster", "nmrf skirmish trains an nmrf unit")
	scene.free()
	SMFront.faction_id = "gtfc"
	check(SMFront.current() == "gtfc", "faction selection resets")
	await process_frame

func _spawned(faction: String, id: StringName, display: String, weapon: String, secondary: String, damage: float) -> bool:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var field: SMPointer = SMPointer.new()
	preload("res://game/sim_presenter.gd").follow_pointer(field)
	field.bind_faction(host, cam, faction)
	field.use_open(8, 8, 2.0, Vector3.ZERO)
	var roster: SMRoster = SMRoster.new()
	roster.setup(faction)
	var made: StringName = roster.train_and_finish(id)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3.ZERO, id)
	var ok: bool = made == id and field.name_of(u) == display and str(u.get_meta("weapon")) == weapon and str(u.get_meta("secondary")) == secondary and is_equal_approx(u.attack_damage, damage)
	host.free()
	return ok

func _trained(path: String) -> String:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var before: int = field.count_team(0)
	var label: String = str(scene.call("train_unit"))
	var grew: bool = field.count_team(0) == before + 1
	scene.free()
	await process_frame
	if not grew:
		return ""
	return label

func _duel(personality: StringName, map_id: String, foe: StringName, needs_water: bool, limit: float = 45.0) -> bool:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var bot: SMBot = SMBot.new(personality)
	var other: SMBot = SMBot.new(foe)
	var result: Dictionary = bot.fight(other, map_id, limit, host)
	var ok: bool = bool(result["won"]) and float(result["time"]) <= limit and bool(result["scout_first"]) and bool(result["muster"]) and bool(result["flank"]) and bool(result["retreat"]) and bool(result["rebuilt"]) and bool(result["protocol"]) and bool(result["ability"]) and bool(result["power"]) and (not needs_water or bool(result["water"]))
	duel_note = "" if ok else bot.last_note
	host.free()
	return ok

func _passive_macro() -> void:
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/sop_ruak.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var steps: int = 0
	while steps < 600:
		scene._process(0.5)
		steps += 1
	var field: SMPointer = scene.get("field") as SMPointer
	var raider: SMRaider = scene.get("raider") as SMRaider
	var end: SMOutcome = scene.get("outcome") as SMOutcome
	var player_n: int = field.units_of(SMPointer.PLAYER).size()
	check(player_n > 0 and end != null and not end.over, "a passive company is still standing after five minutes")
	check(raider.fielded >= 15, "the bot has fielded at least fifteen units")
	var plant: bool = raider.power_id != &"" and raider.yard.structure_alive(raider.power_id)
	var barracks: bool = raider.barracks_id != &"" and raider.yard.structure_alive(raider.barracks_id)
	var factory: bool = raider.factory_id != &"" and raider.yard.structure_alive(raider.factory_id)
	check(plant and barracks and factory, "the bot finished a plant, barracks, and factory")
	check(raider.naval_id != &"" and raider.yard.structure_alive(raider.naval_id), "Sop Ruak's water gets a naval yard")
	scene.free()
	await process_frame
	SMFront.faction_id = "gtfc"

func _enemy_fights(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var raider: SMRaider = scene.get("raider") as SMRaider
	var field: SMPointer = scene.get("field") as SMPointer
	var foe: RTSUnit = field.units_of(1)[0]
	var label: String = path.get_file()
	check(raider != null and raider.built and raider.yard.finished.has(&"enemy_yard") and scene.get_node_or_null("EnemyYard") is MeshInstance3D, "%s enemy builds a yard" % label)
	check(raider.expanded and raider.goods.has_collector(raider.node_id) and scene.get_node_or_null("EnemyClaim") is MeshInstance3D, "%s enemy expands onto a ruby node" % label)
	check(raider.attacked and foe.attack_target != null and foe.attack_target.team == 0 and (foe.is_moving() or foe.attack_target.hp < foe.attack_target.max_hp), "%s enemy attacks the player" % label)
	scene.free()
	await process_frame

func _orders(scene: Node, field: SMPointer) -> bool:
	if scene.find_child("SelectionBox", true, false) == null:
		return false
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	if picked != friends[0] or field.selection.count() != 1:
		return false
	var grid: SMDomainGrid = scene.get("grid") as SMDomainGrid
	var step: Vector3 = grid.cell_center(Vector2i(2, 6))
	if field.command_at(step, _proj(step), Callable(self, "_proj")) != &"move" or not friends[0].is_moving():
		return false
	var foes: Array[RTSUnit] = field.units_of(1)
	if field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj")) != &"attack":
		return false
	if friends[0].attack_target != foes[0]:
		return false
	return bool(scene.call("fire_ability"))

func _proportion_fault() -> String:
	var buildings: Dictionary = {}
	var also_unit: Dictionary = {}
	var factions: PackedStringArray = PackedStringArray(["gtfc", "mvd", "nmrf", "black_market"])
	for faction: String in factions:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/factions/%s/faction.json" % faction))
		var data: Dictionary = parsed as Dictionary
		if data.is_empty():
			return "faction %s" % faction
		var rows: Array = data.get("buildings", []) as Array
		for item: Variant in rows:
			if item is Dictionary:
				buildings[str((item as Dictionary).get("id", ""))] = true
		var troops: Array = data.get("units", []) as Array
		for item: Variant in troops:
			if item is Dictionary:
				also_unit[str((item as Dictionary).get("id", ""))] = true
	var specifics: PackedStringArray = PackedStringArray([
		"gtfc_airfield", "gtfc_naval_yard", "gtfc_war_factory",
		"mvd_airfield", "mvd_naval_yard", "mvd_war_factory",
		"nmrf_airfield", "nmrf_naval_yard", "nmrf_war_factory",
	])
	for extra: String in specifics:
		buildings[extra] = true
	var ids: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string("res://data/tripo_ids.txt").split("\n"):
		var name: String = line.strip_edges()
		if name != "":
			ids.append(name)
	var host: Node3D = Node3D.new()
	root.add_child(host)
	for id: String in ids:
		if buildings.has(id):
			var fault: String = _proportion_structure(host, id)
			if fault != "":
				host.free()
				return fault
		if not buildings.has(id) or also_unit.has(id):
			var unit_fault: String = _proportion_unit(host, id)
			if unit_fault != "":
				host.free()
				return unit_fault
	host.free()
	return ""

func _proportion_structure(host: Node3D, id: String) -> String:
	var node_name: String = id
	if id.begins_with("gtfc_") or id.begins_with("mvd_") or id.begins_with("nmrf_"):
		node_name = id.substr(id.find("_") + 1)
	var sample: MeshInstance3D = MeshInstance3D.new()
	sample.name = "Built_%s" % node_name
	sample.mesh = Forms.structure_mesh(Forms.structure_form(sample.name), Color.WHITE, SMPointer.BUILDING_SIZE.y)
	if sample.mesh == null:
		sample.free()
		return "%s mesh" % id
	var foot: AABB = sample.mesh.get_aabb()
	var span: float = maxf(foot.size.x, foot.size.z)
	host.add_child(sample)
	var dressed: bool = ModelBook.apply_structure(sample, id, Color.WHITE, Color.WHITE)
	var model: Node3D = sample.get_node_or_null("Model") as Node3D
	var wide: float = _horizontal_span(sample)
	var fault: String = ""
	if not dressed or model == null:
		fault = "%s missing" % id
	elif not _scales_even(sample):
		fault = "%s stretched" % id
	elif absf(wide - span) > maxf(0.05, span * 0.02):
		fault = "%s footprint %.2f vs %.2f" % [id, wide, span]
	elif not _height_kept(model):
		fault = "%s height" % id
	sample.free()
	return fault

func _proportion_unit(host: Node3D, id: String) -> String:
	var body: MeshInstance3D = Forms.dress_unit(id, "infantry", "ground", Color.WHITE)
	host.add_child(body)
	var model: Node3D = body.get_node_or_null("Model") as Node3D
	var fault: String = ""
	if model == null:
		fault = "%s missing" % id
	elif not _scales_even(body):
		fault = "%s stretched" % id
	elif not _height_kept(model):
		fault = "%s height" % id
	body.free()
	return fault

func _scales_even(root_node: Node) -> bool:
	var stack: Array[Node] = [root_node]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		var spatial: Node3D = node as Node3D
		if spatial != null:
			var s: Vector3 = spatial.scale
			if not is_equal_approx(s.x, s.y) or not is_equal_approx(s.y, s.z) or s.x <= 0.0:
				return false
		for child: Node in node.get_children():
			stack.append(child)
	return true

func _height_kept(model: Node3D) -> bool:
	var local: AABB = _mesh_bounds(model, true)
	var wide: float = maxf(local.size.x, local.size.z)
	if wide < 0.001 or local.size.y < 0.001:
		return false
	var src: float = local.size.y / wide
	var fitted: float = (local.size.y * model.scale.y) / maxf(wide * model.scale.x, 0.001)
	return absf(src - fitted) < 0.02 and model.scale.x > 0.02 and model.scale.x < 30.0

func _horizontal_span(root_node: Node3D) -> float:
	var box: AABB = _mesh_bounds(root_node, true)
	return maxf(box.size.x, box.size.z)

func _mesh_bounds(root_node: Node3D, world: bool) -> AABB:
	var box: AABB = AABB()
	var started: bool = false
	var meshes: Array[MeshInstance3D] = []
	var own: MeshInstance3D = root_node as MeshInstance3D
	if own != null and own.mesh != null and str(own.name) != "ContactShadow":
		meshes.append(own)
	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null and str(mesh_node.name) != "ContactShadow":
			meshes.append(mesh_node)
	for mesh_node: MeshInstance3D in meshes:
		var xf: Transform3D = Transform3D.IDENTITY
		if world:
			var walk: Node3D = mesh_node
			while walk != null and walk != root_node:
				xf = walk.transform * xf
				var parent: Node = walk.get_parent()
				walk = parent as Node3D
		var placed: AABB = xf * mesh_node.mesh.get_aabb()
		if not started:
			box = placed
			started = true
		else:
			box = box.merge(placed)
	return box

func _has_names(field: SMPointer, need: PackedStringArray) -> bool:
	var names: PackedStringArray = PackedStringArray()
	for u: RTSUnit in field.units_of(0):
		names.append(field.name_of(u))
	for item: String in need:
		if not names.has(item):
			return false
	return true

func _unit_kind(field: SMPointer, team: int, kind: String) -> RTSUnit:
	for u: RTSUnit in field.units_of(team):
		if str(u.unit_type) == kind:
			return u
	return null

func _mesh_kind(u: RTSUnit) -> String:
	if u == null:
		return ""
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body == null or u.get_node_or_null("NameTag") == null:
		return ""
	if body.mesh == null and str(body.get_meta("model", "")) == "":
		return ""
	return str(body.get_meta("form", ""))

func _shape_is(field: SMPointer, team: int, kind: String, want: String) -> bool:
	return _mesh_kind(_unit_kind(field, team, kind)) == want

func _yard_shown(node: MeshInstance3D) -> bool:
	if node == null:
		return false
	if str(node.get_meta("model", "")) != "":
		return true
	return _tall_mesh(node.mesh)

func _tall_mesh(mesh: Mesh) -> bool:
	if mesh == null:
		return false
	var aabb: AABB = mesh.get_aabb()
	return aabb.size.y > aabb.size.x and aabb.size.y > aabb.size.z

func _structure_forms(scene: Node, side: SMSide, field: SMPointer) -> bool:
	var ids: PackedStringArray = PackedStringArray(["salween_hydro", "slag_refinery", "barracks", "war_factory", "naval_yard"])
	var want: PackedStringArray = PackedStringArray(["power", "refinery", "barracks", "factory", "naval"])
	for i: int in ids.size():
		if side.order_building(StringName(ids[i])) != "built":
			return false
		var node: MeshInstance3D = scene.get_node_or_null("Built_%s" % ids[i]) as MeshInstance3D
		if node == null or str(node.get_meta("form", "")) != want[i]:
			return false
	var extra: PackedStringArray = PackedStringArray(["airfield", "slag_pillbox", "flak_slag_mast", "tech_center"])
	var extra_want: PackedStringArray = PackedStringArray(["airfield", "defense", "mast", "tech"])
	for i: int in extra.size():
		var sample: MeshInstance3D = MeshInstance3D.new()
		sample.name = "Built_%s" % extra[i]
		var dressed: bool = Forms.dress_structure(sample, SMPointer.BUILDING_SIZE, Color.WHITE)
		var got: String = str(sample.get_meta("form", ""))
		sample.free()
		if not dressed or got != extra_want[i]:
			return false
	if side.fire_super(field) <= 0:
		return false
	var needle: MeshInstance3D = scene.get_node_or_null("Super_seismic_imploder") as MeshInstance3D
	if needle == null or str(needle.get_meta("form", "")) != "super":
		return false
	var yard_node: MeshInstance3D = scene.get_node_or_null("PlayerYard") as MeshInstance3D
	if yard_node == null or str(yard_node.get_meta("form", "")) != "yard" or needle.mesh == null:
		return false
	if yard_node.mesh == null:
		return str(yard_node.get_meta("model", "")) != "" and _tall_mesh(needle.mesh)
	return _tall_mesh(needle.mesh) and needle.mesh.get_aabb().size.y > yard_node.mesh.get_aabb().size.y

func _albedo(u: RTSUnit) -> Color:
	var body: MeshInstance3D = u.get_child(0) as MeshInstance3D
	if body != null and body.has_meta("paint"):
		return body.get_meta("paint") as Color
	var mat: StandardMaterial3D = body.material_override as StandardMaterial3D
	if mat == null:
		return Color()
	return mat.albedo_color

func _card_line(boot: Node, node_name: String, map_name: String, terrain: String) -> bool:
	var card: Button = boot.find_child(node_name, true, false) as Button
	if card == null:
		return false
	var title: Label = card.find_child("Title", true, false) as Label
	var line: Label = card.find_child("Terrain", true, false) as Label
	if title == null or line == null:
		return false
	return title.text == map_name and line.text == terrain

func _faction_line(boot: Node, node_name: String, faction_name: String, style: String, hex: String) -> bool:
	var card: Button = boot.find_child(node_name, true, false) as Button
	if card == null:
		return false
	var title: Label = card.find_child("Title", true, false) as Label
	var style_label: Label = card.find_child("Style", true, false) as Label
	var swatch: ColorRect = card.find_child("Primary", true, false) as ColorRect
	if title == null or style_label == null or swatch == null:
		return false
	return title.text == faction_name and style_label.text == style and swatch.color == Color.html(hex)

func _bar_ok(boot: Node) -> bool:
	var bar: Label = boot.find_child("ControlBar", true, false) as Label
	if bar == null or not bar.is_visible_in_tree():
		return false
	var text: String = bar.text
	return text.contains("Esc") and text.contains("Back") and text.contains("Enter") and text.contains("Select") and not text.contains("Left click")

func _play_map(path: String, mesh_a: String, mesh_b: String, from_cell: Vector2i, to_cell: Vector2i, move_cell: Vector2i) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.get_node_or_null(mesh_a) is MeshInstance3D and scene.get_node_or_null(mesh_b) is MeshInstance3D, "%s shows its terrain" % path.get_file())
	var field: SMPointer = scene.get("field") as SMPointer
	var grid: SMDomainGrid = scene.get("grid") as SMDomainGrid
	var route: PackedVector3Array = field.nav.find_path(grid.cell_center(from_cell), grid.cell_center(to_cell))
	check(route.size() > 0, "%s path reaches the enemy shore" % path.get_file())
	check(_gtfc_names(field), "%s labels the six GTFC placeholders" % path.get_file())
	check(field.name_of(field.units_of(1)[0]) == "Enemy", "%s labels the enemy" % path.get_file())
	check(scene.find_child("SelectionBox", true, false) != null, "%s shows a selection box" % path.get_file())
	var friends: Array[RTSUnit] = field.units_of(0)
	var picked: RTSUnit = field.select_click(_proj(friends[0].global_position), Callable(self, "_proj"))
	check(picked == friends[0] and field.selection.count() == 1, "%s left click selects" % path.get_file())
	var step: Vector3 = grid.cell_center(move_cell)
	var moved: StringName = field.command_at(step, _proj(step), Callable(self, "_proj"))
	check(moved == &"move" and friends[0].is_moving(), "%s right click moves" % path.get_file())
	var foes: Array[RTSUnit] = field.units_of(1)
	var attacked: StringName = field.command_at(foes[0].global_position, _proj(foes[0].global_position), Callable(self, "_proj"))
	check(attacked == &"attack" and friends[0].attack_target == foes[0], "%s right click attacks" % path.get_file())
	check(bool(scene.call("fire_ability")), "%s F fires the ability" % path.get_file())
	check(field.count_team(1) >= 1 and str(scene.get("map_id")) != "", "%s is GTFC versus one enemy" % path.get_file())
	if path.ends_with("chiang_rai.tscn"):
		var garrison: MeshInstance3D = scene.get_node_or_null("Garrison_garrison_a") as MeshInstance3D
		var bazaar: MeshInstance3D = scene.get_node_or_null("Tech_bazaar_a") as MeshInstance3D
		check(garrison != null and str(garrison.get_meta("form", "")) == "garrison" and bazaar != null and str(bazaar.get_meta("form", "")) == "bazaar", "chiang rai garrisons and bazaars read as buildings")
	scene.free()
	await process_frame

func _gtfc_names(field: SMPointer) -> bool:
	var names: PackedStringArray = PackedStringArray()
	for u: RTSUnit in field.units_of(0):
		names.append(field.name_of(u))
	for need: String in ["Shan Insurgent Militia", "Shar Htoo Waw Kloud Drone Truck", "Salween RPG Trooper", "Shan Behemoth Tank", "Slag Jump Mortar", "Salween Smuggler Boat"]:
		if not names.has(need):
			return false
	return true

func test_sm_difficulty() -> void:
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var skirmish_hard: Button = boot.find_child("SkirmishDiffHard", true, false) as Button
	var campaign_easy: Button = boot.find_child("CampaignDiffEasy", true, false) as Button
	check(boot.find_child("SkirmishDiffEasy", true, false) != null and boot.find_child("SkirmishDiffNormal", true, false) != null and skirmish_hard != null, "skirmish offers Easy, Normal, and Hard")
	check(campaign_easy != null and boot.find_child("CampaignDiffNormal", true, false) != null and boot.find_child("CampaignDiffHard", true, false) != null, "campaign offers Easy, Normal, and Hard")
	skirmish_hard.pressed.emit()
	check(Settings.difficulty == "hard", "a skirmish choice saves Hard")
	campaign_easy.pressed.emit()
	Settings.reread()
	check(Settings.difficulty == "easy", "a campaign choice saves Easy")
	boot.free()
	await process_frame
	var hard_hp: float = await _foe_stat("hard", "hp")
	var easy_hp: float = await _foe_stat("easy", "hp")
	var hard_dmg: float = await _foe_stat("hard", "damage")
	var easy_dmg: float = await _foe_stat("easy", "damage")
	check(hard_hp > 100.0 and easy_hp < 100.0 and hard_hp > easy_hp and hard_dmg > easy_dmg, "campaign enemies are tougher on Hard than on Easy")
	var hard_life: float = await _company_life("hard", 180.0)
	var easy_cap: float = minf(180.0, hard_life + 45.0)
	var easy_life: float = await _company_life("easy", easy_cap)
	check(easy_life > hard_life + 15.0, "easy lasts longer than hard for a passive player")
	Settings.set_difficulty("normal")
	SMFront.faction_id = "gtfc"

func test_sm_guns() -> void:
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var field: SMPointer = SMPointer.new()
	field.host = host
	field.faction_id = "gtfc"
	var side: SMSide = SMSide.new()
	side.yard.load_catalog(SMCatalog.faction("gtfc"))
	_place_gun(side, &"slag_pillbox", Vector3.ZERO)
	side.yard.finished.append(&"barracks")
	field.side_link = side
	var squad: Array[RTSUnit] = []
	var i: int = 0
	while i < 6:
		squad.append(field.spawn(SMPointer.PLAYER, Vector3(-8.0, 0.0, float(i)), &"militia"))
		i += 1
	var tank: RTSUnit = field.spawn(SMPointer.PLAYER, Vector3(-8.0, 0.0, 8.0), &"amber_tank")
	var five: Array[RTSUnit] = []
	var n: int = 0
	while n < 5:
		five.append(squad[n])
		n += 1
	field.select_only(five)
	var order: StringName = field.command_at(Vector3.ZERO, Vector2(-400.0, -400.0), Callable(self, "_proj"))
	var inside: int = 0
	for u: RTSUnit in five:
		if bool(u.get_meta("garrisoned", false)) and not u.visible:
			inside += 1
	check(order == &"garrison" and inside == 5, "five infantry garrison the pillbox")
	field.select_only([squad[5], tank])
	var refused: int = SMGuns.try_enter(side, field, Vector3.ZERO)
	check(refused == 0 and not bool(squad[5].get_meta("garrisoned", false)) and not bool(tank.get_meta("garrisoned", false)), "a full pillbox turns away another soldier and a tank")
	var foe: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(6.0, 0.0, 0.0), &"raider")
	foe.hp = 200.0
	SMGuns.tick(side, field, 0.2)
	check(is_equal_approx(foe.hp, 200.0), "the pillbox stays quiet on low power")
	side.yard.finished.append(&"salween_hydro")
	SMGuns.tick(side, field, 0.2)
	check(is_equal_approx(foe.hp, 160.0), "a garrisoned pillbox fires the rifles when the plant is up")
	foe.position = Vector3(0.0, 0.0, 80.0)
	var released: int = SMGuns.unload(side, &"slag_pillbox")
	check(released == 5 and not bool(five[0].get_meta("garrisoned", false)) and five[0].visible, "clicking the pillbox unloads the infantry")
	_place_gun(side, &"multigunner", Vector3(40.0, 0.0, 40.0))
	var crew_foe: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(46.0, 0.0, 40.0), &"raider")
	crew_foe.hp = 100.0
	SMGuns.tick(side, field, 0.2)
	field.select_only([squad[5]])
	var crewed: int = SMGuns.try_enter(side, field, Vector3(40.0, 0.0, 40.0))
	side.gun_cool[&"multigunner"] = 0.0
	SMGuns.tick(side, field, 0.05)
	check(crewed == 1 and is_equal_approx(crew_foe.hp, 83.0), "a multigunner adapts to the garrisoned rifle")
	_place_gun(side, &"flak_slag_mast", Vector3(80.0, 0.0, 0.0))
	var soldier: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(86.0, 0.0, 0.0), &"raider")
	soldier.hp = 40.0
	var copter: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(86.0, 0.0, 3.0), &"hub_drone")
	copter.set_meta("locomotion", "air")
	copter.hp = 40.0
	_place_gun(side, &"spectrum_prism", Vector3(0.0, 0.0, -40.0))
	var chain: Array[RTSUnit] = []
	var c: int = 0
	while c < 3:
		var link: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(4.0, 0.0, -40.0 + float(c) * 2.0), &"raider")
		link.hp = 30.0
		chain.append(link)
		c += 1
	var far: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(40.0, 0.0, -40.0), &"raider")
	far.hp = 30.0
	_place_gun(side, &"defender_vx", Vector3(-40.0, 0.0, 0.0))
	var walker: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(-34.0, 0.0, 0.0), &"raider")
	walker.hp = 50.0
	var flyer: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(-34.0, 0.0, 3.0), &"hub_drone")
	flyer.set_meta("locomotion", "air")
	flyer.hp = 50.0
	_place_gun(side, &"wave_force", Vector3(0.0, 0.0, 40.0))
	var boat: RTSUnit = field.spawn(SMPointer.ENEMY, Vector3(6.0, 0.0, 40.0), &"raider")
	boat.hp = 40.0
	SMGuns.tick(side, field, 0.2)
	check(is_equal_approx(soldier.hp, 40.0) and is_equal_approx(copter.hp, 26.0), "flak hits aircraft and leaves the soldier")
	check(is_equal_approx(chain[0].hp, 21.0) and is_equal_approx(chain[1].hp, 21.0) and is_equal_approx(chain[2].hp, 21.0) and is_equal_approx(far.hp, 30.0), "the spectrum prism chains three targets")
	check(is_equal_approx(walker.hp, 38.0) and is_equal_approx(flyer.hp, 50.0), "the defender starts on its ground gun")
	check(is_equal_approx(boat.hp, 24.0), "the wave-force turret fires")
	walker.position = Vector3(-80.0, 0.0, 40.0)
	var mode: String = side.order_building(&"defender_vx")
	side.gun_cool[&"defender_vx"] = 0.0
	SMGuns.tick(side, field, 0.05)
	check(mode == "defender air" and is_equal_approx(flyer.hp, 38.0) and is_equal_approx(walker.hp, 38.0), "a second click swaps the defender to its air gun")
	field.select_only([five[0]])
	var back: int = SMGuns.try_enter(side, field, Vector3.ZERO)
	var refund: int = side.sell_structure(&"slag_pillbox")
	check(back == 1 and refund == 60 and five[0].visible and not bool(five[0].get_meta("garrisoned", false)), "selling the pillbox releases the infantry")
	check(SMGuide.howto_text().contains("Slag Pillbox") and SMGuide.howto_text().contains("silences defenses"), "the how-to names garrison and low power")
	host.free()

func _place_gun(side: SMSide, id: StringName, at: Vector3) -> void:
	side.yard.finished.append(id)
	side.yard.structure_pos[id] = at

func _foe_stat(diff: String, which: String) -> float:
	Settings.set_difficulty(diff)
	SMCampaign.selected = "tachileik"
	var scene: Node = (load("res://game/campaign_mission.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var field: SMPointer = scene.get("field") as SMPointer
	var best: float = 0.0
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		var value: float = u.max_hp if which == "hp" else u.attack_damage
		if value > best:
			best = value
	scene.free()
	await process_frame
	return best

func _company_life(diff: String, cap: float) -> float:
	Settings.set_difficulty(diff)
	SMFront.faction_id = "gtfc"
	var scene: Node = (load("res://game/burma_road.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var lived: float = 0.0
	while lived < cap:
		scene._process(0.5)
		lived += 0.5
		var field: SMPointer = scene.get("field") as SMPointer
		var end: SMOutcome = scene.get("outcome") as SMOutcome
		var standing: bool = field.units_of(SMPointer.PLAYER).size() > 0
		var defeated: bool = end != null and end.over and not end.victory
		if not standing or defeated:
			break
	scene.free()
	await process_frame
	return lived

func test_sm_settings() -> void:
	var banned: PackedStringArray = PackedStringArray([
		"MeshInstance3D.new", "MultiMesh.new", "MultiMeshInstance3D.new",
		"SurfaceTool.new", "Label3D.new", "ShaderMaterial.new",
		"BoxMesh.new", "StandardMaterial3D.new", "CapsuleMesh.new",
		"CylinderMesh.new", "SphereMesh.new", "TorusMesh.new",
		"PlaneMesh.new", "ArrayMesh.new", ".gdshader",
	])
	var dirty: String = ""
	var game_ref: String = ""
	var files: PackedStringArray = DirAccess.get_files_at("res://addons/rts_advanced")
	for file_name: String in files:
		if not file_name.begins_with("sm_") or not file_name.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string("res://addons/rts_advanced/%s" % file_name)
		if game_ref == "" and text.contains("res://game/"):
			game_ref = file_name
		for token: String in banned:
			if text.contains(token):
				dirty = "%s %s" % [file_name, token]
				break
		if dirty != "":
			break
	check(dirty == "", "sim scripts stay free of meshes and shaders")
	check(game_ref == "", "sim scripts do not reference game views")
	check(FileAccess.file_exists("res://game/shaders/channel_water.gdshader") and FileAccess.file_exists("res://game/shaders/monsoon_rain.gdshader") and not DirAccess.dir_exists_absolute("res://assets/shaders"), "shaders live under game")
	check(Settings.quality_for_adapter("ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)") == "low", "swiftshader defaults to low graphics")
	check(Settings.quality_for_adapter("llvmpipe") == "low" and Settings.quality_for_adapter("NVIDIA GeForce RTX") == "high", "software adapters default low and a gpu stays high")
	Settings.hold("")
	Settings.set_graphics("low")
	Settings.set_master(0.4)
	Settings.set_sfx(0.25)
	Settings.set_music(0.3)
	Settings.set_pan(1.6)
	Settings.set_edge(false)
	Settings.set_difficulty("hard")
	Settings.reread()
	check(Settings.graphics == "low" and is_equal_approx(Settings.master, 0.4) and is_equal_approx(Settings.sfx, 0.25) and is_equal_approx(Settings.music, 0.3) and is_equal_approx(Settings.pan, 1.6) and not Settings.edge and Settings.difficulty == "hard" and Settings.voice == "english", "settings round-trip through user://")
	Settings.set_voice("mandarin")
	Settings.reread()
	check(Settings.voice == "mandarin", "the voice language round-trips")
	Settings.set_voice("latin")
	check(Settings.voice == "english" and Settings.voice_name("burmese") == "Burmese", "an unknown voice language stays English")
	check(Settings.idb_script().contains("indexedDB") and Settings.idb_script().contains("settings"), "settings mirror into IndexedDB on the web")
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var gear: Button = boot.find_child("SettingsButton", true, false) as Button
	check(gear != null, "the menu has a settings button")
	gear.pressed.emit()
	var menu_panel: Control = boot.find_child("SettingsPanel", true, false) as Control
	var voice_row: Button = boot.find_child("VoiceValue", true, false) as Button
	var covered_title: Label = boot.find_child("GameTitle", true, false) as Label
	var dimmer: ColorRect = boot.find_child("SettingsDimmer", true, false) as ColorRect
	var opened: bool = menu_panel != null and menu_panel.visible and covered_title != null and not covered_title.visible and dimmer != null and dimmer.color.a > 0.25 and dimmer.color.a < 0.6
	gear.pressed.emit()
	check(opened and menu_panel != null and not menu_panel.visible and covered_title.visible and gear.visible, "the menu settings button opens the panel")
	gear.pressed.emit()
	var audio_tab: Button = boot.find_child("SettingsTabAudio", true, false) as Button
	if audio_tab != null:
		audio_tab.pressed.emit()
	var music_row: HSlider = boot.find_child("MusicVolume", true, false) as HSlider
	check(menu_panel != null and menu_panel.visible and audio_tab != null and music_row != null and music_row.visible, "the menu settings audio page has a music slider")
	var esc: InputEventKey = InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	menu_panel._unhandled_input(esc)
	check(not menu_panel.visible and covered_title.visible, "escape closes settings and brings the menu back")
	check(voice_row != null and voice_row.text == "English", "settings lists the voice language")
	boot.free()
	await process_frame
	var scene: Node = (load("res://game/phillips_channel.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var trees: MultiMeshInstance3D = scene.get_node_or_null("JungleTrees") as MultiMeshInstance3D
	var book: SMSight = scene.get("sight") as SMSight
	book.force_monsoon(true)
	SMSight.update_match(book, scene.get("field") as SMPointer, scene as Node3D, (scene.get("sim") as SMMatch).tech, scene.get("raider") as SMRaider)
	var rain: MeshInstance3D = scene.get_node_or_null("Rain") as MeshInstance3D
	var env: WorldEnvironment = scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	var suns: Array[Node] = scene.find_children("", "DirectionalLight3D", true, false)
	var sun: DirectionalLight3D = suns[0] as DirectionalLight3D if suns.size() > 0 else null
	var match_panel: Control = scene.find_child("SettingsPanel", true, false) as Control
	check(trees != null and not trees.visible and (rain == null or not rain.visible) and env != null and env.environment != null and not env.environment.fog_enabled and sun != null and not sun.shadow_enabled, "low graphics hides trees, rain, fog, and shadows")
	var low_field: SMPointer = scene.get("field") as SMPointer
	var low_unit: RTSUnit = null
	var low_body: MeshInstance3D = null
	var low_blob: MeshInstance3D = null
	var low_bar: MeshInstance3D = null
	if low_field != null and low_field.units_of(0).size() > 0:
		low_unit = low_field.units_of(0)[0]
	if low_unit != null:
		low_body = low_unit.get_node_or_null("Body") as MeshInstance3D
		low_bar = low_unit.get_node_or_null("HealthBar") as MeshInstance3D
	if low_body != null:
		low_blob = low_body.get_node_or_null("ContactShadow") as MeshInstance3D
	check(low_blob != null and not low_blob.visible and low_bar != null and not low_bar.visible and low_unit.hp >= low_unit.max_hp - 0.1, "low graphics hides blob shadows and full health bars")
	check(cam != null and cam.edge_pan_px <= 0.0 and is_equal_approx(cam.pan_speed, 1.6) and match_panel != null, "edge pan and pan speed follow the saved settings")
	scene.free()
	await process_frame
	Settings.set_graphics("high")
	Settings.set_master(1.0)
	Settings.set_sfx(1.0)
	Settings.set_music(0.55)
	Settings.set_pan(1.0)
	Settings.set_edge(true)
	Settings.set_difficulty("normal")
	Settings.set_voice("english")
	Settings.hold("high")
	var web_script: GDScript = load("res://addons/rts_advanced/sm_web.gd") as GDScript
	check(int(web_script.call("pointer_mode", true)) == Input.MOUSE_MODE_CONFINED and int(web_script.call("pointer_mode", false)) == Input.MOUSE_MODE_VISIBLE, "a match keeps the pointer inside the window")

func _motion_unit(stage: Node3D, kind: String, role: String, at: Vector3, team: int, animate: bool) -> RTSUnit:
	var u: RTSUnit = RTSUnit.new()
	u.unit_type = StringName(kind)
	u.team = team
	stage.add_child(u)
	u.position = at
	if animate:
		var body: MeshInstance3D = Forms.dress_unit(kind, role, "ground", Color.RED, Color.RED, Color.YELLOW)
		u.add_child(body)
		Motion.attach(u, body)
	return u

func _motion_duel(animate: bool) -> PackedFloat32Array:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var a: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3(0, 0, 0), 0, animate)
	var b: RTSUnit = _motion_unit(stage, "amber_tank", "armor", Vector3(0, 0, -20), 1, animate)
	a.attack_range = 8.0
	b.attack_range = 6.0
	b.attack_damage = 30.0
	a.set_path(PackedVector3Array([Vector3(0, 0, -10)]))
	a.attack_target = b
	b.attack_target = a
	var step: int = 0
	while step < 240:
		for u: RTSUnit in [a, b]:
			if u.is_alive():
				u.advance(1.0 / 30.0)
				if animate:
					Forms.animate(u, 1.0 / 30.0)
		step += 1
	var out: PackedFloat32Array = PackedFloat32Array([a.position.x, a.position.z, a.hp, b.position.x, b.position.z, b.hp, a.rotation.y, b.rotation.y])
	stage.queue_free()
	return out

func test_unit_motion() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var rifle: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3.ZERO, 0, true)
	var body: MeshInstance3D = rifle.get_node("Body") as MeshInstance3D
	var player: AnimationPlayer = Motion.player_of(body)
	check(player != null, "the rigged militia mounts with an AnimationPlayer")
	var clips: PackedStringArray = PackedStringArray()
	if player != null:
		for clip: StringName in player.get_animation_list():
			clips.append(str(clip).get_slice("/", str(clip).get_slice_count("/") - 1))
	check(clips.has("idle") and clips.has("walk") and clips.has("shoot") and clips.has("die"), "the rigged militia carries idle, walk, shoot, and die clips")
	check(Motion.clip_for(rifle, body) == "idle", "a still soldier idles")
	rifle.set_path(PackedVector3Array([Vector3(0, 0, -5)]))
	Motion.pose(rifle, 0.1)
	check(Motion.clip_for(rifle, body) == "walk" and player != null and str(player.current_animation).ends_with("walk"), "a moving soldier plays walk")
	var foe: RTSUnit = _motion_unit(stage, "cyan_ifv", "armor", Vector3(0, 0, -4), 1, true)
	rifle.stop()
	rifle.attack_range = 6.0
	rifle.attack_target = foe
	Motion.pose(rifle, 0.1)
	check(Motion.clip_for(rifle, body) == "shoot" and str(player.current_animation).ends_with("shoot"), "a soldier with a target in range plays shoot")
	check(player.get_animation(player.current_animation).loop_mode == Animation.LOOP_LINEAR, "the shoot clip loops")
	var tank: RTSUnit = _motion_unit(stage, "amber_tank", "armor", Vector3(6, 0, 0), 0, true)
	var hull: MeshInstance3D = tank.get_node("Body") as MeshInstance3D
	var turret: Node3D = hull.get_node_or_null("Turret") as Node3D
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
	check(Motion.player_of(hull) == null and turret != null and barrel != null, "the tank stays procedural with a turret and barrel")
	tank.attack_target = foe
	var frame: int = 0
	while frame < 30:
		Motion.pose(tank, 1.0 / 30.0)
		frame += 1
	var dir: Vector3 = foe.global_position - tank.global_position
	var want: float = wrapf(atan2(-dir.x, -dir.z) - tank.rotation.y, -PI, PI)
	check(turret != null and absf(wrapf(turret.rotation.y - want, -PI, PI)) < 0.05, "the turret turns onto its target")
	Motion.pose(tank, 1.0 / 30.0)
	var rest: Vector3 = barrel.position if barrel != null else Vector3.ZERO
	Motion.on_fired(tank, foe)
	Motion.pose(tank, 1.0 / 30.0)
	check(barrel != null and barrel.position.distance_to(rest) > 0.1, "firing kicks the barrel back")
	frame = 0
	while frame < 30:
		Motion.pose(tank, 1.0 / 30.0)
		frame += 1
	check(barrel != null and barrel.position.distance_to(rest) < 0.01, "the barrel settles after the shot")
	check(stage.get_node_or_null("MuzzleFlash") != null, "a shot leaves a muzzle flash in the stage")
	rifle.take_damage(9999.0)
	var dying: Node = stage.get_node_or_null("Dying_%d" % rifle.get_instance_id())
	check(rifle.get_node_or_null("Body") == null and dying != null and dying.get_node_or_null("Body") != null, "a dead unit hands its body to a death rig")
	check(player != null and str(player.current_animation).ends_with("die"), "the death rig plays the die clip")
	var calm: PackedFloat32Array = _motion_duel(false)
	var shown: PackedFloat32Array = _motion_duel(true)
	check(calm == shown, "the same duel ends identically with and without unit motion")
	_check_non_infantry_motion(stage, foe)
	var mi: MeshInstance3D = WorldView.slab(stage, "Built_barracks", Vector3(20, 2.3, 0), Vector3(2.2, 4.6, 2.2), Color.RED)
	var fx: Node = mi.get_node_or_null("BuildingFx")
	check(fx != null and mi.position.y < 2.3 - 0.5, "a new structure starts below ground for its rise")
	await process_frame
	check(stage.get_node_or_null("Scaffold_Built_barracks") != null, "the rise puts up a scaffold")
	var rise: int = 0
	while rise < 80 and int(fx.get("phase")) == BuildingFx.Phase.RAISE:
		fx._process(0.05)
		rise += 1
	await process_frame
	check(is_equal_approx(mi.position.y, 2.3) and stage.get_node_or_null("Scaffold_Built_barracks") == null, "the structure settles at its placed height and the scaffold comes down")
	BuildingFx.set_health(mi, 0.5)
	check(fx.get_node_or_null("Smoke") != null and fx.get_node_or_null("Fire") == null, "half health smokes")
	BuildingFx.set_health(mi, 0.2)
	check(fx.get_node_or_null("Fire") != null, "low health burns")
	var yard: SMBuildYard = SMBuildYard.new()
	yard.structure_hp[&"barracks"] = 10.0
	yard.structure_max[&"barracks"] = 100.0
	BuildingWatch.watch(stage, yard)
	var watcher: Node = stage.get_node_or_null("BuildingWatch_%d" % yard.get_instance_id())
	check(watcher != null, "a yard gets one building watch")
	watcher.call("_process", 1.0)
	check(is_equal_approx(float(fx.get("health")), 0.1), "the watch passes yard health to the structure")
	check(yard.structure_hp[&"barracks"] == 10.0, "the watch leaves yard health untouched")
	mi.visible = false
	var ruin: Node3D = stage.get_node_or_null("Ruin_Built_barracks") as Node3D
	check(ruin != null and ruin.visible and not mi.visible, "hiding a structure leaves a collapsing ruin in its place")
	stage.queue_free()

func _check_non_infantry_motion(stage: Node3D, foe: RTSUnit) -> void:
	var veh_count: int = 0
	var air_count: int = 0
	var boat_count: int = 0
	var veh_bad: PackedStringArray = PackedStringArray()
	var air_bad: PackedStringArray = PackedStringArray()
	var boat_bad: PackedStringArray = PackedStringArray()
	for fac: String in ["gtfc", "nmrf", "mvd", "black_market"]:
		var data: Dictionary = SMCatalog.faction(fac)
		for unit: Dictionary in SMCatalog.units_of(data):
			var uid: String = str(unit.get("id", ""))
			var role: String = str(unit.get("role", ""))
			var loco: String = str(unit.get("locomotion", "ground"))
			var cls: String = Scale.unit_class(uid)
			if cls == "infantry" or cls == "hero" or cls == "dog" or cls == "walker" or cls == "mobile_yard":
				continue
			var u: RTSUnit = RTSUnit.new()
			u.unit_type = StringName(uid)
			u.team = 0
			u.speed = 6.0
			u.attack_range = 30.0
			stage.add_child(u)
			u.position = Vector3.ZERO
			u.set_meta("role", role)
			u.set_meta("locomotion", loco)
			var body: MeshInstance3D = Forms.dress_unit(uid, role, loco, Color.RED, Color.RED, Color.YELLOW, fac)
			u.add_child(body)
			Motion.attach(u, body)
			var form: String = str(body.get_meta("form", ""))
			u.set_path(PackedVector3Array([Vector3(12.0, 0.0, -12.0)]))
			for step: int in 10:
				u.advance(1.0 / 30.0)
				Forms.animate(u, 1.0 / 30.0)
			if Forms.is_vehicle_unit(uid, role, form):
				veh_count += 1
				var wheels: Node3D = body.get_node_or_null("Wheels") as Node3D
				var turret: Node3D = body.get_node_or_null("Turret") as Node3D
				var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
				var w0: Node3D = wheels.get_child(0) as Node3D if wheels != null and wheels.get_child_count() > 0 else null
				var spun: bool = w0 != null and absf(w0.rotation.x) > 0.1
				u.attack_target = foe
				for step2: int in 15:
					Forms.animate(u, 1.0 / 30.0)
				var aimed: bool = turret != null and absf(turret.rotation.y) > 0.05 and absf(turret.rotation.x) > 0.01
				Motion.on_fired(u, foe)
				Forms.animate(u, 1.0 / 30.0)
				var recoiled: bool = barrel != null and absf(body.rotation.x) > 0.001 and float(body.get_meta("anim_kick", 0.0)) > 0.5
				if not (spun and aimed and recoiled):
					veh_bad.append(uid)
			elif Forms.is_air_unit(uid, role, loco, form):
				air_count += 1
				var rotor: Node3D = body.get_node_or_null("Rotor") as Node3D
				var spun_r: bool = rotor != null and absf(rotor.rotation.y) > 0.2
				var pitched: bool = absf(body.rotation.x) > 0.01 and absf(body.position.y) > 0.001
				u.set_path(PackedVector3Array([Vector3(-20.0, 0.0, 5.0)]))
				u.advance(1.0 / 30.0)
				Forms.animate(u, 1.0 / 30.0)
				var banked: bool = absf(body.rotation.z) > 0.01
				Motion.on_fired(u, foe)
				Forms.animate(u, 1.0 / 30.0)
				var fire_pitch: bool = float(body.get_meta("anim_kick", 0.0)) > 0.5
				if not (spun_r and pitched and banked and fire_pitch):
					air_bad.append(uid)
			elif Forms.is_boat_unit(uid, role, loco, form):
				boat_count += 1
				var wake: MeshInstance3D = body.get_node_or_null("Wake") as MeshInstance3D
				var spray: MeshInstance3D = body.get_node_or_null("BowSpray") as MeshInstance3D
				var turret: Node3D = body.get_node_or_null("Turret") as Node3D
				var moving_foam: bool = wake != null and wake.visible and spray != null and spray.visible
				var water_pose: bool = absf(body.rotation.x) > 0.005 or absf(body.rotation.z) > 0.005
				u.attack_target = foe
				for step3: int in 15:
					Forms.animate(u, 1.0 / 30.0)
				var aimed_b: bool = turret != null and absf(turret.rotation.y) > 0.05
				u.stop()
				Forms.animate(u, 1.0 / 30.0)
				var stopped_foam: bool = wake != null and not wake.visible and spray != null and not spray.visible
				if not (moving_foam and water_pose and aimed_b and stopped_foam):
					boat_bad.append(uid)
			u.free()
	check(veh_count >= 14 and veh_bad.is_empty(), "every vehicle rolls its wheels, aims its turret in yaw and pitch, and recoils on fire (%d) %s" % [veh_count, veh_bad])
	check(air_count >= 19 and air_bad.is_empty(), "every aircraft and drone spins its rotor, bobs, banks into turns, and pitches on acceleration and fire (%d) %s" % [air_count, air_bad])
	check(boat_count >= 9 and boat_bad.is_empty(), "every boat pitches and rolls on water, shows wake and bow spray while moving, and aims its turret (%d) %s" % [boat_count, boat_bad])

const FACING_STATIC: PackedStringArray = ["amber_tank", "cyan_ifv", "channel_skiff", "cyan_gunship", "hub_drone", "sampan"]
const COMPASS: PackedStringArray = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

## Walks one unit toward each compass point and returns the worst angle, in degrees, between the drawn forward and the move.
func _facing_error(stage: Node3D, id: String, role: String) -> float:
	var worst: float = 0.0
	for i: int in COMPASS.size():
		var u: RTSUnit = _motion_unit(stage, id, role, Vector3.ZERO, 0, true)
		var ang: float = float(i) * PI / 4.0
		var move: Vector3 = Vector3(sin(ang), 0.0, -cos(ang))
		u.set_path(PackedVector3Array([move * 40.0]))
		var frame: int = 0
		while frame < 40:
			u.advance(1.0 / 30.0)
			Motion.pose(u, 1.0 / 30.0)
			frame += 1
		await process_frame
		var body: Node3D = u.get_node("Body") as Node3D
		var seen: Vector3 = Motion.rendered_forward(body)
		worst = maxf(worst, rad_to_deg(absf(seen.signed_angle_to(move, Vector3.UP))))
		u.free()
	return worst

func test_unit_facing() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var ids: PackedStringArray = PackedStringArray(Catalog.RIGGED_YAW.keys())
	ids.sort()
	for id: String in ids:
		var err: float = await _facing_error(stage, id, "infantry")
		check(err <= 15.0, "rigged %s faces its move vector in all 8 directions (worst %.1f deg)" % [id, err])
	for id: String in FACING_STATIC:
		var role: String = "air" if id == "cyan_gunship" or id == "hub_drone" else ("boat" if id == "sampan" or id == "channel_skiff" else "armor")
		var err: float = await _facing_error(stage, id, role)
		check(err <= 15.0, "%s faces its move vector in all 8 directions (worst %.1f deg)" % [id, err])
	var probe: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3.ZERO, 0, true)
	var body: Node3D = probe.get_node("Body") as Node3D
	check(bool(body.get_meta("model_rigged", false)) and is_equal_approx(float(body.get_meta("model_yaw", 0.0)), float(Catalog.RIGGED_YAW["militia"])), "the registry turns the rigged militia by its catalog yaw")
	Motion.pose(probe, 1.0 / 30.0)
	probe.set_path(PackedVector3Array([Vector3(30, 0, 0)]))
	probe.advance(1.0 / 30.0)
	Motion.pose(probe, 1.0 / 30.0)
	var first: float = absf(wrapf(Motion.heading_of(probe) - probe.rotation.y, -PI, PI))
	check(first > 0.5, "a hard turn is not snapped: the body still lags the path heading after one frame")
	var turn: int = 0
	while turn < 20:
		probe.advance(1.0 / 30.0)
		Motion.pose(probe, 1.0 / 30.0)
		turn += 1
	check(absf(wrapf(Motion.heading_of(probe) - probe.rotation.y, -PI, PI)) < 0.05, "the body finishes the turn onto the path heading")
	probe.stop()
	var foe: RTSUnit = _motion_unit(stage, "cyan_ifv", "armor", Vector3(0, 0, 8), 1, false)
	probe.attack_range = 12.0
	probe.attack_target = foe
	turn = 0
	while turn < 30:
		Motion.pose(probe, 1.0 / 30.0)
		turn += 1
	var aim: float = Motion.yaw_to(probe.global_position, foe.global_position)
	check(absf(wrapf(Motion.heading_of(probe) - aim, -PI, PI)) < 0.05, "a standing soldier turns to face its target")
	var tank: RTSUnit = _motion_unit(stage, "amber_tank", "armor", Vector3(10, 0, 0), 0, true)
	tank.attack_range = 30.0
	tank.attack_target = foe
	tank.set_path(PackedVector3Array([Vector3(10, 0, -30)]))
	turn = 0
	while turn < 45:
		tank.advance(1.0 / 30.0)
		Motion.pose(tank, 1.0 / 30.0)
		turn += 1
	var hull: Node3D = tank.get_node("Body") as Node3D
	var turret: Node3D = hull.get_node("Turret") as Node3D
	var turret_world: float = hull.global_rotation.y + turret.rotation.y
	check(absf(wrapf(Motion.heading_of(tank) - tank.rotation.y, -PI, PI)) < 0.05 and absf(wrapf(turret_world - Motion.yaw_to(tank.global_position, foe.global_position), -PI, PI)) < 0.1, "a moving tank keeps its hull on the path and its turret on the target")
	stage.queue_free()

## The hand bone, read in the weapon's own frame, must not drift: the weapon is a rigid prop riding the hand.
func _weapon_drift(id: String) -> Array:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path("res://game/models/rigged/%s.glb" % id), state) != OK:
		return [-1.0, 0]
	var model: Node3D = doc.generate_scene(state) as Node3D
	root.add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var weapons: Array[MeshInstance3D] = []
	for node: Node in model.find_children("Weapon*", "MeshInstance3D", true, false):
		weapons.append(node as MeshInstance3D)
	var worst: float = 0.0
	var poses: int = 0
	var start: Dictionary = {}
	for clip: StringName in player.get_animation_list():
		player.play(clip)
		var length: float = player.get_animation(clip).length
		for k: int in 4:
			player.seek(length * float(k) / 4.0, true)
			await process_frame
			poses += 1
			for w: MeshInstance3D in weapons:
				var holder: BoneAttachment3D = w.get_parent() as BoneAttachment3D
				if holder == null or w.skin != null:
					worst = 999.0
					continue
				var hand: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone(holder.bone_name)).origin
				var local: Vector3 = w.global_transform.affine_inverse() * hand
				var scale: Vector3 = w.global_basis.get_scale()
				var key: String = str(w.name)
				if not start.has(key):
					start[key] = [local, scale]
				var was: Array = start[key]
				worst = maxf(worst, maxf(local.distance_to(was[0] as Vector3), (scale - (was[1] as Vector3)).length()))
	model.free()
	return [worst, poses]

func test_weapon_sockets() -> void:
	var armed: PackedStringArray = ["militia", "clearance_trooper", "amber_scout", "charcoal_bike", "clearance_engineer", "emerald_cutter", "olive_ranger", "olive_sapper", "ruby_lancer", "ruby_mortar",
		"river_rifle", "crimson_sapper", "packer_escort", "relay_van", "packer", "wharf_gun"]
	for id: String in armed:
		var got: Array = await _weapon_drift(id)
		check(float(got[0]) >= 0.0 and float(got[0]) < 0.002 and int(got[1]) >= 20, "%s weapons stay rigid on their socket across every clip (%d poses, drift %.4f)" % [id, int(got[1]), float(got[0])])
	for id: String in armed:
		var aim: Vector3 = await _barrel_aim(id)
		var mounted: bool = id in ["packer", "wharf_gun"]
		check(absf(aim.x) <= (22.0 if mounted else 8.0) and absf(aim.y) <= (25.0 if mounted else 15.0) and aim.z > 0.15, "%s fires with its barrel near level and on the target (pitch %.1f deg, yaw %.1f deg, tip %.2f m ahead)" % [id, aim.x, aim.y, aim.z])
	for id: String in armed:
		var gap: Vector2 = await _grip_gap(id)
		if gap.y > 0.0:
			check(gap.x < 0.05, "%s keeps its off hand on the weapon grip while firing (worst %.3f m over %d poses)" % [id, gap.x, int(gap.y)])
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var rifle: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3.ZERO, 0, true)
	var body: MeshInstance3D = rifle.get_node("Body") as MeshInstance3D
	Motion.player_of(body)
	var weapon: MeshInstance3D = body.find_child("Weapon", true, false) as MeshInstance3D
	var muzzle: Node3D = Motion.muzzle_of(body)
	check(weapon != null and weapon.get_parent() is BoneAttachment3D and (weapon.get_parent() as BoneAttachment3D).bone_name == "R_Hand" and muzzle != null, "the militia rifle rides the right hand socket with a muzzle at the barrel tip")
	var ik: Node = body.find_child("OffHandIK", true, false)
	check(ik is OffHandIK and (ik as OffHandIK).get_skeleton().get_bone_name((ik as OffHandIK).hand) == "L_Hand", "the two-handed rifle puts the left hand on its grip through IK")
	Motion.pose(rifle, 1.0 / 30.0)
	await process_frame
	var rest: Vector3 = weapon.position
	Motion.on_fired(rifle, null)
	var flash: Node3D = stage.get_node_or_null("MuzzleFlash") as Node3D
	check(flash != null and flash.global_position.distance_to(muzzle.global_position) < 0.01, "the muzzle flash starts at the barrel tip")
	Motion.pose(rifle, 1.0 / 60.0)
	var kicked: Vector3 = weapon.position - rest
	var barrel: Vector3 = weapon.basis * (muzzle.position - weapon.get_aabb().get_center())
	check(kicked.length() > 0.001 and kicked.normalized().dot(-barrel.normalized()) > 0.95, "recoil pushes the rifle straight back along its barrel")
	var settle: int = 0
	while settle < 20:
		Motion.pose(rifle, 1.0 / 30.0)
		settle += 1
	check(weapon.position.distance_to(rest) < 0.0005, "the rifle settles back into the hand after recoil")
	var shield_unit: RTSUnit = _motion_unit(stage, "clearance_trooper", "infantry", Vector3(4, 0, 0), 0, true)
	var shield: MeshInstance3D = shield_unit.find_child("Shield", true, false) as MeshInstance3D
	var ext: Vector3 = shield.get_aabb().size if shield != null else Vector3.ZERO
	var dims: Array[float] = [ext.x, ext.y, ext.z]
	dims.sort()
	check(shield != null and shield.skin == null and (shield.get_parent() as BoneAttachment3D).bone_name == "L_Forearm" and dims[1] > 0.5 * dims[2] and dims[0] < 0.4 * dims[1], "the riot shield is a rigid forearm prop with full face proportions")
	var slinger: RTSUnit = _motion_unit(stage, "river_rifle", "infantry", Vector3(8, 0, 0), 0, true)
	var foe: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3(8, 0, -6), 1, false)
	var sling_body: MeshInstance3D = slinger.get_node("Body") as MeshInstance3D
	var slung: MeshInstance3D = sling_body.find_child("Weapon", true, false) as MeshInstance3D
	var sling: Node3D = Motion.sling_of(sling_body)
	check(slung != null and sling != null and (sling.get_parent() as BoneAttachment3D).bone_name == "Spine02" and Motion.muzzle_of(sling_body) != null, "the river rifle has a rigid rifle with a muzzle and a sling marker on the spine")
	slinger.set_path(PackedVector3Array([Vector3(8, 0, -3)]))
	for f: int in 20:
		slinger.advance(1.0 / 30.0)
		Motion.pose(slinger, 1.0 / 30.0)
		await process_frame
	check(slung.get_parent() == sling and slung.global_position.distance_to(sling.global_position) < 0.01, "on the move the river rifle carries its rifle slung on the back")
	slinger.stop()
	slinger.attack_range = 12.0
	slinger.attack_target = foe
	for f: int in 30:
		Motion.pose(slinger, 1.0 / 30.0)
		await process_frame
	var sling_ik: OffHandIK = sling_body.find_child("OffHandIK", true, false) as OffHandIK
	check(slung.global_position.distance_to(sling.global_position) > 0.2 and sling_ik != null and sling_ik.influence > 0.95, "to fire, the river rifle draws the rifle into both hands")
	stage.queue_free()

## Worst distance between the off hand and the weapon's Grip socket across the shoot clip, measured on the posed
## skeleton after the modifiers ran, and the number of poses sampled (0 when the unit has no off-hand IK).
func _grip_gap(id: String) -> Vector2:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var u: RTSUnit = _motion_unit(stage, id, "infantry", Vector3.ZERO, 0, true)
	var foe: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3(0, 0, -6), 1, false)
	var body: MeshInstance3D = u.get_node("Body") as MeshInstance3D
	var player: AnimationPlayer = Motion.player_of(body)
	var ik: OffHandIK = body.find_child("OffHandIK", true, false) as OffHandIK
	if ik == null or player == null:
		stage.queue_free()
		return Vector2.ZERO
	var skel: Skeleton3D = ik.get_skeleton()
	var gaps: Array[float] = []
	var measure: Callable = func() -> void:
		gaps.append((skel.global_transform * skel.get_bone_global_pose(ik.hand).origin).distance_to(ik.target.global_position))
	u.attack_range = 12.0
	u.attack_target = foe
	for f: int in 30:
		Motion.pose(u, 1.0 / 30.0)
	var length: float = player.get_animation(player.current_animation).length
	var worst: float = 0.0
	var sampled: int = 0
	skel.skeleton_updated.connect(measure)
	for k: int in 16:
		player.seek(length * float(k) / 16.0, true)
		Motion.pose(u, 0.0)
		gaps.clear()
		await process_frame
		await process_frame
		if not gaps.is_empty():
			worst = maxf(worst, gaps[gaps.size() - 1])
			sampled += 1
	skel.skeleton_updated.disconnect(measure)
	stage.queue_free()
	return Vector2(worst, float(sampled))

## Barrel pitch and yaw off the target in degrees, and how far the muzzle sits toward the target, averaged over the
## whole shoot clip. The build points the Muzzle socket's -Z along the barrel, which arrives in glTF as -Y.
func _barrel_aim(id: String) -> Vector3:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var u: RTSUnit = _motion_unit(stage, id, "infantry", Vector3.ZERO, 0, true)
	var foe: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3(0, 0, -6), 1, false)
	var body: MeshInstance3D = u.get_node("Body") as MeshInstance3D
	Motion.player_of(body)
	var weapon: MeshInstance3D = body.find_child("Weapon", true, false) as MeshInstance3D
	var muzzle: Node3D = Motion.muzzle_of(body)
	if weapon == null or muzzle == null:
		stage.queue_free()
		return Vector3(90.0, 90.0, 0.0)
	u.attack_range = 12.0
	u.attack_target = foe
	for f: int in 30:
		Motion.pose(u, 1.0 / 30.0)
	var player: AnimationPlayer = Motion.player_of(body)
	var length: float = player.get_animation(player.current_animation).length
	var pitch: float = 0.0
	var yaw: float = 0.0
	var ahead: float = 0.0
	for k: int in 16:
		player.seek(length * float(k) / 16.0, true)
		Motion.pose(u, 0.0)
		await process_frame
		var barrel: Vector3 = -muzzle.global_basis.y.normalized()
		pitch += rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0))) / 16.0
		yaw += rad_to_deg(Vector3(barrel.x, 0.0, barrel.z).signed_angle_to(Vector3.FORWARD, Vector3.UP)) / 16.0
		ahead += (muzzle.global_position - u.global_position).dot(Vector3.FORWARD) / 16.0
	stage.queue_free()
	return Vector3(pitch, yaw, ahead)

func test_dog_motion() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var dog: RTSUnit = _motion_unit(stage, "kachin_dog", "infantry", Vector3.ZERO, 0, true)
	var body: MeshInstance3D = dog.get_node("Body") as MeshInstance3D
	var player: AnimationPlayer = Motion.player_of(body)
	var missing: PackedStringArray = []
	for clip: String in ["idle", "walk", "run", "shoot", "ability", "flinch", "die"]:
		if not Motion.has_clip(player, clip):
			missing.append(clip)
	check(player != null and missing.is_empty(), "the sapper dog ships authored idle, walk, run, bite, howl, flinch and death clips (missing: %s)" % ", ".join(missing))
	var skel: Skeleton3D = body.find_child("Skeleton3D", true, false) as Skeleton3D
	var worst: float = 0.0
	for clip: String in ["idle", "run", "shoot", "ability"]:
		Motion.play(player, clip, 1.0)
		player.seek(0.0, true)
		await process_frame
		var low: float = 99.0
		for b: int in skel.get_bone_count():
			low = minf(low, (skel.global_transform * skel.get_bone_global_pose(b).origin).y)
		worst = maxf(worst, absf(low))
	check(worst < 0.06, "the sapper dog stands on the ground in every clip (lowest bone off the ground by %.3f m)" % worst)
	var foe: RTSUnit = _motion_unit(stage, "militia", "infantry", Vector3(0, 0, -4), 1, false)
	dog.attack_range = 8.0
	dog.attack_target = foe
	for f: int in 20:
		Motion.pose(dog, 1.0 / 30.0)
	await process_frame
	Motion.on_fired(dog, foe)
	var flash: Node3D = stage.get_node_or_null("MuzzleFlash") as Node3D
	var head: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("tripo__Head_0")).origin
	check(flash != null and flash.global_position.distance_to(head) < 0.3 and flash.global_position.y < 1.2, "the dog's howl starts at its head, not above it")
	stage.queue_free()

func test_building_materials() -> void:
	var ids: Dictionary = {}
	for faction: String in ["gtfc", "mvd", "nmrf"]:
		for item: Variant in SMCatalog.faction(faction).get("buildings", []):
			var id: String = str((item as Dictionary).get("id", ""))
			ids[id] = true
			ids["%s_%s" % [faction, id]] = false
	var missing: Array[String] = []
	for id: String in ids.keys():
		var tripo: bool = FileAccess.file_exists(ProjectSettings.globalize_path("res://game/models/tripo/%s.glb" % id))
		if not bool(ids[id]) and not tripo:
			continue
		var kinds: PackedStringArray = Catalog.materials_of(id)
		var ok: bool = Catalog.MATERIALS.has(id) and kinds.size() >= 1 and kinds.size() <= 2
		for kind: String in kinds:
			ok = ok and Catalog.KINDS.has(kind)
		if not ok:
			missing.append(id)
	check(missing.is_empty(), "every building and faction variant carries one or two catalog materials %s" % [missing])
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var hide: MeshInstance3D = WorldView.slab(stage, "Built_bamboo_hide", Vector3(-12, 2.3, 0), Vector3(2.2, 4.6, 2.2), Color.RED)
	var barracks: MeshInstance3D = WorldView.slab(stage, "Built_barracks", Vector3(0, 2.3, 0), Vector3(2.2, 4.6, 2.2), Color.RED)
	var factory: MeshInstance3D = WorldView.slab(stage, "Built_mvd_war_factory", Vector3(12, 2.3, 0), Vector3(2.2, 4.6, 2.2), Color.RED)
	check(str(barracks.get_meta("model", "")) != "" and BuildingFx.materials_for(barracks)[0] == Catalog.BRICK, "the barracks mounts its model and reads brick from the catalog")
	var ink: PackedColorArray = Debris.palette(barracks, "barracks")
	var spread: float = ink[4].get_luminance() - ink[0].get_luminance()
	var warm: bool = false
	for c: Color in ink:
		warm = warm or (c.r > c.b + 0.08)
	check(ink.size() == 5 and spread > 0.15 and warm, "the barracks palette comes from its red brick texture, dark to light")
	var fx: Node3D = barracks.get_node("BuildingFx") as Node3D
	fx.set("phase", BuildingFx.Phase.STAND)
	fx.call("_start_work")
	check(fx.get_node_or_null("Working") != null, "a standing building runs a working loop")
	BuildingFx.set_state(barracks, false, false)
	check(not (fx.get_node("Working") as Node3D).visible, "low power stops the working loop")
	await process_frame
	for mi: MeshInstance3D in [hide, barracks, factory]:
		mi.visible = false
	var hide_ruin: Node3D = stage.get_node_or_null("Ruin_Built_bamboo_hide") as Node3D
	var brick_ruin: Node3D = stage.get_node_or_null("Ruin_Built_barracks") as Node3D
	var steel_ruin: Node3D = stage.get_node_or_null("Ruin_Built_mvd_war_factory") as Node3D
	var chunk_root: Node = brick_ruin.get_node_or_null("Chunks") if brick_ruin != null else null
	check(chunk_root != null and chunk_root.get_child_count() >= 8, "the barracks breaks into textured chunks of its own model")
	var source_tris: int = 0
	for node: Node in barracks.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (node as MeshInstance3D).mesh
		if m != null and node.name != "ContactShadow":
			for s: int in m.get_surface_count():
				source_tris += m.surface_get_array_index_len(s) / 3 if m.surface_get_array_index_len(s) > 0 else m.surface_get_array_len(s) / 3
	var chunk_tris: int = 0
	if chunk_root != null:
		for node: Node in chunk_root.get_children():
			var m: Mesh = (node as MeshInstance3D).mesh
			for s: int in m.get_surface_count():
				chunk_tris += m.surface_get_array_len(s) / 3
	check(source_tris > 0 and chunk_tris == source_tris, "the chunks keep every triangle of the model (%d of %d)" % [chunk_tris, source_tris])
	check(hide_ruin != null and hide_ruin.find_child("Embers", true, false) != null, "bamboo and thatch throw burning embers")
	check(brick_ruin != null and brick_ruin.find_child("Dust", true, false) != null and brick_ruin.find_child("Splinters", true, false) != null, "brick raises dust and the timber frame splinters")
	check(steel_ruin != null and steel_ruin.find_child("Sparks", true, false) != null and steel_ruin.find_child("Glass", true, false) != null, "steel throws sparks and glass panels shatter")
	var heap: MeshInstance3D = brick_ruin.get_node_or_null("RubbleMound") as MeshInstance3D if brick_ruin != null else null
	check(heap != null and (heap.material_override as StandardMaterial3D).albedo_color.is_equal_approx(ink[1]), "the rubble mound is shaded from the same palette")
	var piece_kinds: Dictionary = {}
	var piece_root: Node = brick_ruin.get_node_or_null("Debris") if brick_ruin != null else null
	if piece_root != null:
		for node: Node in piece_root.get_children():
			piece_kinds[str(node.get_meta("material", ""))] = true
	check(piece_kinds.has(Catalog.BRICK) and not piece_kinds.has(Catalog.GLASS), "barracks debris pieces are brick and timber, not generic blocks")
	stage.queue_free()

func _plain_box(node: Node) -> bool:
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	return mesh_node != null and mesh_node.mesh is BoxMesh

func _flat_olive(tex: Texture2D) -> bool:
	if tex == null:
		return true
	var img: Image = tex.get_image()
	if img == null or img.get_width() < 2 or img.get_height() < 2:
		return true
	var seen: Dictionary = {}
	var y: int = 0
	while y < img.get_height():
		var x: int = 0
		while x < img.get_width():
			var ink: Color = img.get_pixel(x, y)
			var key: String = "%d,%d,%d" % [int(ink.r * 8.0), int(ink.g * 8.0), int(ink.b * 8.0)]
			seen[key] = true
			x += 4
		y += 4
	return seen.size() < 3


const LANG_LOCALES: PackedStringArray = ["my", "zh", "th", "ms"]
## Non-Latin words an English screen may show: each language's own name on the Language row.
const ENGLISH_APPROVED: PackedStringArray = ["မြန်မာ", "中文", "ไทย"]

static func _catalog(locale: String) -> Dictionary:
	var out: Dictionary = {}
	var tr: Translation = load("res://localization/game/%s.po" % locale) as Translation
	if tr == null:
		return out
	for key: StringName in tr.get_message_list():
		out[String(key)] = String(tr.get_message(key))
	return out

## Letters outside Latin, with symbols, punctuation, and arrows allowed.
static func _foreign_letters(line: String, approved: PackedStringArray) -> String:
	var rest: String = line
	for word: String in approved:
		rest = rest.replace(word, "")
	for i: int in rest.length():
		var c: int = rest.unicode_at(i)
		if c <= 0x024F or (c >= 0x1E00 and c <= 0x1EFF) or (c >= 0x2000 and c <= 0x2BFF) or c == 0xFE0F:
			continue
		return rest.substr(i, 1)
	return ""

static func _marks(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var rx: RegEx = RegEx.create_from_string(SMLang.PLACEHOLDER)
	for m: RegExMatch in rx.search_all(line):
		out.append(m.get_string())
	return out

func _shown_texts(node: Node, out: PackedStringArray) -> void:
	var item: CanvasItem = node as CanvasItem
	if item != null and not item.is_visible_in_tree():
		return
	var label: Label = node as Label
	var button: Button = node as Button
	var raw: String = ""
	if label != null:
		raw = label.text
	elif button != null:
		raw = button.text
	if raw.strip_edges() != "":
		var control: Control = node as Control
		out.append(control.atr(raw) if control.can_auto_translate() else raw)
	for child: Node in node.get_children():
		_shown_texts(child, out)

func test_game_language() -> void:
	var en: Dictionary = _catalog("en")
	check(en.size() > 500, "the English catalog holds the player-facing lines (%d)" % en.size())
	for locale: String in LANG_LOCALES:
		var other: Dictionary = _catalog(locale)
		var missing: PackedStringArray = PackedStringArray()
		var broken: PackedStringArray = PackedStringArray()
		for key: String in en:
			var said: String = str(other.get(key, ""))
			if said.strip_edges() == "":
				missing.append(key)
			elif _marks(key) != _marks(said) or key.count("\n") != said.count("\n"):
				broken.append(key)
		check(missing.is_empty(), "every English line has a %s line %s" % [locale, missing.slice(0, 4)])
		check(broken.is_empty(), "%s keeps every placeholder and line break %s" % [locale, broken.slice(0, 4)])
	var foreign: PackedStringArray = PackedStringArray()
	for key: String in en:
		var shown: String = str(en[key])
		if _foreign_letters(key, PackedStringArray()) != "" or _foreign_letters(shown, PackedStringArray()) != "":
			foreign.append(shown)
	check(foreign.is_empty(), "no English line carries non-Latin script %s" % [foreign.slice(0, 4)])
	check(str(en.get("Kris Plasma Rush", "")) == "Kris Dagger Plasma Rush" and str(en.get("Shar Htoo Waw Kloud Drone Truck", "")).contains("Cloud"), "English glosses the flavour words in names")
	var scripts: Dictionary = {"my": [0x1000, 0x109F], "th": [0x0E00, 0x0E7F], "zh": [0x2E80, 0x9FFF]}
	var faces: Array[Font] = preload("res://game/font_faces.gd").script_faces()
	check(faces.size() == 3, "the Burmese, Thai, and Chinese faces ship with the build")
	for locale: String in scripts.keys():
		var span: Array = scripts[locale]
		var gaps: Dictionary = {}
		var lines: Dictionary = _catalog(locale)
		for key: String in lines:
			var said: String = str(lines[key])
			for i: int in said.length():
				var c: int = said.unicode_at(i)
				if c < int(span[0]) or c > int(span[1]):
					continue
				var drawn: bool = false
				for face: Font in faces:
					if face.has_char(c):
						drawn = true
						break
				if not drawn:
					gaps[String.chr(c)] = true
		check(gaps.is_empty(), "the %s face draws every %s character %s" % [locale, locale, gaps.keys().slice(0, 6)])
	SMLang.apply("burmese")
	var built: String = String(TranslationServer.translate(&"Barracks built"))
	var credits: String = String(TranslationServer.translate(&"Credits 640"))
	var direct: String = String(TranslationServer.translate(&"Nothing selected"))
	check(direct != "Nothing selected" and _foreign_letters(direct, PackedStringArray()) != "", "Burmese translates a plain line")
	check(credits.contains("640") and not credits.contains("Credits"), "a formatted line keeps its number in Burmese")
	check(not built.contains("Barracks") and built.contains(String(TranslationServer.translate(&"Barracks"))), "a formatted line translates its argument too")
	SMLang.apply("english")
	check(String(TranslationServer.translate(&"Nothing selected")) == "Nothing selected" and String(TranslationServer.translate(&"Kris Plasma Rush")) == "Kris Dagger Plasma Rush", "English shows English and the glosses")
	var held_language: String = Settings.language
	var held_voice: String = Settings.voice
	Settings.set_language("thai")
	Settings.reread()
	check(Settings.language == "thai" and Settings.voice == "thai" and TranslationServer.get_locale() == "th", "the game language round-trips and the voice follows it")
	Settings.set_voice("english")
	Settings.reread()
	check(Settings.language == "thai" and Settings.voice == "english", "the voice language can differ from the game language")
	Settings.set_language("klingon")
	check(Settings.language == "english" and TranslationServer.get_locale() == "en", "an unknown game language stays English")
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	check(clips.call("_order_for", "en", "gtfc") == PackedStringArray(["en"]) and clips.call("_dialogue_order", "kokang") == PackedStringArray(["en"]), "English voices never borrow another language")
	var boot: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	await process_frame
	var gear: Button = boot.find_child("SettingsButton", true, false) as Button
	if gear != null:
		gear.pressed.emit()
	var panel: Control = boot.find_child("SettingsPanel", true, false) as Control
	var row: Button = boot.find_child("LanguageValue", true, false) as Button
	if panel != null:
		panel.call("_show_page", "language")
	await process_frame
	var lang_label: Control = boot.find_child("LanguageLabel", true, false) as Control
	var offer_card: Control = boot.find_child("TrainingOffer", true, false) as Control
	var blurb_label: Control = boot.find_child("SettingsBlurb", true, false) as Control
	check(lang_label != null and row != null and row.position.x >= lang_label.position.x + lang_label.size.x + 8.0 and (offer_card == null or not offer_card.visible) and blurb_label != null and blurb_label.size.y >= 88.0, "settings hides the first-visit prompt, spaces the language label from its value, and gives help text two-line height")
	var english_texts: PackedStringArray = PackedStringArray()
	_shown_texts(boot, english_texts)
	var english_foreign: PackedStringArray = PackedStringArray()
	for line: String in english_texts:
		if _foreign_letters(line, ENGLISH_APPROVED) != "":
			english_foreign.append(line)
	check(row != null and row.text == "English" and english_foreign.is_empty(), "the English menu and Language page show only English %s" % [english_foreign.slice(0, 4)])
	if row != null:
		row.pressed.emit()
	await process_frame
	var burmese_texts: PackedStringArray = PackedStringArray()
	_shown_texts(boot, burmese_texts)
	var burmese_lines: int = 0
	for line: String in burmese_texts:
		if _foreign_letters(line, PackedStringArray()) != "":
			burmese_lines += 1
	check(Settings.language == "burmese" and row != null and row.text == "မြန်မာ" and burmese_lines * 2 > burmese_texts.size(), "the Language row switches the open menu to Burmese (%d of %d lines)" % [burmese_lines, burmese_texts.size()])
	boot.call("_show_tab", "skirmish")
	await process_frame
	var top_card: Control = boot.find_child("CardPhillips", true, false) as Control
	var title_node: Control = boot.find_child("GameTitle", true, false) as Control
	var bot_row: Control = boot.find_child("SkirmishBotCycle", true, false) as Control
	var menu_back: Control = boot.find_child("MenuBack", true, false) as Control
	var back_hit: Rect2 = bot_row.get_global_rect().intersection(menu_back.get_global_rect()) if bot_row != null and menu_back != null else Rect2()
	check(top_card != null and title_node != null and top_card.position.y >= title_node.position.y + 88.0 and bot_row != null and menu_back != null and (back_hit.size.x < 1.0 or back_hit.size.y < 1.0), "the Skirmish map list sits below the ASEAN 2031 logo and Back stays clear of the Commander and Difficulty rows")
	boot.call("_show_tab", "campaign")
	boot.call("layout_for", Vector2(1231, 663))
	await process_frame
	var camp_scroll: Control = boot.find_child("ActIMissions", true, false) as Control
	var last_mission: Control = boot.find_child("Mission_andaman", true, false) as Control
	var camp_easy: Control = boot.find_child("CampaignDiffEasy", true, false) as Control
	check(camp_scroll != null and last_mission != null and camp_easy != null and last_mission.get_global_rect().end.y <= camp_scroll.get_global_rect().end.y + 1.0 and camp_scroll.get_global_rect().end.y <= camp_easy.get_global_rect().position.y - 4.0, "Burmese campaign missions fit inside the mission list without clipping above the difficulty row")
	var zh_cat: Dictionary = _catalog("zh")
	check(str(zh_cat.get("Medium", "")) == "中" and str(zh_cat.get("Low", "")) == "低" and str(zh_cat.get("High", "")) == "高", "Mandarin translates Low, Medium, and High")
	boot.free()
	await process_frame
	var boot_after: Node = (load("res://game/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot_after)
	await process_frame
	var offer_after: Control = boot_after.find_child("TrainingOffer", true, false) as Control
	check(offer_after == null or not offer_after.visible, "the first-visit training prompt stays dismissed after a match")
	boot_after.free()
	await process_frame
	Settings.set_language(held_language)
	Settings.set_voice(held_voice)
	SMLang.apply("english")

func test_render_budget() -> void:
	check(Settings.quality_for_adapter("llvmpipe") == "low" and Settings.quality_for_adapter("NVIDIA GeForce RTX") == Settings.default_graphics() and Settings.default_graphics() == "high", "desktop GPUs default high, software renderers low")
	Settings.set_graphics("medium")
	Settings.reread()
	check(Settings.graphics == "medium" and Settings.quality_ids().size() == 3, "medium graphics round-trips through user://")
	Settings.set_graphics("ultra")
	check(Settings.graphics == Settings.default_graphics(), "an unknown level falls back to the platform default")
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	Settings.hold("high")
	Settings.budget_shadow(sun)
	var high_ok: bool = sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and sun.directional_shadow_max_distance <= 90.0 and is_equal_approx(Settings.render_scale(), 1.0)
	Settings.hold("medium")
	Settings.budget_shadow(sun)
	var medium_ok: bool = sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and is_equal_approx(Settings.render_scale(), 1.0)
	Settings.hold("low")
	Settings.budget_shadow(sun)
	var low_ok: bool = not sun.shadow_enabled and Settings.render_scale() < 0.8
	Settings.hold("")
	sun.free()
	check(high_ok and medium_ok and low_ok, "high casts two splits, medium one map, low none and renders smaller")
	var grid: SMDomainGrid = SMDomainGrid.new(24, 16, 2.0, Vector3(-24.0, 0.0, -16.0))
	for y: int in range(0, 16):
		grid.set_domain(Vector2i(12, y), SMDomainGrid.Domain.SHALLOW)
	var sight: SMSight = SMSight.new()
	sight.bind(grid)
	sight.begin()
	sight.add_seer(Vector3(-15.3, 0.0, -6.1), 7.0)
	sight.add_seer(Vector3(9.0, 0.0, 4.4), 5.5)
	sight.commit()
	var host: Node3D = Node3D.new()
	root.add_child(host)
	var mismatch: int = 0
	for river: bool in [false, true]:
		sight.river_lit = river
		var lit: Image = WorldView._lit_mask(sight, grid, host)
		for y: int in grid.rows:
			for x: int in grid.cols:
				if (lit.get_pixel(x, y).r > 0.5) != (sight.cell_state(Vector2i(x, y)) == SMSight.CLEAR):
					mismatch += 1
	check(mismatch == 0, "the fog mask matches cell_state with and without the river radar (%d off)" % mismatch)
	sight.river_lit = false
	WorldView.paint_fog(sight, host)
	var veil: MeshInstance3D = host.get_node_or_null("FogVeil") as MeshInstance3D
	var plane: PlaneMesh = veil.mesh as PlaneMesh if veil != null else null
	check(plane != null and plane.size.is_equal_approx(Vector2(48.0, 32.0)) and veil.material_override is ShaderMaterial, "the fog veil is one quad over the grid")
	host.free()
	preload("res://game/render_budget.gd").install()
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var loaded: bool = doc.append_from_file(ProjectSettings.globalize_path("res://game/models/tripo/amber_tank.glb"), state) == OK
	var model: Node = doc.generate_scene(state) if loaded else null
	var faces: int = 0
	var mip_ok: bool = model != null
	if model != null:
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (node as MeshInstance3D).mesh
			faces += mesh.get_faces().size() / 3
			var mat: BaseMaterial3D = mesh.surface_get_material(0) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				var img: Image = mat.albedo_texture.get_image()
				mip_ok = mip_ok and img.has_mipmaps() and img.get_width() <= 512
		model.free()
	check(mip_ok and faces > 1000 and faces < 8000, "a shipped Tripo tank is simplified, 512 px, and mipmapped (%d triangles)" % faces)
	var pack_script: String = FileAccess.get_file_as_string("res://tools/pack_desktop.sh")
	var reg_script: String = FileAccess.get_file_as_string("res://game/model_registry.gd")
	var audio_script: String = FileAccess.get_file_as_string("res://game/match_audio.gd")
	check(pack_script.contains("Contents/Resources") and reg_script.contains("Resources/models") and audio_script.contains("Resources/audio"), "macOS bundles load external folders from Contents/Resources")
	var mvd_stage: Node3D = Node3D.new()
	root.add_child(mvd_stage)
	var mvd_side: SMSide = SMSide.new()
	var mvd_grid: SMDomainGrid = SMDomainGrid.new(16, 16, 4.0, Vector3(-32.0, 0.0, -32.0))
	mvd_side.slab_made.connect(Callable(WorldView, "slab"))
	mvd_side.prepare(mvd_stage, null, mvd_grid, Vector3.ZERO, RTSEconomy.new(), "mvd")
	await process_frame
	var mvd_ruin: Node = mvd_stage.get_node_or_null("Ruin_HubShell")
	check(mvd_ruin == null and mvd_side.hub_mesh != null and not mvd_side.hub_mesh.visible, "the MVD HQ shell stays hidden without spawning a collapse ruin dome")
	mvd_stage.free()
	var haze_env: Environment = Environment.new()
	var haze_sight: SMSight = SMSight.new()
	haze_sight.force_weather(true)
	Ground._fog(haze_env, haze_sight)
	check(haze_env.fog_enabled and haze_env.fog_density <= 0.008, "Strait haze keeps fog density light enough to see terrain and units")
	var backdrop_script: GDScript = load("res://game/menu_backdrop.gd") as GDScript
	backdrop_script.skip_export = true
	backdrop_script._cache.clear()
	var bgs_ok: bool = true
	for bg_name: String in ["main_menu", "gtfc", "nmrf", "mvd", "black_market", "loading"]:
		var bg_tex: Texture2D = backdrop_script.call("texture", bg_name) as Texture2D
		if bg_tex == null or bg_tex.get_width() < 1:
			bgs_ok = false
	backdrop_script.skip_export = false
	backdrop_script._cache.clear()
	var presets_cfg: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var splash_ok: bool = str(ProjectSettings.get_setting("application/boot_splash/image")) == "res://brand/boot_splash.png" and FileAccess.file_exists("res://brand/boot_splash.webp") and FileAccess.file_exists("res://brand/wordmark-vanguard-1024.png")
	var icons_ok: bool = FileAccess.file_exists("res://icon.png") and FileAccess.file_exists("res://brand/icon.ico") and FileAccess.file_exists("res://brand/icon.icns") and presets_cfg.contains("res://brand/icon.ico") and presets_cfg.contains("res://brand/icon.icns")
	check(bgs_ok and splash_ok and icons_ok, "Four Fronts splash, Vanguard wordmark, six menu backgrounds, and Chevron app icons resolve without build/web")
	Settings.set_graphics("high")
