extends RefCounted
## Short tactical UI cues synthesized at runtime, so they need no files and sound the same on desktop and web:
## the weapon-switch bolt click, the placement error buzz, the objective chime and the minimap sonar ping.
## They play on the SFX bus from a small pool on the scene's "SoundBank" node.

const RATE: int = 22050
const KINDS: PackedStringArray = ["weapon_click", "error_buzz", "objective_chime", "ping"]
const POOL: int = 3

static var _cache: Dictionary = {}
## Every cue that started, newest last. Tests read it.
static var played: PackedStringArray = PackedStringArray()

static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind] as AudioStreamWAV
	var samples: PackedFloat32Array = PackedFloat32Array()
	match kind:
		"weapon_click":
			samples = _click()
		"error_buzz":
			samples = _buzz()
		"objective_chime":
			samples = _chime()
		"ping":
			samples = _ping()
		_:
			return null
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	wav.data = bytes
	_cache[kind] = wav
	return wav

static func play(host: Node, kind: String, volume_db: float = -4.0) -> bool:
	if host == null or not is_instance_valid(host):
		return false
	var cue: AudioStreamWAV = stream(kind)
	if cue == null:
		return false
	var bank: Node = host.get_node_or_null("SoundBank")
	if bank == null:
		bank = Node.new()
		bank.name = "SoundBank"
		host.add_child(bank)
		for i: int in POOL:
			var p: AudioStreamPlayer = AudioStreamPlayer.new()
			p.name = "Cue%d" % i
			p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
			bank.add_child(p)
	var pick: AudioStreamPlayer = null
	for child: Node in bank.get_children():
		var p: AudioStreamPlayer = child as AudioStreamPlayer
		if p != null and not p.playing:
			pick = p
			break
	if pick == null:
		pick = bank.get_child(0) as AudioStreamPlayer
	pick.stream = cue
	pick.volume_db = volume_db
	if pick.is_inside_tree():
		pick.play()
	played.append(kind)
	if played.size() > 32:
		played.remove_at(0)
	return true

static func _len(seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(seconds * float(RATE)))
	return out

## Two bolt clicks: a noise snap with a short metallic ring, the second lower and softer.
static func _click() -> PackedFloat32Array:
	var out: PackedFloat32Array = _len(0.16)
	var grain: int = 7
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var v: float = 0.0
		for hit: Array in [[0.0, 1.0, 2900.0], [0.065, 0.7, 2100.0]]:
			var dt: float = t - float(hit[0])
			if dt >= 0.0:
				grain = (grain * 1103515245 + 12345) & 0x7fffffff
				var noise: float = float(grain % 2000) / 1000.0 - 1.0
				v += float(hit[1]) * (noise * exp(-dt * 260.0) * 0.8 + sin(TAU * float(hit[2]) * dt) * exp(-dt * 70.0) * 0.45)
		out[i] = v * 0.7
	return out

## A rough two-tone square buzz, the classic "can't do that" cue.
static func _buzz() -> PackedFloat32Array:
	var out: PackedFloat32Array = _len(0.3)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var env: float = minf(1.0, t * 80.0) * minf(1.0, (0.3 - t) * 30.0)
		var a: float = signf(sin(TAU * 110.0 * t))
		var b: float = signf(sin(TAU * 146.8 * t))
		out[i] = (a * 0.5 + b * 0.35) * env * 0.42
	return out

## Rising two-note chime.
static func _chime() -> PackedFloat32Array:
	var out: PackedFloat32Array = _len(0.55)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var v: float = sin(TAU * 784.0 * t) * exp(-t * 7.0)
		if t > 0.14:
			var u: float = t - 0.14
			v += sin(TAU * 1175.0 * u) * exp(-u * 6.0)
		out[i] = v * 0.33
	return out

## Sonar blip with a slight downward sweep.
static func _ping() -> PackedFloat32Array:
	var out: PackedFloat32Array = _len(0.4)
	var phase: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		phase += TAU * (1500.0 - 500.0 * t) / float(RATE)
		out[i] = sin(phase) * exp(-t * 9.0) * minf(1.0, t * 400.0) * 0.4
	return out
