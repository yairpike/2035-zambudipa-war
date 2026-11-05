extends Control
## Cinematic still under a lazy Theora loop.
## The main menu crossfades gtfc, nmrf, mvd, and mvd_bunker.
## A faction screen holds that faction's loop. Settings stays on stills.
## Headless runs never open a video. A missing file keeps the still.
## Quiet beds in ui/menu/video/bed/ are not played.

const HOLD: float = 12.0
const FADE: float = 0.65

var _main_reel: PackedStringArray = PackedStringArray([
	"main-menu-loop",
])
var _neutral_reel: PackedStringArray = PackedStringArray([
	"black_market", "loading",
])
var _bg_reel: PackedStringArray = PackedStringArray([
	"main_menu", "gtfc", "nmrf", "mvd", "black_market", "loading",
])

var faction_id: String = ""
var screen: String = "main"
var _spin: float = 0.0
var _aim: Vector2 = Vector2.ZERO
var _art: Texture2D
var _reel_t: float = 0.0
var _reel_i: int = 0
var _players: Array[VideoStreamPlayer] = []
var _show: int = 0
var _fading: bool = false
var _fade: float = 1.0
var _current: String = ""
var _headless: bool = false
var _video_wait: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_headless = DisplayServer.get_name() == "headless"
	_apply_art()
	if not _headless:
		for i: int in 2:
			var player := VideoStreamPlayer.new()
			player.name = "MenuVideo%d" % i
			player.set_anchors_preset(Control.PRESET_TOP_LEFT)
			player.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player.expand = true
			player.position = Vector2.ZERO
			player.size = size
			player.loop = true
			player.volume_db = -80.0
			player.visible = false
			player.modulate.a = 0.0
			add_child(player)
			_players.append(player)
		_sync_video(false)
	var scrim: Control = (load("res://game/menu_scrim.gd") as GDScript).new() as Control
	scrim.name = "MenuScrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	if OS.has_feature("web"):
		for poster: String in _bg_reel:
			if texture(poster) == null:
				_pull("cinematic/%s.webp" % poster, poster)
		_start_web_video()

func set_faction(id: String) -> void:
	faction_id = id
	_apply_art()
	_sync_video(true)

func set_screen(which: String) -> void:
	screen = which
	_apply_art()
	_sync_video(true)

func _apply_art() -> void:
	var stem: String = _stem()
	_art = texture(stem)
	if _art == null and OS.has_feature("web") and stem != "":
		_pull("cinematic/%s.webp" % stem, stem)
	queue_redraw()

func _stem() -> String:
	if faction_id == "gtfc" or faction_id == "nmrf" or faction_id == "mvd" or faction_id == "black_market":
		return faction_id
	if screen == "loading":
		return "loading"
	if screen == "settings":
		if _neutral_reel.is_empty():
			return "black_market"
		return _neutral_reel[_reel_i % _neutral_reel.size()]
	return "main_menu"

func _video_stem() -> String:
	if screen == "settings" or screen == "loading" or _headless:
		return ""
	if faction_id == "gtfc" or faction_id == "nmrf" or faction_id == "mvd" or faction_id == "black_market":
		return faction_id
	if _main_reel.is_empty():
		return ""
	return _main_reel[_reel_i % _main_reel.size()]

func _process(delta: float) -> void:
	_spin += delta * 0.22
	var held: bool = faction_id == "gtfc" or faction_id == "nmrf" or faction_id == "mvd" or faction_id == "black_market"
	if not held and screen != "settings" and screen != "loading":
		_reel_t += delta
		if _reel_t >= HOLD:
			_reel_t = 0.0
			_reel_i += 1
			_apply_art()
			_sync_video(true)
	var view: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var norm := Vector2.ZERO
	if view.x > 1.0 and view.y > 1.0:
		norm = Vector2(mouse.x / view.x, mouse.y / view.y) * 2.0 - Vector2.ONE
	_aim = _aim.lerp(norm, minf(1.0, delta * 3.0))
	_tick_video(delta)
	_fit_videos()
	queue_redraw()

func _sync_video(fade: bool) -> void:
	if OS.has_feature("web"):
		_sync_web_video()
	if _headless or _players.size() < 2:
		return
	var stem: String = _video_stem()
	if stem == "":
		_stop_video()
		return
	if stem == _current:
		return
	var path: String = _video_file(stem)
	if path == "":
		_stop_video()
		return
	var nxt: int = 1 - _show
	var player: VideoStreamPlayer = _players[nxt]
	var stream := VideoStreamTheora.new()
	stream.file = path
	player.stream = stream
	player.play()
	player.visible = true
	player.set_meta("since", Time.get_ticks_msec())
	_current = stem
	var front: VideoStreamPlayer = _players[_show]
	if not fade or not front.visible:
		player.modulate.a = 1.0
		front.visible = false
		front.stop()
		_show = nxt
		_fading = false
		return
	player.modulate.a = 0.0
	_fade = 0.0
	_fading = true
	_show = nxt

func _tick_video(delta: float) -> void:
	if _players.is_empty():
		return
	var front: VideoStreamPlayer = _players[_show]
	if front.visible and front.stream != null and not front.is_playing():
		var since: int = int(front.get_meta("since", 0))
		if Time.get_ticks_msec() - since > 800:
			_stop_video()
			return
	if not _fading:
		return
	_fade += delta / FADE
	var a: float = clampf(_fade, 0.0, 1.0)
	_players[_show].modulate.a = a
	_players[1 - _show].modulate.a = 1.0 - a
	if _fade < 1.0:
		return
	_fading = false
	var back: VideoStreamPlayer = _players[1 - _show]
	back.visible = false
	back.stop()

func _stop_video() -> void:
	_current = ""
	_fading = false
	for player: VideoStreamPlayer in _players:
		player.stop()
		player.visible = false
		player.modulate.a = 0.0

func _video_file(stem: String) -> String:
	if stem == "" or stem.contains("..") or stem.contains("/") or stem.contains("\\"):
		return ""
	var name: String = "%s.ogv" % stem
	var user_path: String = "user://menu/video/%s" % name
	if FileAccess.file_exists(user_path):
		return ProjectSettings.globalize_path(user_path)
	var packed: String = "res://ui/menu/video/%s" % name
	if FileAccess.file_exists(packed):
		return ProjectSettings.globalize_path(packed)
	var roots: PackedStringArray = PackedStringArray()
	var base: String = OS.get_executable_path().get_base_dir()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/ui/menu/video"))
	roots.append(base.path_join("ui/menu/video"))
	roots.append(base.get_base_dir().path_join("Resources/ui/menu/video"))
	for root: String in roots:
		var path: String = root.path_join(name)
		if FileAccess.file_exists(path):
			return path
	if OS.has_feature("web"):
		_pull_video(stem)
	return ""

func _draw() -> void:
	if _art != null:
		_cover(_art)
	else:
		_gradient()

func _gradient() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.014, 0.02))
	draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.62), Color(0.03, 0.036, 0.048))
	draw_rect(Rect2(size.x * 0.55, size.y * 0.2, size.x * 0.45, size.y * 0.5), Color(0.05, 0.045, 0.04, 0.35))

func _cover(tex: Texture2D) -> void:
	var tex_size: Vector2 = tex.get_size()
	if tex_size.x < 1.0 or tex_size.y < 1.0 or size.x < 1.0 or size.y < 1.0:
		return
	var pulse: float = 1.0 + sin(_spin) * 0.012
	var scale: float = maxf(size.x / tex_size.x, size.y / tex_size.y) * pulse
	var drawn: Vector2 = tex_size * scale
	var drift := Vector2(sin(_spin * 0.35) * 12.0, cos(_spin * 0.28) * 6.0)
	var nudge := Vector2(_aim.x * 10.0, _aim.y * 6.0) + drift
	var origin: Vector2 = (size - drawn) * 0.5 + nudge
	draw_texture_rect(tex, Rect2(origin, drawn), false)

func _fit_videos() -> void:
	for player: VideoStreamPlayer in _players:
		if not player.visible:
			continue
		var frame: Texture2D = player.get_video_texture()
		if frame == null:
			continue
		var tw: float = float(frame.get_width())
		var th: float = float(frame.get_height())
		if tw < 2.0 or th < 2.0 or size.x < 2.0 or size.y < 2.0:
			continue
		var scale: float = maxf(size.x / tw, size.y / th)
		var drawn := Vector2(tw * scale, th * scale)
		player.position = (size - drawn) * 0.5
		player.size = drawn

func _pull(file_name: String, slot: String) -> void:
	if not OS.has_feature("web") or file_name.contains("..") or file_name.contains("\\"):
		return
	if not is_inside_tree():
		_pull.call_deferred(file_name, slot)
		return
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.ready.connect(_start_pull.bind(http, file_name, slot), CONNECT_ONE_SHOT)
	add_child.call_deferred(http)

func _start_pull(http: HTTPRequest, file_name: String, slot: String) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_got.bind(http, slot))
	var err: Error = http.request(_page() + "ui/menu/" + file_name)
	if err != OK:
		http.queue_free()

func _got(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, slot: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var image := Image.new()
	var err: Error = image.load_webp_from_buffer(body)
	if err != OK:
		err = image.load_png_from_buffer(body)
	if err != OK:
		err = image.load_jpg_from_buffer(body)
	if err != OK:
		return
	var tex := ImageTexture.create_from_image(image)
	_cache[slot] = tex
	if slot == _stem():
		_art = tex
		queue_redraw()

func _pull_video(stem: String) -> void:
	if _video_wait.has(stem) or stem.contains(".."):
		return
	if not is_inside_tree():
		_pull_video.call_deferred(stem)
		return
	_video_wait[stem] = true
	var http := HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	http.ready.connect(_start_pull_video.bind(http, stem), CONNECT_ONE_SHOT)
	add_child.call_deferred(http)

func _start_pull_video(http: HTTPRequest, stem: String) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		_video_wait.erase(stem)
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_got_video.bind(http, stem))
	var err: Error = http.request(_page() + "ui/menu/video/%s.ogv" % stem)
	if err != OK:
		_video_wait.erase(stem)
		http.queue_free()

func _got_video(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, stem: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_video_wait.erase(stem)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://menu/video"))
	var file := FileAccess.open("user://menu/video/%s.ogv" % stem, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(body)
	file.close()
	if stem == _video_stem():
		_current = ""
		_sync_video(false)

func _page() -> String:
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
	return href

func _start_web_video() -> void:
	if not OS.has_feature("web") or _headless:
		return
	var base: String = _page() + "ui/menu/video/main-menu-loop"
	JavaScriptBridge.eval("try{(function(u){var v=document.getElementById('asean-menu-video');if(!v){v=document.createElement('video');v.id='asean-menu-video';v.muted=true;v.loop=true;v.playsInline=true;v.preload='auto';v.poster=u+'-poster.webp';v.style.display='none';var s1=document.createElement('source');s1.src=u+'.webm';s1.type='video/webm';v.appendChild(s1);var s2=document.createElement('source');s2.src=u+'.mp4';s2.type='video/mp4';v.appendChild(s2);document.body.appendChild(v);v.play().catch(function(){});}})(%s)}catch(_){}" % JSON.stringify(base), true)

func _sync_web_video() -> void:
	if not OS.has_feature("web") or _headless:
		return
	var active: bool = screen == "main" and faction_id == ""
	JavaScriptBridge.eval("try{var v=document.getElementById('asean-menu-video');if(v){if(%s){v.play().catch(function(){});}else{v.pause();}}}catch(_){}" % ("true" if active else "false"), true)

static var _cache: Dictionary = {}
static var skip_export: bool = false

static func texture(stem: String) -> Texture2D:
	if stem == "" or stem.contains("..") or stem.contains("\\"):
		return null
	if _cache.has(stem):
		return _cache[stem] as Texture2D
	for ext: String in ["webp", "png", "jpg"]:
		var bytes: PackedByteArray = _read("cinematic/%s.%s" % [stem, ext])
		if bytes.is_empty():
			continue
		var image := Image.new()
		var err: Error = FAILED
		if ext == "webp":
			err = image.load_webp_from_buffer(bytes)
		elif ext == "png":
			err = image.load_png_from_buffer(bytes)
		else:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			continue
		var tex := ImageTexture.create_from_image(image)
		_cache[stem] = tex
		return tex
	return null

static func _read(file_name: String) -> PackedByteArray:
	if file_name.contains("..") or file_name.begins_with("/") or file_name.contains("\\"):
		return PackedByteArray()
	var packed: String = "res://ui/menu/%s" % file_name
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	if not skip_export:
		var roots: PackedStringArray = PackedStringArray()
		var base: String = OS.get_executable_path().get_base_dir()
		roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/ui/menu"))
		roots.append(base.path_join("ui/menu"))
		roots.append(base.get_base_dir().path_join("Resources/ui/menu"))
		for root: String in roots:
			var path: String = root.path_join(file_name)
			if FileAccess.file_exists(path):
				return FileAccess.get_file_as_bytes(path)
	if OS.has_feature("web"):
		return PackedByteArray()
	var fixture: String = "res://tests/fixtures/ui/menu/%s" % file_name
	if FileAccess.file_exists(fixture):
		return FileAccess.get_file_as_bytes(fixture)
	return PackedByteArray()
