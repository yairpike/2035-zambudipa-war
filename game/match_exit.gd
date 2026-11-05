extends Node
## Esc opens the match pause view: frosted glass over the frozen scene, with Resume,
## Restart, the key guide and Quit to menu on the left, the full Settings panel on the
## right, and the now-playing song with a Skip button. N skips the song at any time.
## Single-player matches pause the tree while the view is open; a LAN host keeps running.
## The how-to closes on Esc while it is open. Phones get a menu button that opens the view.

const Glass = preload("res://game/glass.gd")
const Clips = preload("res://game/match_audio.gd")
const Lan = preload("res://game/lan_link.gd")
const NAV_W: float = 228.0

var _shown: bool = false
var _paused_tree: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	call_deferred("_arm")

func _arm() -> void:
	var layer: CanvasLayer = _layer()
	if layer == null:
		return
	if layer.find_child("MissionBoot", true, false) == null:
		var back: Button = Button.new()
		back.name = "MissionBoot"
		back.text = "Boot menu"
		back.position = Vector2(568, 40)
		back.custom_minimum_size = Vector2(160, 36)
		back.z_index = 40
		back.pressed.connect(_to_boot)
		layer.add_child(back)
	if layer.find_child("PauseMenu", true, false) == null:
		_build_pause(layer)
	if layer.find_child("PauseButton", true, false) == null:
		_build_phone_button(layer)

func _build_pause(layer: CanvasLayer) -> void:
	var view: Control = Control.new()
	view.name = "PauseMenu"
	view.visible = false
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.z_index = 60
	layer.add_child(view)
	Glass.sheet(view, "PauseGlass", Color(0.03, 0.04, 0.06, 0.34))
	var card: Panel = Panel.new()
	card.name = "PauseCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	Glass.dress(card, 16, Color(0.06, 0.07, 0.1, 0.5), 0, Color(1, 1, 1, 0.32))
	view.add_child(card)
	var title: Label = Label.new()
	title.name = "PauseTitle"
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	var rule: ColorRect = ColorRect.new()
	rule.name = "PauseRule"
	rule.color = Color(1, 1, 1, 0.16)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rule)
	_pause_row(card, "PauseResume", "Resume", _resume)
	_pause_row(card, "PauseRestart", "Restart", _restart)
	_pause_row(card, "PauseControls", "Key guide", _open_controls)
	_pause_row(card, "PauseQuit", "Quit to menu", _to_boot)
	var caption: Label = Label.new()
	caption.name = "PauseNowCaption"
	caption.text = "NOW PLAYING"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caption)
	var track: Label = Label.new()
	track.name = "PauseTrack"
	track.clip_text = true
	track.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	track.add_theme_font_size_override("font_size", 15)
	track.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(track)
	var skip: Button = _skip_button("PauseSkip")
	card.add_child(skip)
	view.resized.connect(_seat_pause)

func _pause_row(parent: Control, node_name: String, caption: String, call: Callable) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = Vector2(NAV_W - 40.0, 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 19)
	_glass_button(button)
	button.pressed.connect(call)
	parent.add_child(button)

static func _glass_button(button: Button) -> void:
	var states: Dictionary = {
		"normal": Color(1, 1, 1, 0.07),
		"hover": Color(1, 1, 1, 0.16),
		"pressed": Color(1, 1, 1, 0.24),
		"focus": Color(1, 1, 1, 0.12),
	}
	for state: String in states.keys():
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = states[state]
		box.border_color = Color(1, 1, 1, 0.22 if state != "focus" else 0.5)
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		box.content_margin_left = 14
		box.content_margin_right = 14
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))

## Skip control, shared by the pause view and the HUD's now-playing line.
static func _skip_button(node_name: String) -> Button:
	var skip: Button = Button.new()
	skip.name = node_name
	skip.text = "Skip >>  N"
	skip.tooltip_text = "Skip to the next song (N)"
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(96, 30)
	skip.add_theme_font_size_override("font_size", 13)
	var face: Font = ThemeDB.fallback_font
	if face != null:
		skip.add_theme_font_override("font", face)
	_glass_button(skip)
	return skip

func _build_phone_button(layer: CanvasLayer) -> void:
	var button: Button = Button.new()
	button.name = "PauseButton"
	button.text = "☰"
	button.tooltip_text = "Pause and settings"
	button.visible = false
	button.z_index = 45
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52, 52)
	button.size = Vector2(52, 52)
	button.add_theme_font_size_override("font_size", 26)
	var face: Font = ThemeDB.fallback_font
	if face != null:
		button.add_theme_font_override("font", face)
	_glass_button(button)
	button.pressed.connect(open)
	layer.add_child(button)

func _process(_delta: float) -> void:
	var pause: Control = _pause() as Control
	if pause == null:
		return
	if pause.visible != _shown:
		if pause.visible:
			open()
		else:
			_resume()
	_seat_phone_button()
	if _shown:
		_paint_track(pause)
	_wire_hud_skip()

func open() -> void:
	var pause: Control = _pause() as Control
	if pause == null:
		return
	_shown = true
	pause.visible = true
	var layer: Node = pause.get_parent()
	if layer != null:
		layer.move_child(pause, layer.get_child_count() - 1)
	var settings: Control = _settings()
	if settings != null:
		if settings.get_parent() != pause:
			settings.get_parent().remove_child(settings)
			pause.add_child(settings)
		if settings.has_method("embed"):
			settings.call("embed", true, Callable(self, "_resume"))
		settings.visible = true
		settings.z_index = 1
		if settings.has_method("pull"):
			settings.call("pull")
	_seat_pause()
	var resume: Button = pause.find_child("PauseResume", true, false) as Button
	if resume != null and resume.is_inside_tree():
		resume.grab_focus()
	var tree: SceneTree = get_tree()
	if tree != null and not tree.paused and _may_pause():
		tree.paused = true
		_paused_tree = true

func _may_pause() -> bool:
	return not Lan.active_host() and get_parent() != null and get_parent().get_node_or_null("LanRelay") == null

func _seat_pause() -> void:
	var pause: Control = _pause() as Control
	if pause == null:
		return
	var view: Vector2 = pause.size
	if view.x < 32.0:
		view = Vector2(1280, 720)
	var card: Control = pause.get_node_or_null("PauseCard") as Control
	if card == null:
		return
	var w: float = minf(1040.0, view.x - 24.0)
	var h: float = minf(620.0, view.y - 24.0)
	card.position = ((view - Vector2(w, h)) * 0.5).floor()
	card.size = Vector2(w, h)
	var tight: bool = h < 470.0
	var nav: float = NAV_W if w >= 720.0 else 184.0
	var x: float = 20.0
	var y: float = 14.0 if tight else 20.0
	var title: Label = card.get_node_or_null("PauseTitle") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 26 if tight else 34)
		title.position = Vector2(x, y)
		title.size = Vector2(nav - 24.0, 44)
	y += 40.0 if tight else 56.0
	var row_h: float = 38.0 if tight else 44.0
	for node_name: String in ["PauseResume", "PauseRestart", "PauseControls", "PauseQuit"]:
		var row: Control = card.get_node_or_null(node_name) as Control
		if row == null:
			continue
		row.position = Vector2(x, y)
		row.custom_minimum_size = Vector2(nav - 36.0, row_h)
		row.size = Vector2(nav - 36.0, row_h)
		y += row_h + (6.0 if tight else 10.0)
	var caption: Control = card.get_node_or_null("PauseNowCaption") as Control
	var track: Control = card.get_node_or_null("PauseTrack") as Control
	var skip: Control = card.get_node_or_null("PauseSkip") as Control
	var foot: float = h - (78.0 if tight else 96.0)
	foot = maxf(foot, y + 4.0)
	if caption != null:
		caption.position = Vector2(x, foot)
		caption.size = Vector2(nav - 36.0, 16)
	if track != null:
		track.position = Vector2(x, foot + 16.0)
		track.size = Vector2(nav - 36.0, 22)
	if skip != null:
		skip.position = Vector2(x, foot + 42.0)
		skip.size = Vector2(minf(nav - 36.0, 132.0), 30)
	var rule: Control = card.get_node_or_null("PauseRule") as Control
	if rule != null:
		rule.position = Vector2(nav, 18.0)
		rule.size = Vector2(1, h - 36.0)
	var settings: Control = _settings()
	if settings != null and settings.get_parent() == pause:
		settings.position = card.position + Vector2(nav + 12.0, 8.0)
		settings.size = Vector2(w - nav - 24.0, h - 16.0)
		var blurb: CanvasItem = settings.get_node_or_null("SettingsBlurb") as CanvasItem
		if blurb != null:
			blurb.visible = not tight

func _paint_track(pause: Control) -> void:
	var track: Label = pause.find_child("PauseTrack", true, false) as Label
	if track != null:
		var title: String = Clips.current_title()
		track.text = title if title != "" else "—"
	var skip: Button = pause.find_child("PauseSkip", true, false) as Button
	if skip != null:
		skip.disabled = not Clips.can_skip()

## Puts a Skip button beside the HUD's now-playing line once the HUD has built it.
func _wire_hud_skip() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var line: Label = host.find_child("NowPlaying", true, false) as Label
	if line == null or line.get_parent() == null:
		return
	var skip: Button = line.get_parent().get_node_or_null("HudSkip") as Button
	if skip == null:
		skip = _skip_button("HudSkip")
		skip.text = ">>"
		skip.custom_minimum_size = Vector2(34, 22)
		skip.add_theme_font_size_override("font_size", 12)
		skip.pressed.connect(skip_song)
		line.get_parent().add_child(skip)
	skip.visible = line.visible and line.text != "" and Clips.can_skip() and not _shown
	if skip.visible:
		skip.position = Vector2(line.position.x + line.size.x + 6.0, line.position.y - 2.0)
		skip.size = Vector2(34, 22)

func _seat_phone_button() -> void:
	var layer: CanvasLayer = _layer()
	if layer == null:
		return
	var button: Control = layer.get_node_or_null("PauseButton") as Control
	if button == null:
		return
	var hud: SMHud = get_parent().get("hud") as SMHud if get_parent() != null else null
	var phone: bool = hud != null and hud.phone
	button.visible = (phone or DisplayServer.is_touchscreen_available()) and not _shown
	var view: Vector2 = button.get_viewport_rect().size if button.is_inside_tree() else Vector2(1280, 720)
	button.position = Vector2(view.x - 60.0, 40.0) if phone else Vector2(8.0, 40.0)

func skip_song() -> bool:
	var host: Node = get_parent()
	if host == null:
		return false
	return Clips.skip(host)

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_N:
		if skip_song():
			_handled()
		return
	if key.keycode != KEY_ESCAPE:
		return
	var host: Node = get_parent()
	if host == null:
		return
	var settings: Control = _settings()
	if settings != null and settings.visible and not _shown:
		return
	if _shown:
		_resume()
		_handled()
		return
	var guide: CanvasItem = host.find_child("HowToOverlay", true, false) as CanvasItem
	if guide != null and guide.visible:
		guide.visible = false
		_handled()
		return
	if _pause() != null:
		open()
		_handled()
		return
	var boot: BaseButton = host.find_child("MissionBoot", true, false) as BaseButton
	if boot != null:
		boot.pressed.emit()
	else:
		_to_boot()
	_handled()

func _resume() -> void:
	_shown = false
	var pause: CanvasItem = _pause()
	if pause != null:
		pause.visible = false
	var settings: Control = _settings()
	if settings != null and pause != null and settings.get_parent() == pause:
		settings.visible = false
		if settings.has_method("embed"):
			settings.call("embed", false)
		pause.remove_child(settings)
		var layer: Node = (pause as Node).get_parent()
		if layer != null:
			layer.add_child(settings)
	_unpause()

func _unpause() -> void:
	if not _paused_tree:
		return
	_paused_tree = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false

func _open_controls() -> void:
	_resume()
	var host: Node = get_parent()
	if host == null:
		return
	var guide: CanvasItem = host.find_child("HowToOverlay", true, false) as CanvasItem
	if guide != null:
		guide.visible = true

func _restart() -> void:
	_resume()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.reload_current_scene()

func _to_boot() -> void:
	_resume()
	preload("res://game/boot.gd").mark_training_seen()
	Lan.close()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.change_scene_to_file("res://game/boot.tscn")

func _exit_tree() -> void:
	_unpause()
	if Lan.started:
		Lan.close()

func _settings() -> Control:
	var host: Node = get_parent()
	if host == null:
		return null
	return host.find_child("SettingsPanel", true, false) as Control

func _pause() -> CanvasItem:
	var host: Node = get_parent()
	if host == null:
		return null
	return host.find_child("PauseMenu", true, false) as CanvasItem

func _layer() -> CanvasLayer:
	var host: Node = get_parent()
	if host == null:
		return null
	var named: CanvasLayer = host.get_node_or_null("UI") as CanvasLayer
	if named != null:
		return named
	var found: Node = host.find_child("Status", true, false)
	if found != null:
		return found.get_parent() as CanvasLayer
	for child: Node in host.get_children():
		var layer: CanvasLayer = child as CanvasLayer
		if layer != null:
			return layer
	return null

func _handled() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		tree.root.set_input_as_handled()
