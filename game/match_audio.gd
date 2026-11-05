extends RefCounted
## Loads music and barks from the served audio/ folder, outside the pack.
## Desktop runs also read res://audio/. A bark is
## barks/<lang>/{unit}_{select|move|attack}_{n}.ogg.
## Missing files leave the procedural cues in place.
## User songs live in music/user/ and are fetched one at a time. They are
## not part of the startup clip list.
## Voice lines live in barks/<lang>/ and announcer/<lang>/<faction>/.
## Settings ids are english, burmese, mandarin, thai, and malay.
## Those map to the folders on disk: en, my, zh, th, and ms.
## A clip with accent_fail, or status removed, is never played.
## Only the selected voice language plays. A failed take stays a tone,
## so English never borrows a Burmese, Thai, Malay, or Mandarin line.
## The page fetches only the selected language.
## Recorded cues live in sfx/<kind>.ogg. sfx/manifest.json can map a
## kind onto another filename in that folder. A missing file stays a tone.

static var _cache: Dictionary = {}
static var _catalog: Dictionary = {}
static var _inflight: Dictionary = {}
static var _buses_ready: bool = false
static var _sfx_files: Dictionary = {}
static var _sfx_read: bool = false
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _rng_ready: bool = false
static var _pool: Array[AudioStreamPlayer] = []
static var _loop_players: Array[AudioStreamPlayer] = []
static var _loop_unit: Array[int] = []
static var _line_at: int = 0
static var _line_text: String = ""
static var _cash_at: int = 0
static var _cash_seen: int = -1
static var _hp_seen: Dictionary = {}
static var _web_open: bool = false
static var _heard: bool = false
static var _held: Array[AudioStreamPlayer] = []
static var _queue: PackedStringArray = PackedStringArray()
static var _at: int = 0
static var _player_name: String = ""
static var now_title: String = ""
static var _shuffled: PackedStringArray = PackedStringArray()
static var _spin: int = 0
static var _said: Dictionary = {}
static var _owner: Node
static var _bark_index: Dictionary = {}
static var _line_index: Dictionary = {}
static var _dialogue_index: Dictionary = {}
static var _dialogue_state: Dictionary = {}
static var _dialogue_ok: Dictionary = {}
static var _dialogue_known: bool = false
static var _dialogue_loading: bool = false
static var _dialogue_gave_up: bool = false
static var _dialogue_stamp: String = ""
static var _index_state: Dictionary = {}
static var _blocked: Dictionary = {}
static var _unit_faction: Dictionary = {}
static var _barks_known: bool = false
static var _lines_known: bool = false
static var _voice_known: bool = false
static var _voice_loading: bool = false
static var _voice_gave_up: bool = false
static var _manifest_left: int = 0
static var _take_n: Dictionary = {}

const Settings = preload("res://game/match_settings.gd")

static func arm(host: Node, mode: String) -> void:
	if host == null or host.get_node_or_null("MatchAudio") != null:
		return
	_buses()
	var node: Node = (load("res://game/match_audio_player.gd") as GDScript).new() as Node
	node.name = "MatchAudio"
	node.set_meta("mode", mode)
	host.add_child(node)
	_owner = host
	note_voice(host)
	_pull_sfx(host)

static func play_menu(host: Node) -> void:
	_buses()
	_begin(host, "MenuMusic", _rels_for("menu"))

## Every map plays the same shuffled rotation. The faction argument is kept for callers.
static func play_faction(host: Node, _faction: String) -> void:
	_buses()
	_begin(host, "FactionMusic", _rotation_from_next())

## Skips to the next song in the match rotation. The menu loop and the stings ignore it.
static func skip(host: Node) -> bool:
	if host == null or _queue.size() < 2 or _player_name != "FactionMusic":
		return false
	var sting: AudioStreamPlayer = host.get_node_or_null("StingMusic") as AudioStreamPlayer
	if sting != null and sting.playing:
		return false
	var player: AudioStreamPlayer = host.get_node_or_null(_player_name) as AudioStreamPlayer
	if player != null:
		player.stop()
		player.set_meta("started", false)
	_at = (_at + 1) % _queue.size()
	_play_current(host)
	return true

static func can_skip() -> bool:
	return _queue.size() > 1 and _player_name == "FactionMusic"

## The shuffled order is kept for the session, so the next match picks up where the last left off.
static func _rotation_from_next() -> PackedStringArray:
	if _shuffled.size() != _rels_for("rotation").size():
		_shuffled = _shuffle(_rels_for("rotation"), "")
	elif _spin >= _shuffled.size():
		_shuffled = _shuffle(_rels_for("rotation"), _shuffled[_shuffled.size() - 1])
		_spin = 0
	var out: PackedStringArray = PackedStringArray()
	for i: int in _shuffled.size():
		out.append(_shuffled[(_spin + i) % _shuffled.size()])
	return out

static func _shuffle(rels: PackedStringArray, avoid_first: String) -> PackedStringArray:
	_seed()
	var out: PackedStringArray = rels.duplicate()
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var held: String = out[i]
		out[i] = out[j]
		out[j] = held
	if out.size() > 1 and out[0] == avoid_first:
		var first: String = out[0]
		out[0] = out[1]
		out[1] = first
	return out

static func play_sting(host: Node, won: bool) -> void:
	_queue = PackedStringArray()
	_at = 0
	now_title = "Victory" if won else "Defeat"
	var music: AudioStreamPlayer = host.get_node_or_null("FactionMusic") as AudioStreamPlayer
	if music != null:
		music.stop()
		music.set_meta("started", false)
	var player: AudioStreamPlayer = _ensure(host, "StingMusic")
	player.bus = "Music"
	var rel: String = "music/victory_sting.ogg" if won else "music/defeat_sting.ogg"
	_assign(player, rel, false)
	_show_title(host)

static func titles_for(list_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for rel: String in _rels_for(list_id):
		out.append(_title_of(rel))
	return out

static func is_retired(rel: String) -> bool:
	return _rels_for("retired").has(rel)

static func current_title() -> String:
	return now_title

static func is_lazy(rel: String) -> bool:
	if rel.begins_with("music/user/") or rel.begins_with("announcer/") or rel.begins_with("dialogue/"):
		return true
	var parts: PackedStringArray = rel.split("/")
	return parts.size() >= 3 and parts[0] == "barks"

static func alert_key(text: String) -> String:
	var line: String = text.to_lower().strip_edges()
	if line == "low power":
		return "low_power"
	if line.ends_with(" built"):
		return "construction_complete"
	if line == "cannot train" or line == "cannot import":
		return "insufficient_funds"
	if line == "build blocked" or line == "scaffold stalled":
		return "cannot_deploy_here"
	if line.begins_with("raid complete") or line == "objective complete":
		return "mission_accomplished"
	if line == "objective failed" or line == "raid stalled":
		return "mission_failed"
	return ""

static func announce_line(host: Node, faction: String, text: String) -> void:
	announce_key(host, faction, alert_key(text))

## Hero dialogue for one mission beat.
## dialogue/<lang>/<mission>/<beat>.ogg plays when the take passes.
## A clip with accent_fail, or status removed, is never played.
## Only the selected voice language plays. A missing take leaves the subtitle.
static func dialogue(host: Node, mission_id: String, beat: String) -> bool:
	if host == null or not _clip_name(mission_id) or not _clip_name(beat):
		return false
	_ensure_dialogue()
	var order: PackedStringArray = _dialogue_order(mission_id)
	for lang: String in order:
		_pull_dialogue(lang)
	if not _dialogue_known:
		return false
	for lang: String in order:
		var rel: String = "dialogue/%s/%s/%s.ogg" % [lang, mission_id, beat]
		if not _accepted(rel) or bool(_blocked.get(rel, false)) or not bool(_dialogue_ok.get(rel, false)):
			continue
		if OS.has_feature("web") and not _ready(rel):
			var names: PackedStringArray = _dialogue_index.get(lang, PackedStringArray())
			if not names.has("%s/%s.ogg" % [mission_id, beat]):
				continue
		elif not _ready(rel):
			continue
		_buses()
		var player: AudioStreamPlayer = _ensure(host, "Dialogue")
		player.bus = "Radio"
		player.volume_db = -2.0
		_assign(player, rel, false)
		if player.stream != null or bool(player.get_meta("fetching", false)):
			player.set_meta("clip", rel)
			return true
	return false

## True once the manifest is in, or the page gave up, and the fetched
## language indexes have arrived. Callers retry until this is true.
static func dialogue_settled(mission_id: String) -> bool:
	if not _dialogue_known:
		return _dialogue_gave_up
	if not OS.has_feature("web"):
		return true
	for lang: String in _dialogue_order(mission_id):
		if str(_dialogue_state.get(lang, "")) != "ready":
			return false
	return true

static func _clip_name(id: String) -> bool:
	if id == "" or id.length() > 40:
		return false
	for i: int in id.length():
		var c: String = id.substr(i, 1)
		var ok: bool = (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"
		if not ok:
			return false
	return true

static func _pull_dialogue(lang: String) -> void:
	if lang == "" or _dialogue_state.has(lang):
		return
	if not OS.has_feature("web"):
		_dialogue_state[lang] = "ready"
		return
	if _owner == null or not is_instance_valid(_owner):
		return
	_dialogue_state[lang] = "loading"
	_fetch_index(lang, "dialogue/%s/index.txt" % lang, "dialogue")

## Only the selected voice language plays. A missing take leaves the subtitle.
static func _dialogue_order(_mission_id: String) -> PackedStringArray:
	var lang: String = _lang()
	if lang != "en" and lang != "my" and lang != "zh" and lang != "th" and lang != "ms":
		lang = "en"
	return PackedStringArray([lang])

static func _ensure_dialogue() -> void:
	var stamp: String = _dialogue_stamp_now()
	if stamp != _dialogue_stamp:
		_dialogue_stamp = stamp
		_dialogue_known = false
		_dialogue_gave_up = false
		_dialogue_loading = false
		_clear_dialogue_marks()
		if stamp != "":
			var text: String = _read_text("dialogue/manifest.json")
			if text != "" and _ingest_dialogue_text(text):
				_dialogue_known = true
				return
			if not OS.has_feature("web"):
				_dialogue_gave_up = true
				return
	if _dialogue_known or _dialogue_loading or _dialogue_gave_up:
		return
	if not OS.has_feature("web") or _owner == null or not is_instance_valid(_owner):
		if not OS.has_feature("web"):
			_dialogue_gave_up = true
		return
	_dialogue_loading = true
	_fetch_dialogue_manifest()

static func _dialogue_stamp_now() -> String:
	var packed: String = "res://audio/dialogue/manifest.json"
	if FileAccess.file_exists(packed):
		return _file_stamp(packed)
	for root: String in _roots():
		var path: String = root.path_join("dialogue/manifest.json")
		if FileAccess.file_exists(path):
			return _file_stamp(path)
	return ""

static func _file_stamp(path: String) -> String:
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	var size: int = handle.get_length()
	handle.close()
	return "%s:%d:%d" % [path, FileAccess.get_modified_time(path), size]

static func _fetch_dialogue_manifest() -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 30.0
	http.accept_gzip = false
	http.name = "DialogueManifest"
	_owner.add_child(http)
	http.request_completed.connect(_got_dialogue_manifest.bind(http))
	var err: Error = http.request(_page_base() + "audio/dialogue/manifest.json")
	if err != OK:
		http.queue_free()
		_dialogue_loading = false
		_dialogue_gave_up = true

static func _got_dialogue_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()
	_dialogue_loading = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_clear_dialogue_marks()
		if _ingest_dialogue_text(body.get_string_from_utf8()):
			_dialogue_known = true
			_dialogue_gave_up = false
			return
	_dialogue_gave_up = true

static func _ingest_dialogue_text(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed as Dictionary
	var clips: Variant = data.get("clips", {})
	if typeof(clips) != TYPE_DICTIONARY:
		return false
	var clip_map: Dictionary = clips as Dictionary
	for lang_key: Variant in clip_map.keys():
		var missions: Variant = clip_map[lang_key]
		if typeof(missions) != TYPE_DICTIONARY:
			continue
		var mission_map: Dictionary = missions as Dictionary
		for mission_key: Variant in mission_map.keys():
			var beats: Variant = mission_map[mission_key]
			if typeof(beats) != TYPE_DICTIONARY:
				continue
			var beat_map: Dictionary = beats as Dictionary
			for beat_key: Variant in beat_map.keys():
				_consider_dialogue(beat_map[beat_key])
	return true

static func _consider_dialogue(take: Variant) -> void:
	if typeof(take) != TYPE_DICTIONARY:
		return
	var body: Dictionary = take as Dictionary
	var file: String = str(body.get("file", ""))
	if file == "" or file == "<null>" or not file.begins_with("dialogue/"):
		return
	_mark_dialogue(file, body)

static func _mark_dialogue(rel: String, take: Dictionary) -> void:
	if not _accepted(rel):
		_blocked[rel] = true
		_dialogue_ok.erase(rel)
		return
	var failed: bool = take.get("accent_fail", false) == true
	var status: String = str(take.get("status", ""))
	if status == "<null>":
		status = ""
	if failed or status == "removed":
		_blocked[rel] = true
		_dialogue_ok.erase(rel)
		return
	_blocked.erase(rel)
	_dialogue_ok[rel] = true

static func _clear_dialogue_marks() -> void:
	var drop: PackedStringArray = PackedStringArray()
	for key: Variant in _dialogue_ok.keys():
		drop.append(str(key))
	for key: Variant in _blocked.keys():
		var rel: String = str(key)
		if rel.begins_with("dialogue/") and not drop.has(rel):
			drop.append(rel)
	for rel: String in drop:
		_dialogue_ok.erase(rel)
		_blocked.erase(rel)

static func announce_key(host: Node, faction: String, key: String) -> void:
	if host == null or key == "":
		return
	var id: String = faction
	## Black Market has no announcer/<lang>/black_market/ files. GTFC lines stand in.
	if id == "black_market":
		var own: String = _best("announcer", "black_market/%s.ogg" % key)
		id = "black_market" if own != "" else "gtfc"
	elif id != "gtfc" and id != "nmrf" and id != "mvd":
		id = "gtfc"
	var now: int = Time.get_ticks_msec()
	var stamp: int = int(_said.get(key, 0))
	if now - stamp < _gap(key):
		return
	_said[key] = now
	_buses()
	var player: AudioStreamPlayer = _ensure(host, "Announcer")
	player.bus = "Radio"
	player.volume_db = -2.0
	var rel: String = _best("announcer", "%s/%s.ogg" % [id, key])
	if rel == "":
		return
	_assign(player, rel, false)

static func note_voice(owner: Node) -> void:
	if owner != null and is_instance_valid(owner):
		_owner = owner
	if _owner != null and not is_instance_valid(_owner):
		_owner = null
	_ensure_voice()
	for lang: String in _wanted_langs():
		if not _index_state.has(lang):
			_pull_index(lang)

static func _gap(key: String) -> int:
	if key == "base_under_attack":
		return 18000
	if key == "unit_lost":
		return 8000
	if key == "building_captured":
		return 6000
	if key == "superweapon_ready":
		return 20000
	if key == "superweapon_launched":
		return 4000
	if key == "enemy_superweapon_detected":
		return 25000
	return 1600

static func tick(host: Node) -> void:
	if host == null or _queue.is_empty():
		return
	var sting: AudioStreamPlayer = host.get_node_or_null("StingMusic") as AudioStreamPlayer
	if sting != null and sting.playing:
		return
	var player: AudioStreamPlayer = host.get_node_or_null(_player_name) as AudioStreamPlayer
	if player == null or bool(player.get_meta("fetching", false)) or player.playing:
		_show_title(host)
		return
	if not bool(player.get_meta("started", false)):
		return
	_at = (_at + 1) % _queue.size()
	_play_current(host)

static func cue_clip(kind: String) -> AudioStream:
	var resolved: String = _alias(kind)
	if resolved == "":
		return null
	var files: PackedStringArray = _files_of(resolved)
	if files.is_empty():
		return _stream("sfx/%s.ogg" % resolved)
	_seed()
	return _stream(files[_rng.randi() % files.size()])

static func weapon_kind(weapon: String) -> String:
	if weapon == "rifle" or weapon == "carbine" or weapon == "smg" or weapon == "stinger":
		return "weapon_rifle"
	if weapon == "mg" or weapon == "pintle" or weapon == "bow_gun" or weapon == "cab_gun" or weapon == "deck_gun" or weapon == "autocannon" or weapon == "saw":
		return "weapon_mg"
	if weapon == "cannon" or weapon == "hammer" or weapon == "blade":
		return "weapon_cannon"
	if weapon == "tube" or weapon == "mortar" or weapon == "torch" or weapon == "howl":
		return "weapon_artillery"
	if weapon == "lance" or weapon == "rocket" or weapon == "shaped_charge" or weapon == "warhead":
		return "weapon_rocket"
	if weapon == "missile" or weapon == "bomblet" or weapon == "swarm":
		return "weapon_missile"
	if weapon == "torpedo":
		return "weapon_torpedo"
	if weapon == "laser" or weapon == "welder" or weapon == "hook" or weapon == "camera":
		return "weapon_laser"
	if weapon == "dart":
		return "weapon_freeze_ray"
	if weapon == "mast":
		return "weapon_flak"
	if weapon == "":
		return ""
	return "weapon_rifle"

static func impact_kind(amount: float) -> String:
	if amount >= 24.0:
		return "impact_large"
	if amount >= 12.0:
		return "impact_medium"
	return "impact_small"

static func move_kind(role: String, loco: String, unit_id: String) -> String:
	if unit_id == "su30" or unit_id == "ch4":
		return ""
	if loco == "air" or role == "air":
		return "move_helicopter"
	if role == "drone" or (loco == "amphibious" and role != "infantry" and role != "boat"):
		return "move_hover"
	if role == "boat" or loco == "naval":
		return "move_boat_engine"
	if role == "armor" or role == "vehicle" or role == "artillery" or role == "hauler":
		return "move_tank_treads"
	if role == "infantry":
		return "move_footsteps"
	return ""

static func ability_kind(label: String) -> String:
	var text: String = label.to_lower().replace(".", "").replace("-", " ")
	if text.contains("black hole") or text.contains("maelstrom"):
		return "ability_black_hole"
	if text.contains("emp") or text.contains("blackout"):
		return "ability_emp"
	if text.contains("shield") or text.contains("barrier") or text.contains("dome") or text.contains("aegis"):
		return "ability_shield"
	if text.contains("shrink"):
		return "weapon_shrink_ray"
	return "ability_generic"

static func cap_for(kind: String) -> int:
	if kind.begins_with("move_"):
		return 2
	if kind.begins_with("ui_"):
		return 2
	if kind.begins_with("superweapon_"):
		return 1
	return 3

static func voices_of(kind: String) -> int:
	var n: int = 0
	for player: AudioStreamPlayer in _pool:
		if is_instance_valid(player) and player.playing and str(player.get_meta("sfx_kind", "")) == kind:
			n += 1
	return n

static func play_kind(host: Node, kind: String, at: Vector3 = Vector3.INF) -> void:
	_buses()
	var resolved: String = _alias(kind)
	if host == null or resolved == "":
		return
	if _too_far(host, at):
		return
	if voices_of(resolved) >= cap_for(resolved):
		return
	var stream: AudioStream = cue_clip(resolved)
	if stream == null:
		return
	var player: AudioStreamPlayer = _take_player(host)
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = _jitter()
	player.volume_db = Settings.cue_db(_hear_db(host, at))
	player.set_meta("sfx_kind", resolved)
	player.play()

static func _heard_at(unit: RTSUnit) -> Vector3:
	if unit.is_inside_tree():
		return unit.global_position
	return unit.position

static func on_shot(host: Node, unit: RTSUnit, _target: RTSUnit) -> void:
	if unit == null:
		return
	var kind: String = weapon_kind(str(unit.get_meta("weapon", "")))
	var at: Vector3 = _heard_at(unit)
	play_kind(host, kind, at)
	if kind == "weapon_torpedo":
		play_kind(host, "water_splash", at)

static func on_hit(host: Node, unit: RTSUnit, amount: float) -> void:
	if unit == null or amount <= 0.0:
		return
	var at: Vector3 = _heard_at(unit)
	play_kind(host, impact_kind(amount), at)
	if _on_water(host, unit):
		play_kind(host, "water_splash", at)

static func on_death(host: Node, unit: RTSUnit) -> void:
	if host == null or unit == null:
		return
	var role: String = str(unit.get_meta("role", ""))
	var kind: String = "impact_medium"
	if role == "armor" or role == "vehicle" or role == "air" or role == "drone" or role == "boat" or role == "artillery":
		kind = "impact_large"
	play_kind(host, kind, _heard_at(unit))

static func on_defense(host: Node, building_id: String, at: Vector3) -> void:
	play_kind(host, defense_kind(building_id), at)

static func defense_kind(building_id: String) -> String:
	if building_id == "slag_pillbox":
		return "weapon_rifle"
	if building_id == "flak_slag_mast":
		return "weapon_flak"
	if building_id == "spectrum_prism":
		return "weapon_laser"
	if building_id == "wave_force":
		return "weapon_cannon"
	if building_id == "defender_vx":
		return "weapon_mg"
	return "weapon_mg"

static func on_spawn(host: Node, unit: RTSUnit) -> void:
	if unit == null or unit.team != SMPointer.PLAYER:
		return
	play_kind(host, "unit_spawn", _heard_at(unit))

static func on_line(host: Node, text: String) -> void:
	var line: String = text.to_lower()
	var now: int = Time.get_ticks_msec()
	if line == _line_text and now - _line_at < 120:
		return
	_line_text = line
	_line_at = now
	var kind: String = ""
	if line.ends_with(" built") or line == "wharf unpacked":
		kind = "build_complete"
	elif line == "hub placed" or line.ends_with(" placed"):
		kind = "build_place"
	elif line.begins_with("wharf level") or line == "upgraded":
		kind = "build_complete"
	elif line == "repairing":
		kind = "repair"
	elif line.begins_with("sold"):
		kind = "sell"
	elif line == "low power":
		kind = "power_down"
	elif line == "cancelled":
		kind = "ui_back"
	elif line == "build blocked" or line == "cannot sell" or line == "nothing to repair" or line == "superweapon cooling" or line == "no target" or line == "scaffold stalled":
		kind = "ui_error"
	if kind != "":
		play_kind(host, kind)

static func on_super(host: Node, key: String) -> void:
	if key == "superweapon_ready":
		play_kind(host, "superweapon_charge")
	elif key == "superweapon_launched" or key == "enemy_superweapon_detected":
		play_kind(host, "superweapon_launch")

static func drive(host: Node) -> void:
	if host == null:
		return
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return
	_cash(host, field)
	_collapse(host)
	_loops(host, field)

static func _alias(kind: String) -> String:
	if not _cue_id(kind):
		return ""
	if kind == "ui" or kind == "attack" or kind == "move" or kind == "select":
		return "ui_click"
	if kind == "ability" or kind == "ability_cast":
		return "ability_generic"
	return kind

static func _cue_id(kind: String) -> bool:
	return kind != "" and not kind.contains("/") and not kind.contains(".") and not kind.contains("\\")

static func _files_of(kind: String) -> PackedStringArray:
	_load_sfx_map()
	var got: Variant = _sfx_files.get(kind, null)
	if got is PackedStringArray:
		return got as PackedStringArray
	return PackedStringArray()

static func _kind_from(file: String) -> String:
	var stem: String = file.get_file().get_basename()
	var cut: int = stem.rfind("_")
	if cut <= 0:
		return ""
	var tail: String = stem.substr(cut + 1)
	if not tail.is_valid_int():
		return ""
	var kind: String = stem.substr(0, cut)
	if not _cue_id(kind):
		return ""
	return kind

static func _remember_variant(file: String) -> void:
	var kind: String = _kind_from(file)
	if kind == "":
		return
	var rel: String = "sfx/%s" % file.get_file()
	var got: Variant = _sfx_files.get(kind, null)
	var list: PackedStringArray = PackedStringArray()
	if got is PackedStringArray:
		list = got
	if list.has(rel):
		return
	list.append(rel)
	_sfx_files[kind] = list

static func _scan_sfx_dir(dir: String) -> void:
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return
	for name: String in access.get_files():
		if name.ends_with(".ogg") and not name.ends_with(".conflict.ogg"):
			_remember_variant(name)

static func _load_sfx_map() -> void:
	if _sfx_read:
		return
	_sfx_read = true
	_scan_sfx_dir("res://audio/sfx")
	for root: String in _roots():
		_scan_sfx_dir(root.path_join("sfx"))
	var bytes: PackedByteArray = _read_loose("sfx/manifest.json")
	if bytes.is_empty():
		return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var book: Dictionary = parsed as Dictionary
	var kinds: Variant = book.get("kinds", {})
	if typeof(kinds) != TYPE_DICTIONARY:
		return
	var table: Dictionary = kinds as Dictionary
	for key: Variant in table.keys():
		var kind: String = str(key)
		if not _cue_id(kind):
			continue
		var row: Variant = table[key]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var files: Variant = (row as Dictionary).get("files", [])
		if typeof(files) != TYPE_ARRAY:
			continue
		var list: PackedStringArray = PackedStringArray()
		for item: Variant in files as Array:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var file: String = str((item as Dictionary).get("file", "")).get_file()
			if file.ends_with(".ogg") and not file.contains("..") and not file.contains("/") and not file.contains("\\"):
				list.append("sfx/%s" % file)
		if not list.is_empty():
			_sfx_files[kind] = list

static func _read_loose(rel: String) -> PackedByteArray:
	if rel.contains("..") or rel.begins_with("/") or rel.contains("\\"):
		return PackedByteArray()
	var packed: String = "res://audio/%s" % rel
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	for root: String in _roots():
		var path: String = root.path_join(rel)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()

static func _seed() -> void:
	if _rng_ready:
		return
	_rng_ready = true
	_rng.randomize()

static func _jitter() -> float:
	_seed()
	return 0.97 + _rng.randf() * 0.06

static func _take_player(host: Node) -> AudioStreamPlayer:
	var live: Array[AudioStreamPlayer] = []
	var idle: AudioStreamPlayer = null
	for player: AudioStreamPlayer in _pool:
		if not is_instance_valid(player):
			continue
		live.append(player)
		if idle == null and not player.playing:
			idle = player
	_pool = live
	if idle != null:
		return idle
	if _pool.size() >= 12:
		return null
	var made: AudioStreamPlayer = AudioStreamPlayer.new()
	made.name = "SfxPool%d" % _pool.size()
	made.bus = "SFX"
	host.add_child(made)
	_pool.append(made)
	return made

static func _too_far(host: Node, at: Vector3) -> bool:
	if at == Vector3.INF:
		return false
	return _hear_dist(host, at) > 42.0

static func _hear_db(host: Node, at: Vector3) -> float:
	if at == Vector3.INF:
		return -8.0
	var dist: float = _hear_dist(host, at)
	var gain: float = clampf(1.0 - dist / 42.0, 0.18, 1.0)
	return linear_to_db(gain) - 8.0

static func _hear_dist(host: Node, at: Vector3) -> float:
	var cam: RTSCamera = host.get_node_or_null("Camera") as RTSCamera
	var ear: Vector3 = cam.focus if cam != null else Vector3.ZERO
	return at.distance_to(ear)

static func _cash(host: Node, field: SMPointer) -> void:
	var side: SMSide = host.get("side") as SMSide
	if side == null or side.yard == null or side.yard.economy == null:
		return
	var now_credits: int = side.yard.economy.credits(SMPointer.PLAYER)
	if _cash_seen < 0:
		_cash_seen = now_credits
		return
	if now_credits <= _cash_seen:
		_cash_seen = now_credits
		return
	_cash_seen = now_credits
	var now: int = Time.get_ticks_msec()
	if now - _cash_at < 450:
		return
	_cash_at = now
	play_kind(host, "ui_cash_tick")

static func _collapse(host: Node) -> void:
	var side: SMSide = host.get("side") as SMSide
	if side != null:
		_watch_yard(host, side.yard, false)
	var raider: SMRaider = host.get("raider") as SMRaider
	if raider != null:
		_watch_yard(host, raider.yard, true)

static func _watch_yard(host: Node, yard: SMBuildYard, enemy: bool) -> void:
	if yard == null:
		return
	var yard_key: String = str(yard.get_instance_id())
	for id: StringName in yard.finished:
		var hp: float = float(yard.structure_hp.get(id, -1.0))
		var key: String = "%s:%s" % [yard_key, str(id)]
		var prev: float = float(_hp_seen.get(key, hp))
		_hp_seen[key] = hp
		if prev > 0.5 and hp <= 0.0:
			var at: Vector3 = yard.position_of(id)
			play_kind(host, "building_collapse", at)
			if enemy:
				play_kind(host, "impact_large", at)

static func _on_water(host: Node, unit: RTSUnit) -> bool:
	var role: String = str(unit.get_meta("role", ""))
	var loco: String = str(unit.get_meta("locomotion", ""))
	if role == "boat" or loco == "naval" or loco == "amphibious":
		return true
	if host == null:
		return false
	var field: SMPointer = host.get("field") as SMPointer
	if field == null or field.domain == null:
		return false
	var at: Vector3 = unit.global_position if unit.is_inside_tree() else unit.position
	var domain: int = field.domain.domain_at(at)
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP

static func _compact_loops() -> void:
	var players: Array[AudioStreamPlayer] = []
	var units: Array[int] = []
	for i: int in _loop_players.size():
		if not is_instance_valid(_loop_players[i]):
			continue
		players.append(_loop_players[i])
		units.append(_loop_unit[i] if i < _loop_unit.size() else 0)
	_loop_players = players
	_loop_unit = units

static func _loops(host: Node, field: SMPointer) -> void:
	_compact_loops()
	var moving: Array[RTSUnit] = []
	var dist_of: Dictionary = {}
	for u: RTSUnit in field.units:
		if not is_instance_valid(u) or not u.is_alive() or bool(u.get_meta("frozen", false)):
			continue
		var going: bool = not u.path.is_empty()
		var unit_id: String = str(u.unit_type)
		if (unit_id == "su30" or unit_id == "ch4") and going and not bool(u.get_meta("jet_spoke", false)):
			u.set_meta("jet_spoke", true)
			play_kind(host, "move_jet_flyby", u.global_position)
		if not going:
			u.set_meta("jet_spoke", false)
			continue
		var kind: String = move_kind(str(u.get_meta("role", "")), str(u.get_meta("locomotion", "")), unit_id)
		if kind == "":
			continue
		var dist: float = _hear_dist(host, u.global_position)
		if dist > 42.0:
			continue
		u.set_meta("move_kind", kind)
		dist_of[u.get_instance_id()] = dist
		moving.append(u)
	moving.sort_custom(func(a: RTSUnit, b: RTSUnit) -> bool:
		return float(dist_of.get(a.get_instance_id(), 999.0)) < float(dist_of.get(b.get_instance_id(), 999.0))
	)
	var keep: Array[int] = []
	var per_kind: Dictionary = {}
	for u: RTSUnit in moving:
		if keep.size() >= 4:
			break
		var kind: String = str(u.get_meta("move_kind", ""))
		var have: int = int(per_kind.get(kind, 0))
		if have >= cap_for(kind):
			continue
		per_kind[kind] = have + 1
		keep.append(u.get_instance_id())
		_hold_loop(host, u, kind)
	for i: int in _loop_unit.size():
		if keep.has(_loop_unit[i]):
			continue
		var player: AudioStreamPlayer = _loop_players[i]
		if is_instance_valid(player):
			player.stop()
		_loop_unit[i] = 0

static func _hold_loop(host: Node, unit: RTSUnit, kind: String) -> void:
	_buses()
	var id: int = unit.get_instance_id()
	var slot: int = _loop_unit.find(id)
	if slot < 0:
		slot = _loop_unit.find(0)
	if slot < 0 and _loop_players.size() < 4:
		var made: AudioStreamPlayer = AudioStreamPlayer.new()
		made.name = "SfxLoop%d" % _loop_players.size()
		made.bus = "SFX"
		host.add_child(made)
		_loop_players.append(made)
		_loop_unit.append(0)
		slot = _loop_players.size() - 1
	if slot < 0:
		return
	var player: AudioStreamPlayer = _loop_players[slot]
	if str(player.get_meta("sfx_kind", "")) != kind or not player.playing:
		var stream: AudioStream = cue_clip(kind)
		if stream == null:
			return
		var looping: AudioStream = stream.duplicate()
		if looping is AudioStreamOggVorbis:
			(looping as AudioStreamOggVorbis).loop = true
		player.stream = looping
		player.pitch_scale = _jitter()
		player.set_meta("sfx_kind", kind)
		player.play()
	player.volume_db = Settings.cue_db(_hear_db(host, unit.global_position) - 6.0)
	_loop_unit[slot] = id

static func _pull_sfx(host: Node) -> void:
	if not OS.has_feature("web") or host == null:
		return
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 20.0
	http.accept_gzip = false
	http.name = "SfxIndex"
	host.add_child(http)
	http.request_completed.connect(_got_sfx.bind(http, host))
	var err: Error = http.request(_page_base() + "audio/sfx/index.txt")
	if err != OK:
		http.queue_free()

static func _got_sfx(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, host: Node) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not is_instance_valid(host):
		return
	for line: String in body.get_string_from_utf8().split("\n"):
		var name: String = line.strip_edges()
		if not name.ends_with(".ogg") or name.contains("..") or name.contains("/"):
			continue
		_remember_variant(name)
		prefetch(host, "sfx/%s" % name)

static func clip_for(unit_id: String, event: String) -> AudioStream:
	if unit_id == "":
		return null
	var file_event: String = event
	if event == "hurt":
		file_event = "under_attack"
	if file_event != "select" and file_event != "move" and file_event != "attack" and file_event != "ability" and file_event != "under_attack":
		return null
	var found: PackedStringArray = _variants(unit_id, file_event)
	if found.is_empty():
		return null
	var key: String = "%s:%s" % [unit_id, file_event]
	var which: int = int(_take_n.get(key, 0))
	_take_n[key] = which + 1
	return _stream(found[which % found.size()])

static func page_base() -> String:
	return _page_base()

static func remember(rel: String) -> void:
	if not rel.ends_with(".ogg") or rel.contains("..") or rel.begins_with("/"):
		return
	_catalog[rel] = true

static func prefetch(owner: Node, rel: String) -> void:
	if owner == null or not OS.has_feature("web") or _cache.has(rel) or _inflight.has(rel):
		return
	if not rel.ends_with(".ogg") or rel.contains("..") or rel.begins_with("/"):
		return
	_inflight[rel] = true
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 60.0
	http.accept_gzip = false
	http.name = "ClipFetch"
	owner.add_child(http)
	http.request_completed.connect(_prefetched.bind(http, rel))
	var err: Error = http.request(_page_base() + "audio/" + rel)
	if err != OK:
		_inflight.erase(rel)
		http.queue_free()

static func unlock() -> void:
	_web_open = true
	if OS.has_feature("web"):
		var state: String = str(JavaScriptBridge.eval("window.__aseanUnlockAudio ? window.__aseanUnlockAudio() : 'missing'", true))
		print("audio context state: ", state)
	_release_held()

static func pump() -> void:
	if not OS.has_feature("web") or not _web_open:
		return
	if not _heard:
		var state: String = str(JavaScriptBridge.eval("window.__aseanAudioQuiet ? window.__aseanAudioQuiet() : 'none'", true))
		if state != "running":
			JavaScriptBridge.eval("window.__aseanUnlockAudio && window.__aseanUnlockAudio()", true)
			return
		_heard = true
		Settings.apply_audio()
	_release_held()

static func _release_held() -> void:
	if not _audible():
		return
	var pending: Array[AudioStreamPlayer] = []
	for held: AudioStreamPlayer in _held:
		pending.append(held)
	_held.clear()
	for pending_player: AudioStreamPlayer in pending:
		if is_instance_valid(pending_player):
			_start(pending_player)

static func color_voice(sfx: SMSfx) -> void:
	_buses()
	if sfx != null and sfx.voice != null:
		sfx.voice.bus = "Radio"

static func _begin(host: Node, node_name: String, rels: PackedStringArray) -> void:
	for other: String in ["MenuMusic", "FactionMusic"]:
		if other == node_name:
			continue
		var other_player: AudioStreamPlayer = host.get_node_or_null(other) as AudioStreamPlayer
		if other_player != null:
			other_player.stop()
			other_player.set_meta("started", false)
	_queue = rels
	_at = 0
	_player_name = node_name
	_play_current(host)

static func _play_current(host: Node) -> void:
	if host == null or _queue.is_empty():
		return
	var rel: String = _queue[_at]
	now_title = _title_of(rel)
	if _player_name == "FactionMusic":
		var spot: int = _shuffled.find(rel)
		if spot >= 0:
			_spin = spot + 1
	var player: AudioStreamPlayer = _ensure(host, _player_name)
	player.bus = "Music"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	_assign(player, rel, _queue.size() == 1)
	_show_title(host)
	var nxt: String = _queue[(_at + 1) % _queue.size()]
	if nxt != rel and is_lazy(nxt):
		prefetch(host, nxt)

static func _show_title(host: Node) -> void:
	if host == null:
		return
	var label: Label = host.find_child("NowPlaying", true, false) as Label
	if label != null:
		label.text = now_title

## "menu" is Yangonite on a loop. "rotation" is the twelve user songs, shuffled per session
## and shared by every map. "retired" is the generated menu and faction loops: never played
## and never fetched. The victory and defeat stings are separate and stay.
static func _rels_for(list_id: String) -> PackedStringArray:
	match list_id:
		"menu":
			return PackedStringArray(["music/user/yangonite.ogg"])
		"rotation":
			return PackedStringArray([
				"music/user/yangonite.ogg",
				"music/user/ready-to-rage-against-the-abnormalities.ogg",
				"music/user/supayarlat.ogg",
				"music/user/past-cracks.ogg",
				"music/user/machinesfuture.ogg",
				"music/user/humanfuture.ogg",
				"music/user/night.ogg",
				"music/user/love-drunk.ogg",
				"music/user/changes.ogg",
				"music/user/not-needed-anymore.ogg",
				"music/user/poison.ogg",
				"music/user/time.ogg",
			])
		"retired":
			return PackedStringArray([
				"music/menu.ogg",
				"music/gtfc.ogg",
				"music/nmrf.ogg",
				"music/mvd.ogg",
				"music/black_market.ogg",
			])
	return PackedStringArray()

static func _title_of(rel: String) -> String:
	match rel:
		"music/menu.ogg":
			return "Menu"
		"music/gtfc.ogg":
			return "GTFC"
		"music/nmrf.ogg":
			return "NMRF"
		"music/mvd.ogg":
			return "MVD"
		"music/black_market.ogg":
			return "Black Market"
		"music/user/changes.ogg":
			return "Changes"
		"music/user/not-needed-anymore.ogg":
			return "Not Needed Anymore"
		"music/user/yangonite.ogg":
			return "Yangonite"
		"music/user/ready-to-rage-against-the-abnormalities.ogg":
			return "Ready To Rage Against The Abnormalities"
		"music/user/supayarlat.ogg":
			return "Supayarlat"
		"music/user/past-cracks.ogg":
			return "Past Cracks"
		"music/user/machinesfuture.ogg":
			return "Machinesfuture"
		"music/user/humanfuture.ogg":
			return "Humanfuture"
		"music/user/night.ogg":
			return "Night"
		"music/user/love-drunk.ogg":
			return "Love Drunk"
		"music/user/poison.ogg":
			return "Poison"
		"music/user/time.ogg":
			return "Time"
		_:
			return ""

static func _ensure(host: Node, node_name: String) -> AudioStreamPlayer:
	var found: AudioStreamPlayer = host.get_node_or_null(node_name) as AudioStreamPlayer
	if found != null:
		return found
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	host.add_child(player)
	return player

static func _assign(player: AudioStreamPlayer, rel: String, loop: bool) -> void:
	var stream: AudioStream = _stream(rel)
	if stream != null:
		_arm_player(player, stream, loop)
		return
	if OS.has_feature("web"):
		_begin_fetch(player, rel, loop)

static func _arm_player(player: AudioStreamPlayer, stream: AudioStream, loop: bool) -> void:
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = loop
	player.stream = stream
	player.volume_db = 0.0
	player.set_meta("started", false)
	if _audible():
		_start(player)
	elif not _held.has(player):
		_held.append(player)

static func _audible() -> bool:
	if not OS.has_feature("web"):
		return true
	return _web_open and _heard

static func _start(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null or player.playing:
		return
	player.play()
	player.set_meta("started", true)
	if not OS.has_feature("web"):
		return
	var label: String = "audio"
	if player.name == "MenuMusic":
		label = "menu"
	elif player.name == "FactionMusic":
		label = "faction"
	elif player.name == "StingMusic":
		label = "sting"
	JavaScriptBridge.eval("console.log('%s music playing')" % label, true)

static func _stream(rel: String) -> AudioStream:
	if _cache.has(rel):
		var cached: AudioStream = _cache[rel] as AudioStream
		if cached != null:
			return cached
	var bytes: PackedByteArray = _read_local(rel)
	var stream: AudioStream = _decode(bytes)
	if stream != null:
		_cache[rel] = stream
	return stream

static func _voice_of(unit_id: String) -> String:
	if unit_id == "fpv_kamikaze":
		return "monsoon_spotter"
	if unit_id == "printsmith":
		return "militia"
	if unit_id == "teak_technical":
		return "bullion_truck"
	if unit_id == "mekong_uav":
		return "river_drone"
	if unit_id == "spool_fpv":
		return "hub_drone"
	if unit_id == "swarm_hive":
		return "relay_van"
	if unit_id == "longtail_raider":
		return "jade_skiff"
	if unit_id == "plantation_bomber":
		return "mangrove_skiff"
	if unit_id == "kite_loiterer":
		return "orlan10"
	return unit_id

static func _variants(unit_id: String, event: String) -> PackedStringArray:
	var speaker: String = _voice_of(unit_id)
	var found: PackedStringArray = PackedStringArray()
	var english: PackedStringArray = PackedStringArray()
	var n: int = 1
	while n <= 8:
		var rel: String = _best("barks", "%s_%s_%d.ogg" % [speaker, event, n])
		if rel != "":
			found.append(rel)
			if rel.begins_with("barks/en/"):
				english.append(rel)
		n += 1
	if _lang() == "en" and not english.is_empty():
		return english
	return found

static func _lang() -> String:
	return Settings.voice_folder(Settings.voice)

## A bark or announcer line never switches language: a failed take stays a tone.
static func _order_for(lang: String, _faction: String) -> PackedStringArray:
	return PackedStringArray([lang if lang != "" else "en"])

static func _match_faction() -> String:
	if SMFront.faction_id == "nmrf" or SMFront.faction_id == "mvd" or SMFront.faction_id == "black_market":
		return SMFront.faction_id
	return "gtfc"

static func _wanted_langs() -> PackedStringArray:
	return _order_for(_lang(), _match_faction())

static func _best(kind: String, tail: String) -> String:
	note_voice(null)
	var faction: String = _faction_of(kind, tail)
	var order: PackedStringArray = _order_for(_lang(), faction)
	for lang: String in order:
		if not _index_state.has(lang):
			_pull_index(lang)
		if lang == "en" and not _voice_known:
			continue
		var rel: String = "%s/%s/%s" % [kind, lang, tail]
		if rel.contains("_retired") or bool(_blocked.get(rel, false)):
			continue
		_kick(rel, lang)
		if _ready(rel):
			return rel
	return ""

static func _faction_of(kind: String, tail: String) -> String:
	if kind == "announcer":
		var parts: PackedStringArray = tail.split("/")
		if parts.is_empty():
			return ""
		return parts[0]
	return str(_unit_faction.get(_bark_unit(tail), ""))

static func _bark_events() -> PackedStringArray:
	return PackedStringArray(["under_attack", "ability", "attack", "select", "move"])

static func _bark_unit(tail: String) -> String:
	var name: String = tail.trim_suffix(".ogg")
	var cut: int = name.rfind("_")
	if cut < 0:
		return ""
	var stem: String = name.substr(0, cut)
	for event_name: String in _bark_events():
		var suffix: String = "_" + event_name
		if stem.ends_with(suffix):
			return stem.substr(0, stem.length() - suffix.length())
	return ""

static func _ensure_voice() -> void:
	if _voice_known or _voice_loading or _voice_gave_up:
		return
	var bark_text: String = _read_text("barks/manifest.json")
	var line_text: String = _read_text("announcer/manifest.json")
	if bark_text != "" and _ingest_barks_text(bark_text):
		_barks_known = true
	if line_text != "" and _ingest_announcer_text(line_text):
		_lines_known = true
	if _barks_known and _lines_known:
		_voice_known = true
		return
	if not OS.has_feature("web") or _owner == null or not is_instance_valid(_owner):
		return
	_voice_loading = true
	if not _barks_known:
		_fetch_manifest("barks/manifest.json")
	if not _lines_known:
		_fetch_manifest("announcer/manifest.json")
	if _manifest_left == 0:
		_voice_loading = false
		_voice_gave_up = true

static func _fetch_manifest(rel: String) -> void:
	_manifest_left += 1
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 30.0
	http.accept_gzip = false
	http.name = "VoiceManifest"
	_owner.add_child(http)
	http.request_completed.connect(_got_manifest.bind(http, rel))
	var err: Error = http.request(_page_base() + "audio/" + rel)
	if err != OK:
		http.queue_free()
		_manifest_left -= 1
		_finish_manifests()

static func _got_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, rel: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var text: String = body.get_string_from_utf8()
		if rel.begins_with("barks/") and _ingest_barks_text(text):
			_barks_known = true
		elif not rel.begins_with("barks/") and _ingest_announcer_text(text):
			_lines_known = true
	_manifest_left -= 1
	_finish_manifests()

static func _finish_manifests() -> void:
	if _manifest_left > 0:
		return
	_voice_loading = false
	if _barks_known and _lines_known:
		_voice_known = true
	else:
		_voice_gave_up = true

static func _ingest_barks_text(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed as Dictionary
	var units: Variant = data.get("units", {})
	if typeof(units) == TYPE_DICTIONARY:
		var unit_map: Dictionary = units as Dictionary
		for unit_id: Variant in unit_map.keys():
			var info: Variant = unit_map[unit_id]
			if typeof(info) != TYPE_DICTIONARY:
				continue
			_unit_faction[str(unit_id)] = str((info as Dictionary).get("faction", ""))
	var clips: Variant = data.get("clips", {})
	if typeof(clips) != TYPE_DICTIONARY:
		return false
	var clip_map: Dictionary = clips as Dictionary
	for lang_key: Variant in clip_map.keys():
		var by_unit: Variant = clip_map[lang_key]
		if typeof(by_unit) != TYPE_DICTIONARY:
			continue
		var unit_clips: Dictionary = by_unit as Dictionary
		for unit_id: Variant in unit_clips.keys():
			var events: Variant = unit_clips[unit_id]
			if typeof(events) != TYPE_DICTIONARY:
				continue
			var event_map: Dictionary = events as Dictionary
			for event_name: Variant in event_map.keys():
				var takes: Variant = event_map[event_name]
				if typeof(takes) != TYPE_ARRAY:
					continue
				for take: Variant in takes as Array:
					_consider_bark(take)
	return true

static func _consider_bark(take: Variant) -> void:
	if typeof(take) != TYPE_DICTIONARY:
		return
	var body: Dictionary = take as Dictionary
	var file: String = str(body.get("file", ""))
	if file == "" or file == "<null>" or not file.begins_with("barks/"):
		return
	_mark_take(file, body)

static func _ingest_announcer_text(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed as Dictionary
	var clips: Variant = data.get("clips", {})
	if typeof(clips) != TYPE_DICTIONARY:
		return false
	var clip_map: Dictionary = clips as Dictionary
	for lang_key: Variant in clip_map.keys():
		var factions: Variant = clip_map[lang_key]
		if typeof(factions) != TYPE_DICTIONARY:
			continue
		var faction_map: Dictionary = factions as Dictionary
		for faction_key: Variant in faction_map.keys():
			var lines: Variant = faction_map[faction_key]
			if typeof(lines) != TYPE_DICTIONARY:
				continue
			var line_map: Dictionary = lines as Dictionary
			for line_key: Variant in line_map.keys():
				var take: Variant = line_map[line_key]
				if typeof(take) == TYPE_ARRAY:
					var listed: Array = take as Array
					for item: Variant in listed:
						_consider_line(item)
				else:
					_consider_line(take)
	return true

static func _consider_line(take: Variant) -> void:
	if typeof(take) != TYPE_DICTIONARY:
		return
	var body: Dictionary = take as Dictionary
	var file: String = str(body.get("file", ""))
	if file == "" or file == "<null>":
		return
	var rel: String = file
	if not rel.begins_with("announcer/"):
		rel = "announcer/" + rel
	_mark_take(rel, body)

static func _mark_take(rel: String, take: Dictionary) -> void:
	if rel.contains("..") or rel.begins_with("/") or rel.contains("\\") or rel.contains("_retired"):
		_blocked[rel] = true
		return
	var failed: bool = take.get("accent_fail", false) == true
	var status: String = str(take.get("status", ""))
	if status == "<null>":
		status = ""
	if failed or status == "removed":
		_blocked[rel] = true

static func _ready(rel: String) -> bool:
	if _cache.has(rel) and _cache[rel] != null:
		return true
	return _local_exists(rel)

static func _kick(rel: String, lang: String) -> void:
	if not OS.has_feature("web") or _owner == null or not is_instance_valid(_owner) or not _listed(rel):
		return
	if lang != _lang() and _ready(rel):
		return
	prefetch(_owner, rel)

static func _listed(rel: String) -> bool:
	var parts: PackedStringArray = rel.split("/")
	if parts.size() < 3:
		return false
	var lang: String = parts[1]
	if parts[0] == "barks":
		var names: PackedStringArray = _bark_index.get(lang, PackedStringArray())
		return names.has(parts[2])
	if parts[0] == "announcer" and parts.size() >= 4:
		var lines: PackedStringArray = _line_index.get(lang, PackedStringArray())
		return lines.has("%s/%s" % [parts[2], parts[3]])
	return false

static func _pull_index(lang: String) -> void:
	if not OS.has_feature("web") or _owner == null:
		_index_state[lang] = "ready"
		return
	_index_state[lang] = "loading"
	_fetch_index(lang, "barks/%s/index.txt" % lang, "barks")
	_fetch_index(lang, "announcer/%s/index.txt" % lang, "announcer")

static func _fetch_index(lang: String, rel: String, kind: String) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 20.0
	http.accept_gzip = false
	_owner.add_child(http)
	http.request_completed.connect(_got_index.bind(http, lang, kind))
	var err: Error = http.request(_page_base() + "audio/" + rel)
	if err != OK:
		http.queue_free()
		_finish_index(lang, kind, PackedStringArray())

static func _got_index(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, lang: String, kind: String) -> void:
	if is_instance_valid(http):
		http.queue_free()
	var names := PackedStringArray()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var text: String = body.get_string_from_utf8()
		for line: String in text.split("\n"):
			var name: String = line.strip_edges()
			if name == "" or name.contains("..") or name.begins_with("/"):
				continue
			names.append(name)
	_finish_index(lang, kind, names)

static func _finish_index(lang: String, kind: String, names: PackedStringArray) -> void:
	if kind == "barks":
		_bark_index[lang] = names
	elif kind == "dialogue":
		_dialogue_index[lang] = names
		_dialogue_state[lang] = "ready"
		return
	else:
		_line_index[lang] = names
	if _bark_index.has(lang) and _line_index.has(lang):
		_index_state[lang] = "ready"

static func _present(rel: String) -> bool:
	if _cache.has(rel) and _cache[rel] != null:
		return true
	if _catalog.has(rel):
		return true
	return _local_exists(rel)

static func _local_exists(rel: String) -> bool:
	if not _accepted(rel):
		return false
	var packed: String = "res://audio/%s" % rel
	if FileAccess.file_exists(packed):
		return true
	var roots: PackedStringArray = _roots()
	for root: String in roots:
		if FileAccess.file_exists(root.path_join(rel)):
			return true
	return false

static func _accepted(rel: String) -> bool:
	return rel.ends_with(".ogg") and not rel.contains("..") and not rel.begins_with("/") and not rel.contains("\\") and not rel.contains("_retired")

static func _read_text(rel: String) -> String:
	if not rel.ends_with(".json") or rel.contains("..") or rel.begins_with("/") or rel.contains("\\") or rel.contains("_retired"):
		return ""
	var packed: String = "res://audio/%s" % rel
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_string(packed)
	for root: String in _roots():
		var path: String = root.path_join(rel)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_string(path)
	return ""

static func _roots() -> PackedStringArray:
	var roots: PackedStringArray = PackedStringArray()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web/audio"))
	roots.append(OS.get_executable_path().get_base_dir().path_join("audio"))
	return roots

static func _decode(bytes: PackedByteArray) -> AudioStream:
	if bytes.is_empty():
		return null
	return AudioStreamOggVorbis.load_from_buffer(bytes)

static func _read_local(rel: String) -> PackedByteArray:
	if not _accepted(rel):
		return PackedByteArray()
	var packed: String = "res://audio/%s" % rel
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	var roots: PackedStringArray = _roots()
	for root: String in roots:
		var path: String = root.path_join(rel)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()

static func _buses() -> void:
	Settings.apply_audio()
	for player: AudioStreamPlayer in _pool:
		if is_instance_valid(player):
			player.bus = "SFX"
	for player: AudioStreamPlayer in _loop_players:
		if is_instance_valid(player):
			player.bus = "SFX"
	if _buses_ready:
		return
	_buses_ready = true
	_bus("Music", false)
	_bus("Radio", true)

static func _bus(bus_name: String, radio: bool) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var idx: int = Settings.append_bus(bus_name, "Master")
	if not radio:
		return
	var high: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
	high.cutoff_hz = 400.0
	AudioServer.add_bus_effect(idx, high)
	var low: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	low.cutoff_hz = 3400.0
	AudioServer.add_bus_effect(idx, low)
	var grit: AudioEffectDistortion = AudioEffectDistortion.new()
	grit.drive = 0.15
	AudioServer.add_bus_effect(idx, grit)

static func _begin_fetch(player: AudioStreamPlayer, rel: String, loop: bool) -> void:
	if player == null or bool(player.get_meta("fetching", false)):
		return
	player.set_meta("fetching", true)
	var http: HTTPRequest = HTTPRequest.new()
	http.name = "AudioFetch"
	http.timeout = 120.0
	http.accept_gzip = false
	player.add_child(http)
	http.request_completed.connect(_fetched.bind(player, http, rel, loop))
	var err: Error = http.request(_page_base() + "audio/" + rel)
	if err != OK:
		player.set_meta("fetching", false)

static func _fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, player: AudioStreamPlayer, http: HTTPRequest, rel: String, loop: bool) -> void:
	if is_instance_valid(player):
		player.set_meta("fetching", false)
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var stream: AudioStream = _decode(body)
	if stream == null or not is_instance_valid(player):
		return
	_cache[rel] = stream
	_catalog[rel] = true
	_arm_player(player, stream, loop)

static func _prefetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, rel: String) -> void:
	_inflight.erase(rel)
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var stream: AudioStream = _decode(body)
	if stream == null:
		return
	_cache[rel] = stream
	_catalog[rel] = true

static func _page_base() -> String:
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
