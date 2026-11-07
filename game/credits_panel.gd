extends Control
## Credits screen on the main menu: a frosted card over the menu art. Esc or Back closes it.

const Glass = preload("res://game/glass.gd")

const LINES: Array[Array] = [
	["MUSIC", "BlackBloc"],
	["", "Yangonite, Ready To Rage Against The Abnormalities, Supayarlat, Past Cracks, Machinesfuture, Humanfuture, Night, Love Drunk, Changes, Not Needed Anymore, Poison, Time"],
	["SOUND EFFECTS", "Kenney (kenney.nl) and other CC0 sources, listed in game/sfx/CREDITS.md"],
	["ENGINE", "Godot Engine, MIT licence"],
	["FONTS", "Noto Sans Myanmar, Noto Sans Thai, and Noto Sans SC, SIL Open Font License 1.1"],
	["RTS CORE", "Godot RTS Advanced, MIT licence"],
]

static func attach(parent: Node) -> Control:
	var panel: Control = (load("res://game/credits_panel.gd") as GDScript).new() as Control
	parent.add_child(panel)
	return panel

func _ready() -> void:
	name = "CreditsPanel"
	visible = false
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_unhandled_input(true)
	Glass.sheet(self, "CreditsGlass", Color(0.03, 0.04, 0.06, 0.3))
	var card: Panel = Panel.new()
	card.name = "CreditsCard"
	Glass.dress(card, 16, Color(0.06, 0.07, 0.1, 0.52), 0, Color(1, 1, 1, 0.32))
	add_child(card)
	var title: Label = Label.new()
	title.name = "CreditsTitle"
	title.text = "CREDITS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	card.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "CreditsList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	for row: Array in LINES:
		if str(row[0]) != "":
			var head: Label = Label.new()
			head.text = str(row[0])
			head.add_theme_font_size_override("font_size", 12)
			head.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
			list.add_child(head)
		var body: Label = Label.new()
		if str(row[0]) == "MUSIC":
			body.name = "CreditsMusic"
		body.text = str(row[1])
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_font_size_override("font_size", 20 if str(row[0]) == "MUSIC" else 14)
		body.add_theme_color_override("font_color", Color(1, 1, 1, 0.94 if str(row[0]) == "MUSIC" else 0.8))
		list.add_child(body)
	var back: Button = Button.new()
	back.name = "CreditsBack"
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 42)
	back.add_theme_font_size_override("font_size", 18)
	preload("res://game/match_exit.gd")._glass_button(back)
	back.pressed.connect(close)
	card.add_child(back)
	resized.connect(_seat)
	_seat()

func open() -> void:
	visible = true
	var parent: Node = get_parent()
	if parent != null:
		parent.move_child(self, parent.get_child_count() - 1)
	_seat()

func close() -> void:
	visible = false
	var host: Node = get_parent()
	if host != null and host.has_method("credits_closed"):
		host.call("credits_closed")

func _seat() -> void:
	var view: Vector2 = size if size.x >= 160.0 and size.y >= 160.0 else Vector2(1280, 720)
	var card: Control = get_node_or_null("CreditsCard") as Control
	if card == null:
		return
	var w: float = minf(720.0, view.x - 32.0)
	var h: float = minf(560.0, view.y - 32.0)
	card.position = ((view - Vector2(w, h)) * 0.5).floor()
	card.size = Vector2(w, h)
	var title: Control = card.get_node_or_null("CreditsTitle") as Control
	if title != null:
		title.position = Vector2(28, 18)
		title.size = Vector2(w - 56.0, 40)
	var scroll: ScrollContainer = card.get_node_or_null("CreditsScroll") as ScrollContainer
	if scroll != null:
		scroll.position = Vector2(28, 64)
		scroll.size = Vector2(w - 56.0, maxf(120.0, h - 132.0))
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if h >= 540.0 else ScrollContainer.SCROLL_MODE_AUTO
	var list: Control = card.find_child("CreditsList", true, false) as Control
	if list != null:
		list.custom_minimum_size = Vector2(maxf(120.0, w - 72.0), 0.0)
	var back: Control = card.get_node_or_null("CreditsBack") as Control
	if back != null:
		back.position = Vector2(28, h - 54.0)
		back.size = Vector2(120, 42)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_B):
		close()
		get_viewport().set_input_as_handled()
