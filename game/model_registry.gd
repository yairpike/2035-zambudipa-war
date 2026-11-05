extends RefCounted
## Swaps a procedural mesh for res://game/models/<id>.glb or .gltf when that file exists.
## The procedural mesh stays when the file is missing. See game/models/README.md.

static func apply_unit(body: MeshInstance3D, id: String, primary: Color = Color.WHITE, accent: Color = Color.WHITE) -> bool:
	if body == null or id == "":
		return false
	if _mount_unit(body, id, primary, accent):
		if Catalog.RIGGED_YAW.has(id) and not bool(body.get_meta("model_rigged", false)):
			_queue(body, id, primary, accent, "rigged")
		return true
	_queue(body, id, primary, accent, "unit")
	if Catalog.RIGGED_YAW.has(id):
		_queue(body, id, primary, accent, "rigged")
	return false

static func apply_structure(host: MeshInstance3D, id: String, primary: Color = Color.WHITE, accent: Color = Color.WHITE) -> bool:
	if host == null or host.mesh == null or id == "":
		return false
	if _mount_structure(host, id, primary, accent):
		return true
	_queue(host, id, primary, accent, "structure")
	return false

static func _mount_unit(body: MeshInstance3D, id: String, primary: Color, accent: Color) -> bool:
	if str(body.get_meta("model", "")) != "":
		return true
	var rigged: bool = true
	var scene: Node3D = _scene(RIGGED + id)
	if scene == null:
		rigged = false
		scene = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = _merged_aabb(body)
	_mount(body, scene, footprint, false, id, _yaw_of(RIGGED + id if rigged else id), Scale.unit_target(id))
	body.set_meta("model_rigged", rigged)
	_paint(body, primary, accent, id)
	return true

## A rigged copy that arrives after the static model swaps in place.
static func _swap_rigged(body: MeshInstance3D, id: String, primary: Color, accent: Color) -> bool:
	if bool(body.get_meta("model_rigged", false)):
		return true
	var scene: Node3D = _scene(RIGGED + id)
	if scene == null:
		return false
	var old: Node = body.get_node_or_null("Model")
	var footprint: AABB = _merged_aabb(body)
	if old != null:
		body.remove_child(old)
		old.free()
	body.set_meta("model", "")
	_mount(body, scene, footprint, false, id, _yaw_of(RIGGED + id), Scale.unit_target(id))
	body.set_meta("model_rigged", true)
	_paint(body, primary, accent, id)
	return true

static func _mount_structure(host: MeshInstance3D, id: String, primary: Color, accent: Color) -> bool:
	if str(host.get_meta("model", "")) != "":
		return true
	if host.mesh == null:
		return false
	var scene: Node3D = _scene(id)
	if scene == null:
		return false
	var footprint: AABB = host.mesh.get_aabb()
	var plot: Vector2 = host.get_meta("footprint_m", Vector2.ZERO) as Vector2
	if plot != Vector2.ZERO:
		footprint = AABB(Vector3(-plot.x * 0.5, footprint.position.y, -plot.y * 0.5), Vector3(plot.x, footprint.size.y, plot.y))
	_mount(host, scene, footprint, true, id, _yaw_of(id), {}, plot)
	host.set_meta("model_id", id)
	_paint(host, primary, accent, id)
	return true

## Near-black primaries would multiply the grey palette down to plain metal.
static func body_ink(primary: Color) -> Color:
	var peak: float = maxf(primary.r, maxf(primary.g, primary.b))
	var ink: Color = primary
	if peak < 0.45:
		var gain: float = 0.45 / maxf(peak, 0.04)
		ink = Color(minf(primary.r * gain, 1.0), minf(primary.g * gain, 1.0), minf(primary.b * gain, 1.0), primary.a)
	var hi: float = maxf(ink.r, maxf(ink.g, ink.b))
	var lo: float = minf(ink.r, minf(ink.g, ink.b))
	if hi - lo < 0.05:
		ink = ink.lerp(Color(0.62, 0.46, 0.30), 0.4)
	return ink

## About 60% of the lifted faction colour, mixed into a dark ground so the palette stays shaded.
static func body_shade(primary: Color) -> Color:
	return body_ink(primary).lerp(Color(0.16, 0.15, 0.13), 0.4)

## A light multiply for a textured body. White leaves the texture alone.
static func body_wash(primary: Color) -> Color:
	return Color.WHITE.lerp(body_ink(primary), 0.22)

static func warm(owner: Node) -> void:
	if owner == null or not OS.has_feature("web"):
		return
	var host: Node = _request_owner(owner)
	var listed: String = _index_text()
	if listed != "":
		_arm_index(host, listed)
		return
	_pull_index(host)

static func model_id_for(node_name: String) -> String:
	var name: String = node_name.to_lower()
	if name.begins_with("built_"):
		return name.trim_prefix("built_")
	return name

static var _templates: Dictionary = {}
static var _sources: Dictionary = {}

## Keys with this prefix name the rigged copy of a unit in game/models/rigged/. Structures never use it.
const RIGGED: String = "rigged/"
const Catalog = preload("res://game/model_catalog.gd")
const Scale = preload("res://game/model_scale.gd")

static func _scene(key: String) -> Node3D:
	var again: Node3D = _again(key)
	if again != null:
		return again
	return _load_scene(key)

## Exports flatten Tripo files into models/, so a Tripo id counts as Tripo anywhere but the repo's stand-in folder.
static func _yaw_of(key: String) -> float:
	var path: String = str(_sources.get(key, ""))
	var id: String = key.trim_prefix(RIGGED)
	if not key.begins_with(RIGGED) and _tripo_id(id) and not path.get_base_dir().ends_with("game/models"):
		path = "/tripo/" + path.get_file()
	return Catalog.forward_yaw_deg(id, path)

static func source_of(key: String) -> String:
	return str(_sources.get(key, ""))

## One parsed glTF per id, kept as an off-tree template. Each unit gets a duplicate; _paint then gives it its own meshes.
## Re-running generate_scene on a kept GLTFState renames nodes and bones (R_Hand_2, ...), which unbinds sockets and clips.
static func clear_templates() -> void:
	for key: Variant in _templates.keys():
		var node: Node = _templates[key] as Node
		if node != null and is_instance_valid(node):
			node.free()
	_templates.clear()
	_waiting.clear()

static func _again(id: String) -> Node3D:
	var template: Node3D = _templates.get(id) as Node3D
	if template == null or not is_instance_valid(template):
		return null
	return template.duplicate() as Node3D

static func _keep(id: String, scene: Node3D) -> void:
	var old: Node3D = _templates.get(id) as Node3D
	if old != null and is_instance_valid(old):
		old.free()
	_templates[id] = scene.duplicate() as Node3D

static func _load_scene(id: String) -> Node3D:
	var path: String = _path(id)
	if path == "":
		return null
	_sources[id] = path
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var packed: PackedScene = load(path) as PackedScene
		if packed != null:
			var instanced: Node = packed.instantiate()
			return instanced as Node3D
	if path.begins_with("user://") or path.begins_with("res://"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if not bytes.is_empty():
			var parsed: Node3D = _from_buffer(id, bytes)
			if parsed != null:
				return parsed
	var file: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		file = ProjectSettings.globalize_path(path)
	return _from_gltf(id, file)

static func _from_buffer(id: String, bytes: PackedByteArray) -> Node3D:
	if bytes.is_empty():
		return null
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_buffer(bytes, "", state) != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	var scene: Node3D = generated as Node3D
	if scene != null:
		_keep(id, scene)
	return scene

static var _tripo_set: Dictionary = {}
static var _tripo_ready: bool = false
## Empty uses the faction opposite the player. A mission can set this before units spawn.
static var look_faction: String = ""

static func enemy_look(player_faction: String) -> String:
	if look_faction != "":
		return look_faction
	if player_faction == "nmrf":
		return "mvd"
	if player_faction == "mvd":
		return "gtfc"
	if player_faction == "black_market":
		return "gtfc"
	return "nmrf"

## A campaign soldier has no roster id. Pick a finished model for that faction and role.
static func fallback_unit(role: String, loco: String, faction: String) -> String:
	var slot: String = "infantry"
	if role == "air" or role == "drone" or loco == "air":
		slot = "air"
	elif role == "boat" or role == "amphibious" or loco == "naval":
		slot = "boat"
	elif role == "armor":
		slot = "armor"
	elif role == "artillery":
		slot = "artillery"
	var side: String = faction
	if side != "gtfc" and side != "nmrf" and side != "mvd" and side != "black_market":
		side = "nmrf"
	if side == "gtfc":
		if slot == "armor":
			return "amber_tank"
		if slot == "artillery":
			return "monsoon_tube"
		if slot == "boat":
			return "channel_skiff"
		if slot == "air":
			return "bullion_truck"
		return "militia"
	if side == "mvd":
		if slot == "armor":
			return "cyan_ifv"
		if slot == "artillery":
			return "charcoal_mortar"
		if slot == "boat":
			return "cyan_skiff"
		if slot == "air":
			return "hub_drone"
		return "clearance_trooper"
	if side == "black_market":
		if slot == "air" or slot == "artillery":
			return "su30"
		if slot == "boat":
			return "ch4"
		return "orlan10"
	if slot == "armor":
		return "mangrove_skiff"
	if slot == "artillery":
		return "mangrove_tube"
	if slot == "boat":
		return "emerald_gunboat"
	if slot == "air":
		return "jade_skiff"
	return "river_rifle"

static func yard_of(faction: String) -> String:
	if faction == "mvd":
		return "command_hub"
	if faction == "nmrf":
		return "packer"
	return "scaffold_yard"

static func structure_id(node_name: String) -> String:
	var id: String = model_id_for(node_name)
	if id.begins_with("foebuilt_"):
		id = id.trim_prefix("foebuilt_")
	if id == "playeryard":
		return yard_of(SMFront.current())
	if id == "enemyyard" or id == "enemybase":
		return yard_of(enemy_look(SMFront.current()))
	var specific: String = "%s_%s" % [SMFront.current(), id]
	if _tripo_id(specific):
		return specific
	return id

static func _tripo_id(id: String) -> bool:
	if not _tripo_ready:
		_tripo_ready = true
		var listed: String = ""
		if FileAccess.file_exists("res://data/tripo_ids.txt"):
			listed = FileAccess.get_file_as_string("res://data/tripo_ids.txt")
		for line: String in listed.split("\n"):
			var name: String = line.strip_edges()
			if name != "":
				_tripo_set[name] = true
	return bool(_tripo_set.get(id, false))

static func _authored_size(_id: String) -> Vector3:
	return Vector3.ZERO

static func _cache_file(id: String) -> String:
	if id.begins_with(RIGGED):
		return "user://models/%s.glb" % id
	if _tripo_id(id):
		return "user://models/tripo/%s.glb" % id
	return "user://models/%s.glb" % id

static func _cached(id: String) -> String:
	var path: String = _cache_file(id)
	if FileAccess.file_exists(path):
		return path
	if not id.begins_with(RIGGED) and not _tripo_id(id) and FileAccess.file_exists("user://models/%s.gltf" % id):
		return "user://models/%s.gltf" % id
	return ""

static func _path(key: String) -> String:
	if key.begins_with(RIGGED):
		return _rigged_path(key.trim_prefix(RIGGED))
	var id: String = key
	if id == "" or id.contains("..") or id.contains("/") or id.contains("\\"):
		return ""
	var packed_try: PackedStringArray = PackedStringArray()
	if _tripo_id(id):
		packed_try.append("res://game/models/tripo/%s.glb" % id)
		packed_try.append("res://game/models/tripo/%s.gltf" % id)
		packed_try.append(_cache_file(id))
	packed_try.append("res://game/models/%s.glb" % id)
	packed_try.append("res://game/models/%s.gltf" % id)
	if not _tripo_id(id):
		packed_try.append("user://models/%s.glb" % id)
		packed_try.append("user://models/%s.gltf" % id)
	for packed: String in packed_try:
		if ResourceLoader.exists(packed) or FileAccess.file_exists(packed):
			return packed
	var base: String = OS.get_executable_path().get_base_dir()
	var roots: PackedStringArray = PackedStringArray()
	if _tripo_id(id):
		roots.append(ProjectSettings.globalize_path("res://").path_join("game/models/tripo"))
	roots.append(ProjectSettings.globalize_path("res://").path_join("game/models"))
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/models"))
	roots.append(base.path_join("models"))
	roots.append(base.get_base_dir().path_join("Resources/models"))
	for root: String in roots:
		var found: String = root.path_join("%s.glb" % id)
		if FileAccess.file_exists(found):
			return found
		var gltf_path: String = root.path_join("%s.gltf" % id)
		if FileAccess.file_exists(gltf_path):
			return gltf_path
	return ""

static func _rigged_path(id: String) -> String:
	if id == "" or id.contains("..") or id.contains("/") or id.contains("\\") or not Catalog.RIGGED_YAW.has(id):
		return ""
	var tries: PackedStringArray = PackedStringArray()
	tries.append("res://game/models/rigged/%s.glb" % id)
	tries.append(_cache_file(RIGGED + id))
	var base: String = OS.get_executable_path().get_base_dir()
	tries.append(ProjectSettings.globalize_path("res://").path_join("game/models/rigged/%s.glb" % id))
	tries.append(ProjectSettings.globalize_path("res://").path_join("build/web/models/rigged/%s.glb" % id))
	tries.append(base.path_join("models/rigged/%s.glb" % id))
	tries.append(base.get_base_dir().path_join("Resources/models/rigged/%s.glb" % id))
	for path: String in tries:
		if FileAccess.file_exists(path):
			return path
	return ""

static var _index: PackedStringArray = PackedStringArray()
static var _index_read: bool = false
static var _inflight: Dictionary = {}
static var _waiting: Array[MeshInstance3D] = []

static func _queue(body: MeshInstance3D, id: String, primary: Color, accent: Color, kind: String) -> void:
	if body == null or not OS.has_feature("web"):
		return
	body.set_meta("model_id", id)
	body.set_meta("model_primary", primary)
	body.set_meta("model_accent", accent)
	var key: String = id
	if kind == "rigged":
		body.set_meta("model_rigged_wait", true)
		key = RIGGED + id
	else:
		body.set_meta("model_kind", kind)
		if not _index_read or _index.has(id):
			_hold_standin(body)
		else:
			_release_standin(body)
	if not _waiting.has(body):
		_waiting.append(body)
	if not body.is_inside_tree() or not _index_read or not _index.has(key):
		return
	var host: Node = _request_owner(body)
	_fetch(host, key)

## The procedural mesh stays hidden while a GLB for this id is still on the way.
static func _hold_standin(body: MeshInstance3D) -> void:
	if body == null or str(body.get_meta("model", "")) != "":
		return
	body.set_meta("standin_held", true)
	body.visible = false

static func _release_standin(body: MeshInstance3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not bool(body.get_meta("standin_held", false)):
		return
	body.set_meta("standin_held", false)
	if str(body.name) == "HubShell" and not bool(body.get_meta("hub_placed", false)):
		return
	body.visible = true

static func _release_unlisted() -> void:
	var still: Array[MeshInstance3D] = []
	for body: MeshInstance3D in _waiting:
		if not is_instance_valid(body):
			continue
		var id: String = str(body.get_meta("model_id", ""))
		if str(body.get_meta("model", "")) != "":
			body.visible = true
			if bool(body.get_meta("model_rigged_wait", false)):
				still.append(body)
			continue
		if id != "" and not _index.has(id):
			_release_standin(body)
			continue
		still.append(body)
	_waiting = still

static func _redress(key: String) -> void:
	var rigged: bool = key.begins_with(RIGGED)
	var id: String = key.trim_prefix(RIGGED)
	var still: Array[MeshInstance3D] = []
	for body: MeshInstance3D in _waiting:
		if not is_instance_valid(body):
			continue
		if str(body.get_meta("model_id", "")) != id:
			still.append(body)
			continue
		var primary: Color = body.get_meta("model_primary", Color.WHITE)
		var accent: Color = body.get_meta("model_accent", Color.WHITE)
		if rigged and bool(body.get_meta("model_rigged_wait", false)):
			if _swap_rigged(body, id, primary, accent):
				body.set_meta("model_rigged_wait", false)
		elif not rigged and str(body.get_meta("model", "")) == "":
			if str(body.get_meta("model_kind", "unit")) == "structure":
				_mount_structure(body, id, primary, accent)
			else:
				_mount_unit(body, id, primary, accent)
		if str(body.get_meta("model", "")) == "" or bool(body.get_meta("model_rigged_wait", false)):
			still.append(body)
	_waiting = still

static func _arm_index(owner: Node, text: String) -> void:
	if _index_read:
		return
	_index_read = true
	for line: String in text.split("\n"):
		var name: String = line.strip_edges()
		if name.ends_with(".glb") or name.ends_with(".gltf"):
			var id: String = name.get_basename()
			_index.append(id)
	_prefetch_listed(owner)
	_release_unlisted()
	_fetch_waiting(owner)

static func _prefetch_listed(owner: Node) -> void:
	if owner == null:
		return
	for id: String in _index:
		_fetch(owner, id)

static func _request_owner(owner: Node) -> Node:
	if owner != null and owner.get_tree() != null and owner.get_tree().root != null:
		return owner.get_tree().root
	return owner

static func _pull_index(owner: Node) -> void:
	if owner == null or _index_read:
		return
	var host: Node = _request_owner(owner)
	if not host.is_inside_tree():
		_pull_index.call_deferred(owner)
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.accept_gzip = false
	http.ready.connect(_start_index.bind(http, host), CONNECT_ONE_SHOT)
	host.add_child.call_deferred(http)

static func _start_index(http: HTTPRequest, host: Node) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_got_index.bind(http, host))
	var err: Error = http.request(_page() + "models/index.txt")
	if err != OK:
		http.queue_free()

static func _got_index(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, owner: Node) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		if not _index_read:
			_index_read = true
			_release_unlisted()
		return
	_arm_index(owner, body.get_string_from_utf8())

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

static func _index_text() -> String:
	var packed: String = "res://game/models/index.txt"
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_string(packed)
	var roots: PackedStringArray = PackedStringArray()
	var base: String = OS.get_executable_path().get_base_dir()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/models/index.txt"))
	roots.append(base.path_join("models/index.txt"))
	roots.append(base.get_base_dir().path_join("Resources/models/index.txt"))
	for path: String in roots:
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_string(path)
	return ""

static func _fetch_waiting(owner: Node) -> void:
	var seen: Dictionary = {}
	for body: MeshInstance3D in _waiting:
		if not is_instance_valid(body):
			continue
		var id: String = str(body.get_meta("model_id", ""))
		if id == "":
			continue
		var keys: PackedStringArray = PackedStringArray()
		if str(body.get_meta("model", "")) == "":
			keys.append(id)
		if bool(body.get_meta("model_rigged_wait", false)):
			keys.append(RIGGED + id)
		for key: String in keys:
			if seen.has(key) or not _index.has(key):
				continue
			seen[key] = true
			_fetch(owner, key)

static func _fetch(owner: Node, id: String) -> void:
	if owner == null or _inflight.has(id) or id.contains(".."):
		return
	if _cached(id) != "" or _again(id) != null:
		_redress(id)
		return
	var host: Node = _request_owner(owner)
	if not host.is_inside_tree():
		_fetch.call_deferred(owner, id)
		return
	_inflight[id] = true
	var http := HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	http.ready.connect(_start_model.bind(http, id), CONNECT_ONE_SHOT)
	host.add_child.call_deferred(http)

static func _start_model(http: HTTPRequest, id: String) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		_inflight.erase(id)
		if is_instance_valid(http):
			http.queue_free()
		_give_up(id)
		return
	http.request_completed.connect(_got_model.bind(http, id))
	var err: Error = http.request("%smodels/%s.glb" % [_page(), id])
	if err != OK:
		_inflight.erase(id)
		http.queue_free()
		_give_up(id)

static func _got_model(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, id: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_inflight.erase(id)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		_give_up(id)
		return
	var cache_path: String = _cache_file(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_path.get_base_dir()))
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(body)
		file.close()
	var parsed: Node3D = _from_buffer(id, body)
	if parsed != null:
		parsed.free()
	_redress(id)

static func _give_up(id: String) -> void:
	var bare: String = id.trim_prefix(RIGGED)
	var rigged: bool = id.begins_with(RIGGED)
	for body: MeshInstance3D in _waiting:
		if not is_instance_valid(body):
			continue
		if str(body.get_meta("model_id", "")) != bare:
			continue
		if rigged:
			body.set_meta("model_rigged_wait", false)
		elif str(body.get_meta("model", "")) == "":
			_release_standin(body)

static func _from_gltf(id: String, path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var generated: Node = doc.generate_scene(state)
	var scene: Node3D = generated as Node3D
	if scene != null:
		_keep(id, scene)
	return scene

static func _paint(root: Node3D, primary: Color, accent: Color, id: String) -> void:
	_paint_node(root, primary, accent, _tripo_id(id))

static func _paint_node(node: Node, primary: Color, accent: Color, textured_wash: bool) -> void:
	var n: String = str(node.name)
	if n == "Wake" or n == "BowSpray" or n == "ContactShadow" or n == "Wheels":
		return
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		_paint_surfaces(mesh_node, primary, accent, textured_wash)
	for child: Node in node.get_children():
		_paint_node(child, primary, accent, textured_wash)

static func _paint_surfaces(mesh_node: MeshInstance3D, primary: Color, accent: Color, textured_wash: bool) -> void:
	mesh_node.material_override = null
	if mesh_node.mesh != null:
		mesh_node.mesh = mesh_node.mesh.duplicate() as Mesh
	for surface: int in mesh_node.mesh.get_surface_count():
		var src: Material = mesh_node.mesh.surface_get_material(surface)
		var name: String = ""
		if src != null:
			name = str(src.resource_name).to_lower()
		if name == "":
			name = str(mesh_node.name).to_lower()
		if name == "wake":
			continue
		var mat: StandardMaterial3D = _copy_mat(src)
		var trim: bool = name == "trim" or str(mesh_node.name).to_lower() == "trim"
		if trim:
			mat.albedo_color = accent
			mat.albedo_texture = null
			mat.roughness = 0.55
			mat.metallic = 0.0
			mat.resource_name = "Trim"
		elif textured_wash and mat.albedo_texture != null:
			mat.albedo_color = body_wash(primary)
			mat.resource_name = "Body"
		else:
			mat.albedo_color = body_shade(primary)
			mat.roughness = 0.84
			mat.metallic = 0.0
			mat.resource_name = "Body"
			if src is BaseMaterial3D and mat.albedo_texture == null:
				mat.albedo_texture = (src as BaseMaterial3D).albedo_texture
		mesh_node.set_surface_override_material(surface, mat)

static func _copy_mat(src: Material) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var base: BaseMaterial3D = src as BaseMaterial3D
	if base == null:
		return mat
	mat.albedo_color = base.albedo_color
	mat.albedo_texture = base.albedo_texture
	mat.normal_enabled = base.normal_enabled
	mat.normal_texture = base.normal_texture
	mat.roughness = base.roughness
	mat.metallic = base.metallic
	mat.metallic_texture = base.metallic_texture
	mat.metallic_texture_channel = base.metallic_texture_channel
	mat.roughness_texture = base.roughness_texture
	mat.roughness_texture_channel = base.roughness_texture_channel
	mat.ao_enabled = base.ao_enabled
	mat.ao_texture = base.ao_texture
	mat.ao_texture_channel = base.ao_texture_channel
	mat.texture_filter = base.texture_filter
	return mat

## `yaw_deg` turns the model's authored forward onto -Z inside the Model node, so fitting sees the turned bounds.
static func _mount(body: MeshInstance3D, scene: Node3D, footprint: AABB, fill: bool, id: String, yaw_deg: float = 0.0, target: Dictionary = {}, plot: Vector2 = Vector2.ZERO) -> void:
	if absf(yaw_deg) > 0.01:
		var holder: Node3D = Node3D.new()
		scene.name = "Facing"
		scene.rotation.y = deg_to_rad(yaw_deg)
		holder.add_child(scene)
		scene = holder
	scene.name = "Model"
	body.add_child(scene)
	body.set_meta("model_yaw", yaw_deg)
	if not target.is_empty() or plot != Vector2.ZERO:
		_fit_chart(scene, footprint, target, plot)
	else:
		_fit(scene, footprint, fill, _authored_size(id))
	_hoist(body, scene, "Turret")
	_hoist(body, scene, "Rotor")
	_hoist(body, scene, "Wake")
	var barrel: Node3D = scene.find_child("Barrel", true, false) as Node3D
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	if barrel != null and turret != null and barrel.get_parent() != turret:
		var barrel_xf: Transform3D = _to_root(turret, barrel)
		var barrel_parent: Node = barrel.get_parent()
		if barrel_parent != null:
			barrel_parent.remove_child(barrel)
		barrel.owner = null
		turret.add_child(barrel)
		barrel.transform = barrel_xf
	body.mesh = null
	body.material_override = null
	body.set_meta("model", scene.name)
	body.set_meta("hull_parts_ready", false)
	var keep_hidden: bool = str(body.name) == "HubShell" and not bool(body.get_meta("hub_placed", false)) and body.is_inside_tree()
	body.visible = not keep_hidden
	body.set_meta("standin_held", false)

static func _hoist(body: MeshInstance3D, scene: Node3D, node_name: String) -> void:
	var found: Node3D = scene.find_child(node_name, true, false) as Node3D
	if found == null:
		return
	var previous: Node = body.get_node_or_null(node_name)
	if previous != null:
		previous.free()
	var kept: Transform3D = _to_root(body, found)
	var parent: Node = found.get_parent()
	if parent != null:
		parent.remove_child(found)
	found.owner = null
	body.add_child(found)
	found.transform = kept

static func _fit(model: Node3D, footprint: AABB, fill: bool, authored: Vector3) -> void:
	var bounds: AABB = _merged_aabb(model)
	var src_x: float = authored.x if authored.x > 0.05 else bounds.size.x
	var src_z: float = authored.z if authored.z > 0.05 else bounds.size.z
	if src_x < 0.001 and src_z < 0.001:
		return
	var sx: float = footprint.size.x / maxf(src_x, 0.001)
	var sz: float = footprint.size.z / maxf(src_z, 0.001)
	var scale: float = minf(sx, sz)
	if fill:
		var span: float = maxf(footprint.size.x, footprint.size.z)
		var src: float = maxf(src_x, src_z)
		scale = span / maxf(src, 0.001)
	if scale <= 0.0 or is_inf(scale) or is_nan(scale):
		return
	model.scale = Vector3.ONE * scale
	var fitted: AABB = _merged_aabb(model)
	model.position += Vector3(
		footprint.get_center().x - fitted.get_center().x,
		footprint.position.y - fitted.position.y,
		footprint.get_center().z - fitted.get_center().z
	)

## Chart scale: a unit reaches its class height or length, a building fills its plot. Base on the ground, centred on the plot.
static func _fit_chart(model: Node3D, footprint: AABB, target: Dictionary, plot: Vector2) -> void:
	var bounds: AABB = _merged_aabb(model)
	if bounds.size.length() < 0.001:
		return
	var scale: float = Scale.footprint_scale(bounds.size, plot) if plot != Vector2.ZERO else Scale.scale_for(bounds.size, target)
	if scale <= 0.0 or is_inf(scale) or is_nan(scale):
		return
	model.scale = Vector3.ONE * scale
	var fitted: AABB = Transform3D(Basis.from_scale(model.scale), Vector3.ZERO) * bounds
	model.position = Vector3(
		footprint.get_center().x - fitted.get_center().x,
		footprint.position.y - fitted.position.y,
		footprint.get_center().z - fitted.get_center().z
	)

static func _merged_aabb(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var started: bool = false
	var meshes: Array[MeshInstance3D] = []
	var own: MeshInstance3D = root as MeshInstance3D
	if own != null and own.mesh != null:
		meshes.append(own)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			meshes.append(mesh_node)
	for mesh_node: MeshInstance3D in meshes:
		if _under_wake(mesh_node, root):
			continue
		var local: AABB = mesh_node.mesh.get_aabb()
		var placed: AABB = _to_root(root, mesh_node) * local
		if not started:
			box = placed
			started = true
		else:
			box = box.merge(placed)
	return box

static func _to_root(root: Node3D, mesh_node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var node: Node3D = mesh_node
	while node != null and node != root:
		xf = node.transform * xf
		var parent: Node = node.get_parent()
		node = parent as Node3D
	return xf

static func _under_wake(mesh_node: Node, root: Node) -> bool:
	var node: Node = mesh_node
	while node != null and node != root:
		var n: String = str(node.name)
		if n == "Wake" or n == "BowSpray" or n == "ContactShadow" or n == "Wheels":
			return true
		node = node.get_parent()
	var rn: String = str(root.name)
	return rn == "Wake" or rn == "BowSpray" or rn == "ContactShadow" or rn == "Wheels"
