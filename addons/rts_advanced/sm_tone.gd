class_name SMTone
extends RefCounted
## Short procedural cues. No recorded files.

const RATE: int = 22050

static func cue(kind: String) -> AudioStreamWAV:
	if kind == "attack":
		return _noise(0.09, 0.55, 7)
	if kind == "ability":
		return _tone(740.0, 0.14, 0.4)
	if kind == "move":
		return _tone(360.0, 0.08, 0.35)
	if kind == "select":
		return _tone(880.0, 0.05, 0.28)
	if kind == "ui_hover":
		return _tone(990.0, 0.025, 0.16)
	if kind == "ui_click":
		return _tone(180.0, 0.045, 0.5)
	if kind == "bark":
		return _tone(280.0, 0.11, 0.32)
	if kind == "door_open":
		return _noise(0.45, 0.32, 18)
	if kind == "door_close":
		return _noise(0.22, 0.5, 26)
	return _tone(520.0, 0.04, 0.22)

static func peak(wav: AudioStreamWAV) -> int:
	if wav == null:
		return 0
	var data: PackedByteArray = wav.data
	var best: int = 0
	var i: int = 0
	while i + 1 < data.size():
		var raw: int = int(data[i]) | (int(data[i + 1]) << 8)
		if raw >= 32768:
			raw -= 65536
		best = maxi(best, absi(raw))
		i += 2
	return best

static func _tone(freq: float, seconds: float, gain: float) -> AudioStreamWAV:
	var n: int = maxi(1, int(seconds * float(RATE)))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	var i: int = 0
	while i < n:
		var t: float = float(i) / float(RATE)
		var env: float = 1.0 - (float(i) / float(n))
		var sample: float = sin(TAU * freq * t) * gain * env
		_write(bytes, i, sample)
		i += 1
	return _wav(bytes)

static func _noise(seconds: float, gain: float, step: int) -> AudioStreamWAV:
	var n: int = maxi(1, int(seconds * float(RATE)))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(n * 2)
	var state: int = 12345
	var i: int = 0
	while i < n:
		state = (state * 1103515245 + 12345) % 2147483647
		var env: float = 1.0 - (float(i) / float(n))
		var sample: float = (float(state % 2000) - 1000.0) / 1000.0 * gain * env
		if i % step != 0:
			sample *= 0.35
		_write(bytes, i, sample)
		i += 1
	return _wav(bytes)

static func _write(bytes: PackedByteArray, i: int, sample: float) -> void:
	var clamped: int = clampi(int(sample * 32767.0), -32767, 32767)
	var unsigned: int = clamped & 0xffff
	bytes[i * 2] = unsigned & 0xff
	bytes[i * 2 + 1] = (unsigned >> 8) & 0xff

static func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
