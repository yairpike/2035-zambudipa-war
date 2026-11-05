extends SceneTree
## Lists on-screen text the language catalog does not cover. Not part of the test suite.
## godot --headless --path . -s res://tools/loc_coverage.gd [-- --locale my]
## Walks the menu, settings, credits, skirmish HUDs, and campaign missions, and
## prints every Label, Button, tooltip, and placeholder text that has no catalog
## line and matches no template. With --locale, it also prints lines that stay
## English after translation.

const Settings = preload("res://game/match_settings.gd")

var _keys: Dictionary = {}
var _patterns: Array[RegEx] = []
var _seen: Dictionary = {}
var _locale: String = ""
var _target: String = ""

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--locale")
	if at >= 0 and at + 1 < args.size():
		_locale = args[at + 1]
	var en: Translation = load("res://localization/game/en.po") as Translation
	var splitter: RegEx = RegEx.create_from_string(SMLang.PLACEHOLDER)
	for key: StringName in en.get_message_list():
		var src: String = String(key)
		_keys[src] = true
		if splitter.search(src) != null:
			var expr: String = "^" + _quoted_template(src, splitter) + "$"
			var rx: RegEx = RegEx.create_from_string(expr)
			if rx.is_valid():
				_patterns.append(rx)
	_run.call_deferred()

func _quoted_template(src: String, splitter: RegEx) -> String:
	var out: String = ""
	var at: int = 0
	for m: RegExMatch in splitter.search_all(src):
		out += _quote(src.substr(at, m.get_start() - at))
		var mark: String = m.get_string()
		out += "%" if mark == "%%" else ("(.*?)" if mark.ends_with("s") else "(-?[0-9.]+)")
		at = m.get_end()
	return out + _quote(src.substr(at))

func _quote(piece: String) -> String:
	var out: String = ""
	for i: int in piece.length():
		var c: String = piece[i]
		if "\\^$.|?*+()[]{}".contains(c):
			out += "\\"
		out += c
	return out

func _known(line: String, depth: int = 0) -> bool:
	var t: String = line.strip_edges()
	if t == "" or _keys.has(line) or _keys.has(t) or depth > 3:
		return true
	if not RegEx.create_from_string("[A-Za-z]{2,}").search(t):
		return true
	for rx: RegEx in _patterns:
		if rx.search(t) != null or rx.search(line) != null:
			return true
	if t.contains("\n"):
		for part: String in t.split("\n"):
			if not _known(part, depth + 1):
				return false
		return true
	return false

func _collect(where: String) -> void:
	if _target != "":
		SMLang.apply(_target)
	for node: Node in root.find_children("*", "Control", true, false):
		var c: Control = node as Control
		var texts: PackedStringArray = PackedStringArray()
		if c is Label:
			texts.append((c as Label).text)
		elif c is Button:
			texts.append((c as Button).text)
		elif c is LineEdit:
			texts.append((c as LineEdit).placeholder_text)
		if c.tooltip_text != "":
			texts.append(c.tooltip_text)
		for line: String in texts:
			if line.strip_edges() == "" or _seen.has(line):
				continue
			if not c.can_auto_translate() and c.name != "LanguageValue":
				_seen[line] = true
				print("NO-AUTO  %s  [%s] %s" % [where, c.get_path(), line.c_escape()])
				continue
			if not _known(line):
				_seen[line] = true
				print("MISSING  %s  [%s] %s" % [where, c.name, line.c_escape()])
			elif _locale != "" and c.atr(line) == line and RegEx.create_from_string("[A-Za-z]{3,}").search(line) != null:
				_seen[line] = true
				print("ENGLISH  %s  [%s] %s" % [where, c.name, line.c_escape()])

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _visit(path: String, where: String, frames: int = 40) -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await _frames(frames)
	_collect(where)
	return scene

func _run() -> void:
	Settings.hold("low")
	if _locale != "":
		for id: String in SMLang.ids():
			if SMLang.locale_of(id) == _locale:
				_target = id
		Settings.ensure()
		Settings.language = _target
		SMLang.apply(_target)
	var boot: Node = await _visit("res://game/boot.tscn", "menu")
	for tab: String in ["TabCampaign", "TabSkirmish", "TabFaction", "TabMultiplayer", "CreditsButton", "SettingsButton"]:
		var b: Button = boot.find_child(tab, true, false) as Button
		if b != null:
			b.pressed.emit()
			await _frames(6)
			_collect("menu/" + tab)
			if tab == "SettingsButton":
				var panel: Node = boot.find_child("SettingsPanel", true, false)
				for page: String in ["video", "audio", "controls", "gameplay", "hud", "language"]:
					panel.call("_show_page", page)
					await _frames(2)
					_collect("settings/" + page)
				b.pressed.emit()
			var back: Button = boot.find_child("MenuBack", true, false) as Button
			if back != null and back.visible:
				back.pressed.emit()
				await _frames(3)
	boot.free()
	for map: String in ["burma_road", "phillips_channel", "sop_ruak", "mekong_delta", "ten_degree_atolls", "chiang_rai", "greybox", "mvd_yard", "nmrf_yard"]:
		var scene: Node = await _visit("res://game/%s.tscn" % map, map, 90)
		var field: SMPointer = scene.get("field") as SMPointer
		if field != null:
			field.select_only(field.units_of(SMPointer.PLAYER))
			await _frames(10)
			_collect(map + "/selected")
		scene.free()
		await _frames(2)
	for mission: String in SMCampaign.ids():
		SMCampaign.selected = mission
		var path: String = "res://game/mission_kokang.tscn" if mission == "kokang" else "res://game/campaign_mission.tscn"
		var m: Node = await _visit(path, mission, 120)
		m.free()
		await _frames(2)
	print("COVERAGE DONE %d lines" % _seen.size())
	quit(0)
