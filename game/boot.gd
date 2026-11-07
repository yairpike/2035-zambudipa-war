extends Control
## Text menu. Campaign opens GTFC, NMRF, and MVD under the item, then the mission list.

const Plate = preload("res://game/menu_plate.gd")
const Backdrop = preload("res://game/menu_backdrop.gd")
const Lan = preload("res://game/lan_link.gd")
const Marks = preload("res://game/faction_mark.gd")
const Glass = preload("res://game/glass.gd")
const VERSION: String = "v0.9.0"

var selected_map: String = ""
var play_button: Button
var playing_label: Label
var skirmish_panel: Control
var campaign_panel: Control
var faction_panel: Control
var faction_submenu: Control
var backdrop: Control
var multi_note: Label
var lan_panel: Control
var paste_panel: Control
var map_cards: Array[Button] = []
var faction_cards: Array[Button] = []
var tab_buttons: Array[Button] = []
var act_lists: Dictionary[String, Control] = {}
var _pad_cool: float = 0.0
var _save_polled: bool = false
var _faction_i: int = 0
var _menu_tab: String = "main"
var _bot_i: int = 0
var _detail_mission: String = ""
var _hover_map: String = ""
var _now_seen: String = ""
var _now_left: float = 0.0
var _previews: Dictionary = {}
static var _training_seen: bool = false

func _ready() -> void:
	preload("res://game/font_faces.gd").pin()
	backdrop = Backdrop.new() as Control
	backdrop.name = "MenuBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var rail := ColorRect.new()
	rail.name = "MenuRail"
	rail.color = Color(0.02, 0.024, 0.034, 0.88)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Glass.live():
		rail.color = Color(0, 0, 0, 1)
		rail.material = Glass.material(Color(0.03, 0.035, 0.05, 0.6))
	add_child(rail)
	var dim := ColorRect.new()
	dim.name = "MenuDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.14 if Glass.live() else 0.46)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.visible = false
	add_child(dim)
	if DisplayServer.get_name() != "headless":
		var blur := ColorRect.new()
		blur.name = "MenuBlur"
		blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blur.visible = false
		blur.color = Color(0, 0, 0, 1)
		blur.material = Glass.material(Color(0.03, 0.04, 0.06, 0.4))
		add_child(blur)
		move_child(blur, backdrop.get_index() + 1)
	var title: Label = Label.new()
	title.name = "GameTitle"
	title.text = "ASEAN 2031"
	title.position = Vector2(48, 16)
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)
	var wordmark_tex: Texture2D = load("res://brand/wordmark-vanguard-1024.png") as Texture2D
	if wordmark_tex != null:
		var wordmark := TextureRect.new()
		wordmark.name = "TitleWordmark"
		wordmark.texture = wordmark_tex
		wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wordmark)
		title.self_modulate.a = 0.0
	var rule: ColorRect = ColorRect.new()
	rule.name = "TitleRule"
	rule.color = Color(1, 1, 1, 0.9)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	var version: Label = Label.new()
	version.name = "VersionMark"
	version.text = VERSION
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version.add_theme_font_size_override("font_size", 18)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	add_child(version)
	var chip := ColorRect.new()
	chip.name = "NowPlayingChip"
	chip.color = Color(0.02, 0.024, 0.034, 0.88)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Glass.live():
		chip.color = Color(0, 0, 0, 1)
		chip.material = Glass.material(Color(0.03, 0.035, 0.05, 0.5))
	chip.visible = false
	add_child(chip)
	var now_playing: Label = Label.new()
	now_playing.name = "NowPlaying"
	now_playing.position = Vector2(320, 22)
	now_playing.size = Vector2(320, 28)
	now_playing.clip_text = true
	now_playing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	now_playing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	now_playing.visible = false
	now_playing.add_theme_font_size_override("font_size", 18)
	now_playing.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(now_playing)
	_tab("CAMPAIGN", "TabCampaign", "campaign", 48)
	faction_submenu = Control.new()
	faction_submenu.name = "FactionSubmenu"
	faction_submenu.visible = false
	faction_submenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faction_submenu)
	_tab("SKIRMISH", "TabSkirmish", "skirmish", 248)
	_tab("Side", "TabFaction", "faction", 448)
	var side: Button = find_child("TabFaction", true, false) as Button
	if side != null:
		side.visible = false
	skirmish_panel = _panel("PanelSkirmish")
	campaign_panel = _panel("PanelCampaign")
	faction_panel = _panel("PanelFaction")
	_skirmish()
	_campaign()
	_faction()
	_bar()
	_show_tab("main")
	_show_act("act_1")
	_mark_factions()
	_refresh_playing()
	_warm_shaders()
	var gear: Button = Plate.new() as Button
	gear.name = "SettingsButton"
	gear.text = "SETTINGS"
	gear.theme_type_variation = "HeaderButton"
	gear.set_meta("nav", true)
	gear.add_theme_font_size_override("font_size", 32)
	gear.pressed.connect(_toggle_settings)
	add_child(gear)
	tab_buttons.append(gear)
	var multi: Button = Plate.new() as Button
	multi.name = "TabMultiplayer"
	multi.text = "MULTIPLAYER"
	multi.theme_type_variation = "HeaderButton"
	multi.set_meta("nav", true)
	multi.add_theme_font_size_override("font_size", 32)
	multi.pressed.connect(_show_tab.bind("multi"))
	add_child(multi)
	tab_buttons.append(multi)
	var roll: Button = Plate.new() as Button
	roll.name = "CreditsButton"
	roll.text = "CREDITS"
	roll.theme_type_variation = "HeaderButton"
	roll.set_meta("nav", true)
	roll.add_theme_font_size_override("font_size", 32)
	roll.pressed.connect(_open_credits)
	add_child(roll)
	tab_buttons.append(roll)
	var quit: Button = Plate.new() as Button
	quit.name = "QuitButton"
	quit.text = "QUIT"
	quit.set_meta("nav", true)
	quit.add_theme_font_size_override("font_size", 32)
	quit.pressed.connect(_quit)
	if OS.has_feature("web"):
		quit.visible = false
	add_child(quit)
	var back: Button = Plate.new() as Button
	back.name = "MenuBack"
	back.text = "BACK"
	back.visible = false
	back.set_meta("nav", true)
	back.add_theme_font_size_override("font_size", 32)
	back.pressed.connect(_go_back)
	add_child(back)
	multi_note = Label.new()
	multi_note.name = "MultiplayerNote"
	multi_note.visible = false
	multi_note.text = Lan.lan_note(not Lan.show_controls())
	multi_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	multi_note.add_theme_font_size_override("font_size", 18)
	multi_note.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(multi_note)
	_lan_panel()
	_paste_panel()
	set_process_unhandled_input(true)
	SMSave.pull_web()
	preload("res://game/match_settings.gd").pull_web()
	preload("res://game/settings_panel.gd").attach(self)
	preload("res://game/credits_panel.gd").attach(self)
	preload("res://game/match_settings.gd").apply_scene(self)
	mark_difficulty()
	preload("res://game/match_audio.gd").arm(self, "menu")
	_loading_plate()
	preload("res://game/model_registry.gd").warm.call_deferred(self)
	_menu_fade()
	_detail_card()
	_offer_training()
	_layout_menu(_view_size())
	_paint_detail()

func _lan_panel() -> void:
	lan_panel = Control.new()
	lan_panel.name = "LanPanel"
	lan_panel.visible = false
	lan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lan_panel)
	var host: Button = Button.new()
	host.name = "HostLan"
	host.text = "Host LAN"
	host.position = Vector2(0.0, 0.0)
	host.custom_minimum_size = Vector2(160.0, 36.0)
	host.pressed.connect(_host_lan)
	lan_panel.add_child(host)
	var join: Button = Button.new()
	join.name = "JoinLan"
	join.text = "Join LAN"
	join.position = Vector2(176.0, 0.0)
	join.custom_minimum_size = Vector2(160.0, 36.0)
	join.pressed.connect(_join_lan)
	lan_panel.add_child(join)
	var addr: LineEdit = LineEdit.new()
	addr.name = "LanAddress"
	addr.text = "127.0.0.1"
	addr.placeholder_text = "127.0.0.1"
	addr.position = Vector2(0.0, 48.0)
	addr.size = Vector2(336.0, 36.0)
	lan_panel.add_child(addr)
	var status: Label = Label.new()
	status.name = "LanStatus"
	status.text = "Pick host or join."
	status.position = Vector2(0.0, 96.0)
	status.size = Vector2(420.0, 48.0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_panel.add_child(status)
	var found: ItemList = ItemList.new()
	found.name = "LanFound"
	found.position = Vector2(0.0, 148.0)
	found.size = Vector2(420.0, 96.0)
	found.item_selected.connect(_pick_lan)
	lan_panel.add_child(found)
	var lobby: Label = Label.new()
	lobby.name = "LanLobby"
	lobby.position = Vector2(0.0, 250.0)
	lobby.size = Vector2(440.0, 36.0)
	lobby.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby.text = "Pick a faction and a map, then ready up."
	lan_panel.add_child(lobby)
	_lan_choice("LanFaction_gtfc", "GTFC", Vector2(0.0, 290.0), _lan_faction.bind("gtfc"))
	_lan_choice("LanFaction_nmrf", "NMRF", Vector2(88.0, 290.0), _lan_faction.bind("nmrf"))
	_lan_choice("LanFaction_mvd", "MVD", Vector2(176.0, 290.0), _lan_faction.bind("mvd"))
	_lan_choice("LanFaction_black_market", "Market", Vector2(264.0, 290.0), _lan_faction.bind("black_market"))
	_lan_choice("LanMap_phillips_channel", "Phillips", Vector2(0.0, 330.0), _lan_map_pick.bind("res://game/phillips_channel.tscn"))
	_lan_choice("LanMap_sop_ruak", "Sop Ruak", Vector2(88.0, 330.0), _lan_map_pick.bind("res://game/sop_ruak.tscn"))
	_lan_choice("LanMap_burma_road", "Burma", Vector2(176.0, 330.0), _lan_map_pick.bind("res://game/burma_road.tscn"))
	_lan_choice("LanMap_ten_degree_atolls", "Atolls", Vector2(264.0, 330.0), _lan_map_pick.bind("res://game/ten_degree_atolls.tscn"))
	_lan_choice("LanMap_mekong_delta", "Mekong", Vector2(0.0, 368.0), _lan_map_pick.bind("res://game/mekong_delta.tscn"))
	_lan_choice("LanMap_chiang_rai", "Chiang Rai", Vector2(88.0, 368.0), _lan_map_pick.bind("res://game/chiang_rai.tscn"))
	var ready: Button = Button.new()
	ready.name = "LanReady"
	ready.text = "Ready"
	ready.position = Vector2(264.0, 368.0)
	ready.custom_minimum_size = Vector2(120.0, 32.0)
	ready.pressed.connect(_lan_ready)
	lan_panel.add_child(ready)
	var count: Label = Label.new()
	count.name = "LanCount"
	count.position = Vector2(0.0, 408.0)
	count.size = Vector2(420.0, 24.0)
	count.text = ""
	lan_panel.add_child(count)
	var chat: Label = Label.new()
	chat.name = "LanChat"
	chat.position = Vector2(0.0, 432.0)
	chat.size = Vector2(420.0, 48.0)
	chat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat.text = ""
	lan_panel.add_child(chat)
	var entry: LineEdit = LineEdit.new()
	entry.name = "LanChatLine"
	entry.placeholder_text = "Chat"
	entry.position = Vector2(0.0, 484.0)
	entry.size = Vector2(300.0, 32.0)
	lan_panel.add_child(entry)
	var send: Button = Button.new()
	send.name = "LanChatSend"
	send.text = "Send"
	send.position = Vector2(308.0, 484.0)
	send.custom_minimum_size = Vector2(80.0, 32.0)
	send.pressed.connect(_lan_say)
	lan_panel.add_child(send)

func _paste_panel() -> void:
	paste_panel = Control.new()
	paste_panel.name = "PastePanel"
	paste_panel.visible = false
	paste_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paste_panel)
	var offer: Button = Button.new()
	offer.name = "PasteOffer"
	offer.text = "Copy offer"
	offer.position = Vector2(0.0, 0.0)
	offer.custom_minimum_size = Vector2(160.0, 36.0)
	offer.disabled = true
	offer.pressed.connect(_paste_offer)
	paste_panel.add_child(offer)
	var copy: Button = Button.new()
	copy.name = "PasteCopy"
	copy.text = "Copy again"
	copy.position = Vector2(176.0, 0.0)
	copy.custom_minimum_size = Vector2(160.0, 36.0)
	copy.disabled = true
	copy.pressed.connect(_paste_copy)
	paste_panel.add_child(copy)
	var blob: TextEdit = TextEdit.new()
	blob.name = "PasteBlob"
	blob.placeholder_text = "Paste the other browser's offer or answer"
	blob.position = Vector2(0.0, 48.0)
	blob.size = Vector2(420.0, 96.0)
	blob.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	paste_panel.add_child(blob)
	var join: Button = Button.new()
	join.name = "PasteJoin"
	join.text = "Join offer"
	join.position = Vector2(0.0, 156.0)
	join.custom_minimum_size = Vector2(160.0, 36.0)
	join.pressed.connect(_paste_join)
	paste_panel.add_child(join)
	var seal: Button = Button.new()
	seal.name = "PasteSeal"
	seal.text = "Seal answer"
	seal.position = Vector2(176.0, 156.0)
	seal.custom_minimum_size = Vector2(160.0, 36.0)
	seal.pressed.connect(_paste_seal)
	paste_panel.add_child(seal)
	var status: Label = Label.new()
	status.name = "PasteStatus"
	status.text = Lan.lan_note(true)
	status.position = Vector2(0.0, 204.0)
	status.size = Vector2(420.0, 64.0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paste_panel.add_child(status)
	var lobby: Label = Label.new()
	lobby.name = "PasteLobby"
	lobby.position = Vector2(0.0, 276.0)
	lobby.size = Vector2(420.0, 36.0)
	lobby.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby.text = "Pick a faction and a map, then ready up."
	paste_panel.add_child(lobby)
	_paste_choice("PasteFaction_gtfc", "GTFC", Vector2(0.0, 316.0), _lan_faction.bind("gtfc"))
	_paste_choice("PasteFaction_nmrf", "NMRF", Vector2(88.0, 316.0), _lan_faction.bind("nmrf"))
	_paste_choice("PasteFaction_mvd", "MVD", Vector2(176.0, 316.0), _lan_faction.bind("mvd"))
	_paste_choice("PasteFaction_black_market", "Market", Vector2(264.0, 316.0), _lan_faction.bind("black_market"))
	var ready: Button = Button.new()
	ready.name = "PasteReady"
	ready.text = "Ready"
	ready.position = Vector2(0.0, 360.0)
	ready.custom_minimum_size = Vector2(120.0, 32.0)
	ready.pressed.connect(_lan_ready)
	paste_panel.add_child(ready)
	var count: Label = Label.new()
	count.name = "PasteCount"
	count.position = Vector2(136.0, 364.0)
	count.size = Vector2(280.0, 24.0)
	count.text = ""
	paste_panel.add_child(count)
	var chat: Label = Label.new()
	chat.name = "PasteChat"
	chat.position = Vector2(0.0, 400.0)
	chat.size = Vector2(420.0, 48.0)
	chat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat.text = ""
	paste_panel.add_child(chat)
	var entry: LineEdit = LineEdit.new()
	entry.name = "PasteChatLine"
	entry.placeholder_text = "Chat"
	entry.position = Vector2(0.0, 456.0)
	entry.size = Vector2(300.0, 32.0)
	paste_panel.add_child(entry)
	var send: Button = Button.new()
	send.name = "PasteChatSend"
	send.text = "Send"
	send.position = Vector2(308.0, 456.0)
	send.custom_minimum_size = Vector2(80.0, 32.0)
	send.pressed.connect(_paste_say)
	paste_panel.add_child(send)

func _paste_choice(node_name: String, caption: String, at: Vector2, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.position = at
	b.custom_minimum_size = Vector2(84.0, 32.0)
	b.clip_text = true
	b.pressed.connect(fn)
	paste_panel.add_child(b)

func _paste_blob() -> String:
	var blob: TextEdit = find_child("PasteBlob", true, false) as TextEdit
	if blob == null:
		return ""
	return blob.text.strip_edges()

func _arm_paste_offer() -> void:
	if Lan.role != "":
		_paint_paste()
		return
	var err: Error = Lan.paste_host()
	if err == OK:
		Lan.faction = SMFront.faction_id
		if selected_map != "":
			Lan.map_path = selected_map
	_paint_paste()
	_paint_lobby()

func _paste_offer() -> void:
	if Lan.paste_text() == "":
		if Lan.role == "" and not Lan.show_controls():
			_arm_paste_offer()
		else:
			_paint_paste()
		return
	_paste_copy()
	_paint_lobby()

func _paste_copy() -> void:
	var text: String = Lan.paste_text()
	if text == "":
		_paint_paste()
		return
	DisplayServer.clipboard_set(text)
	var blob: TextEdit = find_child("PasteBlob", true, false) as TextEdit
	if blob != null:
		blob.text = text
	_paint_paste()

func _paste_join() -> void:
	var err: Error = Lan.paste_join(_paste_blob())
	if err == OK:
		Lan.faction = SMFront.faction_id
	_paint_paste()
	_paint_lobby()

func _paste_seal() -> void:
	Lan.paste_seal(_paste_blob())
	_paint_paste()
	_paint_lobby()

func _paste_say() -> void:
	var entry: LineEdit = find_child("PasteChatLine", true, false) as LineEdit
	if entry == null or Lan.role == "":
		return
	Lan.seat().say(entry.text)
	entry.text = ""
	_paint_lobby()

func _paint_paste() -> void:
	var status: Label = find_child("PasteStatus", true, false) as Label
	var ready: bool = Lan.paste_text() != ""
	var offer: Button = find_child("PasteOffer", true, false) as Button
	var copy: Button = find_child("PasteCopy", true, false) as Button
	if offer != null:
		offer.disabled = not ready
	if copy != null:
		copy.disabled = not ready
	if status == null:
		return
	var note: String = Lan.paste_note()
	if note == "":
		note = Lan.lan_note(true)
	if ready:
		var kind: String = "Answer" if Lan.role == "client" else "Offer"
		note = "%s  %s is ready to copy." % [note, kind]
	status.text = note

func _paste_poll(delta: float) -> void:
	_paint_paste()
	if Lan.role == "":
		return
	Lan.pump()
	var raw: String = Lan.take()
	while raw != "":
		_lan_packet(raw)
		raw = Lan.take()
	if Lan.seat().tick_lobby(delta) == "start":
		SMFront.faction_id = Lan.faction
		_open(Lan.map_path)
		return
	_paint_lobby()

func _host_lan() -> void:
	var err: Error = Lan.open_host()
	var status: Label = find_child("LanStatus", true, false) as Label
	if status == null:
		return
	if err == OK:
		Lan.faction = SMFront.faction_id
		if selected_map != "":
			Lan.map_path = selected_map
		status.text = "Waiting on port %d." % Lan.port
	else:
		status.text = "The port is busy."

func _join_lan() -> void:
	var addr: LineEdit = find_child("LanAddress", true, false) as LineEdit
	var dest: String = "127.0.0.1"
	if addr != null and addr.text.strip_edges() != "":
		dest = addr.text.strip_edges()
	Lan.faction = SMFront.faction_id
	var err: Error = Lan.open_client(dest)
	var status: Label = find_child("LanStatus", true, false) as Label
	if status == null:
		return
	if err == OK:
		status.text = "Connecting to %s." % dest
	else:
		status.text = "Could not join."

func _lan_map() -> String:
	if selected_map != "":
		return selected_map
	return "res://game/phillips_channel.tscn"

func _pick_lan(index: int) -> void:
	var ip: String = Lan.host_address(index)
	if ip == "":
		return
	var addr: LineEdit = find_child("LanAddress", true, false) as LineEdit
	if addr != null:
		addr.text = ip
	var status: Label = find_child("LanStatus", true, false) as Label
	if status != null:
		status.text = "Found %s." % ip

func _fill_lan() -> void:
	var found: ItemList = find_child("LanFound", true, false) as ItemList
	if found == null:
		return
	var rows: PackedStringArray = Lan.hosts()
	var same: bool = found.item_count == rows.size()
	if same:
		for i: int in rows.size():
			if found.get_item_text(i) != rows[i]:
				same = false
				break
	if same:
		return
	found.clear()
	for row: String in rows:
		found.add_item(row)

func _lan_poll(delta: float) -> void:
	if not Lan.show_controls():
		_paste_poll(delta)
		return
	if lan_panel != null and lan_panel.visible and Lan.role != "host":
		Lan.listen()
		Lan.gather()
		_fill_lan()
	if Lan.role == "":
		return
	Lan.pump()
	var raw: String = Lan.take()
	while raw != "":
		_lan_packet(raw)
		raw = Lan.take()
	if Lan.seat().tick_lobby(delta) == "start":
		SMFront.faction_id = Lan.faction
		_open(Lan.map_path)
		return
	_paint_lobby()

func _lan_packet(raw: String) -> void:
	var kind: String = Lan.ingest(raw)
	if kind == "start" and Lan.role == "client":
		_open("res://game/lan_mirror.tscn")

func _lan_choice(node_name: String, caption: String, at: Vector2, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.position = at
	b.custom_minimum_size = Vector2(84.0, 32.0)
	b.clip_text = true
	b.pressed.connect(fn)
	lan_panel.add_child(b)

func _lan_faction(id: String) -> void:
	if Lan.role == "host":
		SMFront.faction_id = id
	Lan.seat().pick_faction(id)
	_paint_lobby()

func _lan_map_pick(path: String) -> void:
	if Lan.role != "host":
		return
	selected_map = path
	Lan.seat().pick_map(path)
	_paint_lobby()

func _lan_ready() -> void:
	if Lan.role == "":
		Lan.seat().host_ready = not Lan.seat().host_ready
		_paint_lobby()
		return
	var on: bool = not (Lan.seat().host_ready if Lan.role == "host" else Lan.seat().guest_ready)
	Lan.seat().set_ready(on)
	_paint_lobby()

func _lan_say() -> void:
	var entry: LineEdit = find_child("LanChatLine", true, false) as LineEdit
	if entry == null:
		return
	if Lan.role == "":
		return
	Lan.seat().say(entry.text)
	entry.text = ""
	_paint_lobby()

func _paint_lobby() -> void:
	var lobby: Label = find_child("LanLobby", true, false) as Label
	var chat: Label = find_child("LanChat", true, false) as Label
	var count: Label = find_child("LanCount", true, false) as Label
	if lobby != null:
		lobby.text = Lan.seat().lobby_line()
	if chat != null:
		var lines: String = ""
		for line: String in Lan.seat().chat_lines:
			if lines != "":
				lines += "\n"
			lines += line
		chat.text = lines
	if count != null:
		count.text = "Starting in %d." % Lan.seat().count_shown if Lan.seat().counting else ""
	var paste_lobby: Label = find_child("PasteLobby", true, false) as Label
	var paste_chat: Label = find_child("PasteChat", true, false) as Label
	var paste_count: Label = find_child("PasteCount", true, false) as Label
	if paste_lobby != null and lobby != null:
		paste_lobby.text = lobby.text
	if paste_chat != null and chat != null:
		paste_chat.text = chat.text
	if paste_count != null and count != null:
		paste_count.text = count.text

func _skirmish() -> void:
	_card(skirmish_panel, "CardPhillips", "Phillips Channel", "Water", "res://game/phillips_channel.tscn", Vector2(48, 16))
	_card(skirmish_panel, "CardSopRuak", "Sop Ruak", "River", "res://game/sop_ruak.tscn", Vector2(348, 16))
	_card(skirmish_panel, "CardBurma", "Burma Road", "Land", "res://game/burma_road.tscn", Vector2(648, 16))
	_card(skirmish_panel, "CardAtolls", "Ten Degree Atolls", "Water", "res://game/ten_degree_atolls.tscn", Vector2(48, 124))
	_card(skirmish_panel, "CardMekong", "Mekong Delta", "River", "res://game/mekong_delta.tscn", Vector2(348, 124))
	_card(skirmish_panel, "CardChiang", "Siege of Chiang Rai", "River", "res://game/chiang_rai.tscn", Vector2(648, 124))
	_card(skirmish_panel, "CardShowcase", "Golden Confluence", "River", "res://game/showcase.tscn", Vector2(48, 232))
	playing_label = Label.new()
	playing_label.name = "PlayingAs"
	playing_label.position = Vector2(48, 236)
	playing_label.add_theme_font_size_override("font_size", 18)
	playing_label.add_theme_color_override("font_color", Color(1, 1, 1))
	skirmish_panel.add_child(playing_label)
	var hint: Label = Label.new()
	hint.name = "SkirmishHint"
	hint.visible = false
	hint.text = "Pick a map, then Play. The enemy builds, expands, and attacks."
	skirmish_panel.add_child(hint)
	_difficulty_row(skirmish_panel, "Skirmish", Vector2(48, 308))
	_make_cycle("SkirmishFactionCycle", "faction")
	_make_cycle("SkirmishDiffCycle", "diff")
	_make_cycle("SkirmishBotCycle", "bot")
	var grey: Button = Plate.new() as Button
	grey.name = "GreyboxButton"
	grey.text = "Sandbox"
	grey.custom_minimum_size = Vector2(180, 44)
	grey.add_theme_font_size_override("font_size", 22)
	grey.tooltip_text = "Practice map."
	grey.pressed.connect(_open.bind("res://game/greybox.tscn"))
	skirmish_panel.add_child(grey)
	var grey_note: Label = Label.new()
	grey_note.name = "GreyboxNote"
	grey_note.visible = false
	grey_note.text = "Practice map."
	skirmish_panel.add_child(grey_note)
	var train: Button = Plate.new() as Button
	train.name = "BasicTraining"
	train.text = "Basic training"
	train.custom_minimum_size = Vector2(220, 44)
	train.add_theme_font_size_override("font_size", 22)
	train.pressed.connect(_basic_training)
	skirmish_panel.add_child(train)
	play_button = Plate.new() as Button
	play_button.name = "PlayButton"
	play_button.text = "Play"
	play_button.custom_minimum_size = Vector2(200, 52)
	play_button.disabled = true
	play_button.pressed.connect(_play)
	skirmish_panel.add_child(play_button)

func _campaign() -> void:
	var note: Label = Label.new()
	note.name = "CampaignNote"
	note.visible = false
	note.text = "Start with Kokang and Mogok. The match opens with a short lesson."
	note.position = Vector2(48, 8)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	campaign_panel.add_child(note)
	_difficulty_row(campaign_panel, "Campaign", Vector2(48, 492))
	var acts: PackedStringArray = SMCampaign.act_ids()
	for act: String in acts:
		var b: Button = Plate.new() as Button
		b.name = _act_button_name(act)
		b.text = SMCampaign.act_title(act)
		b.custom_minimum_size = Vector2(180, 44)
		b.pressed.connect(_show_act.bind(act))
		campaign_panel.add_child(b)
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = _act_list_name(act)
		scroll.position = Vector2(268, 48)
		scroll.size = Vector2(960, 430)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var box: VBoxContainer = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size = Vector2(900, 0)
		box.add_theme_constant_override("separation", 8)
		scroll.add_child(box)
		for mission_id: String in SMCampaign.act_missions(act):
			_mission_row(box, mission_id)
		campaign_panel.add_child(scroll)
		act_lists[act] = scroll

func _faction() -> void:
	var note: Label = Label.new()
	note.text = "The selected side is who you play on the next skirmish."
	note.position = Vector2(48, 8)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	faction_panel.add_child(note)
	_faction_card("gtfc", "FactionGtfc", Vector2(48, 48))
	_faction_card("nmrf", "FactionNmrf", Vector2(440, 48))
	_faction_card("mvd", "FactionMvd", Vector2(832, 48))
	_yard_link("NmrfYardButton", "res://game/nmrf_yard.tscn", Vector2(440, 300))
	_yard_link("MvdYardButton", "res://game/mvd_yard.tscn", Vector2(832, 300))

func _bar() -> void:
	var bar: Label = Label.new()
	bar.name = "ControlBar"
	bar.text = "Esc  Back    ·    Enter  Select"
	bar.position = Vector2(48, 670)
	bar.add_theme_font_size_override("font_size", 18)
	bar.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

func _panel(node_name: String) -> Control:
	var panel: Control = Control.new()
	panel.name = node_name
	panel.position = Vector2(0, 104)
	panel.size = Vector2(1280, 540)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func _tab(caption: String, node_name: String, which: String, _x: float) -> void:
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = caption
	if node_name == "TabCampaign" or node_name == "TabSkirmish":
		b.theme_type_variation = "HeaderButton"
	if which == "campaign":
		b.pressed.connect(_expand_campaign)
	else:
		b.pressed.connect(_show_tab.bind(which))
	b.set_meta("nav", true)
	b.add_theme_font_size_override("font_size", 32)
	add_child(b)
	tab_buttons.append(b)

func _card(panel: Control, node_name: String, map_name: String, terrain: String, path: String, pos: Vector2) -> void:
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = ""
	b.position = pos
	b.custom_minimum_size = Vector2(280, 72)
	b.size = Vector2(280, 72)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = map_name
	title.position = Vector2(12, 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(title)
	var line: Label = Label.new()
	line.name = "Terrain"
	line.text = terrain
	line.visible = false
	line.position = Vector2(16, 50)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	b.add_child(line)
	b.set_meta("map_path", path)
	b.pressed.connect(_choose_map.bind(path, b))
	b.mouse_entered.connect(_preview_map.bind(path))
	panel.add_child(b)
	map_cards.append(b)

func _mission_row(box: VBoxContainer, mission_id: String) -> void:
	var b: Button = Plate.new() as Button
	b.name = "Mission_%s" % mission_id
	b.text = SMCampaign.title_of(mission_id)
	b.custom_minimum_size = Vector2(720, 52)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_start_mission.bind(mission_id))
	box.add_child(b)
	var brief: Label = Label.new()
	brief.name = "Brief_%s" % mission_id
	brief.text = SMCampaign.briefing_of(mission_id)
	brief.visible = false
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.max_lines_visible = 2
	brief.clip_text = true
	brief.custom_minimum_size = Vector2(400, 44)
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief.add_theme_font_size_override("font_size", 18)
	brief.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	box.add_child(brief)
	var more: Button = Button.new()
	more.name = "Details_%s" % mission_id
	more.text = "Details"
	more.visible = false
	more.custom_minimum_size = Vector2(120, 36)
	more.add_theme_font_size_override("font_size", 18)
	more.pressed.connect(_toggle_lines.bind(brief))
	box.add_child(more)
	b.mouse_entered.connect(_preview_mission.bind(mission_id))
	b.focus_entered.connect(_preview_mission.bind(mission_id))
	b.add_theme_font_size_override("font_size", 18)
	_ensure_done(b, mission_id)

func _process(delta: float) -> void:
	_tick_now(delta)
	_lan_poll(delta)
	preload("res://game/match_settings.gd").poll_web()
	if not _save_polled and SMSave.poll_web():
		_save_polled = true
		for id: String in SMCampaign.ids():
			var button: Button = find_child("Mission_%s" % id, true, false) as Button
			_ensure_done(button, id)
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	var credits: Control = find_child("CreditsPanel", true, false) as Control
	var offer: CanvasItem = find_child("TrainingOffer", true, false) as CanvasItem
	if offer != null and offer.visible:
		if _training_done() or _menu_tab != "main" or (settings != null and settings.visible) or (credits != null and credits.visible) or (faction_submenu != null and faction_submenu.visible):
			offer.visible = false
	_pad_cool = maxf(0.0, _pad_cool - delta)
	if _pad_cool > 0.0:
		return
	if settings != null and settings.visible:
		return
	var y_axis: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var x_axis: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if absf(y_axis) > 0.55:
		_move_focus(1 if y_axis > 0.0 else -1)
		_pad_cool = 0.24
	elif absf(x_axis) > 0.55:
		_move_faction(1 if x_axis > 0.0 else -1)
		_pad_cool = 0.24

func _ensure_done(button: Button, mission_id: String) -> void:
	if button == null or not SMSave.has(mission_id):
		return
	if button.find_child("Done_%s" % mission_id, true, false) != null:
		return
	var done: Label = Label.new()
	done.name = "Done_%s" % mission_id
	done.text = "Done"
	done.position = Vector2(620, 4)
	done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_child(done)

func _warm_shaders() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "ShaderWarmup"
	holder.visible = false
	add_child(holder)
	var paths: PackedStringArray = PackedStringArray([
		"res://game/shaders/cryo_freeze_overlay.gdshader",
		"res://game/shaders/aegis_dome_shield.gdshader",
		"res://game/shaders/slag_corrosion_pool.gdshader",
	])
	for i: int in paths.size():
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "Warm%d" % i
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.2, 0.2, 0.2)
		mesh.mesh = box
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = load(paths[i]) as Shader
		mesh.material_override = mat
		holder.add_child(mesh)

func _faction_card(id: String, node_name: String, pos: Vector2) -> void:
	var saved: String = SMFront.faction_id
	SMFront.faction_id = id
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = ""
	b.position = pos
	b.clip_contents = true
	b.custom_minimum_size = Vector2(300, 58)
	b.size = Vector2(300, 58)
	b.set_meta("faction", id)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = SMFront.display_name()
	title.position = Vector2(84, 14)
	title.size = Vector2(240, 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(title)
	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = Marks.texture(id)
	logo.position = Vector2(8, 6)
	logo.size = Vector2(36, 36)
	logo.custom_minimum_size = Vector2(36, 36)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(logo)
	var colors: Label = Label.new()
	colors.name = "Colors"
	colors.text = SMFront.color_line()
	colors.visible = false
	colors.position = Vector2(120, 6)
	colors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colors.add_theme_font_size_override("font_size", 12)
	colors.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(colors)
	var style: Label = Label.new()
	style.name = "Style"
	style.text = SMFront.style_line()
	style.position = Vector2(2, 22)
	style.visible = false
	style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style.add_theme_font_size_override("font_size", 13)
	style.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_child(style)
	var primary: ColorRect = ColorRect.new()
	primary.name = "Primary"
	primary.color = SMFront.primary()
	primary.position = Vector2(2, 38)
	primary.size = Vector2(6, 6)
	primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(primary)
	var accent: ColorRect = ColorRect.new()
	accent.name = "Accent"
	accent.color = SMFront.accent()
	accent.position = Vector2(8, 44)
	accent.size = Vector2(6, 6)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(accent)
	b.pressed.connect(_choose_faction.bind(id))
	b.mouse_entered.connect(_preview_faction.bind(id))
	b.mouse_exited.connect(_preview_faction.bind(""))
	b.add_theme_font_size_override("font_size", 16)
	b.visible = false
	add_child(b)
	faction_cards.append(b)
	SMFront.faction_id = saved

func _yard_link(node_name: String, path: String, pos: Vector2) -> void:
	var b: Button = Plate.new() as Button
	b.name = node_name
	b.text = "Open yard"
	b.position = pos
	b.custom_minimum_size = Vector2(180, 48)
	b.pressed.connect(_open.bind(path))
	faction_panel.add_child(b)

func _set_submenu(open: bool) -> void:
	if faction_submenu != null:
		faction_submenu.visible = open
	for card: Button in faction_cards:
		card.visible = open
	var campaign: Button = find_child("TabCampaign", true, false) as Button
	if campaign != null:
		campaign.set_meta("mark", "chevron" if open else "arrow")
		campaign.queue_redraw()

func _expand_campaign() -> void:
	_set_submenu(true)
	_show_tab("main")

func _show_tab(which: String) -> void:
	if which != "multi" and Lan.role != "":
		Lan.close()
	_menu_tab = which
	_show_menu_chrome()
	skirmish_panel.visible = which == "skirmish"
	campaign_panel.visible = which == "campaign"
	faction_panel.visible = which == "faction"
	if multi_note != null:
		multi_note.visible = which == "multi"
	if lan_panel != null:
		lan_panel.visible = which == "multi" and Lan.show_controls()
	if paste_panel != null:
		var show_paste: bool = which == "multi" and not Lan.show_controls()
		paste_panel.visible = show_paste
		if show_paste:
			_arm_paste_offer()
	if which == "skirmish" or which == "multi":
		_set_submenu(false)
	elif which == "campaign" or which == "faction":
		_set_submenu(true)
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	var settings_open: bool = settings != null and settings.visible
	for tab: Button in tab_buttons:
		var on: bool = false
		if which == "skirmish":
			on = tab.name == "TabSkirmish"
		elif which == "multi":
			on = tab.name == "TabMultiplayer"
		elif which == "campaign" or which == "main":
			on = tab.name == "TabCampaign" and faction_submenu.visible
		else:
			on = tab.name == "TabFaction"
		if tab.name == "SettingsButton":
			on = settings_open
		_style_button(tab, Color(0.12, 0.13, 0.16), Color(0.32, 0.34, 0.38), on)
	_refresh_playing()
	_sync_art()
	_apply_screen(settings_open)
	_layout_menu(_view_size())
	_paint_detail()
	_fade()

func _show_act(act: String) -> void:
	var keys: Array = act_lists.keys()
	for key: Variant in keys:
		var panel: Control = act_lists[str(key)]
		panel.visible = str(key) == act
	var ids: PackedStringArray = SMCampaign.act_missions(act)
	var keep: bool = false
	for mission_id: String in ids:
		if mission_id == _detail_mission:
			keep = true
	if not keep and ids.size() > 0:
		_detail_mission = ids[0]
	_paint_detail()

func _choose_map(path: String, card: Button) -> void:
	selected_map = path
	play_button.disabled = false
	for other: Button in map_cards:
		var on: bool = other == card
		var fill: Color = Color(0.18, 0.16, 0.12) if on else Color(0.11, 0.12, 0.15)
		var edge: Color = Color(0.86, 0.7, 0.32) if on else Color(0.3, 0.32, 0.36)
		_style_button(other, fill, edge, on)
	_paint_detail()

func _choose_faction(id: String) -> void:
	SMFront.faction_id = id
	_mark_factions()
	_refresh_playing()
	_preview_faction(id)
	_show_tab("campaign")

func _preview_faction(id: String) -> void:
	if id != "":
		_paint_faction(id)
		return
	_sync_art()

func _paint_faction(id: String) -> void:
	if backdrop == null or not backdrop.has_method("set_faction"):
		return
	backdrop.call("set_screen", "faction")
	backdrop.call("set_faction", id)

func _sync_art() -> void:
	if backdrop == null or not backdrop.has_method("set_faction"):
		return
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	if settings != null and settings.visible:
		backdrop.call("set_screen", "settings")
		backdrop.call("set_faction", "")
		return
	if skirmish_panel.visible or campaign_panel.visible or faction_panel.visible:
		_paint_faction(SMFront.current())
		return
	backdrop.call("set_screen", "main")
	backdrop.call("set_faction", "")

func _mark_factions() -> void:
	for card: Button in faction_cards:
		var on: bool = str(card.get_meta("faction")) == SMFront.current()
		var fill: Color = Color(0.18, 0.16, 0.12) if on else Color(0.1, 0.11, 0.14)
		var edge: Color = Color(0.86, 0.7, 0.32) if on else Color(0.3, 0.32, 0.36)
		_style_button(card, fill, edge, on)

func _difficulty_row(parent: Control, prefix: String, at: Vector2) -> void:
	var label: Label = Label.new()
	label.name = prefix + "DiffLabel"
	label.text = "Difficulty"
	label.position = at
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(label)
	var names: PackedStringArray = PackedStringArray(["Easy", "Normal", "Hard"])
	for i: int in names.size():
		var b: Button = Plate.new() as Button
		b.name = prefix + "Diff" + names[i]
		b.text = names[i]
		b.position = at + Vector2(120.0 + float(i) * 112.0, -6.0)
		b.custom_minimum_size = Vector2(104, 40)
		b.add_theme_font_size_override("font_size", 16)
		var id: String = names[i].to_lower()
		b.pressed.connect(_pick_difficulty.bind(id))
		parent.add_child(b)
	mark_difficulty()

func _pick_difficulty(id: String) -> void:
	preload("res://game/match_settings.gd").set_difficulty(id)
	mark_difficulty()

func mark_difficulty() -> void:
	var current: String = str(preload("res://game/match_settings.gd").difficulty)
	var names: PackedStringArray = PackedStringArray(["Easy", "Normal", "Hard"])
	var prefixes: PackedStringArray = PackedStringArray(["Skirmish", "Campaign"])
	for prefix: String in prefixes:
		for caption: String in names:
			var b: Button = find_child(prefix + "Diff" + caption, true, false) as Button
			if b == null:
				continue
			var on: bool = caption.to_lower() == current
			var fill: Color = Color(0.28, 0.2, 0.1) if on else Color(0.12, 0.13, 0.16)
			var edge: Color = Color(0.9, 0.72, 0.28) if on else Color(0.32, 0.34, 0.38)
			_style_button(b, fill, edge, on)
	_paint_cycles()

func _refresh_playing() -> void:
	if playing_label != null:
		playing_label.text = "Next skirmish: %s" % SMFront.banner()

func _toggle_settings() -> void:
	var panel: Control = find_child("SettingsPanel", true, false) as Control
	if panel == null:
		return
	panel.visible = not panel.visible
	if panel.visible and panel.has_method("pull"):
		panel.call("pull")
	if panel.visible:
		move_child(panel, get_child_count() - 1)
		_hide_menu_chrome()
		_sync_art()
		_layout_menu(_view_size())
	else:
		settings_closed()

func _open_credits() -> void:
	var panel: Control = find_child("CreditsPanel", true, false) as Control
	if panel == null:
		return
	panel.call("open")
	_hide_menu_chrome()

func credits_closed() -> void:
	_show_tab(_menu_tab)

func settings_closed() -> void:
	var panel: Control = find_child("SettingsPanel", true, false) as Control
	if panel != null:
		panel.visible = false
	_show_tab(_menu_tab)

func _show_menu_chrome() -> void:
	var names: PackedStringArray = PackedStringArray([
		"GameTitle", "TitleWordmark", "TitleRule", "VersionMark", "ControlBar", "QuitButton",
	])
	for node_name: String in names:
		var node: CanvasItem = find_child(node_name, true, false) as CanvasItem
		if node == null:
			continue
		if node_name == "QuitButton" and OS.has_feature("web"):
			node.visible = false
		else:
			node.visible = true
	for tab: Button in tab_buttons:
		tab.visible = true
		tab.z_index = 0

## A sub-screen replaces the option list. Back and Esc return to the main list.
func _apply_screen(settings_open: bool) -> void:
	var back: CanvasItem = find_child("MenuBack", true, false) as CanvasItem
	var submenu_open: bool = faction_submenu != null and faction_submenu.visible and _menu_tab == "main"
	var main: bool = _menu_tab == "main" and not settings_open and not submenu_open
	if back != null:
		back.visible = not main and not settings_open
	if settings_open:
		_hide_menu_chrome()
		return
	if submenu_open:
		for tab: Button in tab_buttons:
			tab.visible = tab.name == "TabCampaign"
		var folded_quit: CanvasItem = find_child("QuitButton", true, false) as CanvasItem
		if folded_quit != null:
			folded_quit.visible = false
		return
	if main:
		return
	for tab: Button in tab_buttons:
		tab.visible = false
	var quit: CanvasItem = find_child("QuitButton", true, false) as CanvasItem
	if quit != null:
		quit.visible = false

func _go_back() -> void:
	if faction_submenu != null and faction_submenu.visible and _menu_tab == "main":
		_set_submenu(false)
		_show_tab("main")
		return
	_show_tab("main")

func _fade() -> void:
	if not is_inside_tree():
		return
	var veil: CanvasItem = find_child("MenuFade", true, false) as CanvasItem
	if veil == null:
		return
	veil.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(veil, "modulate:a", 0.0, 0.15)

func _hide_menu_chrome() -> void:
	var names: PackedStringArray = _chrome_names()
	for node_name: String in names:
		var node: CanvasItem = find_child(node_name, true, false) as CanvasItem
		if node != null:
			node.visible = false
	for tab: Button in tab_buttons:
		tab.visible = false
		tab.z_index = 0

func _chrome_names() -> PackedStringArray:
	return PackedStringArray([
		"GameTitle", "TitleWordmark", "TitleRule", "VersionMark", "NowPlaying", "ControlBar",
		"MultiplayerNote", "FactionSubmenu", "LanPanel", "PastePanel", "PanelSkirmish",
		"PanelCampaign", "PanelFaction", "QuitButton", "MenuBack", "TrainingOffer",
	])

func _play() -> void:
	if selected_map == "":
		return
	Lan.close()
	_open(selected_map)

func _basic_training() -> void:
	Lan.close()
	preload("res://game/match_coach.gd").armed = true
	if selected_map == "":
		selected_map = "res://game/phillips_channel.tscn"
	_play()

func _offer_training() -> void:
	if _training_done():
		return
	var card: PanelContainer = PanelContainer.new()
	card.name = "TrainingOffer"
	card.z_index = 2
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.94)
	style.border_color = Color(0.93, 0.78, 0.38)
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var title: Label = Label.new()
	title.text = "New to ASEAN 2031?"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	box.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var raid: Button = Button.new()
	raid.name = "TrainingRaid"
	raid.text = "Play the training raid"
	raid.custom_minimum_size = Vector2(220, 44)
	raid.add_theme_font_size_override("font_size", 16)
	raid.pressed.connect(_accept_training)
	row.add_child(raid)
	var skip: Button = Button.new()
	skip.name = "TrainingSkip"
	skip.text = "Skip"
	skip.custom_minimum_size = Vector2(96, 44)
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_skip_training)
	row.add_child(skip)
	add_child(card)

func _accept_training() -> void:
	_mark_training_seen()
	_start_mission("kokang")

func _skip_training() -> void:
	_mark_training_seen()
	var offer: CanvasItem = find_child("TrainingOffer", true, false) as CanvasItem
	if offer != null:
		offer.visible = false

static func _training_done() -> bool:
	if _training_seen or FileAccess.file_exists("user://training_offer.cfg"):
		_training_seen = true
		return true
	if OS.has_feature("web"):
		var saved: Variant = JavaScriptBridge.eval("try{localStorage.getItem('asean2031_training_seen')||''}catch(_){''}", true)
		if saved is String and str(saved) != "":
			_training_seen = true
			return true
	return false

static func mark_training_seen() -> void:
	_training_seen = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('asean2031_training_seen','1')}catch(_){}", true)
	var file: FileAccess = FileAccess.open("user://training_offer.cfg", FileAccess.WRITE)
	if file == null:
		return
	file.store_line("seen")
	file.close()

func _mark_training_seen() -> void:
	mark_training_seen()
	var offer: CanvasItem = find_child("TrainingOffer", true, false) as CanvasItem
	if offer != null:
		offer.visible = false

func _start_mission(mission_id: String) -> void:
	Lan.close()
	if mission_id == "kokang":
		_open("res://game/mission_kokang.tscn")
		return
	SMCampaign.selected = mission_id
	_open("res://game/campaign_mission.tscn")

func _open(path: String) -> void:
	_mark_training_seen()
	preload("res://game/model_registry.gd").warm(self)
	var loading: Control = find_child("LoadingPlate", true, false) as Control
	if loading != null:
		loading.visible = true
		move_child(loading, get_child_count() - 1)
		var art: Node = loading.get_child(0)
		if art != null and art.has_method("set_faction"):
			art.call("set_screen", "loading")
			art.call("set_faction", "")
		var title: Label = loading.find_child("LoadingTitle", true, false) as Label
		if title != null:
			title.text = _mission_title(path)
		var mark: TextureRect = loading.find_child("LoadingMark", true, false) as TextureRect
		if mark != null:
			mark.texture = Marks.texture_large(SMFront.current())
		var progress: Label = loading.find_child("LoadingProgress", true, false) as Label
		if progress != null:
			progress.text = "0%"
	await get_tree().process_frame
	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		get_tree().change_scene_to_file(path)
		return
	while is_inside_tree():
		var progress_out: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress_out)
		var digits: Label = find_child("LoadingProgress", true, false) as Label
		if digits != null and not progress_out.is_empty():
			digits.text = "%d%%" % int(round(float(progress_out[0]) * 100.0))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
			if packed != null:
				get_tree().change_scene_to_packed(packed)
			else:
				get_tree().change_scene_to_file(path)
			return
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			get_tree().change_scene_to_file(path)
			return
		await get_tree().process_frame

func _mission_title(path: String) -> String:
	var file: String = path.get_file()
	if file == "mission_kokang.tscn":
		return SMCampaign.title_of("kokang")
	if file == "campaign_mission.tscn":
		return SMCampaign.title_of(SMCampaign.selected)
	if file == "phillips_channel.tscn":
		return "Phillips Channel"
	if file == "sop_ruak.tscn":
		return "Sop Ruak"
	if file == "burma_road.tscn":
		return "Burma Road"
	if file == "ten_degree_atolls.tscn":
		return "Ten Degree Atolls"
	if file == "mekong_delta.tscn":
		return "Mekong Delta"
	if file == "chiang_rai.tscn":
		return "Siege of Chiang Rai"
	if file == "showcase.tscn":
		return "Golden Confluence"
	if file == "greybox.tscn":
		return "Greybox"
	if file == "nmrf_yard.tscn":
		return "NMRF yard"
	if file == "mvd_yard.tscn":
		return "MVD yard"
	return "Loading"

func _loading_plate() -> void:
	var plate: Control = Control.new()
	plate.name = "LoadingPlate"
	plate.visible = false
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.z_index = 40
	var art: Control = Backdrop.new() as Control
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(art)
	var label: Label = Label.new()
	label.name = "LoadingTitle"
	label.text = "LOADING"
	label.theme_type_variation = "Header"
	label.position = Vector2(64, 56)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	plate.add_child(label)
	var progress: Label = Label.new()
	progress.name = "LoadingProgress"
	progress.text = ""
	progress.position = Vector2(64, 128)
	var mark := TextureRect.new()
	mark.name = "LoadingMark"
	mark.position = Vector2(64, 188)
	mark.size = Vector2(128, 128)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.texture = Marks.texture_large(SMFront.current())
	plate.add_child(mark)
	progress.add_theme_font_size_override("font_size", 28)
	progress.add_theme_color_override("font_color", Color(1, 1, 1))
	plate.add_child(progress)
	add_child(plate)

func _act_button_name(act: String) -> String:
	if act == "act_1":
		return "ActI"
	if act == "act_2":
		return "ActII"
	return "ActIII"

func _act_list_name(act: String) -> String:
	if act == "act_1":
		return "ActIMissions"
	if act == "act_2":
		return "ActIIMissions"
	return "ActIIIMissions"

func _style_button(b: Button, fill: Color, edge: Color, strong: bool) -> void:
	if b.get_script() == Plate:
		b.set_meta("lit", strong)
		b.queue_redraw()
		return
	var width: int = 2 if strong else 1
	b.add_theme_stylebox_override("normal", _box(fill, edge, width))
	b.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge.lightened(0.1), width))
	b.add_theme_stylebox_override("pressed", _box(fill.darkened(0.06), edge, width))
	b.add_theme_stylebox_override("disabled", _box(Color(0.1, 0.1, 0.11), Color(0.22, 0.22, 0.24), 1))
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.28))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))

func layout_for(size: Vector2) -> void:
	_layout_menu(size)

func _view_size() -> Vector2:
	if not is_inside_tree():
		return Vector2(1280, 720)
	var view: Vector2 = get_viewport_rect().size
	if view.x < 160.0 or view.y < 160.0:
		return Vector2(1280, 720)
	return view

func _layout_menu(size: Vector2) -> void:
	if size.x < 160.0 or size.y < 160.0:
		size = Vector2(1280, 720)
	var narrow: bool = size.x < 900.0 or size.y > size.x + 4.0
	if faction_submenu != null:
		faction_submenu.position = Vector2.ZERO
		faction_submenu.size = size
	var left: float = 24.0 if narrow else 96.0
	var sub_open: bool = _menu_tab == "skirmish" or _menu_tab == "campaign" or _menu_tab == "faction"
	var title_x: float = (16.0 if narrow else 28.0) if sub_open else left
	var title_y: float = 36.0 if narrow else (28.0 if sub_open else 96.0)
	var title_px: int = 36 if narrow else (42 if sub_open else 48)
	var title: Control = find_child("GameTitle", true, false) as Control
	if title != null:
		title.position = Vector2(title_x, title_y)
		title.add_theme_font_size_override("font_size", title_px)
	var rule: Control = find_child("TitleRule", true, false) as Control
	if rule != null:
		rule.visible = false
	var version: Control = find_child("VersionMark", true, false) as Control
	if version != null:
		version.add_theme_font_size_override("font_size", 18)
		version.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
		version.position = Vector2(left, size.y - 36.0)
	var portrait: bool = size.y > size.x
	var rail_w: float = size.x * (0.8 if portrait else 0.4)
	var rail: Control = find_child("MenuRail", true, false) as Control
	if rail != null:
		rail.position = Vector2.ZERO
		rail.size = Vector2(rail_w, size.y)
	if title != null:
		title.size = Vector2(maxf(160.0, (size.x if portrait else rail_w) - left - 16.0), 64.0)
		var title_label: Label = title as Label
		if title_label != null:
			title_label.clip_text = true
		var wordmark: Control = find_child("TitleWordmark", true, false) as Control
		if wordmark != null:
			wordmark.visible = title.visible
			wordmark.position = title.position
			var wm_w: float = maxf(200.0, (size.x if portrait else rail_w) - title_x - 16.0)
			if sub_open:
				wm_w = minf(wm_w, 340.0)
			wordmark.size = Vector2(wm_w, 60.0 if sub_open or narrow else 74.0)
	var settings_open: bool = false
	var settings_panel: Control = find_child("SettingsPanel", true, false) as Control
	if settings_panel != null:
		settings_open = settings_panel.visible
	var panel_open: bool = settings_open or _menu_tab != "main" or (faction_submenu != null and faction_submenu.visible)
	for veil_name: String in ["MenuDim", "MenuBlur"]:
		var veil: CanvasItem = find_child(veil_name, true, false) as CanvasItem
		if veil != null and veil.get_parent() == self:
			veil.visible = panel_open and not settings_open
			var veil_rect: Control = veil as Control
			if veil_rect != null:
				veil_rect.position = Vector2.ZERO
				veil_rect.size = size
	var now: Control = find_child("NowPlaying", true, false) as Control
	var chip: Control = find_child("NowPlayingChip", true, false) as Control
	var chip_y: float = 80.0 if portrait else 22.0
	if now != null:
		now.position = Vector2(size.x - 348.0, chip_y + 6.0)
		now.size = Vector2(320.0, 28.0)
	if chip != null:
		chip.position = Vector2(size.x - 360.0, chip_y)
		chip.size = Vector2(340.0, 34.0 if portrait else 40.0)
	var plate_w: float = rail_w - (48.0 if narrow else 104.0)
	var y: float = 120.0 if narrow else 180.0
	var row_h: float = 48.0
	y = _seat(find_child("TabCampaign", true, false) as Control, left, y, plate_w, row_h)
	var faction_end: float = y
	var camp_open: bool = campaign_panel != null and campaign_panel.visible
	if faction_submenu != null and faction_submenu.visible:
		if camp_open:
			var camp_left: float = 16.0 if narrow else 28.0
			var camp_w: float = maxf(180.0, rail_w - camp_left - 16.0)
			faction_end = _seat_factions(camp_left, 112.0 if narrow else 124.0, camp_w, narrow)
		else:
			faction_end = _seat_factions(left, y, plate_w, narrow or plate_w < 520.0)
			y = faction_end
	y = _seat(find_child("TabSkirmish", true, false) as Control, left, y, plate_w, row_h)
	var multi_h: float = row_h
	y = _seat(find_child("TabMultiplayer", true, false) as Control, left, y, plate_w, multi_h)
	y = _seat(find_child("SettingsButton", true, false) as Control, left, y, plate_w, row_h)
	y = _seat(find_child("CreditsButton", true, false) as Control, left, y, plate_w, row_h)
	y = _seat(find_child("QuitButton", true, false) as Control, left, y, plate_w, row_h)
	_seat(find_child("MenuBack", true, false) as Control, left, size.y - 88.0, 220.0, row_h)
	var side: Control = find_child("TabFaction", true, false) as Control
	if side != null:
		side.position = Vector2(-400, -400)
	if multi_note != null:
		multi_note.position = Vector2(left + 8.0 if narrow else 460.0, y if narrow else 180.0)
		multi_note.size = Vector2(plate_w if narrow else 420.0, 72)
	if lan_panel != null:
		lan_panel.position = multi_note.position + Vector2(0.0, 80.0)
		lan_panel.size = Vector2(plate_w if narrow else 440.0, 530.0)
	if paste_panel != null:
		paste_panel.position = multi_note.position + Vector2(0.0, 80.0)
		paste_panel.size = Vector2(plate_w if narrow else 440.0, 560.0)
	var content_y: float = 0.0
	var content_x: float = 0.0
	var content_w: float = size.x
	var content_h: float = size.y
	for panel_name: String in ["PanelSkirmish", "PanelCampaign", "PanelFaction"]:
		var panel: Control = find_child(panel_name, true, false) as Control
		if panel == null:
			continue
		panel.position = Vector2(content_x, content_y)
		panel.size = Vector2(content_w, content_h)
	var bar: Control = find_child("ControlBar", true, false) as Control
	if bar != null:
		bar.position = Vector2(size.x - 360.0, size.y - 36.0)
		bar.size = Vector2(340.0, 24)
		bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bar.clip_text = true
	var offer: Control = find_child("TrainingOffer", true, false) as Control
	if offer != null:
		var seen: bool = _training_done()
		var credits_panel: Control = find_child("CreditsPanel", true, false) as Control
		var credits_open: bool = credits_panel != null and credits_panel.visible
		offer.visible = _menu_tab == "main" and not seen and not narrow and not settings_open and not credits_open and (faction_submenu == null or not faction_submenu.visible)
		offer.position = Vector2(minf(640.0, size.x * 0.46), 240.0)
		offer.size = Vector2(minf(460.0, maxf(280.0, size.x - offer.position.x - 24.0)), 150.0)
	var card: Control = find_child("MenuDetail", true, false) as Control
	if card != null:
		var show_card: bool = (skirmish_panel != null and skirmish_panel.visible) or (campaign_panel != null and campaign_panel.visible)
		card.visible = show_card and not narrow and not settings_open
		var card_x: float = rail_w + 28.0
		card.position = Vector2(card_x, 110.0)
		card.size = Vector2(maxf(280.0, size.x - card_x - 28.0), maxf(220.0, size.y - 230.0))
	_place_skirmish(content_w, content_h)
	var camp_top: float = 168.0 if narrow else 176.0
	if campaign_panel != null and campaign_panel.visible and faction_submenu != null and faction_submenu.visible:
		camp_top = faction_end + 4.0
	_place_campaign(content_w, content_h, camp_top)
	_place_factions(content_w)

func _seat_factions(x: float, y: float, width: float, narrow: bool) -> float:
	if faction_cards.is_empty():
		return y
	if narrow:
		var cursor: float = y
		for card: Button in faction_cards:
			cursor = _seat(card, x, cursor, width, 52.0)
			_fit_mark(card)
		return cursor
	var gap: float = 12.0
	var slot: float = maxf(72.0, (width - gap * float(faction_cards.size() - 1)) / float(faction_cards.size()))
	for i: int in faction_cards.size():
		var card: Button = faction_cards[i]
		card.position = Vector2(x + float(i) * (slot + gap), y)
		card.size = Vector2(slot, 48.0)
		card.custom_minimum_size = Vector2(slot, 48.0)
		_fit_mark(card)
	return y + 52.0

func _fit_mark(card: Button) -> void:
	var compact: bool = card.size.x < 220.0
	var logo: TextureRect = card.find_child("Logo", true, false) as TextureRect
	if logo != null:
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = 32.0 if compact else 40.0
		logo.custom_minimum_size = Vector2(side, side)
		logo.position = Vector2(6.0, floorf((card.size.y - side) * 0.5))
		logo.size = Vector2(side, side)
	var title: Label = card.find_child("Title", true, false) as Label
	if title != null:
		var tx: float = 44.0 if compact else 84.0
		title.position = Vector2(tx, floorf((card.size.y - 24.0) * 0.5))
		title.size = Vector2(maxf(60.0, card.size.x - tx - 8.0), 24.0)

func _quit() -> void:
	preload("res://game/render_budget.gd").shutdown(get_tree())
	get_tree().quit()

func _focusables() -> Array[Button]:
	var rows: Array[Button] = []
	for node_name: String in ["TabCampaign", "TabSkirmish", "TabMultiplayer", "SettingsButton", "CreditsButton", "QuitButton"]:
		var button: Button = find_child(node_name, true, false) as Button
		if button != null:
			rows.append(button)
	return rows

func _unhandled_input(event: InputEvent) -> void:
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	if settings != null and settings.visible:
		return
	var roll: Control = find_child("CreditsPanel", true, false) as Control
	if roll != null and roll.visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			if _menu_tab != "main" or (faction_submenu != null and faction_submenu.visible):
				_go_back()
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_DOWN or key.keycode == KEY_S:
			_move_focus(1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_UP or key.keycode == KEY_W:
			_move_focus(-1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_move_faction(-1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_move_faction(1)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			if _launch_detail(true):
				get_viewport().set_input_as_handled()
				return
			_activate_focus()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_SPACE:
			_activate_focus()
			get_viewport().set_input_as_handled()
		return
	var joy: InputEventJoypadButton = event as InputEventJoypadButton
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_DPAD_DOWN:
			_move_focus(1)
		elif joy.button_index == JOY_BUTTON_DPAD_UP:
			_move_focus(-1)
		elif joy.button_index == JOY_BUTTON_DPAD_LEFT:
			_move_faction(-1)
		elif joy.button_index == JOY_BUTTON_DPAD_RIGHT:
			_move_faction(1)
		elif joy.button_index == JOY_BUTTON_A:
			_activate_focus()
		else:
			return
		get_viewport().set_input_as_handled()

func _move_focus(step: int) -> void:
	var rows: Array[Button] = _focusables()
	if rows.is_empty():
		return
	var current: int = 0
	var owner: Control = get_viewport().gui_get_focus_owner()
	for i: int in rows.size():
		if rows[i] == owner:
			current = i
	var nxt: int = posmod(current + step, rows.size())
	rows[nxt].grab_focus()

func _move_faction(step: int) -> void:
	if faction_submenu == null or not faction_submenu.visible or faction_cards.is_empty():
		return
	_faction_i = posmod(_faction_i + step, faction_cards.size())
	var card: Button = faction_cards[_faction_i]
	card.grab_focus()
	_preview_faction(str(card.get_meta("faction", "")))

func _activate_focus() -> void:
	var owner: Button = get_viewport().gui_get_focus_owner() as Button
	if owner != null and owner.is_visible_in_tree() and not owner.disabled:
		owner.pressed.emit()

func _seat(node: Control, x: float, y: float, w: float, h: float) -> float:
	if node == null:
		return y
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)
	node.custom_minimum_size = Vector2(w, h)
	node.set_meta("base_pos", node.position)
	return y + h + 8.0

func _menu_fade() -> void:
	var veil: ColorRect = ColorRect.new()
	veil.name = "MenuFade"
	veil.color = Color(0, 0, 0, 1)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.z_index = 25
	veil.modulate.a = 0.0
	add_child(veil)

func _detail_card() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "MenuDetail"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_detail_gui)
	card.z_index = 2
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0.93, 0.78, 0.38, 1)
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	if Glass.live():
		Glass.dress(card, 10, Color(0.04, 0.045, 0.06, 0.55), 20, Color(0.93, 0.78, 0.38, 0.85))
	add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title: Label = Label.new()
	title.name = "DetailTitle"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	box.add_child(title)
	var preview := TextureRect.new()
	preview.name = "DetailMap"
	preview.custom_minimum_size = Vector2(280, 140)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview)
	var players := Label.new()
	players.name = "DetailPlayers"
	players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	players.add_theme_font_size_override("font_size", 18)
	players.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	box.add_child(players)
	var body: Label = Label.new()
	body.name = "DetailBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 8
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	box.add_child(body)
	var tags: Label = Label.new()
	tags.name = "DetailTags"
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags.add_theme_font_size_override("font_size", 18)
	tags.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	box.add_child(tags)
	var more: Button = Button.new()
	more.name = "DetailMore"
	more.text = "Details"
	more.custom_minimum_size = Vector2(140, 40)
	more.add_theme_font_size_override("font_size", 18)
	more.pressed.connect(_toggle_detail)
	box.add_child(more)

func _on_detail_gui(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_launch_detail(false)

## Enter, or a click on the briefing card, starts the mission shown in the card.
func _launch_detail(from_key: bool) -> bool:
	if campaign_panel == null or not campaign_panel.visible:
		return false
	if from_key:
		var owner: Control = get_viewport().gui_get_focus_owner() as Control
		if owner != null and (owner is LineEdit or owner.name == "DetailMore"):
			return false
	var mission_id: String = _detail_mission if _detail_mission != "" else SMCampaign.selected
	if mission_id == "":
		return false
	_start_mission(mission_id)
	return true

func _toggle_detail() -> void:
	var body: Label = find_child("DetailBody", true, false) as Label
	_toggle_lines(body)

func _toggle_lines(body: Label) -> void:
	if body == null:
		return
	body.max_lines_visible = 0 if body.max_lines_visible == 2 else 2

func _make_cycle(node_name: String, kind: String) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.pressed.connect(_spin_cycle.bind(kind))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 80 if kind == "faction" else 8
	empty.content_margin_top = 8
	empty.content_margin_bottom = 8
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, empty)
	if kind == "faction":
		var logo := TextureRect.new()
		logo.name = "FactionLogo"
		logo.position = Vector2(6, 6)
		logo.size = Vector2(32, 32)
		logo.custom_minimum_size = Vector2(32, 32)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.texture = Marks.texture(SMFront.current())
		button.add_child(logo)
	skirmish_panel.add_child(button)

func _cycle_row(node_name: String, x: float, y: float, width: float, height: float = 36.0) -> void:
	var row: Control = find_child(node_name, true, false) as Control
	if row == null:
		return
	row.position = Vector2(x, y)
	row.size = Vector2(width, height)
	row.custom_minimum_size = Vector2(width, height)

func _spin_cycle(kind: String) -> void:
	if kind == "faction":
		var ids: PackedStringArray = PackedStringArray(["gtfc", "nmrf", "mvd"])
		var at: int = ids.find(SMFront.current())
		SMFront.faction_id = ids[(at + 1) % ids.size()]
		_mark_factions()
		_refresh_playing()
		_preview_faction(SMFront.current())
	elif kind == "diff":
		var names: PackedStringArray = PackedStringArray(["easy", "normal", "hard"])
		var at_diff: int = names.find(str(preload("res://game/match_settings.gd").difficulty))
		if at_diff < 0:
			at_diff = 1
		preload("res://game/match_settings.gd").set_difficulty(names[(at_diff + 1) % names.size()])
		mark_difficulty()
	else:
		_bot_i = (_bot_i + 1) % 3
	_paint_cycles()

func _paint_cycles() -> void:
	var faction: Button = find_child("SkirmishFactionCycle", true, false) as Button
	if faction != null:
		faction.text = "Faction:  %s" % SMFront.display_name()
		var logo: TextureRect = faction.find_child("FactionLogo", true, false) as TextureRect
		if logo != null:
			logo.texture = Marks.texture(SMFront.current())
	var diff: Button = find_child("SkirmishDiffCycle", true, false) as Button
	if diff != null:
		var label: String = str(preload("res://game/match_settings.gd").difficulty)
		diff.text = "Difficulty:  %s" % label.capitalize()
	var bot: Button = find_child("SkirmishBotCycle", true, false) as Button
	if bot != null:
		var bots: PackedStringArray = PackedStringArray(["Raider", "Holder", "Rusher"])
		bot.text = "Commander:  %s" % bots[_bot_i]

func _preview_mission(mission_id: String) -> void:
	_detail_mission = mission_id
	_paint_detail()

func _preview_map(path: String) -> void:
	_hover_map = path
	_paint_detail()

func _tick_now(delta: float) -> void:
	var label: Label = find_child("NowPlaying", true, false) as Label
	var chip: CanvasItem = find_child("NowPlayingChip", true, false) as CanvasItem
	if label == null:
		return
	var settings: Control = find_child("SettingsPanel", true, false) as Control
	var blocked: bool = settings != null and settings.visible
	var text: String = label.text.strip_edges()
	if text != "" and text != _now_seen:
		_now_seen = text
		_now_left = 4.0
	if _now_left > 0.0:
		_now_left -= delta
	var show: bool = _now_left > 0.0 and text != "" and not blocked
	label.visible = show
	if chip != null:
		chip.visible = show

func _paint_detail() -> void:
	var title: Label = find_child("DetailTitle", true, false) as Label
	var body: Label = find_child("DetailBody", true, false) as Label
	var tags: Label = find_child("DetailTags", true, false) as Label
	var preview: TextureRect = find_child("DetailMap", true, false) as TextureRect
	var players: Label = find_child("DetailPlayers", true, false) as Label
	if title == null or body == null or tags == null:
		return
	_paint_cycles()
	if skirmish_panel != null and skirmish_panel.visible:
		var shown: String = _hover_map if _hover_map != "" else selected_map
		var map_title: String = "Choose a map"
		var terrain: String = ""
		for card: Button in map_cards:
			if str(card.get_meta("map_path", "")) == shown:
				var line: Label = card.find_child("Title", true, false) as Label
				var kind: Label = card.find_child("Terrain", true, false) as Label
				if line != null:
					map_title = line.text
				if kind != null:
					terrain = kind.text
		title.text = map_title
		body.text = "Two players. You and one enemy."
		tags.text = terrain if terrain != "" else "2 players"
		if players != null:
			players.visible = true
			players.text = "Players: 2"
		if preview != null:
			preview.visible = shown != ""
			preview.texture = _map_preview(shown)
		return
	if campaign_panel != null and campaign_panel.visible:
		var mission_id: String = _detail_mission if _detail_mission != "" else SMCampaign.selected
		title.text = SMCampaign.title_of(mission_id) if mission_id != "" else "Campaign"
		body.text = SMCampaign.briefing_of(mission_id)
		tags.text = "Clear the field    Hold the line    Bring it home"
		if players != null:
			players.visible = false
		if preview != null:
			var rel: String = SMCampaign.still_of(mission_id)
			if rel == "":
				preview.texture = null
				preview.visible = false
			else:
				preload("res://game/served_art.gd").bind(preview, rel)
		return
	title.text = ""
	body.text = ""
	tags.text = ""
	if players != null:
		players.visible = false
	if preview != null:
		preview.visible = false

func _map_preview(path: String) -> Texture2D:
	if path == "":
		return null
	if _previews.has(path):
		return _previews[path] as Texture2D
	var grid: SMDomainGrid = _grid_for(path)
	if grid == null:
		return null
	var scale: int = 4
	var img := Image.create(grid.cols * scale, grid.rows * scale, false, Image.FORMAT_RGBA8)
	for y: int in grid.rows:
		for x: int in grid.cols:
			img.fill_rect(Rect2i(x * scale, y * scale, scale, scale), _domain_ink(grid.domain_at_cell(Vector2i(x, y))))
	var tex := ImageTexture.create_from_image(img)
	_previews[path] = tex
	return tex

func _grid_for(path: String) -> SMDomainGrid:
	var file: String = path.get_file()
	if file == "phillips_channel.tscn":
		return SMDomainGrid.phillips_layout()
	if file == "sop_ruak.tscn":
		return SMDomainGrid.sop_ruak_layout()
	if file == "burma_road.tscn":
		return SMDomainGrid.burma_road_layout()
	if file == "ten_degree_atolls.tscn":
		return SMDomainGrid.ten_degree_atolls_layout()
	if file == "mekong_delta.tscn":
		return SMDomainGrid.mekong_delta_layout()
	if file == "chiang_rai.tscn":
		return SMDomainGrid.chiang_rai_layout()
	if file == "showcase.tscn":
		return SMDomainGrid.showcase_layout()
	return null

func _domain_ink(domain: int) -> Color:
	if domain == SMDomainGrid.Domain.SHALLOW:
		return Color(0.25, 0.55, 0.62, 1)
	if domain == SMDomainGrid.Domain.DEEP:
		return Color(0.08, 0.22, 0.38, 1)
	if domain == SMDomainGrid.Domain.CLIFF:
		return Color(0.42, 0.36, 0.3, 1)
	if domain == SMDomainGrid.Domain.AIR:
		return Color(0.55, 0.7, 0.78, 1)
	return Color(0.45, 0.52, 0.36, 1)

func _selected_card() -> Button:
	for card: Button in map_cards:
		if bool(card.get_meta("lit", false)):
			return card
	return null

func _place_skirmish(panel_w: float, panel_h: float) -> void:
	var names: PackedStringArray = PackedStringArray([
		"CardPhillips", "CardSopRuak", "CardBurma", "CardAtolls", "CardMekong", "CardChiang", "CardShowcase",
	])
	if panel_w > panel_h and panel_h < 600.0 and panel_w < 900.0:
		_place_skirmish_short(names, panel_w)
		return
	var narrow: bool = panel_w < 900.0
	var rail_w: float = panel_w if narrow else panel_w * 0.4
	var list_x: float = 16.0 if narrow else 28.0
	var list_w: float = maxf(160.0, rail_w - list_x - 16.0)
	var row_y: float = 112.0 if narrow else 140.0
	var card_step: float = 34.0
	for i: int in names.size():
		var card: Control = find_child(names[i], true, false) as Control
		if card == null:
			continue
		card.position = Vector2(list_x, row_y + float(i) * card_step)
		card.size = Vector2(list_w, 32.0)
		card.custom_minimum_size = Vector2(list_w, 32.0)
	var after: float = row_y + float(names.size()) * card_step + 6.0
	var playing: Control = find_child("PlayingAs", true, false) as Control
	if playing != null:
		playing.position = Vector2(list_x, after)
		playing.size = Vector2(list_w, 26.0)
	_cycle_row("SkirmishFactionCycle", list_x, after + 28.0, list_w, 34.0)
	_cycle_row("SkirmishDiffCycle", list_x, after + 64.0, list_w, 34.0)
	_cycle_row("SkirmishBotCycle", list_x, after + 100.0, list_w, 34.0)
	var foot: float = panel_h - 72.0
	var foot_x: float = list_x if narrow else rail_w + 16.0
	var play: Control = find_child("PlayButton", true, false) as Control
	if play != null:
		var play_x: float = list_x if narrow else panel_w - 260.0
		var play_y: float = after + 236.0 if narrow else foot
		play.position = Vector2(play_x, play_y)
		play.size = Vector2(220, 52)
		play.custom_minimum_size = Vector2(220, 52)
	var grey: Control = find_child("GreyboxButton", true, false) as Control
	if grey != null:
		grey.position = Vector2(foot_x, after + 184.0 if narrow else foot + 6.0)
		grey.size = Vector2(168.0, 44.0)
		grey.custom_minimum_size = Vector2(168.0, 44.0)
	var train: Control = find_child("BasicTraining", true, false) as Control
	if train != null:
		var train_x: float = foot_x + 180.0
		var train_y: float = after + 184.0 if narrow else foot + 6.0
		train.position = Vector2(train_x, train_y)
		train.size = Vector2(228.0, 44.0)
		train.custom_minimum_size = Vector2(228.0, 44.0)
	_hide_old_difficulty()

## Landscape phones: maps in a two-wide grid on the left, choices and Play on the right.
func _place_skirmish_short(names: PackedStringArray, panel_w: float) -> void:
	var left_x: float = 24.0
	var half: float = panel_w * 0.5
	var card_w: float = (half - left_x - 12.0) * 0.5 - 4.0
	var row_y: float = 88.0
	for i: int in names.size():
		var card: Control = find_child(names[i], true, false) as Control
		if card == null:
			continue
		card.position = Vector2(left_x + float(i % 2) * (card_w + 8.0), row_y + floorf(float(i) / 2.0) * 40.0)
		card.size = Vector2(card_w, 36.0)
		card.custom_minimum_size = Vector2(card_w, 36.0)
	var tools_y: float = row_y + ceilf(float(names.size()) / 2.0) * 40.0 + 4.0
	var grey: Control = find_child("GreyboxButton", true, false) as Control
	if grey != null:
		grey.position = Vector2(left_x, tools_y)
		grey.size = Vector2(card_w, 40.0)
	var train: Control = find_child("BasicTraining", true, false) as Control
	if train != null:
		train.position = Vector2(left_x + card_w + 8.0, tools_y)
		train.size = Vector2(card_w, 40.0)
	var right_x: float = half + 12.0
	var right_w: float = panel_w - right_x - 24.0
	var playing: Control = find_child("PlayingAs", true, false) as Control
	if playing != null:
		playing.position = Vector2(right_x, row_y - 8.0)
		playing.size = Vector2(right_w, 28.0)
	_cycle_row("SkirmishFactionCycle", right_x, row_y + 22.0, right_w)
	_cycle_row("SkirmishDiffCycle", right_x, row_y + 70.0, right_w)
	_cycle_row("SkirmishBotCycle", right_x, row_y + 118.0, right_w)
	var play: Control = find_child("PlayButton", true, false) as Control
	if play != null:
		play.position = Vector2(right_x, row_y + 172.0)
		play.size = Vector2(220, 52)
		play.custom_minimum_size = Vector2(220, 52)
	_hide_old_difficulty()

func _hide_old_difficulty() -> void:
	for hidden_name: String in ["SkirmishDiffEasy", "SkirmishDiffNormal", "SkirmishDiffHard", "SkirmishDiffLabel"]:
		var hidden: CanvasItem = find_child(hidden_name, true, false) as CanvasItem
		if hidden != null:
			hidden.visible = false

func _place_campaign(panel_w: float, panel_h: float, start_y: float) -> void:
	var acts: PackedStringArray = PackedStringArray(["ActI", "ActII", "ActIII"])
	var lists: PackedStringArray = PackedStringArray(["ActIMissions", "ActIIMissions", "ActIIIMissions"])
	var gap: float = 8.0
	var narrow: bool = panel_w < 900.0
	var rail_w: float = panel_w if narrow else panel_w * 0.4
	var left: float = 16.0 if narrow else 28.0
	var list_w: float = maxf(180.0, rail_w - left - 16.0)
	var tab_w: float = (list_w - gap * 2.0) / 3.0
	var act_y: float = start_y
	for i: int in acts.size():
		var act: Control = find_child(acts[i], true, false) as Control
		if act == null:
			continue
		act.add_theme_font_size_override("font_size", 16)
		act.position = Vector2(left + float(i) * (tab_w + gap), act_y)
		act.size = Vector2(tab_w, 38)
		act.custom_minimum_size = Vector2(tab_w, 38)
	var list_top: float = act_y + 44.0
	var diff_y: float = panel_h - 144.0
	var list_h: float = maxf(80.0, diff_y - list_top - 12.0)
	for list_name: String in lists:
		var scroll: ScrollContainer = find_child(list_name, true, false) as ScrollContainer
		if scroll == null:
			continue
		scroll.clip_contents = true
		scroll.position = Vector2(left, list_top)
		scroll.size = Vector2(list_w, list_h)
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if list_h >= 240.0 else ScrollContainer.SCROLL_MODE_AUTO
		if scroll.get_child_count() > 0:
			var inner: VBoxContainer = scroll.get_child(0) as VBoxContainer
			if inner != null:
				inner.custom_minimum_size = Vector2(maxf(80.0, list_w - 8.0), 0)
				inner.add_theme_constant_override("separation", 4)
	for mission_id: String in SMCampaign.ids():
		var row: Button = find_child("Mission_%s" % mission_id, true, false) as Button
		if row == null:
			continue
		row.add_theme_font_size_override("font_size", 16)
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size = Vector2(maxf(80.0, list_w - 8.0), 42)
		var done: Control = row.find_child("Done_%s" % mission_id, true, false) as Control
		if done != null:
			done.position = Vector2(maxf(120.0, list_w - 84.0), 8.0)
	var camp_names: PackedStringArray = PackedStringArray(["CampaignDiffEasy", "CampaignDiffNormal", "CampaignDiffHard"])
	var camp_gap: float = 12.0
	var camp_w: float = (list_w - camp_gap * 2.0) / 3.0
	for slot: int in camp_names.size():
		var choice: Button = find_child(camp_names[slot], true, false) as Button
		if choice == null:
			continue
		choice.clip_text = true
		choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choice.alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice.position = Vector2(left + float(slot) * (camp_w + camp_gap), diff_y)
		choice.size = Vector2(camp_w, 44)
		choice.custom_minimum_size = Vector2(camp_w, 44)
	var camp_label: Control = find_child("CampaignDiffLabel", true, false) as Control
	if camp_label != null:
		camp_label.visible = false

func _place_factions(panel_w: float) -> void:
	var yard_nmrf: Control = find_child("NmrfYardButton", true, false) as Control
	var yard_mvd: Control = find_child("MvdYardButton", true, false) as Control
	if yard_nmrf != null:
		yard_nmrf.position = Vector2(16, 16)
		yard_nmrf.custom_minimum_size = Vector2(minf(220.0, panel_w - 32.0), 48)
	if yard_mvd != null:
		yard_mvd.position = Vector2(16, 76)
		yard_mvd.custom_minimum_size = Vector2(minf(220.0, panel_w - 32.0), 48)

func _box(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
