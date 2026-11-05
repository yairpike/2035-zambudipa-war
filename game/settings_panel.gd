extends Control
## Full-screen settings list. Esc, Back, and a gamepad B close it.

const Settings = preload("res://game/match_settings.gd")
const Ground = preload("res://game/ground_view.gd")
const Backdrop = preload("res://game/menu_backdrop.gd")
const Glass = preload("res://game/glass.gd")

var low_button: Button
var high_button: Button
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var pan_slider: HSlider
var edge_box: CheckButton
var voice_value: Button
var language_value: Button
var master_readout: Label
var music_readout: Label
var sfx_readout: Label
var pan_readout: Label
var master_value: Label
var music_value: Label
var sfx_value: Label
var pan_value: Label
var blurb: Label
var highlight: ColorRect
var _syncing: bool = false
var _rows: Array[Control] = []
var _page: String = "video"
## Set while the match Esc view hosts the panel: no backdrop, rail, title or Back row.
var embedded: bool = false
var on_close: Callable = Callable()

static func attach(parent: Node) -> Control:
	var script: GDScript = load("res://game/settings_panel.gd") as GDScript
	var panel: Control = script.new() as Control
	parent.add_child(panel)
	return panel

func _ready() -> void:
	name = "SettingsPanel"
	visible = false
	z_index = 30
	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var art: Control = Backdrop.new() as Control
	art.name = "SettingsBackdrop"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.call("set_screen", "settings")
	art.call("set_faction", "")
	add_child(art)
	var dim: ColorRect = ColorRect.new()
	dim.name = "SettingsDimmer"
	dim.color = Color(0.04, 0.05, 0.07, 0.34)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	if DisplayServer.get_name() != "headless":
		var blur := ColorRect.new()
		blur.name = "SettingsBlur"
		blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blur.set_anchors_preset(Control.PRESET_FULL_RECT)
		blur.color = Color(0, 0, 0, 1)
		blur.material = Glass.material(Color(0.03, 0.04, 0.06, 0.3), Glass.EDGE, 2.6)
		add_child(blur)
		move_child(blur, art.get_index() + 1)
	var rail := ColorRect.new()
	rail.name = "SettingsRail"
	rail.color = Color(0.02, 0.024, 0.034, 0.88)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Glass.live():
		rail.color = Color(0, 0, 0, 1)
		rail.material = Glass.material(Color(0.03, 0.035, 0.05, 0.58))
	add_child(rail)
	highlight = ColorRect.new()
	highlight.name = "SettingsHighlight"
	highlight.color = Color(1, 1, 1, 0.12)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.visible = false
	highlight.position = Vector2(-400, -400)
	add_child(highlight)
	var title: Label = Label.new()
	title.name = "SettingsTitle"
	title.text = "SETTINGS"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)
	_section("SectionGraphics", "GRAPHICS")
	_section("SectionAudio", "AUDIO")
	_section("SectionControls", "CONTROLS")
	_section("SectionGameplay", "GAMEPLAY")
	_section("SectionHud", "HUD")
	var quality: Label = _caption("QualityLabel", "Quality")
	add_child(quality)
	low_button = _choice("GraphicsLow", "Low")
	high_button = _choice("GraphicsHigh", "High")
	low_button.pressed.connect(_pick_graphics.bind("low"))
	high_button.pressed.connect(_pick_graphics.bind("high"))
	low_button.set_meta("blurb", "Low drops trees, rain, fog, and shadows.")
	high_button.set_meta("blurb", "High keeps trees, rain, fog, and shadows.")
	add_child(low_button)
	add_child(high_button)
	master_readout = _caption("MasterLabel", "Master")
	music_readout = _caption("MusicLabel", "Music")
	sfx_readout = _caption("SfxLabel", "SFX")
	pan_readout = _caption("PanLabel", "Pan speed")
	add_child(master_readout)
	add_child(music_readout)
	add_child(sfx_readout)
	add_child(pan_readout)
	master_value = _caption("MasterValue", "100")
	music_value = _caption("MusicValue", "55")
	sfx_value = _caption("SfxValue", "100")
	pan_value = _caption("PanValue", "1.0")
	add_child(master_value)
	add_child(music_value)
	add_child(sfx_value)
	add_child(pan_value)
	master_slider = _slider("MasterVolume", 0.0, 1.0, 0.05)
	music_slider = _slider("MusicVolume", 0.0, 1.0, 0.05)
	sfx_slider = _slider("SfxVolume", 0.0, 1.0, 0.05)
	pan_slider = _slider("PanSpeed", 0.4, 2.2, 0.1)
	master_slider.set_meta("blurb", "Overall loudness.")
	music_slider.set_meta("blurb", "Menu and match songs. The default sits a little under full.")
	sfx_slider.set_meta("blurb", "Menu ticks, weapons, and the radio.")
	pan_slider.set_meta("blurb", "How fast the camera slides.")
	master_slider.value_changed.connect(_on_master)
	music_slider.value_changed.connect(_on_music)
	sfx_slider.value_changed.connect(_on_sfx)
	pan_slider.value_changed.connect(_on_pan)
	add_child(master_slider)
	add_child(music_slider)
	add_child(sfx_slider)
	add_child(pan_slider)
	var voice_label: Label = _caption("VoiceLabel", "Voice language")
	add_child(voice_label)
	voice_value = _choice("VoiceValue", "English")
	voice_value.set_meta("blurb", "English, Burmese, Mandarin, Thai, or Malay. A missing line plays the English take.")
	voice_value.pressed.connect(_cycle_voice.bind(1))
	add_child(voice_value)
	edge_box = CheckButton.new()
	edge_box.name = "EdgePan"
	edge_box.text = "Edge pan"
	edge_box.add_theme_font_size_override("font_size", 18)
	edge_box.add_theme_color_override("font_color", Color(1, 1, 1))
	edge_box.set_meta("blurb", "The camera slides when the pointer nears the screen edge.")
	edge_box.toggled.connect(_on_edge)
	add_child(edge_box)
	var diff_label: Label = _caption("DifficultyLabel", "Difficulty")
	add_child(diff_label)
	var easy: Button = _choice("SettingsDiffEasy", "Easy")
	var normal: Button = _choice("SettingsDiffNormal", "Normal")
	var hard: Button = _choice("SettingsDiffHard", "Hard")
	easy.set_meta("blurb", "A slower enemy, for learning the company.")
	normal.set_meta("blurb", "The intended skirmish and campaign pace.")
	hard.set_meta("blurb", "A faster, tougher enemy.")
	easy.pressed.connect(_pick_difficulty.bind("easy"))
	normal.pressed.connect(_pick_difficulty.bind("normal"))
	hard.pressed.connect(_pick_difficulty.bind("hard"))
	add_child(easy)
	add_child(normal)
	add_child(hard)
	_section("SectionLanguage", "LANGUAGE")
	add_child(_caption("LanguageLabel", "Game language"))
	language_value = _choice("LanguageValue", SMLang.native_name("english"))
	language_value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_value.set_meta("blurb", "Menus, HUD, briefings, and subtitles. Voices follow; the Audio page can change them.")
	language_value.pressed.connect(_cycle_language.bind(1))
	add_child(language_value)
	var hud_note: Label = _caption("HudNote", "Command deck")
	hud_note.set_meta("blurb", "The match keeps the command deck, minimap, and unit card.")
	add_child(hud_note)
	var hud_value: Label = _caption("HudValue", "On")
	add_child(hud_value)
	var close: Button = _choice("SettingsClose", "Back")
	close.set_meta("blurb", "Return to the previous screen.")
	close.pressed.connect(_close)
	add_child(close)
	var restore: Button = _choice("SettingsRestore", "Restore Defaults")
	restore.set_meta("blurb", "High graphics, full volume, voices in the game language, normal difficulty, edge pan on.")
	restore.pressed.connect(_restore)
	add_child(restore)
	blurb = Label.new()
	blurb.name = "SettingsBlurb"
	blurb.text = "Highlight a row to read what it changes."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 18)
	blurb.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(blurb)
	_watch(low_button)
	_watch(high_button)
	_watch(master_slider)
	_watch(music_slider)
	_watch(sfx_slider)
	_watch(voice_value)
	_watch(pan_slider)
	_watch(edge_box)
	_watch(easy)
	_watch(normal)
	_watch(hard)
	_watch(language_value)
	_watch(close)
	_watch(restore)
	_page_tab("SettingsTabVideo", "VIDEO", "video")
	_page_tab("SettingsTabAudio", "AUDIO", "audio")
	_page_tab("SettingsTabControls", "CONTROLS", "controls")
	_page_tab("SettingsTabGameplay", "GAMEPLAY", "gameplay")
	_page_tab("SettingsTabHud", "HUD", "hud")
	_page_tab("SettingsTabLanguage", "LANGUAGE", "language")
	_tag_pages()
	_layout(Vector2(1280, 720))
	resized.connect(_on_resized)

func _on_resized() -> void:
	_layout(size)

func embed(on: bool, closer: Callable = Callable()) -> void:
	embedded = on
	on_close = closer
	for node_name: String in ["SettingsBackdrop", "SettingsDimmer", "SettingsBlur", "SettingsRail", "SettingsTitle", "SettingsClose"]:
		var item: CanvasItem = get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.visible = not on
	if on:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
	else:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
	_layout(size if size.x > 32.0 else Vector2(1280, 720))

func _page_tab(node_name: String, caption: String, page: String) -> void:
	var button: Button = _choice(node_name, caption)
	button.set_meta("page_id", page)
	button.pressed.connect(_show_page.bind(page))
	add_child(button)

func _show_page(page: String) -> void:
	_page = page
	_layout(size if size.x > 32.0 else Vector2(1280, 720))

func _tag_pages() -> void:
	var groups: Dictionary = {
		"video": ["SectionGraphics", "QualityLabel", "GraphicsLow", "GraphicsHigh"],
		"audio": ["SectionAudio", "MasterLabel", "MasterVolume", "MasterValue", "MusicLabel", "MusicVolume", "MusicValue", "SfxLabel", "SfxVolume", "SfxValue", "VoiceLabel", "VoiceValue"],
		"controls": ["SectionControls", "EdgePan", "PanLabel", "PanSpeed", "PanValue"],
		"gameplay": ["SectionGameplay", "DifficultyLabel", "SettingsDiffEasy", "SettingsDiffNormal", "SettingsDiffHard"],
		"hud": ["SectionHud", "HudNote", "HudValue"],
		"language": ["SectionLanguage", "LanguageLabel", "LanguageValue"],
	}
	for page: Variant in groups.keys():
		var names: Array = groups[page]
		for node_name: Variant in names:
			var node: Node = get_node_or_null(str(node_name))
			if node != null:
				node.set_meta("page", str(page))

func _layout(view: Vector2) -> void:
	var narrow: bool = view.x < 900.0 or view.y > view.x + 4.0
	if embedded:
		narrow = view.x < 520.0
	var rail_w: float = view.x if narrow or embedded else view.x * 0.4
	var rail: Control = get_node_or_null("SettingsRail") as Control
	if rail != null:
		rail.position = Vector2.ZERO
		rail.size = Vector2(rail_w, view.y)
	for child: Node in get_children():
		var page: String = str(child.get_meta("page", ""))
		if page == "":
			continue
		var item: CanvasItem = child as CanvasItem
		if item == null:
			continue
		item.visible = page == _page
		if page != _page:
			var parked: Control = child as Control
			if parked != null:
				parked.position = Vector2(-800.0, -800.0)
	var left: float = 20.0
	var nav_w: float = rail_w - 40.0 if narrow else 150.0
	var title: Control = get_node_or_null("SettingsTitle")
	if title != null:
		title.position = Vector2(left, 24.0)
		title.add_theme_font_size_override("font_size", 36 if not narrow else 28)
	var tab_y: float = 8.0 if embedded else 84.0
	var tabs: PackedStringArray = PackedStringArray([
		"SettingsTabVideo", "SettingsTabAudio", "SettingsTabControls", "SettingsTabGameplay", "SettingsTabHud", "SettingsTabLanguage",
	])
	for i: int in tabs.size():
		var tab: Control = get_node_or_null(tabs[i])
		if tab == null:
			continue
		tab.modulate = Color(1, 1, 1, 1.0 if str(tab.get_meta("page_id", "")) == _page else 0.55)
		tab.position = Vector2(left, tab_y + float(i) * 44.0)
		tab.size = Vector2(nav_w, 36)
		tab.custom_minimum_size = Vector2(nav_w, 36)
	var content_x: float = left if narrow else left + nav_w + 16.0
	var content_w: float = maxf(140.0, rail_w - content_x - 16.0)
	var y: float = tab_y + float(tabs.size()) * 44.0 + 12.0 if narrow else tab_y
	var label_w: float = minf(120.0, content_w * 0.34)
	var value_w: float = 52.0
	var value_x: float = content_x + content_w - value_w
	var slider_x: float = content_x + label_w + 8.0
	var slider_w: float = maxf(72.0, value_x - slider_x - 8.0)
	y = _place_section("SectionGraphics", content_x, y, content_w)
	y = _place_row(get_node_or_null("QualityLabel"), content_x, y, label_w)
	_place_value(low_button, slider_x, y - 44.0, 72.0)
	_place_value(high_button, slider_x + 80.0, y - 44.0, 72.0)
	y = _place_section("SectionAudio", content_x, y, content_w)
	y = _place_slider(master_readout, master_slider, master_value, content_x, y, label_w, slider_x, slider_w, value_x)
	y = _place_slider(music_readout, music_slider, music_value, content_x, y, label_w, slider_x, slider_w, value_x)
	y = _place_slider(sfx_readout, sfx_slider, sfx_value, content_x, y, label_w, slider_x, slider_w, value_x)
	y = _place_row(get_node_or_null("VoiceLabel"), content_x, y, maxf(96.0, value_x - content_x - 12.0))
	_place_value(voice_value, value_x, y - 44.0, value_w)
	y = _place_section("SectionControls", content_x, y, content_w)
	y = _place_row(edge_box, content_x, y, content_w)
	y = _place_slider(pan_readout, pan_slider, pan_value, content_x, y, label_w, slider_x, slider_w, value_x)
	y = _place_section("SectionGameplay", content_x, y, content_w)
	y = _place_row(get_node_or_null("DifficultyLabel"), content_x, y, label_w)
	_place_value(get_node_or_null("SettingsDiffEasy"), slider_x, y - 44.0, 64.0)
	_place_value(get_node_or_null("SettingsDiffNormal"), slider_x + 68.0, y - 44.0, 72.0)
	_place_value(get_node_or_null("SettingsDiffHard"), slider_x + 144.0, y - 44.0, 64.0)
	y = _place_section("SectionHud", content_x, y, content_w)
	y = _place_row(get_node_or_null("HudNote"), content_x, y, label_w)
	_place_value(get_node_or_null("HudValue"), value_x, y - 44.0, value_w)
	y = _place_section("SectionLanguage", content_x, y, content_w)
	y = _place_row(get_node_or_null("LanguageLabel"), content_x, y, label_w)
	_place_value(language_value, slider_x, y - 44.0, maxf(120.0, content_x + content_w - slider_x))
	var back: Control = get_node_or_null("SettingsClose")
	var restore: Control = get_node_or_null("SettingsRestore")
	var foot: float = view.y - 52.0
	if back != null:
		back.position = Vector2(left, foot)
		back.size = Vector2(88, 40)
		back.custom_minimum_size = Vector2(88, 40)
	if restore != null:
		restore.position = Vector2(left if embedded else left + 100.0, foot)
		restore.size = Vector2(minf(200.0, rail_w - 140.0), 40)
		restore.custom_minimum_size = Vector2(restore.size.x, 40)
	if blurb != null:
		blurb.position = Vector2(left, foot - 72.0)
		blurb.size = Vector2(maxf(120.0, rail_w - 40.0), 64)
	var card: CanvasItem = get_node_or_null("SettingsCard") as CanvasItem
	if card != null:
		card.visible = false

func _place_slider(label: Control, slider: Control, value: Control, x: float, y: float, label_w: float, slider_x: float, slider_w: float, value_x: float) -> float:
	if label != null and not label.visible:
		return y
	y = _place_row(label, x, y, label_w)
	if slider != null:
		slider.position = Vector2(slider_x, y - 42.0)
		slider.size = Vector2(slider_w, 28)
		slider.custom_minimum_size = Vector2(slider_w, 28)
	if value != null:
		value.position = Vector2(value_x, y - 40.0)
		value.size = Vector2(52, 28)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return y

func _place_section(node_name: String, x: float, y: float, width: float) -> float:
	var label: Control = get_node_or_null(node_name)
	if label == null or not label.visible:
		return y
	label.position = Vector2(x, y)
	label.size = Vector2(width, 22)
	return y + 48.0

func _place_row(node: Control, x: float, y: float, width: float) -> float:
	if node == null or not node.visible:
		return y
	node.position = Vector2(x, y)
	node.size = Vector2(width, 48)
	node.custom_minimum_size = Vector2(node.custom_minimum_size.x, 48)
	return y + 48.0

func _place_value(node: Control, x: float, y: float, width: float) -> void:
	if node == null:
		return
	node.position = Vector2(x, y)
	node.size = Vector2(width, 36)
	node.custom_minimum_size = Vector2(width, 36)

func _section(node_name: String, text: String) -> void:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = "Header"
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(label)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(1, 1, 1, 0.35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.size = Vector2(220, 1)
	rule.position = Vector2(0, 20)
	label.add_child(rule)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE or key.keycode == KEY_B:
			_close()
			_handled()
		elif key.keycode == KEY_UP:
			_move_row(-1)
			_handled()
		elif key.keycode == KEY_DOWN:
			_move_row(1)
			_handled()
		elif key.keycode == KEY_LEFT:
			_nudge(-1)
			_handled()
		elif key.keycode == KEY_RIGHT:
			_nudge(1)
			_handled()
		return
	var joy: InputEventJoypadButton = event as InputEventJoypadButton
	if joy != null and joy.pressed:
		if joy.button_index == JOY_BUTTON_B or joy.button_index == JOY_BUTTON_DPAD_DOWN or joy.button_index == JOY_BUTTON_DPAD_UP:
			if joy.button_index == JOY_BUTTON_B:
				_close()
			elif joy.button_index == JOY_BUTTON_DPAD_DOWN:
				_move_row(1)
			else:
				_move_row(-1)
			_handled()
		elif joy.button_index == JOY_BUTTON_DPAD_LEFT:
			_nudge(-1)
			_handled()
		elif joy.button_index == JOY_BUTTON_DPAD_RIGHT:
			_nudge(1)
			_handled()

func _handled() -> void:
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()

func _move_row(step: int) -> void:
	if _rows.is_empty():
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	var current: int = 0
	for i: int in _rows.size():
		if _rows[i] == owner:
			current = i
	_rows[posmod(current + step, _rows.size())].grab_focus()

func _nudge(step: int) -> void:
	var owner: Control = get_viewport().gui_get_focus_owner()
	var slider: HSlider = owner as HSlider
	if slider != null:
		slider.value = clampf(slider.value + slider.step * float(step), slider.min_value, slider.max_value)
		return
	if owner == low_button or owner == high_button:
		_pick_graphics("high" if step > 0 else "low")
		return
	if owner != null and str(owner.name).begins_with("SettingsDiff"):
		var order: PackedStringArray = PackedStringArray(["easy", "normal", "hard"])
		var at: int = order.find(Settings.difficulty)
		_pick_difficulty(order[posmod(at + step, order.size())])
		return
	if owner == voice_value:
		_cycle_voice(step)
	elif owner == language_value:
		_cycle_language(step)

func pull() -> void:
	_syncing = true
	Settings.ensure()
	low_button.disabled = Settings.graphics == "low"
	high_button.disabled = Settings.graphics == "high"
	low_button.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.graphics == "low" else 0.45))
	high_button.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.graphics == "high" else 0.45))
	master_slider.value = Settings.master
	music_slider.value = Settings.music
	sfx_slider.value = Settings.sfx
	pan_slider.value = Settings.pan
	edge_box.button_pressed = Settings.edge
	_mark_difficulty()
	_paint_voice()
	_paint_language()
	_paint_readouts()
	_syncing = false
	_layout(size if size.x > 32.0 else Vector2(1280, 720))

func _pick_graphics(q: String) -> void:
	if _syncing:
		return
	Settings.set_graphics(q)
	pull()
	_apply()

func _on_master(v: float) -> void:
	if _syncing:
		return
	Settings.set_master(v)
	_paint_readouts()
	_apply()

func _on_music(v: float) -> void:
	if _syncing:
		return
	Settings.set_music(v)
	_paint_readouts()
	_apply()

func _on_sfx(v: float) -> void:
	if _syncing:
		return
	Settings.set_sfx(v)
	_paint_readouts()
	_apply()

func _on_pan(v: float) -> void:
	if _syncing:
		return
	Settings.set_pan(v)
	_paint_readouts()
	_apply()

func _cycle_voice(step: int) -> void:
	if _syncing:
		return
	var order: PackedStringArray = Settings.voice_ids()
	var at: int = order.find(Settings.voice)
	if at < 0:
		at = 0
	Settings.set_voice(order[posmod(at + step, order.size())])
	_paint_voice()
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	clips.call("note_voice", self)

func _cycle_language(step: int) -> void:
	if _syncing:
		return
	var order: PackedStringArray = Settings.language_ids()
	var at: int = maxi(0, order.find(Settings.language))
	Settings.set_language(order[posmod(at + step, order.size())])
	_paint_language()
	_paint_voice()
	var clips: GDScript = load("res://game/match_audio.gd") as GDScript
	clips.call("note_voice", self)

func _paint_language() -> void:
	if language_value != null:
		language_value.text = SMLang.native_name(Settings.language)

func _paint_voice() -> void:
	if voice_value == null:
		return
	voice_value.text = Settings.voice_name(Settings.voice)

func _pick_difficulty(id: String) -> void:
	if _syncing:
		return
	Settings.set_difficulty(id)
	_mark_difficulty()
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("mark_difficulty"):
		scene.call("mark_difficulty")

func _mark_difficulty() -> void:
	var easy: Button = get_node_or_null("SettingsDiffEasy") as Button
	var normal: Button = get_node_or_null("SettingsDiffNormal") as Button
	var hard: Button = get_node_or_null("SettingsDiffHard") as Button
	if easy != null:
		easy.disabled = Settings.difficulty == "easy"
		easy.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.difficulty == "easy" else 0.45))
	if normal != null:
		normal.disabled = Settings.difficulty == "normal"
		normal.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.difficulty == "normal" else 0.45))
	if hard != null:
		hard.disabled = Settings.difficulty == "hard"
		hard.add_theme_color_override("font_color", Color(1, 1, 1, 1 if Settings.difficulty == "hard" else 0.45))

func _on_edge(on: bool) -> void:
	if _syncing:
		return
	Settings.set_edge(on)
	_apply()

func _close() -> void:
	if embedded and on_close.is_valid():
		on_close.call()
		return
	visible = false
	var host: Node = get_parent()
	if host != null and host.has_method("settings_closed"):
		host.call("settings_closed")
		return
	if host != null and host.has_method("_sync_art"):
		host.call("_sync_art")

func _restore() -> void:
	Settings.restore()
	pull()
	_apply()
	var host: Node = get_parent()
	if host != null and host.has_method("mark_difficulty"):
		host.call("mark_difficulty")

func _paint_readouts() -> void:
	master_readout.text = "Master"
	music_readout.text = "Music"
	sfx_readout.text = "SFX"
	pan_readout.text = "Pan speed"
	master_value.text = "%d" % int(round(Settings.master * 100.0))
	music_value.text = "%d" % int(round(Settings.music * 100.0))
	sfx_value.text = "%d" % int(round(Settings.sfx * 100.0))
	pan_value.text = "%.1f" % Settings.pan

func _apply() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	Settings.apply_scene(scene)
	var host: Node3D = scene as Node3D
	if host == null:
		return
	var sight: SMSight = host.get("sight") as SMSight
	if sight == null:
		return
	var cam: RTSCamera = host.get_node_or_null("Camera") as RTSCamera
	Ground.apply_sky(host, sight)
	Ground.cull_props(host, cam)

func _caption(node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	return label

func _choice(node_name: String, text: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	return button

func _slider(node_name: String, lo: float, hi: float, step: float) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.name = node_name
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size = Vector2(120, 36)
	return slider

func _watch(node: Control) -> void:
	if node == null:
		return
	_rows.append(node)
	node.mouse_entered.connect(_show_blurb.bind(node))
	node.focus_entered.connect(_show_blurb.bind(node))

func _show_blurb(node: Control) -> void:
	if blurb == null or node == null:
		return
	var text: String = str(node.get_meta("blurb", ""))
	if text != "":
		blurb.text = text
	if highlight == null:
		return
	highlight.visible = true
	highlight.position = node.position
	var fit: Vector2 = node.size
	if fit.x < 8.0:
		fit = node.custom_minimum_size
	highlight.size = fit
