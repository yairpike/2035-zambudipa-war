extends RefCounted
## Graphics, volume, and camera preferences. user:// is the source of truth.
## Web builds also mirror the same record into IndexedDB.

const PATH: String = "user://settings.cfg"
const IDB_JS: String = "(function(payload){try{if(self.localStorage)localStorage.setItem('asean2031_settings',payload);}catch(e){}if(!self.indexedDB)return;var openReq=indexedDB.open('asean2031',1);openReq.onupgradeneeded=function(){if(!openReq.result.objectStoreNames.contains('saves'))openReq.result.createObjectStore('saves');};openReq.onsuccess=function(){var tx=openReq.result.transaction('saves','readwrite');tx.objectStore('saves').put(payload,'settings');};})(%s);"
const PULL_JS: String = "(function(){window.__settingsReady=false;window.__settingsSave='';try{if(self.localStorage){var ls=localStorage.getItem('asean2031_settings');if(ls){window.__settingsSave=String(ls);}}}catch(e){}if(!self.indexedDB){window.__settingsReady=true;return;}var openReq=indexedDB.open('asean2031',1);openReq.onupgradeneeded=function(){if(!openReq.result.objectStoreNames.contains('saves'))openReq.result.createObjectStore('saves');};openReq.onerror=function(){window.__settingsReady=true;};openReq.onsuccess=function(){try{var tx=openReq.result.transaction('saves','readonly');var req=tx.objectStore('saves').get('settings');req.onerror=function(){window.__settingsReady=true;};req.onsuccess=function(){var v=req.result;if(v!=null&&String(v)!=='')window.__settingsSave=String(v);window.__settingsReady=true;};}catch(e){window.__settingsReady=true;}};})();"

static var loaded: bool = false
static var _web_pull: bool = false
static var _web_done: bool = false
static var graphics: String = "high"
static var master: float = 1.0
static var sfx: float = 1.0
## 0.55 is about 5 dB under full scale, inside the 4–6 dB quieter default.
static var music: float = 0.55
static var pan: float = 1.0
static var edge: bool = true
static var difficulty: String = "normal"
static var voice: String = "english"
static var language: String = "english"
static var lock: String = ""

static func voice_ids() -> PackedStringArray:
	return PackedStringArray(["english", "burmese", "mandarin", "thai", "malay"])

static func language_ids() -> PackedStringArray:
	return SMLang.ids()

static func hold(q: String) -> void:
	lock = q

static func quality_for_adapter(adapter: String) -> String:
	var name: String = adapter.to_lower()
	if name.contains("swiftshader") or name.contains("llvmpipe") or name.contains("softpipe") or name.contains("software") or name.contains("lavapipe"):
		return "low"
	return default_graphics()

## Medium on the web, where WebGL pays the most for shadows and full-size frames.
static func default_graphics() -> String:
	return "medium" if OS.has_feature("web") else "high"

static func quality_ids() -> PackedStringArray:
	return PackedStringArray(["low", "medium", "high"])

static func _quality(q: String) -> String:
	return q if quality_ids().has(q) else default_graphics()

static func ensure() -> void:
	if loaded:
		return
	if FileAccess.file_exists(PATH):
		loaded = true
		_read()
		if OS.has_feature("web") and not _web_done:
			pull_web()
		SMLang.apply(language)
		return
	if OS.has_feature("web"):
		var raw: String = str(JavaScriptBridge.eval("(function(){try{return self.localStorage?String(localStorage.getItem('asean2031_settings')||''):'';}catch(e){return'';}})()", true))
		if raw.strip_edges() != "" and _apply_payload_dict(raw):
			loaded = true
			_write()
			SMLang.apply(language)
			return
		pull_web()
		language = SMLang.from_locale(OS.get_locale())
		voice = language
	SMLang.apply(language)
	var adapter: String = _adapter()
	if adapter.strip_edges() == "" and OS.has_feature("web"):
		graphics = default_graphics()
		return
	loaded = true
	graphics = quality_for_adapter(adapter)
	_write()

static func pull_web() -> void:
	if not OS.has_feature("web") or _web_pull or _web_done:
		return
	_web_pull = true
	JavaScriptBridge.eval(PULL_JS, true)

static func poll_web() -> bool:
	if not OS.has_feature("web"):
		return true
	if _web_done:
		return true
	if not _web_pull:
		pull_web()
		return false
	if not bool(JavaScriptBridge.eval("window.__settingsReady===true", true)):
		return false
	_web_done = true
	var raw: String = str(JavaScriptBridge.eval("String(window.__settingsSave||'')", true))
	if raw.strip_edges() != "" and _apply_payload_dict(raw):
		loaded = true
		SMLang.apply(language)
		_write()
	return true

static func _apply_payload_dict(raw: String) -> bool:
	var text: String = raw.strip_edges()
	if text == "":
		return false
	var parsed: Variant = JSON.parse_string(text)
	if parsed is String:
		parsed = JSON.parse_string(str(parsed))
	if not (parsed is Dictionary):
		return false
	var row: Dictionary = parsed as Dictionary
	if row.has("graphics"):
		graphics = _quality(str(row.get("graphics", default_graphics())))
	if row.has("master"):
		master = clampf(float(row.get("master", 1.0)), 0.0, 1.0)
	if row.has("sfx"):
		sfx = clampf(float(row.get("sfx", 1.0)), 0.0, 1.0)
	if row.has("music"):
		music = clampf(float(row.get("music", 0.55)), 0.0, 1.0)
	if row.has("pan"):
		pan = clampf(float(row.get("pan", 1.0)), 0.4, 2.2)
	if row.has("edge"):
		edge = bool(row.get("edge", true))
	if row.has("difficulty"):
		var d: String = str(row.get("difficulty", "normal"))
		difficulty = d if (d == "easy" or d == "hard") else "normal"
	if row.has("language"):
		var l: String = str(row.get("language", "english"))
		language = l if language_ids().has(l) else "english"
	if row.has("voice"):
		var v: String = str(row.get("voice", language))
		voice = v if voice_ids().has(v) else "english"
	return true

static func _adapter() -> String:
	var name: String = RenderingServer.get_video_adapter_name()
	if not OS.has_feature("web"):
		return name
	var js: String = "(function(){try{var c=document.querySelector('canvas');if(!c)return'';var gl=c.getContext('webgl2');if(!gl)return'';var ext=gl.getExtension('WEBGL_debug_renderer_info');if(!ext)return String(gl.getParameter(gl.RENDERER));return String(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL));}catch(e){return'';}})()"
	var extra: String = str(JavaScriptBridge.eval(js))
	if extra == "null" or extra == "<null>":
		extra = ""
	return "%s %s" % [name, extra]

static func reread() -> void:
	loaded = false
	ensure()

static func effective() -> String:
	if lock != "":
		return lock
	ensure()
	return graphics

static func low() -> bool:
	return effective() == "low"

static func high() -> bool:
	return effective() == "high"

static func idb_script() -> String:
	return IDB_JS

static func set_graphics(q: String) -> void:
	ensure()
	graphics = _quality(q)
	_write()

static func set_master(v: float) -> void:
	ensure()
	master = clampf(v, 0.0, 1.0)
	_write()

static func set_sfx(v: float) -> void:
	ensure()
	sfx = clampf(v, 0.0, 1.0)
	_write()

static func set_music(v: float) -> void:
	ensure()
	music = clampf(v, 0.0, 1.0)
	_write()

static func set_pan(v: float) -> void:
	ensure()
	pan = clampf(v, 0.4, 2.2)
	_write()

static func set_edge(on: bool) -> void:
	ensure()
	edge = on
	_write()

static func restore() -> void:
	ensure()
	graphics = default_graphics()
	master = 1.0
	sfx = 1.0
	music = 0.55
	pan = 1.0
	edge = true
	difficulty = "normal"
	voice = language
	_write()

static func voice_folder(id: String) -> String:
	if id == "burmese":
		return "my"
	if id == "mandarin":
		return "zh"
	if id == "thai":
		return "th"
	if id == "malay":
		return "ms"
	return "en"

static func voice_name(id: String) -> String:
	if id == "burmese":
		return "Burmese"
	if id == "mandarin":
		return "Mandarin"
	if id == "thai":
		return "Thai"
	if id == "malay":
		return "Malay"
	return "English"

static func set_voice(id: String) -> void:
	ensure()
	voice = id if voice_ids().has(id) else "english"
	_write()

## Menus, HUD, briefings, and subtitles. The voice follows; the Audio page can set it apart afterwards.
static func set_language(id: String) -> void:
	ensure()
	language = id if language_ids().has(id) else "english"
	voice = language
	SMLang.apply(language)
	_write()

static func set_difficulty(id: String) -> void:
	ensure()
	if id == "easy" or id == "hard":
		difficulty = id
	else:
		difficulty = "normal"
	_write()

static func pace() -> Dictionary:
	ensure()
	if difficulty == "easy":
		return {"income": 0.55, "wave_time": 1.7, "wave_size": 0.55, "react": 1.75, "hp": 0.7, "damage": 0.65}
	if difficulty == "hard":
		return {"income": 2.4, "wave_time": 0.12, "wave_size": 2.0, "react": 0.45, "hp": 1.45, "damage": 1.4}
	return {"income": 1.0, "wave_time": 1.0, "wave_size": 1.0, "react": 1.0, "hp": 1.0, "damage": 1.0}

static func apply_raider(raider: SMRaider) -> void:
	if raider == null:
		return
	var row: Dictionary = pace()
	raider.apply_pace(float(row["income"]), float(row["wave_time"]), float(row["wave_size"]), float(row["react"]))

static func apply_story(story: SMStory) -> void:
	if story == null:
		return
	var row: Dictionary = pace()
	story.prepare_foe(float(row["hp"]), float(row["damage"]))

const SFX_TRIM_DB: float = 4.0

static func cue_db(base: float) -> float:
	ensure()
	if sfx <= 0.001:
		return -80.0
	return base + linear_to_db(sfx)

static func sfx_bus_db() -> float:
	ensure()
	if sfx <= 0.001:
		return -80.0
	return linear_to_db(sfx) - SFX_TRIM_DB

static func music_bus_db() -> float:
	ensure()
	if music <= 0.001:
		return -80.0
	return linear_to_db(music)

## Append a bus in place. add_bus() on the web export reorders the sample
## graph and disconnects Master from the speakers, so every runtime bus uses this.
static func append_bus(bus_name: String, send_to: String = "Master") -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	var count: int = AudioServer.bus_count
	AudioServer.bus_count = count + 1
	AudioServer.set_bus_name(count, bus_name)
	AudioServer.set_bus_send(count, send_to)
	return count

static func apply_audio() -> void:
	ensure()
	var db: float = -80.0
	if master > 0.001:
		db = linear_to_db(master)
	AudioServer.set_bus_volume_db(0, db)
	_limit_master()
	var sfx_i: int = append_bus("SFX", "Master")
	AudioServer.set_bus_volume_db(sfx_i, sfx_bus_db())
	var music_i: int = append_bus("Music", "Master")
	AudioServer.set_bus_volume_db(music_i, music_bus_db())
	AudioServer.set_bus_send(music_i, "Master")

static func _limit_master() -> void:
	var found: int = AudioServer.get_bus_effect_count(0)
	for i: int in found:
		var fx: AudioEffect = AudioServer.get_bus_effect(0, i)
		if fx is AudioEffectLimiter:
			var have: AudioEffectLimiter = fx as AudioEffectLimiter
			have.ceiling_db = -1.0
			have.threshold_db = -1.0
			return
	var cap: AudioEffectLimiter = AudioEffectLimiter.new()
	cap.ceiling_db = -1.0
	cap.threshold_db = -1.0
	AudioServer.add_bus_effect(0, cap)

static func apply_scene(host: Node) -> void:
	apply_audio()
	if host == null:
		return
	var lights: Array[Node] = host.find_children("", "DirectionalLight3D", true, false)
	for node: Node in lights:
		budget_shadow(node as DirectionalLight3D)
	var view: Viewport = host.get_viewport()
	if view != null:
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		view.scaling_3d_scale = render_scale()
	var cam: RTSCamera = host.find_child("Camera", true, false) as RTSCamera
	if cam == null:
		return
	if not cam.has_meta("edge_authored"):
		cam.set_meta("edge_authored", cam.edge_pan_px)
	var authored: float = float(cam.get_meta("edge_authored"))
	cam.pan_speed = pan
	cam.edge_pan_px = authored if edge else 0.0

## Share of the window the 3D view renders at. The HUD always draws at full size.
static func render_scale() -> float:
	var q: String = effective()
	if q == "low":
		return 0.7
	if q == "medium" and OS.has_feature("web"):
		return 0.85
	return 1.0

## One sun casts shadows. High uses two splits, Medium one orthogonal map. Low and web Medium cast none.
## Only units and buildings cast; scenery multimeshes already opt out.
static func budget_shadow(light: DirectionalLight3D) -> void:
	if light == null:
		return
	var q: String = effective()
	var web: bool = OS.has_feature("web")
	light.shadow_enabled = q == "high" or (q == "medium" and not web)
	if not light.shadow_enabled:
		return
	light.shadow_blur = 1.0
	if q == "high" and not web:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = 90.0
		light.directional_shadow_blend_splits = false
	else:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 70.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if q == "high" and not web else 1024, true)

static func _read() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	graphics = _quality(str(cfg.get_value("game", "graphics", default_graphics())))
	master = clampf(float(cfg.get_value("game", "master", 1.0)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("game", "sfx", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("game", "music", 0.55)), 0.0, 1.0)
	pan = clampf(float(cfg.get_value("game", "pan", 1.0)), 0.4, 2.2)
	edge = bool(cfg.get_value("game", "edge", true))
	var stored_diff: String = str(cfg.get_value("game", "difficulty", "normal"))
	if stored_diff == "easy" or stored_diff == "hard":
		difficulty = stored_diff
	else:
		difficulty = "normal"
	var stored_voice: String = str(cfg.get_value("game", "voice", "english"))
	voice = stored_voice if voice_ids().has(stored_voice) else "english"
	var stored_language: String = str(cfg.get_value("game", "language", "english"))
	language = stored_language if language_ids().has(stored_language) else "english"

static func _write() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("game", "graphics", graphics)
	cfg.set_value("game", "master", master)
	cfg.set_value("game", "sfx", sfx)
	cfg.set_value("game", "music", music)
	cfg.set_value("game", "pan", pan)
	cfg.set_value("game", "edge", edge)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "voice", voice)
	cfg.set_value("game", "language", language)
	cfg.save(PATH)
	_mirror()

static func _mirror() -> void:
	if not OS.has_feature("web"):
		return
	var payload: Dictionary = {
		"graphics": graphics,
		"master": master,
		"sfx": sfx,
		"music": music,
		"pan": pan,
		"edge": edge,
		"difficulty": difficulty,
		"voice": voice,
		"language": language,
	}
	var body: String = JSON.stringify(payload)
	JavaScriptBridge.eval(IDB_JS % JSON.stringify(body))
