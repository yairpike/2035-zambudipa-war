extends RefCounted
## Webp art served beside the page, outside the pack.
## Desktop and headless runs also read res://, build/web/, and tests/fixtures/.
## The web build fetches briefings/<id>.webp over HTTP, the same way models are fetched.

static var _cache: Dictionary = {}
static var _inflight: Dictionary = {}
static var _waiters: Dictionary = {}
## Tests set this so a fixture resolves when build/web/briefings is absent.
static var skip_export: bool = false

static func texture(rel: String) -> Texture2D:
	if not _ok(rel):
		return null
	if _cache.has(rel):
		return _cache[rel] as Texture2D
	var bytes: PackedByteArray = _read(rel)
	if bytes.is_empty():
		return null
	return _store(rel, bytes)

## Fill a rect now, or when the web fetch finishes.
static func bind(rect: TextureRect, rel: String) -> void:
	if rect == null:
		return
	var tex: Texture2D = texture(rel)
	if tex != null:
		rect.texture = tex
		rect.visible = true
		return
	rect.texture = null
	rect.visible = false
	if not _ok(rel) or not OS.has_feature("web"):
		return
	var waiting: Array = _list(_waiters, rel)
	if not waiting.has(rect):
		waiting.append(rect)
	_waiters[rel] = waiting
	_fetch(rect, rel)

static func _ok(rel: String) -> bool:
	return rel.ends_with(".webp") and not rel.contains("..") and not rel.begins_with("/") and not rel.contains("\\")

static func _read(rel: String) -> PackedByteArray:
	var packed: String = "res://%s" % rel
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	if not skip_export:
		var base: String = OS.get_executable_path().get_base_dir()
		var roots: PackedStringArray = PackedStringArray()
		roots.append(ProjectSettings.globalize_path("res://").path_join("build/web"))
		roots.append(base)
		roots.append(base.get_base_dir().path_join("Resources"))
		for root: String in roots:
			var path: String = root.path_join(rel)
			if FileAccess.file_exists(path):
				return FileAccess.get_file_as_bytes(path)
	if OS.has_feature("web"):
		return PackedByteArray()
	var fixture: String = "res://tests/fixtures/%s" % rel
	if FileAccess.file_exists(fixture):
		return FileAccess.get_file_as_bytes(fixture)
	return PackedByteArray()

static func _store(rel: String, bytes: PackedByteArray) -> Texture2D:
	var image := Image.new()
	if image.load_webp_from_buffer(bytes) != OK:
		return null
	var tex := ImageTexture.create_from_image(image)
	_cache[rel] = tex
	return tex

static func _fetch(owner: Node, rel: String) -> void:
	if owner == null or _inflight.has(rel):
		return
	_inflight[rel] = true
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.accept_gzip = false
	var host: Node = owner
	if owner.get_tree() != null and owner.get_tree().root != null:
		host = owner.get_tree().root
	http.ready.connect(_start_fetch.bind(http, rel), CONNECT_ONE_SHOT)
	host.add_child.call_deferred(http)

static func _start_fetch(http: HTTPRequest, rel: String) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		_inflight.erase(rel)
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_got.bind(http, rel))
	var err: Error = http.request(_page() + rel)
	if err != OK:
		_inflight.erase(rel)
		http.queue_free()

static func _got(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, rel: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_inflight.erase(rel)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		return
	var tex: Texture2D = _store(rel, body)
	if tex == null:
		return
	var waiting: Array = _list(_waiters, rel)
	for item: Variant in waiting:
		var rect: TextureRect = item as TextureRect
		if rect != null and is_instance_valid(rect):
			rect.texture = tex
			rect.visible = true
	_waiters.erase(rel)

static func _list(book: Dictionary, key: String) -> Array:
	var got: Variant = book.get(key, [])
	if got is Array:
		return got as Array
	return []

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
