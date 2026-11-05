extends Control
## Match HUD in the Red Alert 3 layout, skinned per faction: a framed sidebar with the
## minimap, power gauge, build tabs and cameo grid; a unit panel with the command bar;
## top-bar credits; and EVA alert banners. Menus and cards behind it use frosted glass.

const SWEEP := preload("res://game/cameo_sweep.gd")
const Clips = preload("res://game/match_audio.gd")
const Marks = preload("res://game/faction_mark.gd")
const Look = preload("res://game/hud_skin.gd")
const Glass = preload("res://game/glass.gd")
const MapArt = preload("res://game/hud_minimap_art.gd")
const Rank = preload("res://game/hud_rank.gd")
const ICONS: String = "res://ui/hud/icons/%s.webp"
const SIDE_W: float = 260.0
const TOP_H: float = 30.0

var _goals_open: bool = false
var _skin: String = "gtfc"
var _tiles_key: String = ""
var _glassed: Dictionary = {}

static func install(layer: CanvasLayer, hud: SMHud, grid: SMDomainGrid, camera: RTSCamera) -> void:
	var root: Control = (load("res://game/match_hud.tscn") as PackedScene).instantiate() as Control
	layer.add_child(root)
	root._bind(hud, grid, camera)

func _bind(hud: SMHud, grid: SMDomainGrid, camera: RTSCamera) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud.use_tiles = true
	_skin = Look.id_for(self, _mark_id(hud))
	_selection_row()
	var top: HBoxContainer = _top_bar()
	_faction_mark(top, hud)
	var now_playing: Label = Label.new()
	now_playing.name = "NowPlaying"
	now_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_playing.clip_text = true
	now_playing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	now_playing.add_theme_font_size_override("font_size", 13)
	now_playing.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_anchor(now_playing, 0.0, 0.0, 0.0, 0.0, 12.0, 36.0, 480.0, 54.0)
	add_child(now_playing)
	hud.faction_label = _label(top, "HudFaction", 15)
	_pin_bar_label(hud.faction_label)
	hud.faction_label.add_theme_color_override("font_color", Look.color(_skin, "trim_hi"))
	var purse: PanelContainer = PanelContainer.new()
	purse.name = "CreditsPlate"
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var purse_box: StyleBoxFlat = Look.well_style(_skin, 3)
	purse_box.content_margin_left = 10
	purse_box.content_margin_right = 10
	purse_box.content_margin_top = 0
	purse_box.content_margin_bottom = 0
	purse.add_theme_stylebox_override("panel", purse_box)
	top.add_child(purse)
	var purse_row: HBoxContainer = HBoxContainer.new()
	purse_row.add_theme_constant_override("separation", 8)
	purse_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(purse_row)
	hud.credits_label = _label(purse_row, "HudCredits", 17)
	_pin_bar_label(hud.credits_label)
	hud.credits_label.add_theme_color_override("font_color", Look.color(_skin, "glow").lightened(0.2))
	hud.credits_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud.credits_label.add_theme_constant_override("outline_size", 3)
	hud.income_label = _label(purse_row, "HudIncome", 14)
	_pin_bar_label(hud.income_label)
	hud.income_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.5))
	hud.income_label.visible = false
	hud.map_label = _label(top, "HudMap", 15)
	hud.map_label.size_flags_stretch_ratio = 2.2
	hud.map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.map_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))
	hud.weather_label = _label(top, "HudWeather", 14)
	_pin_bar_label(hud.weather_label)
	hud.weather_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.85))
	var menu: Button = Button.new()
	menu.name = "HudMenu"
	menu.text = "☰"
	menu.custom_minimum_size = Vector2(30, 22)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_END
	menu.add_theme_font_size_override("font_size", 16)
	menu.add_theme_font_override("font", ThemeDB.fallback_font)
	Look.dress_button(menu, _skin)
	menu.pressed.connect(_open_menu)
	top.add_child(menu)
	var column: ScrollContainer = _column()
	var wrap: VBoxContainer = column.get_child(0) as VBoxContainer
	var host: Control = wrap.get_node("MonitorFrame/MonitorStack/MonitorHost") as Control
	var minimap: SMMinimap = SMMinimap.new()
	minimap.name = "Minimap"
	minimap.setup(grid, hud.field, camera)
	minimap.position = Vector2.ZERO
	minimap.custom_minimum_size = Vector2(224, 224)
	minimap.size = Vector2(224, 224)
	minimap.backdrop = MapArt.bake(grid, MapArt.profile_for(_match_host()))
	host.add_child(minimap)
	hud.minimap = minimap
	hud.monitor_cameo = wrap.get_node("MonitorFrame/MonitorStack/MonitorCameo") as TextureRect
	hud.power_fill = wrap.get_node("PowerRow/PowerTrack/PowerFill") as ColorRect
	hud.power_mark = wrap.get_node("PowerRow/PowerTrack/PowerMark") as ColorRect
	hud.power_label = wrap.get_node("PowerRow/HudPower") as Label
	hud.repair_button = wrap.get_node("ModeRow/RepairButton") as Button
	hud.sell_button = wrap.get_node("ModeRow/SellButton") as Button
	hud.repair_button.pressed.connect(_mode_sound)
	hud.repair_button.pressed.connect(hud.toggle_repair_mode)
	hud.sell_button.pressed.connect(_mode_sound)
	hud.sell_button.pressed.connect(hud.toggle_sell_mode)
	hud.icon_grid = wrap.get_node("PhoneIconGrid") as GridContainer
	hud.sidebar = wrap.get_node("Sidebar") as VBoxContainer
	hud.super_dock = get_node("SuperDock") as VBoxContainer
	hud.command_row = find_child("CommandRow", true, false) as VBoxContainer
	hud.unit_card = find_child("UnitCard", true, false) as PanelContainer
	hud.card_cameo = find_child("CardCameo", true, false) as TextureRect
	hud.selection_label = find_child("HudSelection", true, false) as Label
	hud.build_label = find_child("HudBuild", true, false) as Label
	hud.radio_label = find_child("RadioLine", true, false) as Label
	hud.health_fill = find_child("HealthFill", true, false) as ColorRect
	hud.veteran_label = find_child("HudVeteran", true, false) as Label
	hud.breakdown_label = find_child("HudBreakdown", true, false) as Label
	_wire_tab(hud, "TabBuildings", "buildings")
	_wire_tab(hud, "TabDefenses", "defenses")
	_wire_tab(hud, "TabInfantry", "infantry")
	_wire_tab(hud, "TabVehicles", "vehicles")
	_wire_tab(hud, "TabAircraft", "aircraft")
	_wire_tab(hud, "TabNaval", "naval")
	var scroll: ScrollContainer = get_node("CommandColumn") as ScrollContainer
	if scroll != null and not scroll.gui_input.is_connected(hud._drag_column):
		scroll.gui_input.connect(hud._drag_column)
	hud.paint_extra = Callable(self, "paint")
	set_meta("hud", hud)
	set_process_unhandled_input(true)

func _match_host() -> Node:
	var layer: Node = get_parent()
	return layer.get_parent() if layer != null else null

func paint(hud: SMHud) -> void:
	_seat_chrome()
	_glass_overlays()
	_paint_power(hud)
	_paint_monitor(hud)
	_paint_modes(hud)
	_paint_sweeps(hud)
	_paint_super(hud)
	_paint_protocols(hud)
	_paint_selection(hud)
	_paint_tiles(hud)
	_paint_tabs(hud)
	_paint_card(hud)

func _paint_protocols(hud: SMHud) -> void:
	if hud.layer_node == null:
		return
	var grid: Node = hud.layer_node.find_child("Protocols", true, false)
	if grid == null or grid.get_child_count() == 0:
		return
	var book: SMProtocols = grid.get_meta("book", null) as SMProtocols
	if book == null:
		return
	var inner: Node = grid.get_child(0)
	for child: Node in inner.get_children():
		var button: Button = child as Button
		if button == null or not str(button.name).begins_with("Proto_"):
			continue
		var id: StringName = StringName(str(button.name).trim_prefix("Proto_"))
		var left: float = float(book.cool_left.get(id, 0.0))
		var ratio: float = 0.0
		if left > 0.0 and SMProtocols.COOL_TIME > 0.0:
			ratio = 1.0 - clampf(left / SMProtocols.COOL_TIME, 0.0, 1.0)
		_sweep(button, ratio, 0)

func _process(delta: float) -> void:
	_seat_chrome()
	_seat_tip()
	_pulse_power_tile()
	_glass_overlays()
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud == null or hud.side == null:
		return
	hud.side.tick_modes(delta)
	SMGuns.tick(hud.side, hud.field, delta)
	if hud.paint_extra != Callable(self, "paint"):
		paint(hud)

func _seat_tip() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var tip: Control = layer.find_child("TipPanel", true, false) as Control
	if tip == null:
		return
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud != null and hud.phone:
		return
	var grid_top: float = 300.0
	if hud != null and hud.icon_grid != null and hud.icon_grid.is_visible_in_tree():
		grid_top = clampf(hud.icon_grid.get_global_rect().position.y, 120.0, size.y - 220.0)
	_anchor(tip, 1.0, 0.0, 1.0, 0.0, -SIDE_W - 372.0, grid_top, -SIDE_W - 12.0, grid_top + 96.0)
	tip.custom_minimum_size = Vector2(360, 96)
	if hud == null or hud.hover_tip == "":
		tip.visible = false
		return
	tip.visible = Time.get_ticks_msec() - hud.tip_at >= 300

func _pulse_power_tile() -> void:
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud == null or hud.icon_grid == null or hud.side == null or hud.side.yard == null:
		return
	var pair: Vector2i = hud._power_pair()
	var pulse: bool = pair.x <= 0
	var wave: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	for child: Node in hud.icon_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var prod: String = str(button.get_meta("prod_id", ""))
		var feeds: bool = prod.contains("hydro") or prod.contains("plant") or prod.contains("reactor") or prod.contains("generator")
		if pulse and feeds and button.visible:
			button.modulate = Color(wave, wave, wave)

func _paint_power(hud: SMHud) -> void:
	if hud.power_fill == null or hud.side == null:
		return
	var pair: Vector2i = hud._power_pair()
	var span: float = float(maxi(maxi(pair.x, pair.y), 1))
	var gen: float = float(pair.x) / span
	var draw: float = float(pair.y) / span
	var low: bool = pair.x < pair.y
	var tight: bool = not low and pair.y > 0 and float(pair.x) < float(pair.y) * 1.2
	hud.power_fill.color = Color(0.86, 0.24, 0.2) if low else (Color(0.95, 0.78, 0.22) if tight else Color(0.3, 0.84, 0.38))
	hud.power_fill.anchor_left = 0.0
	hud.power_fill.anchor_top = 0.0
	hud.power_fill.anchor_bottom = 1.0
	hud.power_fill.anchor_right = gen
	hud.power_fill.offset_left = 0.0
	hud.power_fill.offset_top = 0.0
	hud.power_fill.offset_right = 0.0
	hud.power_fill.offset_bottom = 0.0
	if hud.power_mark != null:
		hud.power_mark.visible = pair.y > 0
		hud.power_mark.anchor_top = 0.0
		hud.power_mark.anchor_bottom = 1.0
		hud.power_mark.anchor_left = draw
		hud.power_mark.anchor_right = draw
		hud.power_mark.offset_left = -1.0
		hud.power_mark.offset_right = 1.0
		hud.power_mark.offset_top = -2.0
		hud.power_mark.offset_bottom = 2.0
	if hud.power_label != null:
		hud.power_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42) if low else Color(1, 1, 1, 0.9))

func _paint_monitor(hud: SMHud) -> void:
	if hud.monitor_cameo != null:
		hud.monitor_cameo.visible = false
	if hud.minimap != null and not hud.phone:
		hud.minimap.visible = true

func _paint_modes(hud: SMHud) -> void:
	if hud.side == null:
		return
	if hud.repair_button != null:
		_lit(hud.repair_button, hud.side.repair_armed)
	if hud.sell_button != null:
		_lit(hud.sell_button, hud.side.sell_armed)

func _lit(button: Button, on: bool) -> void:
	if bool(button.get_meta("lit", false)) == on and button.has_meta("lit"):
		return
	button.set_meta("lit", on)
	button.add_theme_stylebox_override("normal", Look.button_style(_skin, "lit" if on else "normal"))
	button.add_theme_stylebox_override("hover", Look.button_style(_skin, "lit" if on else "hover"))

func _paint_sweeps(hud: SMHud) -> void:
	if hud.icon_grid == null:
		return
	for child: Node in hud.icon_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var id: String = str(button.get_meta("prod_id", ""))
		var kind: String = str(button.get_meta("prod_kind", ""))
		_sweep(button, _ratio(hud, id, kind), _queued(hud, id, kind))

func _paint_super(hud: SMHud) -> void:
	if hud.super_dock == null or hud.side == null or hud.side.yard == null:
		return
	for child: Node in hud.super_dock.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var left: float = hud.side.yard.super_left
		var ready: bool = left <= 0.0 and hud.side.yard.super_name != ""
		var wave: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		button.modulate = Color(1.1 * wave, 1.05 * wave, 0.8) if ready else Color(0.82, 0.84, 0.88)
		button.custom_minimum_size = Vector2(56, 56)
		if str(button.get_meta("dial", "")) != ("ready" if ready else "cool"):
			button.set_meta("dial", "ready" if ready else "cool")
			var plate: StyleBoxFlat = Look.button_style(_skin, "lit" if ready else "normal")
			plate.set_corner_radius_all(28)
			plate.set_border_width_all(3)
			button.add_theme_stylebox_override("normal", plate)
			button.add_theme_stylebox_override("hover", plate)
		var clock: Label = button.get_node_or_null("SuperClock") as Label
		if clock != null:
			clock.text = "RDY" if ready else str(int(ceil(left)))
		_sweep(button, 0.0 if hud.side.yard.super_cooldown <= 0.0 else 1.0 - clampf(left / hud.side.yard.super_cooldown, 0.0, 1.0), 0)

func _ratio(hud: SMHud, id: String, kind: String) -> float:
	if id == "":
		return 0.0
	if kind == "unit" and hud.roster != null and hud.roster.queue != null:
		var queue: RTSProductionQueue = hud.roster.queue
		if not queue.items.is_empty() and str(queue.items[0]) == id:
			return queue.head_ratio()
	if kind == "building" and hud.side != null and hud.side.yard != null:
		var yard: SMBuildYard = hud.side.yard
		if yard.scaffold_active and str(yard.scaffold_id) == id and yard.scaffold_time > 0.0:
			return clampf(yard.scaffold_progress / yard.scaffold_time, 0.0, 1.0)
		if not yard.queue.is_empty() and str(yard.queue[0]) == id:
			var need: float = float(yard.building_time.get(yard.queue[0], 4.0))
			if need > 0.0:
				return clampf(yard.queue_progress / need, 0.0, 1.0)
	return 0.0

func _queued(hud: SMHud, id: String, kind: String) -> int:
	var count: int = 0
	if kind == "unit" and hud.roster != null and hud.roster.queue != null:
		for item: StringName in hud.roster.queue.items:
			if str(item) == id:
				count += 1
	if kind == "building" and hud.side != null and hud.side.yard != null:
		for item: StringName in hud.side.yard.queue:
			if str(item) == id:
				count += 1
		if hud.side.yard.scaffold_active and str(hud.side.yard.scaffold_id) == id:
			count += 1
	return count

func _sweep(button: Button, ratio: float, count: int) -> void:
	var sweep: Control = button.get_node_or_null("CameoSweep") as Control
	if sweep == null:
		sweep = Control.new()
		sweep.name = "CameoSweep"
		sweep.set_script(SWEEP)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(sweep)
	if absf(float(sweep.get("ratio")) - ratio) > 0.001:
		sweep.set("ratio", ratio)
		sweep.queue_redraw()
	var badge: Label = button.get_node_or_null("QueueBadge") as Label
	if badge != null:
		badge.text = str(count)
		badge.visible = count > 0

## Cameo tiles: trim frame, hotkey chip, cost chip, name strip, READY flash, dimmed when locked.
func _paint_tiles(hud: SMHud) -> void:
	if hud.icon_grid == null:
		return
	var key: String = "%d|%s|%s|%d" % [hud.icon_grid.get_child_count(), hud.build_tab, str(hud.phone), hud.icon_grid.columns]
	var purse: int = hud.roster.economy.credits(0) if hud.roster != null and hud.roster.economy != null else 0
	var wave: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
	var restyle: bool = key != _tiles_key
	_tiles_key = key
	for child: Node in hud.icon_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		if restyle or not button.has_meta("skinned"):
			_dress_tile(button)
		var id: String = str(button.get_meta("prod_id", ""))
		var ready: bool = hud.side != null and hud.side.yard != null and str(button.get_meta("prod_kind", "")) == "building" and hud.side.yard.ready.has(StringName(id))
		var flag: Label = button.get_node_or_null("CameoReady") as Label
		if flag != null:
			flag.visible = ready
			flag.modulate.a = wave
		var cost: Label = button.get_node_or_null("CameoCost") as Label
		if cost != null:
			var price: int = int(button.get_meta("cost", -1))
			cost.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if price > purse else Color(1.0, 0.92, 0.6))

func _dress_tile(button: Button) -> void:
	button.set_meta("skinned", true)
	Look.dress_cameo(button, _skin)
	var chip: StyleBoxFlat = StyleBoxFlat.new()
	chip.bg_color = Color(0, 0, 0, 0.72)
	chip.set_corner_radius_all(2)
	chip.content_margin_left = 2
	chip.content_margin_right = 2
	var strip: StyleBoxFlat = StyleBoxFlat.new()
	strip.bg_color = Color(0, 0, 0, 0.66)
	var key_line: Label = button.get_node_or_null("CameoKey") as Label
	if key_line != null:
		key_line.add_theme_stylebox_override("normal", chip)
		key_line.add_theme_color_override("font_color", Look.color(_skin, "trim_hi"))
		key_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_line.position = Vector2(3, 3)
		key_line.size = Vector2(15, 14)
		key_line.visible = key_line.text != ""
	var cost_line: Label = button.get_node_or_null("CameoCost") as Label
	if cost_line != null:
		cost_line.add_theme_stylebox_override("normal", chip)
		cost_line.position = Vector2(34, 3)
		cost_line.size = Vector2(35, 14)
		cost_line.visible = cost_line.text != ""
	var name_line: Label = button.get_node_or_null("CameoName") as Label
	if name_line != null:
		name_line.add_theme_stylebox_override("normal", strip)
		name_line.add_theme_font_size_override("font_size", 10)
		name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_line.position = Vector2(2, 56)
		name_line.size = Vector2(68, 14)
	var badge: Label = button.get_node_or_null("QueueBadge") as Label
	if badge != null:
		badge.position = Vector2(48, 38)
		badge.size = Vector2(20, 16)
		badge.add_theme_stylebox_override("normal", chip)
		badge.add_theme_color_override("font_color", Look.color(_skin, "glow"))
	if button.get_node_or_null("CameoReady") == null:
		var flag: Label = Label.new()
		flag.name = "CameoReady"
		flag.text = "READY"
		flag.visible = false
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		flag.position = Vector2(2, 24)
		flag.size = Vector2(68, 22)
		var glow: StyleBoxFlat = StyleBoxFlat.new()
		glow.bg_color = Look.color(_skin, "accent").darkened(0.2)
		glow.border_color = Look.color(_skin, "glow")
		glow.set_border_width_all(1)
		flag.add_theme_stylebox_override("normal", glow)
		flag.add_theme_font_size_override("font_size", 13)
		flag.add_theme_color_override("font_color", Color(1, 1, 1))
		button.add_child(flag)

## Lit tab, dim others, and a queue count on each.
func _paint_tabs(hud: SMHud) -> void:
	var counts: Dictionary = {}
	if hud.icon_grid != null:
		for child: Node in hud.icon_grid.get_children():
			var button: Button = child as Button
			if button == null:
				continue
			var tab_name: String = str(button.get_meta("tab", ""))
			if tab_name == "aircraft" or tab_name == "naval":
				tab_name = "vehicles"
			counts[tab_name] = int(counts.get(tab_name, 0)) + _queued(hud, str(button.get_meta("prod_id", "")), str(button.get_meta("prod_kind", "")))
	for tab_name: String in ["buildings", "defenses", "infantry", "vehicles"]:
		var tab: Button = find_child("Tab%s" % tab_name.capitalize(), true, false) as Button
		if tab == null:
			continue
		var on: bool = hud.build_tab == tab_name or (tab_name == "vehicles" and (hud.build_tab == "aircraft" or hud.build_tab == "naval"))
		_lit(tab, on)
		if not (tab_name == "buildings" and tab.modulate.g < 0.99 and tab.modulate.b < 0.5):
			tab.modulate = Color(1, 1, 1) if on else Color(0.78, 0.8, 0.84)
		var count: Label = tab.get_node_or_null("TabCount") as Label
		if count != null:
			var n: int = int(counts.get(tab_name, 0))
			count.text = str(n)
			count.visible = n > 0

func _wire_tab(hud: SMHud, node_name: String, tab_name: String) -> void:
	var button: Button = find_child(node_name, true, false) as Button
	if button == null:
		return
	button.mouse_entered.connect(_hover_sound)
	button.pressed.connect(_tab_sound)
	button.pressed.connect(hud.show_build_tab.bind(tab_name))

func _tab_sound() -> void:
	Clips.play_kind(self, "ui_tab")

func _hover_sound() -> void:
	Clips.play_kind(self, "ui_hover")

func _mode_sound() -> void:
	Clips.play_kind(self, "ui_click")

func _top_bar() -> HBoxContainer:
	var top: Panel = Panel.new()
	top.name = "TopBar"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: StyleBoxFlat = Look.plate_style(_skin, 0, 0, 0)
	plate.border_width_bottom = 2
	plate.shadow_size = 6
	top.add_theme_stylebox_override("panel", plate)
	if Glass.live():
		top.material = Look.plate_material(_skin)
	_anchor(top, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, TOP_H)
	add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 12)
	_anchor(row, 0.0, 0.0, 1.0, 1.0, 10.0, 3.0, -10.0, -4.0)
	top.add_child(row)
	return row

func _faction_mark(row: HBoxContainer, hud: SMHud) -> void:
	var mark := TextureRect.new()
	mark.name = "HudFactionMark"
	mark.custom_minimum_size = Vector2(22, 22)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.texture = Marks.texture(_skin if _skin == "black_market" else _mark_id(hud))
	row.add_child(mark)

func _mark_id(hud: SMHud) -> String:
	if hud != null and hud.field != null:
		var id: String = str(hud.field.get("faction_id"))
		if id != "":
			return id
	return SMFront.current()

func _selection_row() -> void:
	var row := Control.new()
	row.name = "SelectionSlots"
	row.visible = false
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.clip_contents = true
	_anchor(row, 0.0, 1.0, 0.0, 1.0, 376.0, -118.0, 472.0, -22.0)
	add_child(row)

## Multi-select: up to 10 group tiles with a health sliver each, over the panel's text rows.
func _paint_selection(hud: SMHud) -> void:
	var row: Control = get_node_or_null("SelectionSlots") as Control
	if row == null or hud == null:
		return
	var units: Array[RTSUnit] = []
	if hud.field != null:
		units = hud.field.selection.units
	var shown: int = mini(10, units.size())
	row.visible = shown > 1 and not hud.phone
	row.z_index = 9
	_tidy_card()
	while row.get_child_count() > shown:
		var extra: Node = row.get_child(row.get_child_count() - 1)
		row.remove_child(extra)
		extra.free()
	for i: int in shown:
		var rect: TextureRect = null
		if i < row.get_child_count():
			rect = row.get_child(i) as TextureRect
		if rect == null:
			rect = TextureRect.new()
			rect.custom_minimum_size = Vector2(36, 36)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var well_bg: ColorRect = ColorRect.new()
			well_bg.name = "WellBg"
			well_bg.color = Color(0.08, 0.09, 0.12, 0.92)
			well_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			well_bg.position = Vector2.ZERO
			well_bg.size = Vector2(36, 36)
			well_bg.show_behind_parent = true
			rect.add_child(well_bg)
			var life: ColorRect = ColorRect.new()
			life.name = "Life"
			life.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.add_child(life)
			row.add_child(rect)
		rect.position = Vector2(float(i) * 39.0, 0.0)
		rect.size = Vector2(36, 36)
		var unit: RTSUnit = units[i]
		var tex: Texture2D = null
		var hp: float = 0.0
		if unit != null and is_instance_valid(unit):
			tex = hud._cameo_texture(hud._faction_id(), _cameo_id_of(unit))
			hp = clampf(unit.hp / maxf(unit.max_hp, 1.0), 0.0, 1.0)
		rect.texture = tex
		rect.visible = true
		var bar: ColorRect = rect.get_node_or_null("Life") as ColorRect
		if bar != null:
			bar.position = Vector2(0, 32)
			bar.size = Vector2(36.0 * hp, 4)
			bar.color = Color(0.3, 0.85, 0.38) if hp > 0.5 else (Color(0.95, 0.78, 0.22) if hp > 0.25 else Color(0.9, 0.25, 0.2))

func _cameo_id_of(unit: RTSUnit) -> String:
	var id: String = str(unit.unit_type)
	if id == "raider" or id == "wave" or id == "":
		var fac: String = str(unit.get_meta("look", SMFront.current()))
		var role: String = str(unit.get_meta("role", "infantry"))
		var loco: String = str(unit.get_meta("locomotion", "ground"))
		id = preload("res://game/model_registry.gd").fallback_unit(role, loco, fac)
	return id

func _faction(hud: SMHud) -> String:
	if hud != null and hud.field != null:
		var id: String = str(hud.field.get("faction_id"))
		if id == "gtfc" or id == "nmrf" or id == "mvd":
			return id
	var front: String = SMFront.current()
	if front == "nmrf" or front == "mvd":
		return front
	return "gtfc"

func _column() -> ScrollContainer:
	var frame: Panel = Panel.new()
	frame.name = "ColumnShade"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: StyleBoxFlat = Look.plate_style(_skin, 0, 3, 0)
	plate.border_width_right = 0
	plate.border_width_top = 0
	plate.shadow_size = 8
	frame.add_theme_stylebox_override("panel", plate)
	if Glass.live():
		frame.material = Look.plate_material(_skin)
	_anchor(frame, 1.0, 0.0, 1.0, 1.0, -SIDE_W, TOP_H, 0.0, 0.0)
	add_child(frame)
	_frame_trim(frame)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CommandColumn"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.clip_contents = true
	_anchor(scroll, 1.0, 0.0, 1.0, 1.0, -SIDE_W + 10.0, TOP_H + 6.0, -6.0, -6.0)
	add_child(scroll)
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "RosterWrap"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 5)
	scroll.add_child(wrap)
	var monitor: PanelContainer = PanelContainer.new()
	monitor.name = "MonitorFrame"
	monitor.custom_minimum_size = Vector2(0, 232)
	var bezel: StyleBoxFlat = Look.well_style(_skin, 4)
	bezel.set_border_width_all(3)
	bezel.border_color = Look.color(_skin, "trim")
	bezel.content_margin_left = 6
	bezel.content_margin_right = 6
	bezel.content_margin_top = 4
	bezel.content_margin_bottom = 4
	monitor.add_theme_stylebox_override("panel", bezel)
	wrap.add_child(monitor)
	var stack: Control = Control.new()
	stack.name = "MonitorStack"
	stack.custom_minimum_size = Vector2(224, 224)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor.add_child(stack)
	var host: Control = Control.new()
	host.name = "MonitorHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(host)
	var cameo: TextureRect = TextureRect.new()
	cameo.name = "MonitorCameo"
	cameo.visible = false
	cameo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cameo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cameo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cameo.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(cameo)
	var power_row: HBoxContainer = HBoxContainer.new()
	power_row.name = "PowerRow"
	power_row.custom_minimum_size = Vector2(0, 22)
	power_row.add_theme_constant_override("separation", 6)
	wrap.add_child(power_row)
	var bolt: TextureRect = TextureRect.new()
	bolt.name = "PowerIcon"
	bolt.custom_minimum_size = Vector2(18, 18)
	bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bolt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bolt.texture = _icon("power")
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_row.add_child(bolt)
	var track: ColorRect = ColorRect.new()
	track.name = "PowerTrack"
	track.color = Color(0.03, 0.035, 0.04)
	track.custom_minimum_size = Vector2(120, 10)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.tooltip_text = "Power generated / power drawn"
	power_row.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.name = "PowerFill"
	fill.color = Color(0.3, 0.84, 0.38)
	fill.layout_mode = 1
	fill.anchor_bottom = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	var mark: ColorRect = ColorRect.new()
	mark.name = "PowerMark"
	mark.color = Color(1, 1, 1, 0.95)
	mark.layout_mode = 1
	mark.anchor_bottom = 1.0
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(mark)
	var power: Label = _label(power_row, "HudPower", 13)
	power.size_flags_horizontal = Control.SIZE_SHRINK_END
	power.custom_minimum_size = Vector2(70, 18)
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power.tooltip_text = "Power generated / power drawn"
	var modes: HBoxContainer = HBoxContainer.new()
	modes.name = "ModeRow"
	modes.add_theme_constant_override("separation", 4)
	wrap.add_child(modes)
	_mode_button(modes, "RepairButton", "Repair", "repair")
	_mode_button(modes, "SellButton", "Sell", "sell")
	var tabs: GridContainer = GridContainer.new()
	tabs.name = "BuildTabs"
	tabs.columns = 4
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	wrap.add_child(tabs)
	_tab_button(tabs, "TabBuildings", "Structures", "tab_buildings")
	_tab_button(tabs, "TabDefenses", "Defenses", "tab_defenses")
	_tab_button(tabs, "TabInfantry", "Infantry", "tab_infantry")
	_tab_button(tabs, "TabVehicles", "Vehicles", "tab_vehicles")
	_tab_button(tabs, "TabAircraft", "Aircraft", "tab_aircraft")
	_tab_button(tabs, "TabNaval", "Naval", "tab_naval")
	var grid: GridContainer = GridContainer.new()
	grid.name = "PhoneIconGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(0, 640)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	wrap.add_child(grid)
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.name = "Sidebar"
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 4)
	wrap.add_child(sidebar)
	var supers: VBoxContainer = VBoxContainer.new()
	supers.name = "SuperDock"
	supers.add_theme_constant_override("separation", 6)
	_anchor(supers, 0.0, 0.0, 0.0, 0.0, 8.0, 100.0, 64.0, 280.0)
	add_child(supers)
	_unit_card()
	return scroll

## Accent stripe and corner rivets on the sidebar frame.
func _frame_trim(frame: Control) -> void:
	var stripe: ColorRect = ColorRect.new()
	stripe.name = "FrameStripe"
	stripe.color = Look.color(_skin, "accent")
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(stripe, 0.0, 0.0, 0.0, 1.0, 3.0, 0.0, 6.0, 0.0)
	frame.add_child(stripe)
	for at: Vector2 in [Vector2(10, 6), Vector2(SIDE_W - 14.0, 6)]:
		var rivet: ColorRect = ColorRect.new()
		rivet.name = "Rivet"
		rivet.color = Look.color(_skin, "trim_hi")
		rivet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rivet.position = at
		rivet.size = Vector2(3, 3)
		frame.add_child(rivet)

func _unit_card() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "UnitCard"
	card.visible = false
	card.z_index = 8
	card.clip_contents = true
	var plate: StyleBoxFlat = Look.plate_style(_skin, 6, 2, 6)
	card.add_theme_stylebox_override("panel", plate)
	if Glass.live():
		card.material = Look.plate_material(_skin)
	_anchor(card, 0.0, 1.0, 0.0, 1.0, 380.0, -128.0, 920.0, -8.0)
	add_child(card)
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "CardRow"
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)
	var well: PanelContainer = PanelContainer.new()
	well.name = "PortraitWell"
	well.add_theme_stylebox_override("panel", Look.well_style(_skin, 3))
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(well)
	var portrait: TextureRect = TextureRect.new()
	portrait.name = "CardCameo"
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.visible = false
	well.add_child(portrait)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.name = "CardStack"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 4)
	body.add_child(lines)
	var text_block: Control = Control.new()
	text_block.name = "CardText"
	text_block.custom_minimum_size = Vector2(0, 38)
	text_block.clip_contents = true
	text_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(text_block)
	var selected: Label = _card_label(text_block, "HudSelection", 15)
	selected.autowrap_mode = TextServer.AUTOWRAP_OFF
	selected.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected.position = Vector2(0, 0)
	selected.size = Vector2(380, 18)
	selected.self_modulate = Color(1, 1, 1, 0)
	var who: Label = _card_label(text_block, "CardName", 15)
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_theme_color_override("font_color", Look.color(_skin, "ink"))
	var group: Label = _card_label(text_block, "CardGroup", 12)
	group.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var chip: StyleBoxFlat = StyleBoxFlat.new()
	chip.bg_color = Look.color(_skin, "accent").darkened(0.3)
	chip.border_color = Look.color(_skin, "trim")
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(3)
	group.add_theme_stylebox_override("normal", chip)
	var track: ColorRect = ColorRect.new()
	track.name = "HealthTrack"
	track.color = Color(0.03, 0.035, 0.04)
	track.position = Vector2(0, 26)
	track.size = Vector2(140, 8)
	text_block.add_child(track)
	var fill: ColorRect = ColorRect.new()
	fill.name = "HealthFill"
	fill.color = Color(0.3, 0.84, 0.38)
	fill.layout_mode = 1
	fill.anchor_bottom = 1.0
	fill.offset_right = 120.0
	track.add_child(fill)
	var hp: Label = _card_label(text_block, "CardHp", 12)
	hp.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	var rank: Control = Control.new()
	rank.name = "CardRank"
	rank.set_script(Rank)
	rank.size = Vector2(16, 18)
	text_block.add_child(rank)
	var veteran: Label = _card_label(text_block, "HudVeteran", 12)
	veteran.add_theme_color_override("font_color", Look.color(_skin, "trim_hi"))
	var ability: Label = _card_label(text_block, "CardAbility", 12)
	ability.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ability.add_theme_color_override("font_color", Look.color(_skin, "glow").lightened(0.25))
	var built: Label = _card_label(text_block, "HudBuild", 13)
	built.visible = false
	built.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	built.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	built.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	var breakdown: Label = _card_label(text_block, "HudBreakdown", 13)
	breakdown.visible = false
	var commands: VBoxContainer = VBoxContainer.new()
	commands.name = "CommandRow"
	commands.custom_minimum_size = Vector2(0, 56)
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.add_theme_constant_override("separation", 0)
	lines.add_child(commands)
	_message_lane()

## Places the panel's text rows for the block width, and fills name, HP, rank, group and ability.
func _paint_card(hud: SMHud) -> void:
	var block: Control = find_child("CardText", true, false) as Control
	if block == null:
		return
	var w: float = maxf(block.size.x, 260.0)
	var first: RTSUnit = null
	var count: int = 0
	if hud.field != null:
		count = hud.field.selection.count()
		if count > 0:
			first = hud.field.selection.units[0]
	if first != null and not is_instance_valid(first):
		first = null
	var multi: bool = count > 1
	var who: Label = block.get_node_or_null("CardName") as Label
	var group: Label = block.get_node_or_null("CardGroup") as Label
	var hp: Label = block.get_node_or_null("CardHp") as Label
	var rank: Control = block.get_node_or_null("CardRank") as Control
	var veteran: Label = block.get_node_or_null("HudVeteran") as Label
	var ability: Label = block.get_node_or_null("CardAbility") as Label
	var track: Control = block.get_node_or_null("HealthTrack") as Control
	var built: Label = block.get_node_or_null("HudBuild") as Label
	var solo: bool = first != null and not multi
	var group_n: int = _group_of(hud)
	if who != null:
		who.visible = solo
		who.position = Vector2(0, 0)
		who.size = Vector2(w * 0.6, 18)
		if solo:
			who.text = hud.field.name_of(first)
	if group != null:
		group.visible = group_n >= 0
		group.text = str(group_n)
		group.position = Vector2(w - 22.0, 0) if multi else Vector2(minf(w * 0.6 + 4.0, w - 22.0), 0)
		group.size = Vector2(20, 16)
	if built != null:
		built.position = Vector2(w * 0.6 + 28.0, 0) if solo else Vector2(0, 0)
		built.size = Vector2(maxf(40.0, w - built.position.x), 16)
		if built.visible and multi:
			built.visible = false
	if track != null:
		track.visible = solo
		track.size = Vector2(minf(140.0, w * 0.34), 8)
	if hud.health_fill != null and track != null and first != null:
		var ratio: float = clampf(first.hp / maxf(first.max_hp, 1.0), 0.0, 1.0)
		hud.health_fill.offset_right = track.size.x * ratio
		hud.health_fill.color = Color(0.3, 0.84, 0.38) if ratio > 0.5 else (Color(0.95, 0.78, 0.22) if ratio > 0.25 else Color(0.9, 0.25, 0.2))
	var x: float = (track.size.x + 6.0) if track != null else 146.0
	if hp != null:
		hp.visible = solo
		hp.position = Vector2(x, 21)
		hp.size = Vector2(64, 16)
		if solo:
			hp.text = "%d/%d" % [int(round(first.hp)), int(round(first.max_hp))]
	x += 66.0
	var kills: int = int(first.get_meta("kills", 0)) if first != null else 0
	if rank != null:
		rank.visible = solo
		rank.position = Vector2(x, 19)
		rank.size = Vector2(16, 18)
		rank.call("show_rank", 3 if kills >= 5 else (1 if kills >= 2 else 0), Look.color(_skin, "trim_hi"))
	x += 18.0
	if veteran != null:
		veteran.position = Vector2(x, 21)
		veteran.size = Vector2(62, 16)
		if multi:
			veteran.visible = false
	x += 64.0
	if ability != null:
		ability.visible = solo
		ability.position = Vector2(x, 21)
		ability.size = Vector2(maxf(30.0, w - x), 16)
		if solo:
			ability.text = "F  %s" % _ability_of(hud, first)
	var well: Control = find_child("PortraitWell", true, false) as Control
	if well != null and hud.card_cameo != null:
		well.visible = hud.card_cameo.visible or hud.card_cameo.texture != null

func _group_of(hud: SMHud) -> int:
	if hud.field == null or hud.field.selection.count() == 0:
		return -1
	var picked: Array[RTSUnit] = hud.field.selection.units
	for i: int in hud.field.selection.groups:
		var members: Array = hud.field.selection.groups[i]
		if members.size() != picked.size():
			continue
		var same: bool = true
		for u: RTSUnit in picked:
			if not members.has(u):
				same = false
				break
		if same:
			return i
	return -1

func _ability_of(hud: SMHud, unit: RTSUnit) -> String:
	if unit.has_meta("ability") and str(unit.get_meta("ability")) != "":
		return str(unit.get_meta("ability"))
	if unit.has_meta("secondary"):
		return hud._ability_name(str(unit.get_meta("secondary")))
	return "ability"

## EVA banner under the top bar: faction mark, one line, fades out.
func _message_lane() -> void:
	var lane: PanelContainer = PanelContainer.new()
	lane.name = "MessageLane"
	lane.visible = false
	lane.z_index = 9
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(lane, 0.0, 0.0, 0.0, 0.0, 380.0, 72.0, 900.0, 108.0)
	add_child(lane)
	Glass.dress(lane, 6, Color(Look.color(_skin, "accent").darkened(0.55), 0.62), 8, Color(Look.color(_skin, "glow"), 0.6))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "EvaRow"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.add_child(row)
	var bar: ColorRect = ColorRect.new()
	bar.name = "EvaBar"
	bar.color = Look.color(_skin, "glow")
	bar.custom_minimum_size = Vector2(3, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var mark: TextureRect = TextureRect.new()
	mark.name = "EvaMark"
	mark.custom_minimum_size = Vector2(22, 22)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.texture = Marks.texture(_skin if _skin == "black_market" else _faction(null))
	row.add_child(mark)
	var radio: Label = Label.new()
	radio.name = "RadioLine"
	radio.visible = false
	radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio.size_flags_vertical = Control.SIZE_FILL
	radio.custom_minimum_size = Vector2(0, 22)
	radio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	radio.clip_text = true
	radio.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	radio.add_theme_font_size_override("font_size", 16)
	radio.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	radio.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	radio.add_theme_constant_override("outline_size", 3)
	row.add_child(radio)

func _mode_button(row: HBoxContainer, node_name: String, text: String, icon_name: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = text
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("icon_max_width", 20)
	Look.dress_button(button, _skin)
	button.icon = _icon(icon_name)
	row.add_child(button)

func _tab_button(grid: GridContainer, node_name: String, text: String, icon_name: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = ""
	button.clip_text = false
	button.tooltip_text = text
	button.custom_minimum_size = Vector2(54, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 28)
	Look.dress_button(button, _skin)
	button.icon = _icon(icon_name)
	if button.icon == null:
		button.text = text.substr(0, 3)
	var count: Label = Label.new()
	count.name = "TabCount"
	count.visible = false
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.position = Vector2(36, 1)
	count.size = Vector2(16, 14)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 11)
	count.add_theme_color_override("font_color", Color(0, 0, 0))
	var pip: StyleBoxFlat = StyleBoxFlat.new()
	pip.bg_color = Look.color(_skin, "glow")
	pip.set_corner_radius_all(7)
	count.add_theme_stylebox_override("normal", pip)
	button.add_child(count)
	grid.add_child(button)

func _icon(icon_name: String) -> Texture2D:
	var path: String = ICONS % icon_name
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _pin_bar_label(label: Label) -> void:
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size = Vector2(48, 20)

func _tidy_card() -> void:
	var extra: CanvasItem = find_child("HudBreakdown", true, false) as CanvasItem
	if extra != null:
		extra.visible = false

func _label(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _card_label(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = _label(parent, node_name, size)
	label.custom_minimum_size = Vector2(0, 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_O:
		return
	var layer: Node = get_parent()
	if layer != null:
		var pause: CanvasItem = layer.find_child("PauseMenu", true, false) as CanvasItem
		if pause != null and pause.visible:
			return
	_goals_open = not _goals_open
	var view: Viewport = get_viewport()
	if view != null:
		view.set_input_as_handled()

func _open_menu() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var pause: CanvasItem = layer.find_child("PauseMenu", true, false) as CanvasItem
	if pause != null:
		pause.visible = true

## Frosted glass on the cards other scripts build: tip, guide, strip, coach, toasts, briefing, pause.
func _glass_overlays() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	for node_name: String in ["TipPanel", "HowToOverlay", "MatchStrip", "CoachCard", "ToastLane", "BriefingShade", "Protocols", "MissionPanel", "PhoneDrawer"]:
		if _glassed.has(node_name):
			continue
		var node: Control = layer.find_child(node_name, true, false) as Control
		if node == null:
			continue
		_glassed[node_name] = true
		_glass(node)
	var boot: Button = layer.find_child("MissionBoot", true, false) as Button
	if boot != null and not _glassed.has("MissionBoot"):
		_glassed["MissionBoot"] = true
		Look.dress_button(boot, _skin)

func _glass(node: Control) -> void:
	var tint: Color = Glass.TINT
	if node is PanelContainer or node is Panel:
		var margin: int = 10 if node.name != "MatchStrip" else 6
		Glass.dress(node, 8, tint, margin)
		return
	if node is ColorRect:
		var shade: ColorRect = node as ColorRect
		shade.color = Color(0, 0, 0, 0)
		var pane: Panel = Panel.new()
		pane.name = "%sGlass" % node.name
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pane.position = shade.position
		pane.size = shade.size
		Glass.dress(pane, 6, tint, 0)
		var parent: Node = shade.get_parent()
		if parent != null:
			parent.add_child(pane)
			parent.move_child(pane, shade.get_index())
		return
	for child: Node in node.get_children():
		var flat: ColorRect = child as ColorRect
		if flat != null and flat.get_index() == 0:
			flat.color = Color(0, 0, 0, 0)
	Glass.sheet(node, "Glass", tint, 6)

func _seat_chrome() -> void:
	var hud: SMHud = get_meta("hud", null) as SMHud
	if hud != null and hud.phone:
		_seat_phone(hud)
		return
	_seat_desktop()
	_seat_context()
	_seat_message()
	_seat_objective()
	_seat_now_playing()
	_seat_flyout()
	_seat_strip()
	_seat_boot()
	_seat_toast()
	_seat_briefing()
	var layer: Node = get_parent()
	if layer == null:
		return
	var help: CanvasItem = layer.find_child("HelpButton", true, false) as CanvasItem
	if help != null:
		help.visible = false

## The base phone layout docks the card at 72 px tall; the RA3 card needs two rows.
func _seat_phone(hud: SMHud) -> void:
	var layer: Node = get_parent()
	if layer != null:
		for node_name: String in ["ObjectiveShade", "ObjectiveMark"]:
			var chrome: CanvasItem = layer.get_node_or_null(node_name) as CanvasItem
			if chrome != null:
				chrome.visible = false
	var portrait: Control = find_child("CardCameo", true, false) as Control
	if portrait != null:
		portrait.custom_minimum_size = Vector2(64, 64)
	_fit_commands(true)
	var card: Control = get_node_or_null("UnitCard") as Control
	if card == null:
		return
	var sheet: float = hud.phone_sheet if hud.drawer_open else 68.0
	_anchor(card, 0.0, 1.0, 1.0, 1.0, 6.0, -(sheet + 122.0), -6.0, -(sheet + 6.0))

func _seat_desktop() -> void:
	var layer: Node = get_parent()
	if layer != null:
		for node_name: String in ["ObjectiveShade", "ObjectiveMark"]:
			var chrome: CanvasItem = layer.get_node_or_null(node_name) as CanvasItem
			if chrome != null:
				chrome.visible = true
	var portrait: Control = find_child("CardCameo", true, false) as Control
	if portrait != null:
		portrait.custom_minimum_size = Vector2(96, 96)
	_fit_commands(false)
	var view: Vector2 = _view_rect()
	var side: float = 224.0 if view.y >= 600.0 or view.y < 240.0 else clampf(view.y - 278.0, 112.0, 224.0)
	var monitor: Control = find_child("MonitorFrame", true, false) as Control
	var stack: Control = find_child("MonitorStack", true, false) as Control
	var hud: SMHud = get_meta("hud", null) as SMHud
	if monitor == null or stack == null or hud == null or hud.minimap == null:
		return
	if is_equal_approx(hud.minimap.size.y, side):
		return
	monitor.custom_minimum_size.y = side + 8.0
	stack.custom_minimum_size = Vector2(224, side)
	hud.minimap.custom_minimum_size = Vector2(side, side)
	hud.minimap.size = Vector2(side, side)
	hud.minimap.position = Vector2((224.0 - side) * 0.5, 0.0)

func _fit_commands(narrow: bool) -> void:
	var cells: Node = find_child("CommandCells", true, false)
	if cells == null:
		return
	for child: Node in cells.get_children():
		var button: Button = child as Button
		if button == null or narrow == button.has_meta("wide_flags"):
			continue
		if narrow:
			button.set_meta("wide_flags", button.size_flags_horizontal)
			button.custom_minimum_size = Vector2(0, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 10)
		else:
			button.size_flags_horizontal = int(button.get_meta("wide_flags"))
			button.remove_meta("wide_flags")
			button.custom_minimum_size = Vector2(56, 56)
			button.add_theme_font_size_override("font_size", 12)

func _view_rect() -> Vector2:
	if size.x >= 64.0 and size.y >= 64.0:
		return size
	var vp: Viewport = get_viewport()
	if vp != null:
		var visible: Vector2 = vp.get_visible_rect().size
		if visible.x >= 64.0 and visible.y >= 64.0:
			return visible
	return Vector2(1280.0, 720.0)

func _seat_context() -> void:
	var card: Control = get_node_or_null("UnitCard") as Control
	if card == null:
		return
	var view: Vector2 = _view_rect()
	var width: float = 540.0
	var sidebar: float = view.x - SIDE_W - 8.0
	var x: float = (sidebar - width) * 0.5
	if x < 80.0:
		x = 80.0
		width = maxf(280.0, sidebar - 80.0)
	_anchor(card, 0.0, 1.0, 0.0, 1.0, x, -128.0, x + width, -8.0)
	var slots: Control = get_node_or_null("SelectionSlots") as Control
	if slots == null:
		return
	var slot_x: float = maxf(x + 8.0 + 102.0 + 8.0, 360.0)
	_anchor(slots, 0.0, 1.0, 0.0, 1.0, slot_x, -124.0, minf(slot_x + 392.0, x + width - 10.0), -82.0)

func _seat_message() -> void:
	var lane: Control = get_node_or_null("MessageLane") as Control
	var radio: Label = find_child("RadioLine", true, false) as Label
	if lane == null or radio == null:
		return
	var column: Rect2 = _story_column()
	_anchor(lane, 0.0, 0.0, 0.0, 0.0, column.position.x, 70.0, column.end.x, 106.0)
	var layer: Node = get_parent()
	var brief: CanvasItem = layer.find_child("Briefing", true, false) as CanvasItem if layer != null else null
	var brief_up: bool = brief != null and brief.visible
	lane.visible = radio.visible and radio.text != "" and not brief_up
	lane.modulate.a = radio.modulate.a

## The centre column under the top bar, right of the objective and coach stack:
## EVA line, then toast, then mission heading and briefing, so none of them overlap.
func _story_column() -> Rect2:
	var view: Vector2 = _view_rect()
	var play_w: float = view.x - SIDE_W
	var x: float = 448.0
	var width: float = clampf(play_w - x - 12.0, 280.0, 560.0)
	if x + width > play_w - 8.0:
		x = maxf(220.0, play_w - 8.0 - width)
	return Rect2(x, 70.0, width, 180.0)

func _seat_briefing() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var brief: Label = layer.find_child("Briefing", true, false) as Label
	if brief == null or not brief.visible:
		return
	var column: Rect2 = _story_column()
	var heading: Control = layer.find_child("MissionHeading", true, false) as Control
	var top: float = 148.0
	if heading != null and heading.visible:
		heading.position = Vector2(column.position.x, top)
		heading.size = Vector2(column.size.x, 24.0)
		(heading as Label).clip_text = true
		top += 28.0
	var width: float = minf(column.size.x, 760.0)
	brief.position = Vector2(column.position.x, top)
	brief.custom_minimum_size = Vector2(width, 64.0)
	brief.size = Vector2(width, 64.0)
	var base: Node = brief.get_parent()
	for node_name: String in ["BriefingShade", "BriefingShadeGlass"]:
		var shade: Control = base.get_node_or_null(node_name) as Control if base != null else null
		if shade != null:
			shade.position = brief.position
			shade.size = brief.size
	var details: Control = base.get_node_or_null("BriefingDetails") as Control if base != null else null
	if details != null:
		details.position = Vector2(brief.position.x + brief.size.x - 104.0, brief.position.y + brief.size.y + 4.0)
	var dismiss: Control = base.get_node_or_null("BriefingDismiss") as Control if base != null else null
	if dismiss != null:
		dismiss.position = Vector2(brief.position.x + brief.size.x - 208.0, brief.position.y + brief.size.y + 4.0)
	var dialogue: Control = layer.find_child("SetDialogue", true, false) as Control
	if dialogue != null:
		var dialogue_top: float = brief.position.y + brief.size.y + 40.0
		if dialogue.position.y < dialogue_top:
			dialogue.position.y = dialogue_top

func _seat_toast() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var toast: Control = layer.find_child("ToastLane", true, false) as Control
	if toast == null or not toast.visible:
		return
	var brief: CanvasItem = layer.find_child("Briefing", true, false) as CanvasItem
	if brief != null and brief.visible:
		toast.visible = false
		return
	var column: Rect2 = _story_column()
	var width: float = minf(column.size.x, 420.0)
	toast.position = Vector2(column.position.x, 112.0)
	toast.size = Vector2(width, 28.0)
	var line: Control = toast.find_child("ToastLine", true, false) as Control
	if line != null:
		line.size = Vector2(width - 16.0, 20.0)

func _seat_objective() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var status: Label = layer.find_child("Status", true, false) as Label
	if status == null:
		return
	var shade: Panel = layer.get_node_or_null("ObjectiveShade") as Panel
	if shade == null:
		shade = Panel.new()
		shade.name = "ObjectiveShade"
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		shade.z_index = 6
		Glass.dress(shade, 6, Glass.TINT, 0)
		layer.add_child(shade)
		layer.move_child(shade, 0)
	var mark: Label = layer.get_node_or_null("ObjectiveMark") as Label
	if mark == null:
		mark = Label.new()
		mark.name = "ObjectiveMark"
		mark.text = "☐"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.z_index = 7
		mark.add_theme_font_size_override("font_size", 16)
		mark.add_theme_color_override("font_color", Look.color(_skin, "trim_hi"))
		var face: Font = ThemeDB.fallback_font
		if face != null:
			mark.add_theme_font_override("font", face)
		layer.add_child(mark)
	var height: float = 120.0 if _goals_open else 28.0
	_anchor(shade, 0.0, 0.0, 0.0, 0.0, 72.0, 36.0, 384.0, 36.0 + height)
	_anchor(mark, 0.0, 0.0, 0.0, 0.0, 78.0, 38.0, 98.0, 62.0)
	status.z_index = 7
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _goals_open else TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.max_lines_visible = 6 if _goals_open else 1
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size = Vector2(0, 22)
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_anchor(status, 0.0, 0.0, 0.0, 0.0, 100.0, 38.0, 376.0, 36.0 + height)

func _seat_flyout() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var fly: Control = layer.find_child("Protocols", true, false) as Control
	if fly == null:
		return
	var view: Vector2 = _view_rect()
	var card_top: float = view.y - 136.0
	var bottom: float = minf(340.0, card_top - 8.0)
	if bottom < 148.0:
		bottom = 148.0
	fly.offset_left = 72.0
	fly.offset_top = 100.0
	fly.offset_right = 432.0
	fly.offset_bottom = bottom
	fly.custom_minimum_size = Vector2(320, minf(120.0, bottom - 100.0))

func _seat_strip() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var strip: Control = layer.find_child("MatchStrip", true, false) as Control
	if strip == null or not strip.visible:
		return
	var view: Vector2 = _view_rect()
	var sidebar: float = view.x - SIDE_W - 8.0
	var right: float = minf(700.0, sidebar - 8.0)
	if right - 448.0 < 96.0:
		return
	_anchor(strip, 0.0, 0.0, 0.0, 0.0, 448.0, 36.0, right, 64.0)

## Menu chip on the left rail, under the superweapon dial, clear of the unit panel.
func _seat_boot() -> void:
	var layer: Node = get_parent()
	if layer == null:
		return
	var boot: Control = layer.find_child("MissionBoot", true, false) as Control
	if boot == null:
		return
	var match_end: CanvasItem = layer.get_node_or_null("MatchEnd") as CanvasItem
	var outro_plate: CanvasItem = layer.get_node_or_null("OutroPlate") as CanvasItem
	if (match_end != null and match_end.visible) or (outro_plate != null and outro_plate.visible):
		boot.visible = false
		return
	var view: Vector2 = _view_rect()
	var y: float = clampf(view.y - 176.0, 290.0, view.y - 52.0)
	boot.position = Vector2(8.0, y)
	boot.size = Vector2(64.0, 40.0)
	boot.custom_minimum_size = Vector2(64.0, 40.0)
	var tap: Button = boot as Button
	if tap != null:
		tap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tap.add_theme_font_size_override("font_size", 11)

func _seat_now_playing() -> void:
	var line: Control = get_node_or_null("NowPlaying") as Control
	if line == null:
		return
	var view: Vector2 = _view_rect()
	if view.x < 1200.0:
		line.visible = false
		return
	line.visible = true
	var right: float = view.x - SIDE_W - 12.0
	_anchor(line, 0.0, 0.0, 0.0, 0.0, right - 240.0, view.y - 156.0, right, view.y - 138.0)
	(line as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _anchor(node: Control, left: float, top: float, right: float, bottom: float, ol: float, ot: float, orr: float, ob: float) -> void:
	node.layout_mode = 1
	node.anchor_left = left
	node.anchor_top = top
	node.anchor_right = right
	node.anchor_bottom = bottom
	node.offset_left = ol
	node.offset_top = ot
	node.offset_right = orr
	node.offset_bottom = ob
