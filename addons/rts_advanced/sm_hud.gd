class_name SMHud
extends RefCounted

const Power = preload("res://addons/rts_advanced/sm_power.gd")
## In-match readout. Primitive controls and a flat minimap. No map mesh.

signal layer_mounted(who: SMHud, layer: CanvasLayer)
signal line_voiced(text: String, key: String)

var field: SMPointer
var roster: SMRoster
var side: SMSide
var tech: SMTechNet
var sidebar: VBoxContainer
var imports_ready: bool = false
var map_name: String = ""
var rally: Vector3 = Vector3.ZERO
var on_ability: Callable
var faction_label: Label
var credits_label: Label
var income_label: Label
var power_label: Label
var map_label: Label
var weather_label: Label
var selection_label: Label
var build_label: Label
var minimap: SMMinimap
var sfx: SMSfx
var cameo_for: Callable
var guide_panel: Control
var tutorial_label: Label
var tip_panel: Control
var tip_label: Label
var tip_cameo: TextureRect
var hover_tip: String = ""
var hover_cameo: String = ""
var hover_key: String = ""
var hover_facts: String = ""
var tip_at: int = 0
var tip_name: Label
var tip_chip: Label
var radio_label: Label
var radio_until: int = 0
var radio_queue: PackedStringArray = PackedStringArray()
var unit_card: PanelContainer
var card_cameo: TextureRect
var match_strip: PanelContainer
var purse_mark: int = -1
var purse_ms: int = 0
var purse_rate: int = 0
var purse_window: float = 0.0
var purse_gained: int = 0
var purse_flash: String = ""
var purse_flash_t: float = 0.0
var _map_ms: int = 0
var _shown_credits: int = -999999
var _shown_power: Vector2i = Vector2i(-1, -1)
var _shown_weather: String = ""
var _shown_faction: String = ""
var _shown_map: String = ""
var _shown_selection: String = ""
var layer_node: CanvasLayer
var phone: bool = false
var phone_tab: String = "buildings"
var drawer_open: bool = false
var phone_sheet: float = 280.0
var hint_closed: bool = false
var mission_open: bool = false
var _layout_key: Vector2i = Vector2i(-1, -1)
var phone_drawer: Control
var phone_body: Control
var icon_grid: GridContainer
var _column_drag: float = 0.0
var _column_dragging: bool = false
var _swallow_press: bool = false
var mission_fold: Button
var mission_panel: Control
var rotate_banner: Control
var chrome: Callable
var use_tiles: bool = false
var paint_extra: Callable
var build_tab: String = "buildings"
var command_row: VBoxContainer
var super_dock: VBoxContainer
var monitor_cameo: TextureRect
var health_fill: ColorRect
var veteran_label: Label
var breakdown_label: Label
var power_fill: ColorRect
var power_mark: ColorRect
var repair_button: Button
var sell_button: Button
var sky: SMSight

func mount(layer: CanvasLayer, p_field: SMPointer, p_roster: SMRoster, p_side: SMSide, p_map: String, p_rally: Vector3, ability: Callable, grid: SMDomainGrid, camera: RTSCamera) -> void:
	field = p_field
	roster = p_roster
	side = p_side
	map_name = p_map
	rally = p_rally
	on_ability = ability
	if chrome.is_valid():
		chrome.call(layer, self, grid, camera)
	if faction_label != null:
		var roster_scroll: ScrollContainer = layer.find_child("CommandColumn", true, false) as ScrollContainer
		if roster_scroll != null and not roster_scroll.gui_input.is_connected(_drag_column):
			roster_scroll.gui_input.connect(_drag_column)
		_fill_roster()
		_guide(layer)
		_tip(layer)
		_finish_mount(layer)
		return
	var top: Control = Control.new()
	top.name = "TopBar"
	top.anchor_right = 1.0
	top.offset_bottom = 36.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.92)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(shade)
	var row: HBoxContainer = HBoxContainer.new()
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 12.0
	row.offset_top = 4.0
	row.offset_right = -12.0
	row.offset_bottom = -4.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	faction_label = _flow_label(row, "HudFaction", 16)
	credits_label = _flow_label(row, "HudCredits", 16)
	income_label = _flow_label(row, "HudIncome", 15)
	income_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.48))
	income_label.visible = false
	power_label = _flow_label(row, "HudPower", 16)
	map_label = _flow_label(row, "HudMap", 16)
	map_label.size_flags_stretch_ratio = 2.2
	map_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weather_label = _flow_label(row, "HudWeather", 15)
	minimap = SMMinimap.new()
	minimap.name = "Minimap"
	minimap.setup(grid, field, camera)
	minimap.position = Vector2(8, 42)
	minimap.custom_minimum_size = Vector2(156, 108)
	minimap.size = Vector2(156, 108)
	layer.add_child(minimap)
	_column(layer)
	_guide(layer)
	_tip(layer)
	_finish_mount(layer)

func _finish_mount(layer: CanvasLayer) -> void:
	sfx = SMSfx.new()
	sfx.mount(layer)
	if field != null:
		field.on_cue = Callable(sfx, "play")
		field.on_line = Callable(self, "show_line")
		field.on_bark = Callable(sfx, "bark")
	layer_node = layer
	layer.set_meta("hud", self)
	if minimap != null and side != null:
		minimap.yard = side.yard
	if field != null:
		field.place_rally(rally)
	_hide_empty_tabs()
	show_build_tab(build_tab)
	layer_mounted.emit(self, layer)
	refresh()

## A sight without a grid only names the weather. It keeps the fog it had.
func use_sight(p_sight: SMSight) -> void:
	sky = p_sight
	if minimap == null:
		return
	if p_sight != null and p_sight.grid == null and minimap.sight != null:
		return
	minimap.sight = p_sight

func use_tech(p_tech: SMTechNet) -> void:
	tech = p_tech

func use_goods(p_goods: SMCommodityNet) -> void:
	if minimap != null:
		minimap.goods = p_goods

func refresh() -> void:
	if faction_label == null:
		return
	var faction: String = _faction_name(_faction_id())
	if faction != _shown_faction:
		_shown_faction = faction
		faction_label.text = faction
	var purse: int = 0
	if roster != null and roster.economy != null:
		purse = roster.economy.credits(0)
	_measure_purse()
	if purse != _shown_credits:
		_shown_credits = purse
		credits_label.text = ("%d" % purse) if phone else ("Credits %d" % purse)
	var pair: Vector2i = Power.tally(side.yard if side != null else null)
	if pair != _shown_power:
		_shown_power = pair
		power_label.text = "⚡ %d/%d" % [pair.x, pair.y]
	if map_name != _shown_map:
		_shown_map = map_name
		map_label.text = map_name
	if weather_label != null:
		var sky_name: String = "Clear"
		if sky != null:
			sky_name = sky.weather_name
		elif minimap != null and minimap.sight != null:
			sky_name = minimap.sight.weather_name
		if sky_name != _shown_weather:
			_shown_weather = sky_name
			weather_label.text = sky_name
	if selection_label != null:
		var line: String = _selection_line()
		if line != _shown_selection:
			_shown_selection = line
			selection_label.text = line
		_paint_card()
	_sync_imports()
	_paint_tip()
	_paint_radio()
	_sync_card()
	_paint_mission_fold()
	if minimap != null:
		var now: int = Time.get_ticks_msec()
		if _map_ms <= 0 or now - _map_ms >= 250:
			_map_ms = maxi(now, 1)
			minimap.sample()
			minimap.queue_redraw()
	if paint_extra.is_valid():
		paint_extra.call(self)

func _power_pair() -> Vector2i:
	return Power.tally(side.yard if side != null else null)

func set_rally(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	rally = at
	if field != null:
		field.place_rally(at)
	_note("Rally set")

func _measure_purse() -> void:
	var now: int = Time.get_ticks_msec()
	var dt: float = 0.0
	if purse_ms > 0:
		dt = clampf(float(now - purse_ms) / 1000.0, 0.0, 1.0)
	purse_ms = now
	_apply_purse(dt)

func _apply_purse(delta: float) -> void:
	if roster == null or roster.economy == null:
		return
	var now_credits: int = roster.economy.credits(0)
	if purse_mark < 0:
		purse_mark = now_credits
		return
	var gain: int = now_credits - purse_mark
	purse_mark = now_credits
	if gain > 0:
		purse_gained += gain
		purse_flash = "+%d" % gain
		purse_flash_t = 1.4
	elif purse_flash_t > 0.0:
		purse_flash_t = maxf(0.0, purse_flash_t - delta)
	purse_window += maxf(delta, 0.0)
	if purse_window >= 1.0:
		purse_rate = int(round(float(purse_gained) / purse_window))
		purse_gained = 0
		purse_window = 0.0
	_paint_income()

func _paint_income() -> void:
	if income_label == null:
		return
	var rate: String = "+%d/s" % purse_rate if purse_rate > 0 else ""
	if rate != "" and purse_flash_t > 0.0 and purse_flash != "":
		income_label.text = "%s  %s" % [rate, purse_flash]
	elif rate != "":
		income_label.text = rate
	elif purse_flash_t > 0.0:
		income_label.text = purse_flash
	else:
		income_label.text = ""
	income_label.visible = income_label.text != ""

func show_line(text: String) -> void:
	if radio_label == null:
		return
	if text == "":
		radio_label.text = ""
		radio_label.visible = false
		return
	if _briefing_shown():
		if not radio_queue.has(text):
			radio_queue.append(text)
		return
	_display_radio(text)

func _display_radio(text: String) -> void:
	if radio_label == null:
		return
	radio_label.text = text
	radio_label.visible = text != ""
	radio_label.modulate.a = 1.0
	radio_until = Time.get_ticks_msec() + 5000
	_sync_card()

func _briefing_shown() -> bool:
	if layer_node == null:
		return false
	var brief: CanvasItem = layer_node.find_child("Briefing", true, false) as CanvasItem
	if brief != null:
		return brief.visible
	var host: Node = layer_node.get_parent()
	if host != null:
		var piece: Node = host.get_node_or_null("SetPiece")
		if piece != null and not bool(piece.get("intro_done")):
			return true
	return false

func _paint_radio() -> void:
	if radio_label == null:
		return
	if _briefing_shown():
		if radio_label.visible and radio_label.text != "":
			if not radio_queue.has(radio_label.text):
				radio_queue.insert(0, radio_label.text)
		radio_label.visible = false
		radio_until = 0
		return
	if not radio_label.visible:
		if not radio_queue.is_empty():
			var next_line: String = radio_queue[0]
			radio_queue.remove_at(0)
			_display_radio(next_line)
		return
	var left: int = radio_until - Time.get_ticks_msec()
	if left <= 0:
		radio_label.visible = false
		radio_label.modulate.a = 1.0
		if not radio_queue.is_empty():
			var next_line: String = radio_queue[0]
			radio_queue.remove_at(0)
			_display_radio(next_line)
		return
	radio_label.modulate.a = 1.0 if left >= 800 else clampf(float(left) / 800.0, 0.0, 1.0)

func set_tutorial(text: String) -> void:
	if tutorial_label == null:
		return
	tutorial_label.text = text
	tutorial_label.visible = text != ""

static func present_tip(host: Node, text: String) -> void:
	if host == null or not host.has_meta("hud"):
		return
	var hud: SMHud = host.get_meta("hud") as SMHud
	if hud == null:
		return
	hud.hover_tip = text
	hud.hover_cameo = ""
	hud.hover_key = ""
	hud.hover_facts = ""
	hud.tip_at = Time.get_ticks_msec()
	hud._paint_tip()

func _column(layer: CanvasLayer) -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "ColumnShade"
	backdrop.color = Color(0.05, 0.06, 0.07, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock(backdrop, -260.0, 40.0, -8.0, -8.0, 1.0, 0.0, 1.0, 1.0)
	layer.add_child(backdrop)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CommandColumn"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_contents = true
	scroll.gui_input.connect(_drag_column)
	_dock(scroll, -260.0, 40.0, -8.0, -8.0, 1.0, 0.0, 1.0, 1.0)
	layer.add_child(scroll)
	var wrap: VBoxContainer = VBoxContainer.new()
	wrap.name = "RosterWrap"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)
	scroll.add_child(wrap)
	var grid: GridContainer = GridContainer.new()
	grid.name = "PhoneIconGrid"
	grid.columns = 4
	grid.visible = false
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	wrap.add_child(grid)
	icon_grid = grid
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Sidebar"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, 0)
	box.add_theme_constant_override("separation", 4)
	wrap.add_child(box)
	sidebar = box
	_fill_roster()

func _fill_roster() -> void:
	var box: VBoxContainer = sidebar
	if box == null:
		return
	if box.get_node_or_null("HudTitle") == null:
		_header(box, "HudTitle", "ASEAN 2031")
		_header(box, "GroupBuildings", "Buildings")
	var data: Dictionary = SMCatalog.faction(_faction_id())
	var tile_host: Container = icon_grid if use_tiles and icon_grid != null else box
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				var id: StringName = StringName(str(item.get("id", "")))
				if str(id) == "":
					continue
				var node_name: String = "MovePacker" if str(id) == "packer" else "Build_%s" % str(id)
				if tile_host.get_node_or_null(node_name) != null or box.get_node_or_null(node_name) != null:
					continue
				var building_caption: String = side.building_label(id) if side != null else _pretty(str(id))
				var row: Dictionary = item
				var building_tab: String = "defenses" if str(row.get("role", "")) == "defense" else "buildings"
				_button(tile_host, node_name, building_caption, _order.bind(id), SMGuide.building_tip(row), "build_start", building_tab, int(row.get("cost", 0)))
	var super_host: Container = super_dock if use_tiles and super_dock != null else box
	if side != null and side.yard.super_name != "" and super_host.get_node_or_null("Super_%s" % str(side.yard.super_id)) == null:
		var super_tip: String = "%s. Area hit, then it cools down." % side.yard.super_name
		var super_caption: String = side.yard.super_name
		_button(super_host, "Super_%s" % str(side.yard.super_id), super_caption, _super, super_tip, "ability")
	if box.get_node_or_null("CancelQueue") == null:
		_button(box, "CancelQueue", "Cancel", _cancel, "Cancel the building in progress and refund what it has spent.", "ui", "buildings", -1)
	if box.get_node_or_null("GroupUnits") == null:
		_header(box, "GroupUnits", "Units")
	for unit: Dictionary in SMCatalog.units_of(data):
		var uid: StringName = StringName(str(unit.get("id", "")))
		if str(uid) == "":
			continue
		var train_name: String = "Train_%s" % str(uid)
		if tile_host.get_node_or_null(train_name) != null:
			continue
		var unit_caption: String = str(unit.get("display_name", str(uid)))
		_button(tile_host, train_name, unit_caption, _train.bind(uid), SMGuide.unit_tip(unit), "ui", _unit_tab(unit), int(unit.get("cost", 0)))
	if box.get_node_or_null("GroupAbility") == null:
		_header(box, "GroupAbility", "Ability")
	_fill_commands(box)
	_hide_empty_tabs()
	show_build_tab(build_tab)

func _unit_tab(unit: Dictionary) -> String:
	var role: String = str(unit.get("role", ""))
	var loco: String = str(unit.get("locomotion", ""))
	if role == "air" or loco == "air" or SMCatalog.has_tag(unit, "air"):
		return "aircraft"
	if role == "boat" or role == "naval" or loco == "water" or loco == "naval" or loco == "amphibious" or SMCatalog.has_tag(unit, "naval"):
		return "naval"
	if role == "infantry" or SMCatalog.has_tag(unit, "infantry"):
		return "infantry"
	return "vehicles"

func _fill_commands(box: VBoxContainer) -> void:
	var host: Container = command_row if use_tiles and command_row != null else box
	if host.find_child("AbilityButton", true, false) != null:
		return
	var cells: Container = host
	if command_row != null and use_tiles:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "CommandCells"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		command_row.add_child(row)
		cells = row
	_command_cell(cells, "AttackMove", "A-Move", "Q", _attack_move, "Attack-move ahead of the lead unit.")
	_command_cell(cells, "StopButton", "Stop", "X", _halt, "Stop.")
	_command_cell(cells, "StanceGuard", "Guard", "", _set_stance.bind("guard"), "Guard. Fire at enemies in range.")
	_command_cell(cells, "StanceHold", "Hold", "", _set_stance.bind("hold"), "Hold. Do not acquire targets.")
	_command_cell(cells, "FormationButton", "Form", "Z", _formation, "Formation. Switch between a line and a box.")
	_command_cell(cells, "AbilityButton", "Ability (F)", "F", _ability, SMGuide.ability_tip())

func _command_cell(host: Container, node_name: String, caption: String, chip: String, fn: Callable, tip: String) -> void:
	var cue: String = "ability_cast" if node_name == "AbilityButton" else "ui"
	var button: Button = _button(host, node_name, caption, fn, tip, cue)
	button.custom_minimum_size = Vector2(56, 56)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 12)
	if chip == "":
		return
	var mark: Label = Label.new()
	mark.name = "KeyChip"
	mark.text = chip
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = Vector2(2, 1)
	mark.size = Vector2(18, 14)
	mark.add_theme_font_size_override("font_size", 11)
	mark.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	button.add_child(mark)

func _formation() -> void:
	if field == null:
		return
	var lined: bool = field.toggle_line()
	_note("line" if lined else "box")
	refresh()

func _set_stance(mode: String) -> void:
	if field != null:
		field.set_stance(mode)
	_note(mode)
	refresh()

func _attack_move() -> void:
	if field == null or field.selection.count() == 0:
		return
	var lead: RTSUnit = field.selection.units[0]
	if lead == null:
		return
	field.attack_move_at(lead.global_position + Vector3(8.0, 0.0, 0.0))
	_note("attack move")
	refresh()

func _halt() -> void:
	if field == null:
		return
	field.halt_selected()
	_note("stopped")
	refresh()

func toggle_repair_mode() -> void:
	if side == null:
		return
	side.toggle_repair()
	_note("repair" if side.repair_armed else "repair off")
	refresh()

func toggle_sell_mode() -> void:
	if side == null:
		return
	side.toggle_sell()
	_note("sell" if side.sell_armed else "sell off")
	refresh()

func show_build_tab(which: String) -> void:
	build_tab = which
	_show_tab_children(icon_grid)
	_show_tab_children(sidebar)
	if layer_node == null:
		return
	var tabs: PackedStringArray = PackedStringArray(["buildings", "defenses", "infantry", "vehicles", "aircraft", "naval"])
	for tab_name: String in tabs:
		var button: Button = layer_node.find_child("Tab%s" % tab_name.capitalize(), true, false) as Button
		if button == null:
			continue
		button.modulate = Color(1.0, 0.84, 0.4) if tab_name == which else Color(0.62, 0.66, 0.7)

func _show_tab_children(parent: Node) -> void:
	if parent == null or not use_tiles:
		return
	for child: Node in parent.get_children():
		var tab_name: String = str(child.get_meta("tab", ""))
		if tab_name == "":
			continue
		var item: CanvasItem = child as CanvasItem
		if item != null:
			var shown: bool = tab_name == build_tab
			if build_tab == "vehicles" and (tab_name == "aircraft" or tab_name == "naval"):
				shown = true
			item.visible = shown

func _hide_empty_tabs() -> void:
	if layer_node == null or not use_tiles:
		return
	var counts: Dictionary = {}
	if icon_grid != null:
		for child: Node in icon_grid.get_children():
			var tab_name: String = str(child.get_meta("tab", ""))
			if tab_name != "":
				counts[tab_name] = int(counts.get(tab_name, 0)) + 1
	var tabs: PackedStringArray = PackedStringArray(["buildings", "defenses", "infantry", "vehicles", "aircraft", "naval"])
	for tab_name: String in tabs:
		var button: Button = layer_node.find_child("Tab%s" % tab_name.capitalize(), true, false) as Button
		if button != null:
			if tab_name == "aircraft" or tab_name == "naval":
				button.visible = false
			else:
				var count: int = int(counts.get(tab_name, 0))
				if tab_name == "vehicles":
					count += int(counts.get("aircraft", 0)) + int(counts.get("naval", 0))
				button.visible = count > 0

func _super() -> void:
	if side == null or field == null:
		return
	var hit: int = side.fire_super(field)
	_note(side.yard.super_name if hit > 0 else "superweapon cooling")
	refresh()

func _order(id: StringName) -> void:
	if side == null:
		return
	if not side.repair_armed and not side.sell_armed and side.yard != null and side.yard.finished.has(id) and SMGuns.holds(id):
		var out: int = SMGuns.unload(side, id)
		if out > 0:
			_note("unloaded %d" % out)
			refresh()
			return
	if side.repair_armed and side.yard != null and side.yard.finished.has(id):
		var started: bool = side.yard.begin_repair(id)
		_note("repairing" if started else "nothing to repair")
		refresh()
		return
	if side.sell_armed and side.yard != null and side.yard.finished.has(id):
		var refund: int = side.sell_structure(id)
		_note("sold %d" % refund if refund > 0 else "cannot sell")
		refresh()
		return
	var note: String = side.order_building(id)
	if note == "built":
		note = "%s built" % side.building_label(id)
	_note(note)
	refresh()

func _sync_imports() -> void:
	if sidebar == null:
		return
	var open: bool = tech != null and tech.holds(SMTechNet.BAZAAR, SMPointer.PLAYER)
	if open and not imports_ready:
		_header(sidebar, "GroupImports", "Black Market")
		for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction("black_market")):
			var uid: StringName = StringName(str(unit.get("id", "")))
			if str(uid) == "":
				continue
			var caption: String = str(unit.get("display_name", str(uid)))
			var import_host: Container = icon_grid if use_tiles and icon_grid != null else sidebar
			_button(import_host, "Import_%s" % str(uid), caption, _import.bind(uid), SMGuide.unit_tip(unit), "ui", "buildings", int(unit.get("cost", 0)))
		imports_ready = true
	var show_imports: bool = open and (not use_tiles or build_tab == "buildings") and (not phone or phone_tab == "buildings")
	var header: Node = sidebar.get_node_or_null("GroupImports")
	if header != null:
		header.visible = show_imports and not phone
	if not imports_ready:
		return
	for child: Node in sidebar.get_children():
		if str(child.name).begins_with("Import_"):
			(child as CanvasItem).visible = show_imports
	if icon_grid == null:
		return
	for grid_child: Node in icon_grid.get_children():
		if str(grid_child.name).begins_with("Import_"):
			(grid_child as CanvasItem).visible = show_imports

func _import(id: StringName) -> void:
	if roster == null or field == null or tech == null or not tech.holds(SMTechNet.BAZAAR, SMPointer.PLAYER):
		_note("bazaar required")
		refresh()
		return
	var cost: int = 0
	var row: Dictionary = {}
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction("black_market")):
		if str(unit.get("id", "")) == str(id):
			row = unit
			cost = int(unit.get("cost", 0))
	if row.is_empty() or not roster.economy.try_spend(SMPointer.PLAYER, cost):
		_note("cannot import")
		refresh()
		return
	if SMCatalog.has_tag(row, "jet") and not _role_alive("air"):
		roster.economy.earn(SMPointer.PLAYER, cost)
		_note("need an airfield")
		refresh()
		return
	var at: Vector3 = rally + Vector3(6.0 + float(field.count_team(SMPointer.PLAYER) % 4) * 2.0, 0.0, 2.0)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, id)
	_note(field.name_of(u))
	refresh()

func _cancel() -> void:
	var note: String = ""
	if roster != null and roster.queue != null and not roster.queue.items.is_empty():
		roster.queue.cancel(roster.economy)
		note = "cancelled"
	if side != null:
		var built: String = side.cancel_order()
		if note == "":
			note = built
	_note(note if note != "" else "nothing to cancel")
	refresh()

func _train(id: StringName) -> void:
	if roster == null or field == null:
		return
	if side != null and not Power.online(side.yard):
		_note("low power")
		refresh()
		return
	var blocked: String = _train_block(id)
	if blocked != "":
		_note(blocked)
		refresh()
		return
	var done: StringName = roster.train_and_finish(id)
	if done == &"":
		_note("cannot train")
		refresh()
		return
	var at: Vector3 = rally + Vector3(6.0 + float(field.count_team(SMPointer.PLAYER) % 4) * 2.0, 0.0, 2.0)
	var u: RTSUnit = field.spawn(SMPointer.PLAYER, at, done)
	_note(field.name_of(u))
	line_voiced.emit("", "unit_ready")
	refresh()

func _train_block(id: StringName) -> String:
	var row: Dictionary = _catalog_row(id)
	if row.is_empty() or side == null:
		return ""
	var need: String = SMCatalog.producer(row)
	if need != "" and not _role_alive(need):
		if need == "tech":
			return "need a tech center"
		if need == "air":
			return "need an airfield"
		return "need a naval yard"
	if SMCatalog.has_tag(row, "hero") and _hero_count(id) >= 1:
		return "one hero"
	return ""

func _catalog_row(id: StringName) -> Dictionary:
	var lists: Array[String] = []
	if field != null and field.faction_id != "":
		lists.append(field.faction_id)
	if not lists.has("black_market"):
		lists.append("black_market")
	for faction: String in lists:
		for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(faction)):
			if str(unit.get("id", "")) == str(id):
				return unit
	return {}

func _role_alive(role: String) -> bool:
	if side == null:
		return false
	for id: StringName in side.yard.building_role:
		if str(side.yard.building_role[id]) == role and side.yard.structure_alive(id):
			return true
	return false

func _hero_count(id: StringName) -> int:
	var n: int = 0
	if field == null:
		return 0
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if u.unit_type == id and bool(u.get_meta("hero", false)):
			n += 1
	return n

func _ability() -> void:
	if on_ability.is_valid():
		on_ability.call()
	refresh()

func _selection_line() -> String:
	var base: String = "Nothing selected"
	if field != null and field.selection.count() > 0:
		var first: RTSUnit = field.selection.units[0]
		var extra: int = field.selection.count() - 1
		var ability: String = "ability"
		if first.has_meta("ability") and str(first.get_meta("ability")) != "":
			ability = str(first.get_meta("ability"))
		elif first.has_meta("secondary"):
			ability = _ability_name(str(first.get_meta("secondary")))
		base = "%s    HP %d/%d    F %s" % [field.name_of(first), int(round(first.hp)), int(round(first.max_hp)), ability]
		if extra > 0:
			base += "    +%d" % extra
	if field != null and field.group_note_t > 0.0 and field.group_note != "":
		if base == "Nothing selected":
			return field.group_note
		return "%s    %s" % [base, field.group_note]
	return base

func _faction_id() -> String:
	if roster != null and roster.faction_id != "":
		return roster.faction_id
	return SMFront.current()

func _faction_name(id: String) -> String:
	if id == "nmrf":
		return "NMRF"
	if id == "mvd":
		return "MVD"
	return "GTFC"

func _ability_name(kind: String) -> String:
	if kind == "group_toggle":
		return "group toggle"
	if kind == "smart_cast":
		return "smart-cast"
	if kind == "channeled_beam":
		return "beam"
	return "ability"

func _pretty(id: String) -> String:
	var parts: PackedStringArray = id.split("_")
	var words: PackedStringArray = PackedStringArray()
	for part: String in parts:
		if part == "":
			continue
		words.append(part.capitalize())
	return " ".join(words)

func _header(box: VBoxContainer, node_name: String, text: String) -> void:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = "Header"
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.gui_input.connect(_drag_column)
	if use_tiles:
		label.visible = false
	box.add_child(label)

func _guide(layer: CanvasLayer) -> void:
	var help: Button = Button.new()
	help.name = "HelpButton"
	help.text = "How to play (H)"
	help.visible = not use_tiles
	help.clip_text = true
	help.custom_minimum_size = Vector2(168, 44)
	help.z_index = 9
	help.add_theme_font_size_override("font_size", 15)
	_dock(help, 8.0, 40.0, 188.0, 88.0, 0.0, 0.0, 0.0, 0.0)
	help.pressed.connect(_toggle_guide)
	layer.add_child(help)
	if unit_card == null:
		var card: PanelContainer = PanelContainer.new()
		card.name = "UnitCard"
		card.visible = false
		card.z_index = 8
		card.clip_contents = true
		card.add_theme_stylebox_override("panel", _card_style())
		_dock(card, 8.0, -82.0, -268.0, -6.0, 0.0, 1.0, 1.0, 1.0)
		layer.add_child(card)
		unit_card = card
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(row)
		var portrait: TextureRect = TextureRect.new()
		portrait.name = "CardCameo"
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.visible = false
		row.add_child(portrait)
		card_cameo = portrait
		var stack: VBoxContainer = VBoxContainer.new()
		stack.add_theme_constant_override("separation", 0)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(stack)
		selection_label = _card_line(stack, "HudSelection", 16)
		build_label = _card_line(stack, "HudBuild", 14)
		build_label.visible = false
		radio_label = _card_line(stack, "RadioLine", 16)
		radio_label.visible = false
		radio_label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.55))
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "MatchStrip"
	strip.z_index = 8
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", _card_style())
	if use_tiles:
		_dock(strip, 448.0, 36.0, 760.0, 64.0, 0.0, 0.0, 0.0, 0.0)
	else:
		_dock(strip, 8.0, -46.0, -268.0, -6.0, 0.0, 1.0, 1.0, 1.0)
	layer.add_child(strip)
	match_strip = strip
	var short_line: Label = _card_line(strip, "MatchHint", 16)
	short_line.text = "H guide    P protocols"
	short_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "HowToOverlay"
	panel.clip_contents = true
	panel.z_index = 30
	panel.visible = false
	_dock(panel, 168.0, 44.0, -268.0, -56.0, 0.0, 0.0, 1.0, 1.0)
	layer.add_child(panel)
	guide_panel = panel
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	var title: Label = Label.new()
	title.name = "HowToTitle"
	title.text = "How to play"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.45))
	box.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "HowToScroll"
	scroll.visible = false
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)
	tutorial_label = Label.new()
	tutorial_label.name = "TutorialPrompt"
	tutorial_label.visible = false
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	inner.add_child(tutorial_label)
	var body: Label = Label.new()
	body.name = "HowToBody"
	body.text = SMGuide.howto_text()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	inner.add_child(body)
	var hint: Label = Label.new()
	hint.name = "ControlsHint"
	hint.text = SMGuide.controls_hint()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	inner.add_child(hint)
	_controls_card(box)
	var close: Button = Button.new()
	close.name = "HowToClose"
	close.text = "Got it"
	close.custom_minimum_size = Vector2(160, 44)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(_hide_guide)
	box.add_child(close)

func _tip(layer: CanvasLayer) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "TipPanel"
	panel.visible = false
	panel.z_index = 14
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _card_style())
	panel.custom_minimum_size = Vector2(360, 96)
	_dock(panel, -560.0, -300.0, -268.0, -184.0, 1.0, 1.0, 1.0, 1.0)
	layer.add_child(panel)
	tip_panel = panel
	var tip_row: HBoxContainer = HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 8)
	tip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(tip_row)
	var tip_portrait: TextureRect = TextureRect.new()
	tip_portrait.name = "TipCameo"
	tip_portrait.custom_minimum_size = Vector2(56, 56)
	tip_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tip_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tip_portrait.visible = false
	tip_row.add_child(tip_portrait)
	tip_cameo = tip_portrait
	var tip_stack: VBoxContainer = VBoxContainer.new()
	tip_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_stack.add_theme_constant_override("separation", 2)
	tip_row.add_child(tip_stack)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	tip_stack.add_child(name_row)
	tip_name = Label.new()
	tip_name.name = "TipName"
	tip_name.theme_type_variation = "Header"
	tip_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_name.clip_text = true
	tip_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tip_name.add_theme_font_size_override("font_size", 18)
	tip_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	name_row.add_child(tip_name)
	tip_chip = Label.new()
	tip_chip.name = "TipChip"
	tip_chip.custom_minimum_size = Vector2(28, 22)
	tip_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_chip.add_theme_font_size_override("font_size", 16)
	tip_chip.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	name_row.add_child(tip_chip)
	tip_label = Label.new()
	tip_label.name = "UnitTip"
	tip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tip_label.clip_text = true
	tip_label.max_lines_visible = 1
	tip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_label.add_theme_font_size_override("font_size", 16)
	tip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	tip_stack.add_child(tip_label)

func _toggle_guide() -> void:
	if guide_panel != null:
		guide_panel.visible = not guide_panel.visible

func _hide_guide() -> void:
	if guide_panel != null:
		guide_panel.visible = false

func guide_blocks() -> bool:
	return OS.has_feature("web") and guide_panel != null and guide_panel.visible

## The roster is taller than the column. A wheel or drag there scrolls the list.
func column_hovered() -> bool:
	if layer_node == null:
		return false
	var view: Viewport = layer_node.get_viewport()
	if view == null:
		return false
	var hovered: Control = view.gui_get_hovered_control()
	if hovered == null:
		return false
	var column: Node = layer_node.find_child("CommandColumn", true, false)
	if column != null and (hovered == column or column.is_ancestor_of(hovered)):
		return true
	if phone_drawer != null and (hovered == phone_drawer or phone_drawer.is_ancestor_of(hovered)):
		return true
	return false

## Edge pan uses the screen edge. The command column and the other panels sit there.
func blocks_edge() -> bool:
	if column_hovered():
		return true
	if layer_node == null:
		return false
	var view: Viewport = layer_node.get_viewport()
	if view == null:
		return false
	var hovered: Control = view.gui_get_hovered_control()
	if hovered == null:
		return false
	var names: PackedStringArray = PackedStringArray([
		"Protocols", "ProtocolsToggle", "Minimap", "MonitorFrame", "UnitCard",
		"HelpButton", "MissionBoot", "SelectionSlots", "PhoneDrawer", "TipPanel",
		"HowToOverlay", "SuperDock", "CommandColumn", "PauseMenu", "TopBar",
		"MessageLane", "ObjectiveShade", "HudMenu", "CoachCard", "ToastLane",
	])
	var node: Node = hovered
	while node != null and node != layer_node:
		if names.has(str(node.name)):
			return true
		node = node.get_parent()
	return false

func _drag_column(event: InputEvent) -> void:
	var scroll: ScrollContainer = _column_scroll()
	if scroll == null:
		return
	var down: InputEventMouseButton = event as InputEventMouseButton
	if down != null and down.button_index == MOUSE_BUTTON_LEFT:
		if down.pressed:
			_swallow_press = false
			_column_drag = 0.0
			_column_dragging = false
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_swallow_press = false
			_column_drag = 0.0
			_column_dragging = false
		return
	var rel_y: float = 0.0
	var screen: InputEventScreenDrag = event as InputEventScreenDrag
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if screen != null:
		rel_y = screen.relative.y
	elif motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		rel_y = motion.relative.y
	else:
		return
	_column_drag += rel_y
	if not _column_dragging and absf(_column_drag) < 12.0:
		return
	_column_dragging = true
	_swallow_press = true
	scroll.scroll_vertical -= int(rel_y)
	if layer_node != null and layer_node.get_viewport() != null:
		layer_node.get_viewport().set_input_as_handled()

func _column_scroll() -> ScrollContainer:
	if sidebar == null:
		return null
	var parent: Node = sidebar.get_parent()
	if parent is ScrollContainer:
		return parent as ScrollContainer
	if parent == null:
		return null
	return parent.get_parent() as ScrollContainer

func _enter_from(b: Button) -> void:
	var chip: String = ""
	var mark: Label = b.find_child("CameoKey", true, false) as Label
	if mark == null:
		mark = b.find_child("KeyChip", true, false) as Label
	if mark != null:
		chip = mark.text
	hover_key = chip
	hover_facts = _facts_for(b)
	_enter_tip(str(b.get_meta("tip", "")), str(b.get_meta("cameo_id", "")))

func _facts_for(b: Button) -> String:
	var id: String = str(b.get_meta("prod_id", ""))
	var kind: String = str(b.get_meta("prod_kind", ""))
	var cost: int = int(b.get_meta("cost", -1))
	var secs: int = -1
	var power: String = ""
	if id != "":
		var data: Dictionary = SMCatalog.faction(_faction_id())
		var raw: Variant = data.get("buildings" if kind == "building" else "units", [])
		if raw is Array:
			for item: Variant in raw:
				if item is Dictionary and str(item.get("id", "")) == id:
					secs = int(item.get("time", -1))
					var role: String = str(item.get("role", ""))
					if role == "power":
						power = "⚡ +100"
					elif role == "barracks" or role == "factory" or role == "naval":
						power = "⚡ 30"
					break
	var bits: String = ""
	if cost >= 0:
		bits = "%d cr" % cost
	if secs >= 0:
		bits += "  %ds" % secs
	if power != "":
		bits += "  " + power
	return bits.strip_edges()

func _enter_tip(text: String, cameo_id: String = "") -> void:
	hover_tip = text
	hover_cameo = cameo_id
	tip_at = Time.get_ticks_msec()
	_paint_tip()

func _exit_tip() -> void:
	hover_tip = ""
	hover_cameo = ""
	hover_key = ""
	hover_facts = ""
	_paint_tip()

func _paint_tip() -> void:
	if tip_label == null or tip_panel == null:
		return
	var head: String = hover_tip
	var body: String = hover_tip
	var cut: int = hover_tip.find(".")
	if cut > 0:
		head = hover_tip.substr(0, cut)
		body = hover_tip.substr(cut + 1).strip_edges()
	if body == "" or (hover_tip.contains("Slag Molotov") and not body.contains("Slag Molotov")):
		body = hover_tip
	if hover_facts != "":
		body = "%s  %s" % [hover_facts, body]
	tip_label.text = body
	tip_label.max_lines_visible = 1
	if tip_name != null:
		tip_name.text = head
	if tip_chip != null:
		tip_chip.text = hover_key
		tip_chip.visible = hover_key != ""
	tip_panel.visible = false
	if tip_cameo == null:
		return
	var portrait: Texture2D = _cameo_texture(_faction_id(), hover_cameo)
	tip_cameo.texture = portrait
	tip_cameo.visible = portrait != null

func _controls_card(box: VBoxContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ControlsCard"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid: VBoxContainer = VBoxContainer.new()
	grid.name = "ControlsGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 4)
	scroll.add_child(grid)
	var rows: PackedStringArray = PackedStringArray([
		"Drag a box    Select",
		"Right-click    Move",
		"Right-click enemy    Attack",
		"Q    Attack-move",
		"X    Stop",
		"Z    Formation",
		"F    Ability",
		"H    Controls",
		"P    Protocols",
		"Tab    Next tab",
		"Space    Last alert",
		"Esc    Pause",
	])
	for row_text: String in rows:
		var line: Label = Label.new()
		line.text = row_text
		line.clip_text = true
		line.add_theme_font_size_override("font_size", 16)
		line.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		grid.add_child(line)

func _button(box: Container, node_name: String, text: String, fn: Callable, tip: String, cue: String, tab_name: String = "", cost: int = -1) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	var shown: String = tip
	if cost >= 0:
		shown += "\nCost %d" % cost
	var hotkey: int = box.get_child_count() + 1
	if tab_name != "" and hotkey <= 9:
		shown += "\nHotkey %d" % hotkey
	b.text = text
	b.tooltip_text = ""
	b.set_meta("tip", shown)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 48 if phone else 40)
	b.add_theme_font_size_override("font_size", 16 if phone else 14)
	b.set_meta("caption", text)
	b.set_meta("cameo_id", _cameo_id(node_name))
	if tab_name != "":
		b.set_meta("tab", tab_name)
	if cost >= 0:
		b.set_meta("cost", cost)
	if node_name.begins_with("Train_") or node_name.begins_with("Import_"):
		b.set_meta("prod_kind", "unit")
		b.set_meta("prod_id", node_name.substr(node_name.find("_") + 1))
	elif node_name.begins_with("Build_") or node_name == "MovePacker":
		b.set_meta("prod_kind", "building")
		b.set_meta("prod_id", "packer" if node_name == "MovePacker" else node_name.substr(node_name.find("_") + 1))
	b.mouse_entered.connect(_enter_from.bind(b))
	b.mouse_exited.connect(_exit_tip)
	b.gui_input.connect(_drag_column)
	b.pressed.connect(_press_cue.bind(fn, cue))
	var badge: Label = Label.new()
	badge.name = "QueueBadge"
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.98, 0.9, 0.45))
	b.add_child(badge)
	if node_name.begins_with("Super_"):
		var clock: Label = Label.new()
		clock.name = "SuperClock"
		clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock.add_theme_font_size_override("font_size", 12)
		b.add_child(clock)
	box.add_child(b)
	b.set_meta("slot", b.get_index())
	_paint_button(b)
	return b

func apply_cameos() -> void:
	if phone:
		_apply_phone_tab()
	_paint_roster_buttons(sidebar)
	_paint_roster_buttons(icon_grid)
	_paint_card()
	_paint_tip()
	if paint_extra.is_valid():
		paint_extra.call(self)

func _paint_roster_buttons(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		var button: Button = child as Button
		if button != null:
			_paint_button(button)

func _paint_button(b: Button) -> void:
	if str(b.name).begins_with("Super_"):
		b.icon = null
		b.text = ""
		b.custom_minimum_size = Vector2(56, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var clock: Label = b.get_node_or_null("SuperClock") as Label
		if clock != null:
			clock.position = Vector2(0, 16)
			clock.size = Vector2(56, 22)
			clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var caption: String = str(b.get_meta("caption", b.text))
	var portrait: Texture2D = _cameo_texture(_faction_id(), str(b.get_meta("cameo_id", "")))
	var in_grid: bool = (use_tiles and icon_grid != null and b.get_parent() == icon_grid) or (use_tiles and str(b.name).begins_with("Super_"))
	if use_tiles and str(b.name).begins_with("Super_") and portrait == null:
		caption = "SW"
	if portrait != null and in_grid:
		b.icon = portrait
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 64 if phone else 72)
		b.add_theme_constant_override("h_separation", 4)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.text = ""
		b.custom_minimum_size = Vector2(72, 72)
		_cameo_corners(b, caption)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		_tint_roster_button(b)
		return
	if portrait != null:
		b.icon = portrait
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 34)
		b.add_theme_constant_override("h_separation", 8)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = caption
		b.custom_minimum_size = Vector2(0, 44)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_theme_font_size_override("font_size", 14)
		_tint_roster_button(b)
		return
	b.icon = null
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 0)
	b.text = caption
	if in_grid:
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 72 if phone else 52)
		b.add_theme_font_size_override("font_size", 11)
		_tint_roster_button(b)
		return
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if phone else HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if phone else TextServer.AUTOWRAP_OFF
	b.custom_minimum_size = Vector2(0, 72) if phone else Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 12 if phone else 14)
	_tint_roster_button(b)

func _cameo_corners(b: Button, caption: String) -> void:
	var name_line: Label = _corner_label(b, "CameoName", Vector2(2, 56), Vector2(68, 14), 12)
	name_line.text = caption
	name_line.clip_text = true
	var cost: int = int(b.get_meta("cost", -1))
	var cost_line: Label = _corner_label(b, "CameoCost", Vector2(34, 1), Vector2(36, 14), 11)
	cost_line.text = str(cost) if cost >= 0 else ""
	cost_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var key_line: Label = _corner_label(b, "CameoKey", Vector2(2, 1), Vector2(16, 14), 11)
	key_line.text = _grid_key(b)

func _corner_label(b: Button, node_name: String, at: Vector2, box: Vector2, px: int) -> Label:
	var label: Label = b.get_node_or_null(node_name) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		b.add_child(label)
	label.position = at
	label.size = box
	return label

func _grid_key(b: Button) -> String:
	var keys: String = "QWERASDFZXCV"
	var parent: Node = b.get_parent()
	if parent == null:
		return ""
	var seen: int = 0
	for child: Node in parent.get_children():
		if child == b:
			break
		var item: CanvasItem = child as CanvasItem
		if item != null and item.visible:
			seen += 1
	if seen < 0 or seen >= keys.length():
		return ""
	return keys.substr(seen, 1)

func _tint_roster_button(b: Button) -> void:
	var cost: int = int(b.get_meta("cost", -1))
	var purse: int = 0
	if roster != null and roster.economy != null:
		purse = roster.economy.credits(0)
	var locked: bool = false
	if str(b.get_meta("prod_kind", "")) == "unit":
		locked = _train_block(StringName(str(b.get_meta("prod_id", "")))) != ""
	var poor: bool = cost >= 0 and purse < cost
	var pair: Vector2i = Power.tally(side.yard if side != null else null)
	var prod: String = str(b.get_meta("prod_id", ""))
	var feeds: bool = prod.contains("hydro") or prod.contains("plant") or prod.contains("reactor") or prod.contains("generator") or prod.contains("power")
	var unpowered: bool = pair.x < pair.y and str(b.get_meta("prod_kind", "")) == "building" and not feeds
	b.modulate = Color(0.45, 0.47, 0.5) if locked or poor or unpowered else Color(1, 1, 1)
	b.modulate.a = 1.0

func _cameo_id(node_name: String) -> String:
	if node_name == "MovePacker":
		return "packer"
	if node_name.begins_with("Train_") or node_name.begins_with("Build_") or node_name.begins_with("Import_") or node_name.begins_with("Super_"):
		return node_name.substr(node_name.find("_") + 1)
	return ""

func _cameo_texture(faction: String, id: String) -> Texture2D:
	if id == "" or not cameo_for.is_valid():
		return null
	var got: Variant = cameo_for.call(faction, id)
	if got is Texture2D:
		return got as Texture2D
	return null

func _paint_card() -> void:
	if card_cameo == null:
		return
	var id: String = ""
	if field != null and field.selection.count() > 0:
		var first: RTSUnit = field.selection.units[0]
		if first != null:
			id = str(first.unit_type)
			if id == "raider" or id == "wave" or id == "":
				var role: String = str(first.get_meta("role", "infantry"))
				var loco: String = str(first.get_meta("locomotion", "ground"))
				id = _fallback_cameo(role, loco, _faction_id())
	var portrait: Texture2D = _cameo_texture(_faction_id(), id)
	card_cameo.texture = portrait
	card_cameo.visible = portrait != null
	_paint_card_stats()

func _fallback_cameo(role: String, loco: String, faction: String) -> String:
	if faction == "mvd":
		if role == "armor":
			return "cyan_ifv"
		if role == "artillery":
			return "charcoal_mortar"
		if role == "boat" or role == "amphibious" or loco == "naval":
			return "cyan_skiff"
		if role == "air" or role == "drone" or loco == "air":
			return "hub_drone"
		return "clearance_trooper"
	if faction == "nmrf":
		if role == "armor":
			return "mangrove_skiff"
		if role == "artillery":
			return "mangrove_tube"
		if role == "boat" or role == "amphibious" or loco == "naval":
			return "emerald_gunboat"
		if role == "air" or role == "drone" or loco == "air":
			return "jade_skiff"
		return "river_rifle"
	if role == "armor":
		return "amber_tank"
	if role == "artillery":
		return "monsoon_tube"
	if role == "boat" or role == "amphibious" or loco == "naval":
		return "channel_skiff"
	if role == "air" or role == "drone" or loco == "air":
		return "bullion_truck"
	return "militia"

func _paint_card_stats() -> void:
	var selected: int = 0
	var first: RTSUnit = null
	if field != null:
		selected = field.selection.count()
		if selected > 0:
			first = field.selection.units[0]
	if health_fill != null:
		var ratio: float = 0.0
		if first != null and first.max_hp > 0.0:
			ratio = clampf(first.hp / first.max_hp, 0.0, 1.0)
		health_fill.offset_right = 140.0 * ratio
		health_fill.visible = first != null
	if veteran_label != null:
		var rank: String = ""
		if selected == 1 and first != null:
			var kills: int = int(first.get_meta("kills", 0))
			rank = "Elite" if kills >= 5 else ("Veteran" if kills >= 2 else "Recruit")
		veteran_label.text = rank
		veteran_label.visible = rank != ""
	if breakdown_label != null:
		breakdown_label.text = _breakdown()
		breakdown_label.visible = breakdown_label.text != ""

func _breakdown() -> String:
	if field == null or field.selection.count() <= 1:
		return ""
	var counts: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for unit: RTSUnit in field.selection.units:
		if unit == null:
			continue
		var label: String = field.name_of(unit)
		if not counts.has(label):
			order.append(label)
		counts[label] = int(counts.get(label, 0)) + 1
	var parts: PackedStringArray = PackedStringArray()
	for label: String in order:
		parts.append("%s x%d" % [label, int(counts[label])])
	return ", ".join(parts)

func _use_icon_grid(on: bool) -> void:
	if use_tiles or sidebar == null or icon_grid == null:
		return
	if on:
		var taken: Array[Button] = []
		for child: Node in sidebar.get_children():
			var button: Button = child as Button
			if button != null and _cameo_texture(_faction_id(), str(button.get_meta("cameo_id", ""))) != null:
				taken.append(button)
		for taken_button: Button in taken:
			taken_button.reparent(icon_grid)
			_paint_button(taken_button)
		icon_grid.visible = icon_grid.get_child_count() > 0
		return
	var back: Array[Button] = []
	for child: Node in icon_grid.get_children():
		var grid_button: Button = child as Button
		if grid_button != null:
			back.append(grid_button)
	for grid_button: Button in back:
		grid_button.reparent(sidebar)
		var slot: int = int(grid_button.get_meta("slot", sidebar.get_child_count() - 1))
		if slot < 0:
			slot = 0
		if slot >= sidebar.get_child_count():
			slot = sidebar.get_child_count() - 1
		sidebar.move_child(grid_button, slot)
		_paint_button(grid_button)
	icon_grid.visible = false

func _press_cue(fn: Callable, cue: String) -> void:
	if _swallow_press:
		_swallow_press = false
		_column_dragging = false
		_column_drag = 0.0
		return
	if sfx != null:
		sfx.play(cue)
	if fn.is_valid():
		fn.call()

func _label(parent: Node, node_name: String, pos: Vector2, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _flow_label(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _card_line(parent: Node, node_name: String, size: int) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.clip_text = true
	label.custom_minimum_size = Vector2(0, 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96))
	parent.add_child(label)
	return label

func _card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.92)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _note(text: String) -> void:
	if build_label == null:
		return
	build_label.text = text
	build_label.visible = text != ""
	_sync_card()
	line_voiced.emit(text, "")

func _sync_card() -> void:
	var busy: bool = false
	if selection_label != null:
		var chosen: bool = selection_label.text != "" and selection_label.text != "Nothing selected"
		selection_label.visible = chosen
		if chosen:
			busy = true
	if build_label != null and build_label.visible and build_label.text != "":
		busy = true
	if unit_card != null:
		unit_card.visible = busy
	if match_strip != null:
		match_strip.visible = not busy and not phone

func _dock(node: Control, left: float, top: float, right: float, bottom: float, anchor_l: float, anchor_t: float, anchor_r: float, anchor_b: float) -> void:
	node.anchor_left = anchor_l
	node.anchor_top = anchor_t
	node.anchor_right = anchor_r
	node.anchor_bottom = anchor_b
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

## Portrait only. Landscape and desktop keep the right-hand column.
func layout_for(size: Vector2) -> void:
	if layer_node == null:
		return
	var want: bool = size.y > size.x + 4.0
	var key: Vector2i = Vector2i(int(round(size.x)), int(round(size.y)))
	if want == phone and key == _layout_key:
		_paint_mission_fold()
		return
	var was: bool = phone or phone_drawer != null
	if was:
		_leave_phone()
	phone = want
	_layout_key = key
	if phone:
		_enter_phone(size)
	_shown_credits = -999999
	_shown_power = Vector2i(-1, -1)
	_shown_faction = ""
	_shown_map = ""
	_shown_weather = ""
	refresh()

func _enter_phone(size: Vector2) -> void:
	phone_sheet = clampf(size.y * 0.38, 240.0, 380.0)
	drawer_open = false
	mission_open = false
	if icon_grid != null:
		var cols: int = int((size.x - 24.0) / 64.0)
		if cols < 3:
			cols = 3
		if cols > 6:
			cols = 6
		icon_grid.columns = cols
	_compact_top()
	_build_drawer(size)
	_build_mission(size)
	_build_hint(size)
	_place_phone_chrome(size)
	_apply_phone_tab()

func _leave_phone() -> void:
	_use_icon_grid(false)
	var names: PackedStringArray = PackedStringArray([
		"CommandColumn", "ColumnShade", "Protocols", "ProtocolsToggle", "HelpButton",
		"Minimap", "TopBar", "UnitCard", "MatchStrip", "HowToOverlay", "TipPanel",
		"Briefing", "Status", "MissionBoot", "MissionHeading", "ObjectiveButton", "HowToClose",
	])
	for node_name: String in names:
		var node: Control = _phone_node(node_name)
		_restore(node)
	if sidebar != null:
		for child: Node in sidebar.get_children():
			_restore(child as Control)
	var grid: Node = _protocol_grid()
	if grid != null:
		for child: Node in grid.get_children():
			_restore(child as Control)
	if weather_label != null:
		weather_label.visible = true
	if faction_label != null:
		_restore(faction_label)
	if credits_label != null:
		_restore(credits_label)
	if power_label != null:
		_restore(power_label)
	if map_label != null:
		_restore(map_label)
	if weather_label != null:
		_restore(weather_label)
	var row: Control = _top_row()
	_restore(row)
	_free_phone(phone_drawer)
	_free_phone(mission_fold)
	_free_phone(mission_panel)
	_free_phone(rotate_banner)
	var guide: Node = _phone_node("PhoneGuide")
	_free_phone(guide as Control)
	phone_drawer = null
	phone_body = null
	mission_fold = null
	mission_panel = null
	rotate_banner = null
	phone = false
	if use_tiles:
		var help_btn: CanvasItem = _phone_node("HelpButton")
		if help_btn != null:
			help_btn.visible = false
	if use_tiles and icon_grid != null:
		icon_grid.columns = 3
	var supers: CanvasItem = _phone_node("SuperDock")
	if supers != null:
		supers.visible = true
	show_build_tab(build_tab)
	_paint_roster_buttons(sidebar)
	_paint_roster_buttons(icon_grid)

func _compact_top() -> void:
	var top: Control = _phone_node("TopBar")
	_snap(top)
	if top != null:
		top.offset_bottom = 32.0
	var row: Control = _top_row()
	_snap(row)
	if row != null:
		row.offset_top = 2.0
		row.offset_bottom = -2.0
	_phone_font(faction_label, 14)
	_phone_font(credits_label, 14)
	_phone_font(power_label, 14)
	_phone_font(map_label, 14)
	if weather_label != null:
		_snap(weather_label)
		weather_label.visible = false

func _build_drawer(size: Vector2) -> void:
	var drawer: PanelContainer = PanelContainer.new()
	drawer.name = "PhoneDrawer"
	drawer.z_index = 20
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.add_theme_stylebox_override("panel", _tab_style())
	_dock(drawer, 0.0, -68.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
	layer_node.add_child(drawer)
	phone_drawer = drawer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "PhoneStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	drawer.add_child(stack)
	var body: Control = Control.new()
	body.name = "PhoneBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.visible = false
	stack.add_child(body)
	phone_body = body
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "PhoneTabs"
	tabs.custom_minimum_size = Vector2(0, 56)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 6)
	stack.add_child(tabs)
	_tab_button(tabs, "PhoneTabBuildings", "Buildings", "buildings")
	_tab_button(tabs, "PhoneTabUnits", "Units", "units")
	_tab_button(tabs, "PhoneTabProtocols", "Protocols", "protocols")
	var column: Control = _phone_node("CommandColumn")
	_snap(column)
	if column != null:
		column.reparent(body, false)
		_dock(column, 6.0, 6.0, -6.0, -6.0, 0.0, 0.0, 1.0, 1.0)
	var shade: Control = _phone_node("ColumnShade")
	_snap(shade)
	if shade != null:
		shade.visible = false
	if sidebar != null:
		for child: Node in sidebar.get_children():
			var control: Control = child as Control
			if control == null:
				continue
			_snap(control)
			var wide: Button = child as Button
			if wide == null:
				continue
			wide.custom_minimum_size = Vector2(0, 48)
			wide.add_theme_font_size_override("font_size", 16)
	var protocols: Control = _phone_node("Protocols")
	_snap(protocols)
	if protocols != null:
		protocols.reparent(body, false)
		_dock(protocols, 6.0, 6.0, -6.0, -6.0, 0.0, 0.0, 1.0, 1.0)
		protocols.visible = false
	var grid: Node = _protocol_grid()
	if grid != null:
		for child: Node in grid.get_children():
			var proto: Button = child as Button
			if proto == null:
				continue
			_snap(proto)
			proto.custom_minimum_size = Vector2(148, 48)
			proto.add_theme_font_size_override("font_size", 15)
	var toggle: Control = _phone_node("ProtocolsToggle")
	_snap(toggle)
	if toggle != null:
		toggle.visible = false
	var help: Control = _phone_node("HelpButton")
	_snap(help)
	if help != null:
		help.visible = false

func _build_mission(size: Vector2) -> void:
	var fold: Button = Button.new()
	fold.name = "MissionFold"
	fold.clip_text = true
	fold.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fold.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fold.custom_minimum_size = Vector2(0, 48)
	fold.add_theme_font_size_override("font_size", 15)
	fold.z_index = 16
	fold.pressed.connect(_toggle_mission)
	_dock(fold, 8.0, 36.0, -78.0, 84.0, 0.0, 0.0, 1.0, 0.0)
	layer_node.add_child(fold)
	mission_fold = fold
	var guide: Button = Button.new()
	guide.name = "PhoneGuide"
	guide.text = "Guide"
	guide.custom_minimum_size = Vector2(64, 48)
	guide.add_theme_font_size_override("font_size", 15)
	guide.z_index = 16
	guide.pressed.connect(_toggle_guide)
	_dock(guide, -72.0, 36.0, -8.0, 84.0, 1.0, 0.0, 1.0, 0.0)
	layer_node.add_child(guide)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "MissionPanel"
	panel.visible = false
	panel.z_index = 17
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _sheet_style())
	_dock(panel, 8.0, 88.0, -8.0, 360.0, 0.0, 0.0, 1.0, 0.0)
	layer_node.add_child(panel)
	mission_panel = panel
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_adopt_mission(box, "MissionHeading")
	_adopt_mission(box, "Briefing")
	_adopt_mission(box, "Status")
	_adopt_mission(box, "MissionBoot")
	var boot: Button = _phone_node("MissionBoot") as Button
	if boot != null:
		boot.custom_minimum_size = Vector2(160, 48)
	var overlay: Control = _phone_node("HowToOverlay")
	_snap(overlay)
	if overlay != null:
		_dock(overlay, 12.0, 40.0, -12.0, -64.0, 0.0, 0.0, 1.0, 1.0)
	var close: Button = layer_node.find_child("HowToClose", true, false) as Button
	if close != null:
		_snap(close)
		close.custom_minimum_size = Vector2(160, 48)

func _build_hint(size: Vector2) -> void:
	if hint_closed:
		return
	var banner: PanelContainer = PanelContainer.new()
	banner.name = "RotateHint"
	banner.z_index = 18
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.add_theme_stylebox_override("panel", _hint_style())
	_dock(banner, 8.0, 86.0, -8.0, 158.0, 0.0, 0.0, 1.0, 0.0)
	layer_node.add_child(banner)
	rotate_banner = banner
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	banner.add_child(row)
	var label: Label = Label.new()
	label.name = "RotateHintText"
	label.text = "Rotate to landscape for the best experience"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.custom_minimum_size = Vector2(180, 48)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	row.add_child(label)
	var dismiss: Button = Button.new()
	dismiss.name = "RotateHintDismiss"
	dismiss.text = "OK"
	dismiss.custom_minimum_size = Vector2(64, 48)
	dismiss.add_theme_font_size_override("font_size", 16)
	dismiss.pressed.connect(_dismiss_hint)
	row.add_child(dismiss)

func _place_phone_chrome(size: Vector2) -> void:
	if not use_tiles:
		var map: Control = _phone_node("Minimap")
		_snap(map)
		if map != null:
			map.position = Vector2(8, 166)
			map.size = Vector2(108, 72)
			map.custom_minimum_size = Vector2(108, 72)
	var supers: CanvasItem = _phone_node("SuperDock")
	if supers != null:
		supers.visible = false
	var card: Control = _phone_node("UnitCard")
	_snap(card)
	var strip: Control = _phone_node("MatchStrip")
	_snap(strip)
	_seat_cards(size)
	var tip: Control = _phone_node("TipPanel")
	_snap(tip)
	if tip != null:
		_dock(tip, 8.0, -168.0, -8.0, -60.0, 0.0, 1.0, 1.0, 1.0)

func _seat_cards(size: Vector2) -> void:
	var sheet: float = phone_sheet if drawer_open else 68.0
	var card: Control = _phone_node("UnitCard")
	if card != null:
		_dock(card, 124.0, -(sheet + 78.0), -8.0, -(sheet + 6.0), 0.0, 1.0, 1.0, 1.0)
	var strip: Control = _phone_node("MatchStrip")
	if strip != null:
		_dock(strip, 124.0, -(sheet + 40.0), -8.0, -(sheet + 6.0), 0.0, 1.0, 1.0, 1.0)

func _tab_button(row: HBoxContainer, node_name: String, caption: String, which: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = caption
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_show_phone_tab.bind(which))
	row.add_child(button)

func _show_phone_tab(which: String) -> void:
	if drawer_open and phone_tab == which:
		drawer_open = false
	else:
		phone_tab = which
		drawer_open = true
		if use_tiles and which == "units":
			build_tab = "infantry"
		elif use_tiles and which == "buildings" and (build_tab == "infantry" or build_tab == "vehicles" or build_tab == "aircraft" or build_tab == "naval"):
			build_tab = "buildings"
	_apply_phone_tab()
	if layer_node != null:
		_seat_cards(layer_node.get_viewport().get_visible_rect().size)

func _apply_phone_tab() -> void:
	if phone_drawer != null:
		var sheet: float = phone_sheet if drawer_open else 68.0
		phone_drawer.offset_top = -sheet
	if phone_body != null:
		phone_body.visible = drawer_open
	var column: CanvasItem = _phone_node("CommandColumn")
	var protocols: CanvasItem = _phone_node("Protocols")
	var show_proto: bool = phone_tab == "protocols"
	if protocols != null:
		protocols.visible = drawer_open and show_proto
	if column != null:
		column.visible = drawer_open and not show_proto
	if use_tiles:
		show_build_tab(build_tab)
		_sync_imports()
		_paint_roster_buttons(sidebar)
		_paint_roster_buttons(icon_grid)
		return
	if sidebar == null:
		return
	for child: Node in sidebar.get_children():
		var item: CanvasItem = child as CanvasItem
		if item == null:
			continue
		item.visible = _phone_shows(str(child.name))
	if icon_grid != null:
		for grid_child: Node in icon_grid.get_children():
			var grid_item: CanvasItem = grid_child as CanvasItem
			if grid_item == null:
				continue
			grid_item.visible = _phone_shows(str(grid_child.name))
	_sync_imports()
	_use_icon_grid(true)
	_paint_roster_buttons(sidebar)

func _phone_shows(node_name: String) -> bool:
	if node_name == "HudTitle" or node_name.begins_with("Group"):
		return false
	if phone_tab == "units":
		return node_name.begins_with("Train_") or node_name == "AbilityButton"
	if phone_tab == "buildings":
		if node_name == "CancelQueue" or node_name == "MovePacker":
			return true
		if node_name.begins_with("Build_") or node_name.begins_with("Super_") or node_name.begins_with("Import_"):
			return true
	return false

func _toggle_mission() -> void:
	mission_open = not mission_open
	if mission_panel != null:
		mission_panel.visible = mission_open
	if rotate_banner != null:
		rotate_banner.visible = not mission_open and not hint_closed
	var map: CanvasItem = _phone_node("Minimap")
	if map != null:
		map.visible = not mission_open
	_paint_mission_fold()

func _dismiss_hint() -> void:
	hint_closed = true
	if rotate_banner != null:
		rotate_banner.visible = false

func _paint_mission_fold() -> void:
	if mission_fold == null:
		return
	if mission_open:
		mission_fold.text = "Hide mission"
		return
	var line: String = "Mission"
	var status: Label = _phone_node("Status") as Label
	if status != null and status.text != "":
		line = status.text
	mission_fold.text = line

func _adopt_mission(box: VBoxContainer, node_name: String) -> void:
	var node: Control = _phone_node(node_name)
	if node == null:
		return
	_snap(node)
	node.reparent(box, false)
	node.position = Vector2.ZERO
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2(0, 44)
	var line: Label = node as Label
	if line != null:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.clip_text = false
	var tap: Button = node as Button
	if tap != null:
		tap.clip_text = false

func _phone_font(label: Label, size: int) -> void:
	if label == null:
		return
	_snap(label)
	label.add_theme_font_size_override("font_size", size)

func _phone_node(node_name: String) -> Control:
	if layer_node == null:
		return null
	return layer_node.find_child(node_name, true, false) as Control

func _protocol_grid() -> Node:
	var protocols: Node = _phone_node("Protocols")
	if protocols == null or protocols.get_child_count() == 0:
		return null
	return protocols.get_child(0)

func _top_row() -> Control:
	var top: Node = _phone_node("TopBar")
	if top == null:
		return null
	for child: Node in top.get_children():
		if child is HBoxContainer:
			return child as Control
	return null

func _tab_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _sheet_style()
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _hint_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _sheet_style()
	style.bg_color = Color(0.14, 0.16, 0.2, 0.96)
	style.border_color = Color(0.86, 0.72, 0.36)
	style.set_border_width_all(1)
	return style

func _sheet_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _snap(node: Control) -> void:
	if node == null or node.has_meta("desk_snap"):
		return
	var font: int = -1
	if node.has_theme_font_size_override("font_size"):
		font = node.get_theme_font_size("font_size")
	node.set_meta("desk_snap", {
		"parent": node.get_parent(),
		"pos": node.position,
		"size": node.size,
		"min": node.custom_minimum_size,
		"al": node.anchor_left,
		"at": node.anchor_top,
		"ar": node.anchor_right,
		"ab": node.anchor_bottom,
		"ol": node.offset_left,
		"ot": node.offset_top,
		"right": node.offset_right,
		"ob": node.offset_bottom,
		"vis": node.visible,
		"font": font,
	})

func _restore(node: Control) -> void:
	if node == null or not is_instance_valid(node) or not node.has_meta("desk_snap"):
		return
	var snap: Dictionary = node.get_meta("desk_snap")
	var parent: Node = snap.get("parent") as Node
	if parent != null and is_instance_valid(parent) and node.get_parent() != parent:
		node.reparent(parent, false)
	node.anchor_left = float(snap.get("al", 0.0))
	node.anchor_top = float(snap.get("at", 0.0))
	node.anchor_right = float(snap.get("ar", 0.0))
	node.anchor_bottom = float(snap.get("ab", 0.0))
	node.offset_left = float(snap.get("ol", 0.0))
	node.offset_top = float(snap.get("ot", 0.0))
	node.offset_right = float(snap.get("right", 0.0))
	node.offset_bottom = float(snap.get("ob", 0.0))
	var anchored: bool = absf(node.anchor_right - node.anchor_left) > 0.001 or absf(node.anchor_bottom - node.anchor_top) > 0.001
	if not anchored:
		node.position = snap.get("pos", Vector2.ZERO) as Vector2
		node.size = snap.get("size", node.size) as Vector2
	node.custom_minimum_size = snap.get("min", Vector2.ZERO) as Vector2
	node.visible = bool(snap.get("vis", true))
	var font: int = int(snap.get("font", -1))
	if font > 0:
		node.add_theme_font_size_override("font_size", font)

func _free_phone(node: Control) -> void:
	if node != null and is_instance_valid(node):
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.queue_free()
