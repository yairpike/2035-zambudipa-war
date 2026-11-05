extends RefCounted
## Faction emblem. The imported 64 and 256 marks win. A flat diamond is only a fallback.

static var _cache: Dictionary = {}

static func texture(id: String) -> Texture2D:
	return _resolve(id, 64)

static func texture_large(id: String) -> Texture2D:
	return _resolve(id, 256)

static func _resolve(id: String, limit: int) -> Texture2D:
	var key: String = "%s:%d" % [id, limit]
	if _cache.has(key):
		var held: Texture2D = _cache[key] as Texture2D
		if held != null:
			return held
	var found: Texture2D = _from_file(id, limit)
	if found == null:
		found = _placeholder(id)
	_cache[key] = found
	return found

static func _from_file(id: String, limit: int) -> Texture2D:
	if id == "" or id.contains("..") or id.contains("/") or id.contains("\\"):
		return null
	var packed: PackedStringArray = PackedStringArray()
	if limit <= 64:
		packed.append("res://ui/logos/%s_64.webp" % id)
	packed.append("res://ui/logos/%s.webp" % id)
	packed.append("res://ui/logos/%s.png" % id)
	packed.append("user://logos/%s.webp" % id)
	packed.append("user://logos/%s.png" % id)
	for path: String in packed:
		var tex: Texture2D = _load_path(path, limit)
		if tex != null:
			return tex
	var base: String = OS.get_executable_path().get_base_dir()
	var roots: PackedStringArray = PackedStringArray()
	roots.append(base.path_join("ui/logos"))
	roots.append(base.get_base_dir().path_join("Resources/ui/logos"))
	var alias: String = _alias(id)
	for root: String in roots:
		for stem: String in [id, alias]:
			for ext: String in ["webp", "png"]:
				var file: String = root.path_join("%s.%s" % [stem, ext])
				if FileAccess.file_exists(file):
					var img := Image.new()
					if img.load(file) == OK:
						return _fit(img, limit)
	return null

static func _alias(id: String) -> String:
	if id == "gtfc":
		return "gtfc-3"
	if id == "nmrf":
		return "nmrf-3"
	if id == "mvd":
		return "mvd-2"
	if id == "black_market":
		return "black_market-3"
	return id

static func _load_path(path: String, limit: int) -> Texture2D:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	var tex: Texture2D = loaded as Texture2D
	if tex == null:
		return null
	if tex.get_width() <= limit and tex.get_height() <= limit:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	return _fit(img, limit)

static func _fit(img: Image, limit: int) -> Texture2D:
	if img.get_width() > limit or img.get_height() > limit:
		img.resize(limit, limit, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

static func _placeholder(id: String) -> Texture2D:
	var ink := Color.html("#B81E2D")
	var mark := Color.html("#E0A106")
	if id == "nmrf":
		ink = Color.html("#5A6824")
		mark = Color.html("#1F9E66")
	elif id == "mvd":
		ink = Color.html("#2A2E32")
		mark = Color.html("#26BFD1")
	elif id == "black_market":
		ink = Color.html("#1A1208")
		mark = Color.html("#C4A46A")
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in 64:
		for x: int in 64:
			var dx: int = absi(x - 32)
			var dy: int = absi(y - 30)
			if dx * 2 + dy < 40:
				img.set_pixel(x, y, ink)
			if dx < 5 and dy < 5:
				img.set_pixel(x, y, mark)
	return ImageTexture.create_from_image(img)
