extends RefCounted
## Neutral Tripo scenery. No faction paint. Glow is the emissive node, hidden on Low.
## Landmark footprints block ground movement and stay indestructible because they are not units.

const Settings = preload("res://game/match_settings.gd")
const Scale = preload("res://game/model_scale.gd")
const Models = preload("res://game/model_registry.gd")

static var _mesh: Dictionary = {}
static var _scene: Dictionary = {}
static var _inflight: Dictionary = {}
static var _hosts: Dictionary = {}

static func clear_cache() -> void:
	for key: Variant in _scene.keys():
		var node: Node = _scene[key] as Node
		if node != null and is_instance_valid(node):
			node.free()
	_scene.clear()
	_mesh.clear()
	_hosts.clear()

static func mesh_of(id: String) -> Mesh:
	if _mesh.has(id) and _mesh[id] != null:
		return _mesh[id] as Mesh
	var root: Node3D = _load(id)
	if root == null:
		return null
	var body: MeshInstance3D = root.find_child("Body", true, false) as MeshInstance3D
	if body == null or body.mesh == null:
		root.free()
		return null
	var baked: Mesh = _bake(body, fit_of(id, _bounds(root)))
	root.free()
	_mesh[id] = baked
	return baked

static func has_mesh(id: String) -> bool:
	return _mesh.has(id) and _mesh[id] != null

static func tree_id(profile: String) -> String:
	if profile == "phillips" or profile == "atolls":
		return "mangrove"
	if profile == "mekong":
		return "coconut_palm"
	if profile == "showcase":
		return "dipterocarp"
	if profile == "sop" or profile == "chiang":
		return "banyan_tree"
	return "teak_tree"

static func palm_id(profile: String) -> String:
	if profile == "burma" or profile == "kokang":
		return "khasi_pine"
	if profile == "mekong" or profile == "showcase":
		return "sugar_palm"
	return "coconut_palm"

static func house_id(profile: String) -> String:
	if profile == "phillips":
		return "peranakan_shophouse"
	if profile == "sop" or profile == "chiang":
		return "neon_shophouse"
	if profile == "mekong":
		return "vn_tube_house"
	if profile == "atolls":
		return "kampong_ayer_house"
	if profile == "showcase":
		return "city_colonial"
	if profile == "mvd" or profile == "nmrf":
		return ""
	return "shan_stilt_house"

## One indestructible landmark per skirmish, plus a dressed showcase.
static func stamp(host: Node3D, grid: SMDomainGrid, profile: String) -> void:
	if host == null or grid == null:
		return
	if profile == "showcase":
		_showcase(host, grid)
		return
	var plan_id: String = str(host.get_meta("map_plan", ""))
	if plan_id != "":
		_stamp_plan(host, grid, SMMapPlan.of(plan_id), _neon(profile))
		return
	if profile == "atolls":
		_place(host, grid, "karst_sea_stack", Vector2i(4, 6), false, false)
		_place(host, grid, "jetty", Vector2i(16, 24), false, false)
	var mark: String = _mark_of(profile)
	var cell: Vector2i = _mark_cell(profile)
	if mark != "" and cell.x >= 0:
		_place(host, grid, mark, cell, true, _neon(profile))

static func _mark_of(profile: String) -> String:
	if profile == "phillips":
		return "lm_intramuros"
	if profile == "sop":
		return "lm_tha_phae"
	if profile == "burma":
		return "lm_sule"
	if profile == "mekong":
		return "lm_turtle_tower"
	if profile == "chiang":
		return "lm_doi_suthep"
	return ""

static func _mark_cell(profile: String) -> Vector2i:
	if profile == "phillips":
		return Vector2i(50, 28)
	if profile == "sop":
		return Vector2i(6, 42)
	if profile == "burma":
		return Vector2i(6, 32)
	if profile == "mekong":
		return Vector2i(8, 38)
	if profile == "chiang":
		return Vector2i(8, 46)
	return Vector2i(-1, -1)

static func _showcase(host: Node3D, grid: SMDomainGrid) -> void:
	var neon: bool = not Settings.low()
	_place(host, grid, "lm_shwedagon", Vector2i(10, 8), true, neon)
	_place(host, grid, "city_hdb", Vector2i(24, 8), false, neon)
	_place(host, grid, "city_highrise", Vector2i(34, 6), false, neon)
	_place(host, grid, "peranakan_shophouse", Vector2i(44, 10), false, neon)
	_place(host, grid, "city_flyover", Vector2i(54, 12), false, neon)
	_place(host, grid, "wet_market", Vector2i(62, 10), false, neon)
	_place(host, grid, "concrete_bridge", Vector2i(34, 24), false, neon)
	_place(host, grid, "longtail_boat", Vector2i(18, 24), false, false)
	_place(host, grid, "jungle_waterfall", Vector2i(8, 40), false, false)
	_place(host, grid, "karst_tower", Vector2i(64, 42), false, false)
	_place(host, grid, "banyan_tree", Vector2i(22, 40), false, false)
	_place(host, grid, "bamboo_clump", Vector2i(40, 42), false, false)
	_place(host, grid, "lao_sim", Vector2i(50, 40), false, neon)

## The plan already holds the landmark rect, so nothing is held here. Props are decoration and never block.
static func _stamp_plan(host: Node3D, grid: SMDomainGrid, plan: SMMapPlan, neon: bool) -> void:
	if plan == null:
		return
	var mark: String = str(plan.landmark.get("id", ""))
	if mark != "":
		var rect: Rect2i = plan.landmark.get("rect", Rect2i()) as Rect2i
		var twin: Rect2i = plan.landmark.get("twin", rect) as Rect2i
		_put(host, grid, mark, "Landmark_%s" % mark, plan.rect_center(rect), 0.0, neon)
		if twin != rect:
			_put(host, grid, mark, "Landmark_%s_b" % mark, plan.rect_center(twin), 180.0, neon)
	for i: int in plan.props.size():
		var row: Dictionary = plan.props[i]
		var id: String = str(row["id"])
		_put(host, grid, id, "Scenery_%s_%d" % [id, i], plan.cell_center(row["cell"] as Vector2i), float(row["yaw"]), neon)

static func _put(host: Node3D, grid: SMDomainGrid, id: String, node_name: String, at: Vector3, yaw: float, neon: bool) -> void:
	if host.get_node_or_null(node_name) != null:
		return
	var cell: Vector2i = grid.cell_at(at)
	if not grid.in_bounds(cell):
		return
	var root: Node3D = _load(id)
	if root == null:
		return
	root.name = node_name
	root.scale = Vector3.ONE * fit_of(id, _bounds(root))
	root.rotation_degrees.y = yaw
	root.position = at + Vector3(0.0, 1.55 if grid.domain_at_cell(cell) == SMDomainGrid.Domain.CLIFF else 0.0, 0.0)
	_glow(root, neon and not Settings.low())
	host.add_child(root)

static func _neon(profile: String) -> bool:
	return profile == "sop" or profile == "chiang" or profile == "phillips" or profile == "mekong" or profile == "showcase"

static func _place(host: Node3D, grid: SMDomainGrid, id: String, cell: Vector2i, landmark: bool, neon: bool) -> void:
	if host.get_node_or_null("Landmark_%s" % id) != null or host.get_node_or_null("Scenery_%s" % id) != null:
		return
	if not grid.in_bounds(cell):
		return
	var domain: int = grid.domain_at_cell(cell)
	var wet_ok: bool = id == "concrete_bridge" or id == "truss_bridge" or id == "longtail_boat" or id == "karst_sea_stack" or id == "jetty"
	if domain != SMDomainGrid.Domain.LAND and not wet_ok:
		return
	var root: Node3D = _load(id)
	if root == null:
		return
	var authored: AABB = _bounds(root)
	var fit: float = fit_of(id, authored)
	root.name = "Landmark_%s" % id if landmark else "Scenery_%s" % id
	root.scale = Vector3.ONE * fit
	root.position = grid.cell_center(cell)
	_glow(root, neon and not Settings.low())
	host.add_child(root)
	if not landmark:
		return
	var span: float = maxf(authored.size.x, authored.size.z) * fit
	var half: int = maxi(1, int(ceil(span / grid.cell_size * 0.5)))
	var rect := Rect2i(cell.x - half, cell.y - half, half * 2 + 1, half * 2 + 1)
	var clipped: Rect2i = rect.intersection(Rect2i(0, 0, grid.cols, grid.rows))
	for y: int in range(clipped.position.y, clipped.position.y + clipped.size.y):
		for x: int in range(clipped.position.x, clipped.position.x + clipped.size.x):
			var spot := Vector2i(x, y)
			if grid.domain_at_cell(spot) == SMDomainGrid.Domain.LAND:
				grid.hold(Rect2i(x, y, 1, 1))

## Scenery scale from the chart class in data/model_scale.json. Unlisted props keep their authored size.
static func fit_of(id: String, authored: AABB) -> float:
	return Scale.scale_for(authored.size, Scale.scenery_target(id))

static func _bounds(root: Node3D) -> AABB:
	return Models._merged_aabb(root)

static func _glow(root: Node, on: bool) -> void:
	var glow: Node = root.find_child("Glow", true, false)
	if glow is Node3D:
		(glow as Node3D).visible = on

static func _bake(body: MeshInstance3D, fit: float = 1.0) -> Mesh:
	var mesh: Mesh = body.mesh
	var xf: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * fit), Vector3.ZERO) * body.transform
	if xf.is_equal_approx(Transform3D.IDENTITY):
		return mesh
	var out := ArrayMesh.new()
	var tool := SurfaceTool.new()
	for surface: int in mesh.get_surface_count():
		tool.clear()
		tool.append_from(mesh, surface, xf)
		tool.set_material(mesh.surface_get_material(surface))
		tool.commit(out)
	return out

static func _load(id: String) -> Node3D:
	if _scene.has(id) and _scene[id] != null:
		var kept: Node = _scene[id] as Node
		if is_instance_valid(kept):
			return kept.duplicate() as Node3D
	var path: String = _file(id)
	if path == "":
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = FAILED
	if path.begins_with("user://") or path.begins_with("res://"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			err = doc.append_from_buffer(bytes, "", state)
		if err != OK:
			err = doc.append_from_file(ProjectSettings.globalize_path(path), state)
	else:
		err = doc.append_from_file(path, state)
	if err != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	var root: Node3D = generated as Node3D
	if root == null:
		return null
	_scene[id] = root
	return root.duplicate() as Node3D

static func _file(id: String) -> String:
	var res_path: String = "res://game/models/env/%s.glb" % id
	if FileAccess.file_exists(res_path):
		return res_path
	var packed: String = ProjectSettings.globalize_path("res://game/models/env/%s.glb" % id)
	if FileAccess.file_exists(packed):
		return packed
	var base: String = OS.get_executable_path().get_base_dir()
	var beside: String = base.path_join("models/env/%s.glb" % id)
	if FileAccess.file_exists(beside):
		return beside
	var bundle_res: String = base.get_base_dir().path_join("Resources/models/env/%s.glb" % id)
	if FileAccess.file_exists(bundle_res):
		return bundle_res
	var web: String = ProjectSettings.globalize_path("res://build/web/models/env/%s.glb" % id)
	if FileAccess.file_exists(web):
		return web
	var cached: String = "user://env/%s.glb" % id
	if FileAccess.file_exists(cached):
		return cached
	return ""

static func _request_owner(owner: Node) -> Node:
	if owner != null and owner.get_tree() != null and owner.get_tree().root != null:
		return owner.get_tree().root
	return owner

## The web pack leaves glbs beside the page. Download one and swap it onto the props.
static func pull_web(host: Node, ids: PackedStringArray) -> void:
	if host == null or not OS.has_feature("web"):
		return
	var req_owner: Node = _request_owner(host)
	for id: String in ids:
		if id == "":
			continue
		if _file(id) != "" or has_mesh(id):
			_apply_to_host(host, id, mesh_of(id))
			continue
		var wait_list: Array = _hosts.get(id, [])
		if not wait_list.has(host):
			wait_list.append(host)
		_hosts[id] = wait_list
		if _inflight.has(id):
			continue
		_inflight[id] = true
		_scene.erase(id)
		_mesh.erase(id)
		var http := HTTPRequest.new()
		http.timeout = 60.0
		http.accept_gzip = false
		http.ready.connect(_start_web_request.bind(http, id), CONNECT_ONE_SHOT)
		req_owner.add_child.call_deferred(http)

static func _start_web_request(http: HTTPRequest, id: String) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		_inflight.erase(id)
		if is_instance_valid(http):
			http.queue_free()
		_release_waiters(id)
		return
	http.request_completed.connect(_got_web.bind(http, id))
	var err: Error = http.request(_page() + "models/env/%s.glb" % id)
	if err != OK:
		_inflight.erase(id)
		http.queue_free()
		_release_waiters(id)

static func wanted(profile: String, plan: SMMapPlan = null) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	if plan != null:
		var mark: String = str(plan.landmark.get("id", ""))
		if mark != "":
			ids.append(mark)
		for row: Dictionary in plan.props + plan.lots + plan.groves:
			if not ids.has(str(row["id"])):
				ids.append(str(row["id"]))
	ids.append(tree_id(profile))
	ids.append(palm_id(profile))
	var house: String = house_id(profile)
	if house != "":
		ids.append(house)
	ids.append("mekong_stilt_house" if profile == "mekong" or profile == "atolls" else "shan_stilt_house")
	var mark: String = _mark_of(profile)
	if mark != "":
		ids.append(mark)
	if profile == "atolls":
		ids.append("karst_sea_stack")
		ids.append("jetty")
	if profile == "showcase":
		ids.append_array(PackedStringArray([
			"lm_shwedagon", "city_hdb", "city_highrise", "peranakan_shophouse", "city_flyover",
			"wet_market", "concrete_bridge", "longtail_boat", "jungle_waterfall", "karst_tower",
			"banyan_tree", "bamboo_clump", "lao_sim",
		]))
	return ids

static func _got_web(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, id: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_inflight.erase(id)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		_release_waiters(id)
		return
	var cache_path: String = "user://env/%s.glb" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://env"))
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(body)
		file.close()
	_scene.erase(id)
	_mesh.erase(id)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_buffer(body, "", state) == OK:
		var generated: Node = doc.generate_scene(state)
		if generated is Node3D:
			_scene[id] = generated as Node3D
	var mesh: Mesh = mesh_of(id)
	var wait_list: Array = _hosts.get(id, [])
	_hosts.erase(id)
	for item: Variant in wait_list:
		var host: Node = item as Node
		_apply_to_host(host, id, mesh)

static func _apply_to_host(host: Node, id: String, mesh: Mesh) -> void:
	if not is_instance_valid(host):
		return
	for child: Node in host.get_children():
		var props: MultiMeshInstance3D = child as MultiMeshInstance3D
		if props == null or props.multimesh == null:
			continue
		if str(props.get_meta("env_id", "")) != id:
			continue
		if mesh != null:
			props.multimesh.mesh = preload("res://game/ground_view.gd")._fade_mesh(mesh)
		props.set_meta("standin_held", false)
		props.visible = not Settings.low()
	var grid: SMDomainGrid = host.get_meta("env_grid", null) as SMDomainGrid
	var profile: String = str(host.get_meta("env_profile", ""))
	if grid != null and profile != "":
		stamp(host, grid, profile)
	if host.has_method("_on_env_ready"):
		host.call("_on_env_ready", id)

static func _release_waiters(id: String) -> void:
	var wait_list: Array = _hosts.get(id, [])
	_hosts.erase(id)
	for item: Variant in wait_list:
		var host: Node = item as Node
		if not is_instance_valid(host):
			continue
		for child: Node in host.get_children():
			var props: MultiMeshInstance3D = child as MultiMeshInstance3D
			if props == null or str(props.get_meta("env_id", "")) != id:
				continue
			props.set_meta("standin_held", false)
			props.visible = not Settings.low()

static func _page() -> String:
	var href: String = str(JavaScriptBridge.eval("window.location.href", true))
	var cut: int = href.find("?")
	if cut >= 0:
		href = href.substr(0, cut)
	cut = href.find("#")
	if cut >= 0:
		href = href.substr(0, cut)
	var slash: int = href.rfind("/")
	if slash >= 0:
		href = href.substr(0, slash + 1)
	return href
