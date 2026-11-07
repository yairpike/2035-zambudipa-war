extends RefCounted
## Sidebar portraits from the served cameos/ folder, outside the pack.
## Desktop runs also read res://cameos/. A new portrait is
## cameos/{id}.webp or cameos/{faction}_{id}.webp.
## Drop the file in and re-export. A missing file leaves the text button.

const Clips = preload("res://game/match_audio.gd")

static var _cache: Dictionary = {}
static var _inflight: Dictionary = {}

static func texture(faction: String, id: String) -> Texture2D:
	if id == "":
		return null
	if faction != "":
		var branded: Texture2D = _texture("%s_%s.webp" % [faction, id])
		if branded != null:
			return branded
	return _texture("%s.webp" % id)

static func arm(host: Node, hud: SMHud) -> void:
	if host == null or hud == null or host.get_node_or_null("CameoFetch") != null:
		return
	var node: Node = Node.new()
	node.name = "CameoFetch"
	node.set_meta("hud", hud)
	host.add_child(node)
	if OS.has_feature("web"):
		_fetch_list(node)

static func _texture(file_name: String) -> Texture2D:
	if _cache.has(file_name):
		return _cache[file_name] as Texture2D
	var bytes: PackedByteArray = _read_local(file_name)
	var portrait: Texture2D = _decode(bytes)
	if portrait != null:
		_cache[file_name] = portrait
	return portrait

static func _decode(bytes: PackedByteArray) -> Texture2D:
	if bytes.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_webp_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

static func _read_local(file_name: String) -> PackedByteArray:
	if file_name.contains("..") or file_name.contains("/") or file_name.contains("\\"):
		return PackedByteArray()
	var packed: String = "res://cameos/%s" % file_name
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	var roots: PackedStringArray = PackedStringArray()
	var base: String = OS.get_executable_path().get_base_dir()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/cameos"))
	roots.append(base.path_join("cameos"))
	roots.append(base.get_base_dir().path_join("Resources/cameos"))
	for root: String in roots:
		var path: String = root.path_join(file_name)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()

static func _fetch_list(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.is_inside_tree():
		_fetch_list.call_deferred(node)
		return
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 30.0
	http.accept_gzip = false
	http.name = "CameoList"
	http.ready.connect(_start_list.bind(node, http), CONNECT_ONE_SHOT)
	node.add_child.call_deferred(http)

static func _start_list(node: Node, http: HTTPRequest) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree() or not is_instance_valid(node):
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_got_list.bind(node, http))
	var err: Error = http.request(Clips.page_base() + "cameos/index.txt")
	if err != OK:
		http.queue_free()

static func _got_list(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, node: Node, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not is_instance_valid(node):
		return
	var lines: PackedStringArray = body.get_string_from_utf8().split("\n")
	for line: String in lines:
		var file_name: String = line.strip_edges()
		if file_name.ends_with(".webp") and not file_name.contains("..") and not file_name.begins_with("/"):
			_prefetch(node, file_name)

static func _prefetch(node: Node, file_name: String) -> void:
	if _cache.has(file_name) or _inflight.has(file_name) or node == null or not is_instance_valid(node):
		return
	_inflight[file_name] = true
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	http.name = "CameoFetch"
	http.ready.connect(_start_prefetch.bind(node, http, file_name), CONNECT_ONE_SHOT)
	node.add_child.call_deferred(http)

static func _start_prefetch(node: Node, http: HTTPRequest, file_name: String) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree() or not is_instance_valid(node):
		_inflight.erase(file_name)
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_prefetched.bind(node, http, file_name))
	var err: Error = http.request(Clips.page_base() + "cameos/" + file_name)
	if err != OK:
		_inflight.erase(file_name)
		http.queue_free()

static func _prefetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, node: Node, http: HTTPRequest, file_name: String) -> void:
	_inflight.erase(file_name)
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var portrait: Texture2D = _decode(body)
	if portrait == null:
		return
	_cache[file_name] = portrait
	if is_instance_valid(node):
		var hud: SMHud = node.get_meta("hud") as SMHud
		if hud != null:
			hud.apply_cameos()
