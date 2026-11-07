extends SceneTree
## Windowed screenshot of a match HUD. Not part of the test suite.
## godot --path . --resolution 1280x720 -s res://tools/hud_shot.gd -- --scene res://game/burma_road.tscn --faction gtfc --out /tmp/a.png [--skin black_market] [--wait 3] [--menu boot|pause|settings|skirmish|campaign] [--hover N] [--language burmese] [--press NodeName]

var _args: Dictionary = {}
var _clock: float = 0.0
var _selected: bool = false
var _opened: bool = false
var _hovered: bool = false

func _initialize() -> void:
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		var value: String = raw[i + 1] if i + 1 < raw.size() else ""
		_args[key] = value
		i += 2
	if _args.has("language"):
		var settings: GDScript = load("res://game/match_settings.gd") as GDScript
		settings.call("ensure")
		settings.set("language", str(_args["language"]))
		settings.set("voice", str(_args["language"]))
		SMLang.apply(str(_args["language"]))
	SMFront.faction_id = str(_args.get("faction", "gtfc"))
	if _args.has("mission"):
		SMCampaign.selected = str(_args["mission"])
	if _args.has("skin"):
		root.set_meta("hud_skin", str(_args["skin"]))
	change_scene_to_file(str(_args.get("scene", "res://game/burma_road.tscn")))

func _process(delta: float) -> bool:
	_clock += delta
	var scene: Node = current_scene
	if scene == null:
		return false
	var wait: float = float(_args.get("wait", "3"))
	if not _selected and _clock > wait * 0.5:
		_selected = true
		var fit_hud: SMHud = scene.get("hud") as SMHud
		if fit_hud != null:
			fit_hud.layout_for(root.get_visible_rect().size)
		var field: SMPointer = scene.get("field") as SMPointer
		if field != null:
			var mine: Array[RTSUnit] = field.units_of(SMPointer.PLAYER)
			var pick: Array[RTSUnit] = []
			var want: int = int(_args.get("select", "1"))
			for u: RTSUnit in mine:
				if pick.size() < want:
					pick.append(u)
			if not pick.is_empty():
				field.select_only(pick)
	if not _opened and _clock > wait * 0.7:
		_opened = true
		var menu: String = str(_args.get("menu", ""))
		if _args.has("press"):
			var press: Button = scene.find_child(str(_args["press"]), true, false) as Button
			if press != null:
				press.pressed.emit()
		if menu == "pause":
			var pause: CanvasItem = scene.find_child("PauseMenu", true, false) as CanvasItem
			if pause != null:
				pause.visible = true
		elif menu == "settings":
			var settings: Control = scene.find_child("SettingsPanel", true, false) as Control
			if settings != null:
				settings.visible = true
		elif menu == "guide":
			var guide: CanvasItem = scene.find_child("HowToOverlay", true, false) as CanvasItem
			if guide != null:
				guide.visible = true
		elif menu == "skirmish":
			var tab: Button = scene.find_child("TabSkirmish", true, false) as Button
			if tab != null:
				tab.pressed.emit()
			var pick: Button = scene.find_child(str(_args.get("card", "CardShowcase")), true, false) as Button
			if pick != null:
				pick.pressed.emit()
		elif menu == "campaign":
			var campaign: Button = scene.find_child("TabCampaign", true, false) as Button
			if campaign != null:
				campaign.pressed.emit()
		elif menu == "credits":
			var roll: Button = scene.find_child("CreditsButton", true, false) as Button
			if roll != null:
				roll.pressed.emit()
		elif menu == "alert":
			var hud: SMHud = scene.get("hud") as SMHud
			if hud != null:
				hud.show_line("Unit ready")
	if not _hovered and _args.has("hover") and _clock > wait * 0.8:
		_hovered = true
		var grid_hud: SMHud = scene.get("hud") as SMHud
		if grid_hud != null and grid_hud.icon_grid != null:
			var at: int = int(_args["hover"])
			var seen: int = 0
			for child: Node in grid_hud.icon_grid.get_children():
				var button: Button = child as Button
				if button != null and button.visible:
					if seen == at:
						button.mouse_entered.emit()
						break
					seen += 1
	if _clock > wait:
		if _args.has("dump"):
			_dump(scene)
		var image: Image = root.get_texture().get_image()
		image.save_png(str(_args.get("out", "/tmp/hud_shot.png")))
		quit()
	return false

func _dump(scene: Node) -> void:
	for node: Node in scene.find_children("", "Control", true, false):
		var c: Control = node as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		if (r.size.x < 40.0 or r.size.y < 12.0 or r.position.y > 300.0) and not str(c.name).contains("Radio"):
			continue
		var bit: String = ""
		var label: Label = c as Label
		if label != null:
			bit = label.text.substr(0, 30)
		print("DUMP %s %s %s z=%d %s" % [c.get_path(), c.get_class(), r, c.z_index, bit])
