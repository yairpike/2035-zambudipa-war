extends RefCounted
## Neutral Tripo scenery. No faction paint. Glow is the emissive node, hidden on Low.
## Landmark footprints block ground movement and stay indestructible because they are not units.

const Settings = preload("res://game/match_settings.gd")
const Scale = preload("res://game/model_scale.gd")
const Models = preload("res://game/model_registry.gd")
const AssetPack = preload("res://game/asset_pack.gd")

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

## The landmark and loose scenery from the map plan, or from the dressing of a map with no plan.
static func stamp(host: Node3D, grid: SMDomainGrid, profile: String) -> void:
	if host == null or grid == null:
		return
	var plan_id: String = str(host.get_meta("map_plan", ""))
	if plan_id != "":
		_stamp_plan(host, grid, SMMapPlan.of(plan_id), _neon(profile))
		return
	var dress_id: String = str(host.get_meta("map_dressing", ""))
	if dress_id != "":
		_stamp_plan(host, grid, SMMapPlan.dressing(dress_id), _neon(profile))

## The plan already holds the landmark rect, so nothing is held here. Props are decoration and never block.
## The landmark turns its calibrated facade to the street in front of its lot.
static func _stamp_plan(host: Node3D, grid: SMDomainGrid, plan: SMMapPlan, neon: bool) -> void:
	if plan == null:
		return
	for lot: Dictionary in plan.lots:
		if str(lot["kind"]) != "landmark":
			continue
		var mark: String = str(lot["id"])
		var node_name: String = "Landmark_%s" % mark if int(lot["side"]) == 0 else "Landmark_%s_b" % mark
		_put(host, grid, mark, node_name, plan.rect_center(lot["rect"] as Rect2i), SMMapPlan.turn_for(mark, float(lot["yaw"])), neon)
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
	var fetched: String = AssetPack.root().path_join("models/env/%s.glb" % id)
	if FileAccess.file_exists(fetched):
		return fetched
	var web: String = ProjectSettings.globalize_path("res://build/web/models/env/%s.glb" % id)
	if FileAccess.file_exists(web):
		return web
	var cached: String = "user://env/%s.glb" % id
	if FileAccess.file_exists(cached):
		return cached
	return ""

static func _request_owner(owner: Node) -> Node:
	if owner != null and owner.is_inside_tree() and owner.get_tree() != null and owner.get_tree().root != null:
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
		for row: Dictionary in plan.props + plan.lots + plan.groves:
			if not ids.has(str(row["id"])):
				ids.append(str(row["id"]))
	ids.append(tree_id(profile))
	ids.append(palm_id(profile))
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
