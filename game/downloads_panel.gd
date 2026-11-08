extends Control
## Installer downloads modal on the main menu: one-click .dmg, .exe, .AppImage, .apk, and .ipa links. Esc or Back closes it.

const Glass = preload("res://game/glass.gd")
const PUBLIC_BASE: String = "https://yairpike.github.io/2035-zambudipa-war/"
const FALLBACK_BASE: String = "https://yairpike.github.io/asean-2031/"

## mib is the size of the file in downloads/, which the installers themselves contain,
## so it is set after a build and checked against the rebuilt files.
const ITEMS: Array[Dictionary] = [
	{
		"id": "macos",
		"node": "DownloadMacOS",
		"label": "macOS (Apple Silicon & Intel) — .dmg",
		"file": "ASEAN-2031-macOS.dmg",
		"mib": 83.0,
	},
	{
		"id": "windows",
		"node": "DownloadWindows",
		"label": "Windows (64-bit) — .exe",
		"file": "ASEAN-2031-Windows.exe",
		"mib": 49.5,
	},
	{
		"id": "linux",
		"node": "DownloadLinux",
		"label": "Linux (x86_64) — .AppImage",
		"file": "ASEAN-2031-Linux-x86_64.AppImage",
		"mib": 49.2,
	},
	{
		"id": "android",
		"node": "DownloadAndroid",
		"label": "Android (ARM64) — .apk",
		"file": "ASEAN-2031-Android.apk",
		"mib": 69.2,
	},
	{
		"id": "ios",
		"node": "DownloadIOS",
		"label": "iOS Sideload (AltStore / SideStore) — .ipa",
		"file": "ASEAN-2031-iOS.ipa",
		"mib": 42.7,
	},
]

static func label_for(row: Dictionary) -> String:
	var mib: float = float(row.get("mib", 0.0))
	var text: String = TranslationServer.translate(str(row["label"]))
	return text if mib <= 0.0 else "%s (%.1f MiB)" % [text, mib]

static var last_requested: String = ""

static func attach(parent: Node) -> Control:
	var panel: Control = (load("res://game/downloads_panel.gd") as GDScript).new() as Control
	parent.add_child(panel)
	return panel

static func page_base() -> String:
	if OS.has_feature("web"):
		var href: String = str(JavaScriptBridge.eval("window.location.href", true))
		var cut: int = href.find("?")
		if cut >= 0:
			href = href.substr(0, cut)
		cut = href.find("#")
		if cut >= 0:
			href = href.substr(0, cut)
		var slash: int = href.rfind("/")
		if slash >= 0:
			href = href.substr(0, slash + 1)
		if href.begins_with("http"):
			return href
	return PUBLIC_BASE

static func url_for(file_name: String) -> String:
	if file_name == "" or file_name.contains("..") or file_name.contains("/") or file_name.contains("\\"):
		return ""
	return page_base() + "downloads/" + file_name

static func trigger_download(file_name: String) -> String:
	var url: String = url_for(file_name)
	if url == "":
		return ""
	last_requested = url
	if DisplayServer.get_name() == "headless":
		return url
	if OS.has_feature("web"):
		var rel: String = "downloads/" + file_name
		var js: String = "try{(function(u,n){var a=document.createElement('a');a.href=u;a.download=n;a.rel='noopener';document.body.appendChild(a);a.click();document.body.removeChild(a);})(%s,%s)}catch(_){window.open(%s,'_blank');}" % [JSON.stringify(rel), JSON.stringify(file_name), JSON.stringify(url)]
		JavaScriptBridge.eval(js, true)
		return url
	OS.shell_open(url)
	return url

func _ready() -> void:
	name = "DownloadsPanel"
	visible = false
	z_index = 30
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_unhandled_input(true)
	Glass.sheet(self, "DownloadsGlass", Color(0.03, 0.04, 0.06, 0.3))
	var card: Panel = Panel.new()
	card.name = "DownloadsCard"
	Glass.dress(card, 16, Color(0.06, 0.07, 0.1, 0.56), 0, Color(1, 1, 1, 0.32))
	add_child(card)
	var title: Label = Label.new()
	title.name = "DownloadsTitle"
	title.text = "DOWNLOAD GAME"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	card.add_child(title)
	var note: Label = Label.new()
	note.name = "DownloadsNote"
	note.text = "First launch downloads game assets automatically."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 0.9))
	card.add_child(note)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "DownloadsList"
	list.add_theme_constant_override("separation", 10)
	card.add_child(list)
	for row: Dictionary in ITEMS:
		var btn: Button = Button.new()
		btn.name = str(row["node"])
		btn.text = label_for(row)
		btn.custom_minimum_size = Vector2(280, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		preload("res://game/match_exit.gd")._glass_button(btn)
		var file_name: String = str(row["file"])
		btn.set_meta("download_file", file_name)
		btn.pressed.connect(_on_download.bind(file_name))
		list.add_child(btn)
	var back: Button = Button.new()
	back.name = "DownloadsBack"
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 44)
	back.add_theme_font_size_override("font_size", 18)
	preload("res://game/match_exit.gd")._glass_button(back)
	back.pressed.connect(close)
	card.add_child(back)
	resized.connect(_seat)
	_seat()

func _on_download(file_name: String) -> void:
	trigger_download(file_name)

func open() -> void:
	visible = true
	var parent: Node = get_parent()
	if parent != null:
		parent.move_child(self, parent.get_child_count() - 1)
	_seat()

func close() -> void:
	visible = false
	var host: Node = get_parent()
	if host != null and host.has_method("downloads_closed"):
		host.call("downloads_closed")

func _seat() -> void:
	var view: Vector2 = size if size.x >= 160.0 and size.y >= 160.0 else Vector2(1280, 720)
	var card: Control = get_node_or_null("DownloadsCard") as Control
	if card == null:
		return
	var w: float = minf(680.0, view.x - 32.0)
	var h: float = minf(540.0, view.y - 32.0)
	card.position = ((view - Vector2(w, h)) * 0.5).floor()
	card.size = Vector2(w, h)
	var title: Control = card.get_node_or_null("DownloadsTitle") as Control
	if title != null:
		title.position = Vector2(28, 16)
		title.size = Vector2(w - 56.0, 44)
	var note: Control = card.get_node_or_null("DownloadsNote") as Control
	if note != null:
		note.position = Vector2(28, 82)
		note.size = Vector2(w - 56.0, 36)
	var list: Control = card.get_node_or_null("DownloadsList") as Control
	if list != null:
		list.position = Vector2(28, 126)
		list.size = Vector2(w - 56.0, maxf(280.0, h - 196.0))
	var back: Control = card.get_node_or_null("DownloadsBack") as Control
	if back != null:
		back.position = Vector2(28, h - 56.0)
		back.size = Vector2(120, 44)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_B):
		close()
		get_viewport().set_input_as_handled()
