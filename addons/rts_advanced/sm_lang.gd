class_name SMLang
extends RefCounted
## The game language. One id drives TranslationServer, so every Label, Button,
## and tooltip auto-translates its English text with no change at the call site.
## Catalogs are res://localization/game/<locale>.po with the English line as msgid.
## en.po carries the English the player sees: glosses for flavour words, else the msgid.
## A line built from a format string ("Credits %d", "%s built") is matched back to
## its template. Its %s arguments are translated in turn.

const DIR: String = "res://localization/game/"
const PLACEHOLDER: String = "%(?:\\.\\d+)?[sdf]|%%"
const CACHE_CAP: int = 4096

static var current: String = "english"
static var _installed: Dictionary = {}
static var _guard_node: Node = null
static var _guard_frame: int = -1

static func ids() -> PackedStringArray:
	return PackedStringArray(["english", "burmese", "mandarin", "thai", "malay"])

static func locale_of(id: String) -> String:
	if id == "burmese":
		return "my"
	if id == "mandarin":
		return "zh"
	if id == "thai":
		return "th"
	if id == "malay":
		return "ms"
	return "en"

## The language's own name, so a player can find it from any language.
static func native_name(id: String) -> String:
	if id == "burmese":
		return "မြန်မာ"
	if id == "mandarin":
		return "中文"
	if id == "thai":
		return "ไทย"
	if id == "malay":
		return "Bahasa Melayu"
	return "English"

## A browser or OS locale ("th_TH", "zh-CN") picks the first-visit language.
static func from_locale(locale: String) -> String:
	var code: String = locale.to_lower().substr(0, 2)
	for id: String in ids():
		if locale_of(id) == code:
			return id
	return "english"

static func apply(id: String) -> void:
	install()
	current = id if ids().has(id) else "english"
	if TranslationServer.get_locale() != locale_of(current):
		TranslationServer.set_locale(locale_of(current))

static func install() -> void:
	for id: String in ids():
		var locale: String = locale_of(id)
		if _installed.has(locale):
			continue
		var table: Table = Table.from_po(DIR + locale + ".po", locale)
		_installed[locale] = table
		if table != null:
			TranslationServer.add_translation(table)
	_guard()

## TranslationServer outlives the script language, so a Table still registered at
## shutdown aborts the engine. A node in the tree removes them as the tree goes down.
static func uninstall() -> void:
	for locale: Variant in _installed.keys():
		var table: Table = _installed[locale] as Table
		if table != null:
			TranslationServer.remove_translation(table)
	_installed.clear()

static func _guard() -> void:
	if _guard_node != null and is_instance_valid(_guard_node) and _guard_node.is_inside_tree():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not tree.root.is_inside_tree():
		return
	if _guard_node == null or not is_instance_valid(_guard_node):
		_guard_node = Guard.new()
		_guard_node.name = "SMLangGuard"
	if _guard_node.get_parent() == null and _guard_frame != Engine.get_process_frames():
		_guard_frame = Engine.get_process_frames()
		_seat_guard.call_deferred(tree.root)

static func _seat_guard(root: Window) -> void:
	if is_instance_valid(root) and is_instance_valid(_guard_node) and _guard_node.get_parent() == null:
		root.add_child(_guard_node)

class Guard:
	extends Node
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			SMLang.uninstall()

static func table(locale: String) -> Table:
	install()
	return _installed.get(locale, null) as Table

## Translates a line in the current language, for text that is not a Control's own text.
static func text(line: String) -> String:
	return String(TranslationServer.translate(StringName(line)))

class Table:
	extends Translation
	var exact: Dictionary = {}
	var patterns: Array = []
	var _cache: Dictionary = {}

	static func from_po(path: String, locale_id: String) -> Table:
		var source: Translation = load(path) as Translation if ResourceLoader.exists(path) else null
		var out: Table = Table.new()
		out.locale = locale_id
		if source == null:
			return out
		var splitter: RegEx = RegEx.create_from_string(PLACEHOLDER)
		for key: StringName in source.get_message_list():
			var src: String = String(key)
			var shown: String = String(source.get_message(key))
			if shown == "":
				continue
			if shown != src:
				out.exact[src] = shown
			if splitter.search(src) != null:
				out._add_pattern(splitter, src, shown)
				if src.strip_edges() != src:
					out._add_pattern(splitter, src.strip_edges(), shown.strip_edges())
		out.patterns.sort_custom(func(a: Array, b: Array) -> bool: return int(a[3]) > int(b[3]))
		return out

	func _add_pattern(splitter: RegEx, src: String, shown: String) -> void:
		var marks: Array[RegExMatch] = splitter.search_all(src)
		var shown_marks: Array[RegExMatch] = splitter.search_all(shown)
		if marks.size() != shown_marks.size():
			return
		var expr: String = "^"
		var kinds: PackedStringArray = PackedStringArray()
		var at: int = 0
		var literal: int = 0
		for m: RegExMatch in marks:
			var piece: String = src.substr(at, m.get_start() - at)
			literal += piece.length()
			expr += _quote(piece)
			var mark: String = m.get_string()
			if mark == "%%":
				expr += "%"
			elif mark.ends_with("s"):
				expr += "(.*?)"
				kinds.append("s")
			elif mark.ends_with("d"):
				expr += "(-?\\d+)"
				kinds.append("d")
			else:
				expr += "(-?\\d+(?:\\.\\d+)?)"
				kinds.append("f")
			at = m.get_end()
		var tail: String = src.substr(at)
		literal += tail.length()
		expr += _quote(tail) + "$"
		if literal < 2:
			return
		var parts: PackedStringArray = PackedStringArray()
		var cursor: int = 0
		for m: RegExMatch in shown_marks:
			parts.append(shown.substr(cursor, m.get_start() - cursor).replace("%%", "%"))
			cursor = m.get_end()
		parts.append(shown.substr(cursor).replace("%%", "%"))
		var regex: RegEx = RegEx.create_from_string(expr)
		if regex.is_valid():
			patterns.append([regex, kinds, parts, literal])

	static func _quote(piece: String) -> String:
		var out: String = ""
		for i: int in piece.length():
			var c: String = piece[i]
			if "\\^$.|?*+()[]{}".contains(c):
				out += "\\"
			out += c
		return out

	func _get_message(src_message: StringName, _context: StringName) -> StringName:
		SMLang._guard()
		var src: String = String(src_message)
		if exact.has(src):
			return StringName(exact[src])
		if src.length() < 2 or patterns.is_empty() and not src.contains("\n"):
			return StringName()
		if _cache.has(src):
			return StringName(_cache[src])
		var out: String = compose(src, 0)
		if _cache.size() >= CACHE_CAP:
			_cache.clear()
		_cache[src] = out
		return StringName(out)

	## "" when nothing in the line has a translation.
	func compose(src: String, depth: int) -> String:
		if exact.has(src):
			return str(exact[src])
		if depth > 3 or src.strip_edges() == "":
			return ""
		var matched: String = _match(src, depth)
		if matched != "":
			return matched
		var core: String = src.strip_edges()
		if core != src:
			var inner: String = compose(core, depth + 1)
			if inner == "":
				return ""
			var lead: int = src.find(core)
			return src.substr(0, lead) + inner + src.substr(lead + core.length())
		if src.contains("\n"):
			var lines: PackedStringArray = src.split("\n")
			var changed: bool = false
			for i: int in lines.size():
				var line: String = compose(lines[i], depth + 1)
				if line != "":
					lines[i] = line
					changed = true
			return "\n".join(lines) if changed else ""
		if src.contains(", "):
			var items: PackedStringArray = src.split(", ")
			for i: int in items.size():
				var item: String = compose(items[i], depth + 1)
				if item == "":
					return ""
				items[i] = item
			return ", ".join(items)
		return ""

	func _match(src: String, depth: int) -> String:
		for row: Array in patterns:
			var found: RegExMatch = (row[0] as RegEx).search(src)
			if found == null:
				continue
			var kinds: PackedStringArray = row[1]
			var parts: PackedStringArray = row[2]
			var out: String = parts[0]
			for i: int in kinds.size():
				var arg: String = found.get_string(i + 1)
				if kinds[i] == "s":
					var said: String = compose(arg, depth + 1)
					if said != "":
						arg = said
				out += arg + parts[i + 1]
			return out
		return ""
