extends Node
## EVA command-AI callouts from res://assets/voices/eva/<lang>/<key>.ogg (assets/voices/eva/manifest.json holds the
## spoken text and voices; tools/eva/make_eva.py builds them). The clips ship inside the pack, so desktop and web
## play the same lines. The selected voice language plays, and English stands in for a missing take.
## Two players live on one "EvaVoice" node under the scene: alerts (placement refusals, weapon swaps) cut in at
## once, and narration (objectives, stages, reinforcements) queues and waits while a hero dialogue line plays.

const Settings = preload("res://game/match_settings.gd")
const PATH: String = "res://assets/voices/eva/%s/%s.ogg"
const LANGS: PackedStringArray = ["en", "my", "zh", "th", "ms"]
const QUEUE_MAX: int = 4
const ALERTS: PackedStringArray = [
	"cannot_deploy", "naval_on_water", "build_near_allied", "blocked_road_terrain", "insufficient_funds",
	"secondary_weapon", "primary_weapon", "building", "training", "unit_ready", "construction_complete", "low_power",
]
const GAPS: Dictionary = {
	"cannot_deploy": 1400, "naval_on_water": 1400, "build_near_allied": 1400, "blocked_road_terrain": 1400,
	"insufficient_funds": 2500, "secondary_weapon": 500, "primary_weapon": 500, "ally_under_attack": 20000,
	"base_under_attack": 18000, "unit_lost": 8000, "wave_incoming": 20000, "enemy_superweapon_detected": 25000,
	"superweapon_ready": 20000, "building": 1200, "training": 1200, "low_power": 6000, "new_objective": 1500,
}
## Announcer keys from match_audio.gd that the EVA set speaks under its own name.
const ALIASES: Dictionary = {"cannot_deploy_here": "cannot_deploy"}

## Every key that was spoken or queued, newest last. Tests and the screenshot tool read it.
static var heard: PackedStringArray = PackedStringArray()
static var _said: Dictionary = {}

var queue: PackedStringArray = PackedStringArray()
var spoken: PackedStringArray = PackedStringArray()
var _alert: AudioStreamPlayer
var _narrator: AudioStreamPlayer

static func lang() -> String:
	var folder: String = Settings.voice_folder(Settings.voice)
	return folder if LANGS.has(folder) else "en"

static func key_of(key: String) -> String:
	return str(ALIASES.get(key, key))

static func has(key: String) -> bool:
	return ResourceLoader.exists(PATH % ["en", key_of(key)])

static func path_for(key: String, language: String = "") -> String:
	var k: String = key_of(key)
	var want: String = language if language != "" else lang()
	if ResourceLoader.exists(PATH % [want, k]):
		return PATH % [want, k]
	return PATH % ["en", k] if ResourceLoader.exists(PATH % ["en", k]) else ""

static func clip(key: String) -> AudioStream:
	var path: String = path_for(key)
	return load(path) as AudioStream if path != "" else null

## Speaks `key` on `host`'s scene. False when there is no such clip or the key is still cooling down.
static func say(host: Node, key: String) -> bool:
	var k: String = key_of(key)
	if host == null or not is_instance_valid(host) or not has(k):
		return false
	var now: int = Time.get_ticks_msec()
	var gap: int = int(GAPS.get(k, 900))
	if _said.has(k) and now - int(_said[k]) < gap:
		return false
	_said[k] = now
	heard.append(k)
	if heard.size() > 64:
		heard.remove_at(0)
	var bank: Node = bank_of(host)
	if bank == null:
		return false
	bank.call("take", k)
	return true

## Speaks the mission's opening objective, or the generic line when the mission has no opener.
static func open_mission(host: Node, mission_id: String) -> bool:
	if has("mission_" + mission_id):
		return say(host, "mission_" + mission_id)
	return say(host, "objective_received")

## Voice line for a placement refusal reason from SMBasePlan / SMSide.
static func reason_key(reason: String) -> String:
	var r: String = reason.to_lower()
	if r.contains("naval") or r.contains("open water"):
		return "naval_on_water"
	if r.contains("build radius"):
		return "build_near_allied"
	if r.contains("road") or r.contains("steep") or r.contains("exit is blocked") or r.contains("dry ground"):
		return "blocked_road_terrain"
	return "cannot_deploy"

static func forget() -> void:
	_said.clear()
	heard.clear()

static func bank_of(host: Node) -> Node:
	var scene: Node = host
	if scene.is_inside_tree() and scene.get_tree().current_scene != null and scene.get_tree().current_scene.is_ancestor_of(scene):
		scene = scene.get_tree().current_scene
	var bank: Node = scene.get_node_or_null("EvaVoice")
	if bank == null:
		bank = Node.new()
		bank.name = "EvaVoice"
		bank.set_script(load("res://game/voice_bank.gd") as GDScript)
		scene.add_child(bank)
	return bank

func _ready() -> void:
	_ready_players()

func take(key: String) -> void:
	_ready_players()
	if ALERTS.has(key):
		_play(_alert, key)
		return
	if queue.has(key):
		return
	queue.append(key)
	while queue.size() > QUEUE_MAX:
		queue.remove_at(0)
	pump()

func pump() -> void:
	if _narrator == null or queue.is_empty() or _narrator.playing or _dialogue_busy():
		return
	var key: String = queue[0]
	queue.remove_at(0)
	_play(_narrator, key)

func _process(_delta: float) -> void:
	pump()

func _play(player: AudioStreamPlayer, key: String) -> void:
	var stream: AudioStream = clip(key)
	if stream == null:
		return
	player.stop()
	player.stream = stream
	player.set_meta("key", key)
	spoken.append(key)
	if player.is_inside_tree():
		player.play()

func _ready_players() -> void:
	if _alert == null:
		_alert = _player("EvaAlert")
	if _narrator == null:
		_narrator = _player("EvaNarrator")
	if not _narrator.finished.is_connected(pump):
		_narrator.finished.connect(pump)

func _player(node_name: String) -> AudioStreamPlayer:
	var have: AudioStreamPlayer = get_node_or_null(node_name) as AudioStreamPlayer
	if have != null:
		return have
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = "Radio" if AudioServer.get_bus_index("Radio") >= 0 else "Master"
	p.volume_db = -1.0
	add_child(p)
	return p

## Hero dialogue (match_audio.gd's "Dialogue" player) has the floor; narration waits for it.
func _dialogue_busy() -> bool:
	var scene: Node = get_parent()
	var talk: AudioStreamPlayer = scene.get_node_or_null("Dialogue") as AudioStreamPlayer if scene != null else null
	return talk != null and talk.playing
