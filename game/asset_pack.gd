extends RefCounted
## Sidecar files a small desktop installer leaves out. tools/pack_installers.sh writes
## asset_pack.json beside the executable (Contents/Resources on macOS). It lists each file
## with its size and git blob SHA-1 and the URLs that serve it. First launch fetches the list
## into user://assets, and every sidecar loader searches that folder after the bundled ones.
## Android and iOS have no folder beside the executable, so their .pck carries MOBILE_FILE,
## which lists every sidecar.

const FILE: String = "asset_pack.json"
const MOBILE_FILE: String = "res://build/mobile/asset_pack.json"
const DIR: String = "user://assets"
const DONE: String = "user://assets/.complete"
const CHUNK: int = 1 << 20

static var _root: String = ""

static func root() -> String:
	if _root == "":
		_root = ProjectSettings.globalize_path(DIR)
	return _root

static func manifest_path() -> String:
	if OS.has_feature("web"):
		return ""
	if OS.has_feature("mobile"):
		return MOBILE_FILE if FileAccess.file_exists(MOBILE_FILE) else ""
	var base: String = OS.get_executable_path().get_base_dir()
	for path: String in [base.path_join(FILE), base.get_base_dir().path_join("Resources").path_join(FILE)]:
		if FileAccess.file_exists(path):
			return path
	return ""

## Empty when the file is missing or malformed.
static func read(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var row: Dictionary = parsed as Dictionary
	if not (row.get("files") is Array) or not (row.get("urls") is Array) or (row["urls"] as Array).is_empty():
		return {}
	return row

static func stamp(manifest: Dictionary) -> String:
	return "%s|%d" % [str(manifest.get("ref", "")), (manifest.get("files", []) as Array).size()]

static func complete(manifest: Dictionary) -> bool:
	return FileAccess.file_exists(DONE) and FileAccess.get_file_as_string(DONE).strip_edges() == stamp(manifest)

static func mark_complete(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(root())
	var out: FileAccess = FileAccess.open(DONE, FileAccess.WRITE)
	if out != null:
		out.store_string(stamp(manifest))

static func safe(rel: String) -> bool:
	return rel != "" and not rel.contains("..") and not rel.begins_with("/") and not rel.contains("\\") and not rel.contains(":")

## Entries [path, size, sha1] or [path, size, sha1, url] not yet in user://assets at their listed size.
static func pending(manifest: Dictionary) -> Array:
	var out: Array = []
	for item: Variant in manifest.get("files", []) as Array:
		if not (item is Array) or (item as Array).size() < 3:
			continue
		var entry: Array = item as Array
		var rel: String = str(entry[0])
		if not safe(rel):
			continue
		if size_of(root().path_join(rel)) != int(entry[1]):
			out.append(entry)
	return out

static func size_of(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	return f.get_length()

static func bytes_of(entries: Array) -> int:
	var total: int = 0
	for entry: Variant in entries:
		total += int((entry as Array)[1])
	return total

## The SHA-1 git gives a blob, so the manifest can be checked against the gh-pages tree.
static func blob_sha1(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	var head: PackedByteArray = ("blob %d" % f.get_length()).to_utf8_buffer()
	head.append(0)
	ctx.update(head)
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(CHUNK))
	return ctx.finish().hex_encode()

static func url_for(base: String, rel: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for piece: String in rel.split("/"):
		parts.append(piece.uri_encode())
	return base.trim_suffix("/") + "/" + "/".join(parts)

## A fourth entry field names the one URL that serves that file. Otherwise every listed base.
## Maps legacy yairpike/asean-2031 URLs in existing manifests onto yairpike/2035-zambudipa-war first, keeping the old URL as fallback.
static func sources(manifest: Dictionary, entry: Array) -> Array:
	if entry.size() > 3 and str(entry[3]).begins_with("https://"):
		var direct: String = str(entry[3])
		var out_direct: Array = []
		if direct.contains("/yairpike/asean-2031/"):
			out_direct.append(direct.replace("/yairpike/asean-2031/", "/yairpike/2035-zambudipa-war/"))
		if direct.contains("yairpike.github.io/asean-2031/"):
			out_direct.append(direct.replace("yairpike.github.io/asean-2031/", "yairpike.github.io/2035-zambudipa-war/"))
		out_direct.append(direct)
		return out_direct
	var out: Array = []
	for base: Variant in manifest.get("urls", []) as Array:
		var b: String = str(base)
		if b.contains("yairpike.github.io/asean-2031/"):
			var mapped_pages: String = url_for(b.replace("yairpike.github.io/asean-2031/", "yairpike.github.io/2035-zambudipa-war/"), str(entry[0]))
			if not out.has(mapped_pages):
				out.append(mapped_pages)
		if b.contains("/yairpike/asean-2031/"):
			var mapped_raw: String = url_for(b.replace("/yairpike/asean-2031/", "/yairpike/2035-zambudipa-war/"), str(entry[0]))
			if not out.has(mapped_raw):
				out.append(mapped_raw)
		var orig: String = url_for(b, str(entry[0]))
		if not out.has(orig):
			out.append(orig)
	return out
