extends CanvasLayer
## First-launch download of the sidecar files a small installer leaves out, with a progress bar.
## Worker threads keep one HTTPS connection each alive across files, so thousands of small files
## cost no handshake apiece and do not wait on the frame rate. Each file lands as .part and only
## takes its real name once size and blob SHA-1 match, so an interrupted run resumes where it
## stopped. When every file is in, the game restarts so every loader starts from the full set.
## Play now hides the screen and lets the download finish quietly.

const Pack = preload("res://game/asset_pack.gd")
const LANES: int = 6
const ROUNDS: int = 3
const STALL_MS: int = 30000
const HEADERS: PackedStringArray = ["User-Agent: ASEAN2031", "Accept: */*"]

signal finished(ok: bool)

var manifest: Dictionary = {}
var restart: bool = true
var total_bytes: int = 0
var done_bytes: int = 0
var failed: Array = []
var _queue: Array = []
var _moving: PackedInt64Array = PackedInt64Array()
var _threads: Array[Thread] = []
var _live: int = 0
var _stop: bool = false
var _mutex: Mutex = Mutex.new()
var _rate: float = 0.0
var _rate_bytes: int = 0
var _rate_clock: float = 0.0
var _over: bool = true
var bar: ProgressBar
var status: Label
var play: Button
var retry: Button

## True when this build ships an asset list and user://assets still lacks part of it.
static func needed() -> bool:
	var row: Dictionary = Pack.read(Pack.manifest_path())
	if row.is_empty() or Pack.complete(row):
		return false
	if Pack.pending(row).is_empty():
		Pack.mark_complete(row)
		return false
	return true

func _init(row: Dictionary = {}) -> void:
	manifest = row if not row.is_empty() else Pack.read(Pack.manifest_path())
	layer = 120
	name = "AssetDownload"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	start()

func _exit_tree() -> void:
	_halt()

func start() -> void:
	if not _threads.is_empty():
		return
	_over = false
	_stop = false
	failed.clear()
	_queue = Pack.pending(manifest)
	total_bytes = Pack.bytes_of(manifest.get("files", []) as Array)
	done_bytes = total_bytes - Pack.bytes_of(_queue)
	_rate_bytes = done_bytes
	if retry != null:
		retry.visible = false
	_moving.resize(LANES)
	_moving.fill(0)
	_live = LANES
	for lane: int in LANES:
		var worker: Thread = Thread.new()
		_threads.append(worker)
		worker.start(_work.bind(lane))

func _halt() -> void:
	_stop = true
	for worker: Thread in _threads:
		worker.wait_to_finish()
	_threads.clear()

func _take() -> Array:
	_mutex.lock()
	var entry: Array = [] if _queue.is_empty() or _stop else _queue.pop_front() as Array
	_mutex.unlock()
	return entry

func _work(lane: int) -> void:
	var client: HTTPClient = HTTPClient.new()
	var host: Array[String] = [""]
	while true:
		var entry: Array = _take()
		if entry.is_empty():
			break
		var ok: bool = false
		var sources: Array = Pack.sources(manifest, entry)
		for pass_no: int in ROUNDS:
			for url: Variant in sources:
				if _stop:
					break
				if fetch(client, host, str(url), entry, _progress.bind(lane)):
					ok = true
					break
			if ok or _stop:
				break
			OS.delay_msec(600 * (pass_no + 1))
		_mutex.lock()
		_moving[lane] = 0
		if ok:
			done_bytes += int(entry[1])
		elif not _stop:
			failed.append(entry)
		_mutex.unlock()
	client.close()
	_mutex.lock()
	_live -= 1
	_mutex.unlock()

func _progress(bytes: int, lane: int) -> void:
	_mutex.lock()
	_moving[lane] = bytes
	_mutex.unlock()

## Downloads one manifest entry over `client`, reusing its connection when `host[0]` matches.
## `report` receives the bytes read so far. Blocking; runs on a worker thread.
static func fetch(client: HTTPClient, host: Array[String], url: String, entry: Array, report: Callable) -> bool:
	if not url.begins_with("https://"):
		return false
	var rest: String = url.trim_prefix("https://")
	var server: String = rest.get_slice("/", 0)
	var path: String = rest.substr(server.length())
	if client.get_status() != HTTPClient.STATUS_CONNECTED or host[0] != server:
		client.close()
		host[0] = ""
		if client.connect_to_host(server, 443, TLSOptions.client()) != OK:
			return false
		if not _wait(client, [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING], HTTPClient.STATUS_CONNECTED):
			client.close()
			return false
		host[0] = server
	if client.request(HTTPClient.METHOD_GET, path, HEADERS) != OK:
		client.close()
		return false
	if not _wait(client, [HTTPClient.STATUS_REQUESTING], -1) or not client.has_response():
		client.close()
		return false
	var final: String = Pack.root().path_join(str(entry[0]))
	var part: String = final + ".part"
	DirAccess.make_dir_recursive_absolute(final.get_base_dir())
	var out: FileAccess = FileAccess.open(part, FileAccess.WRITE)
	if out == null:
		client.close()
		return false
	var code: int = client.get_response_code()
	var got: int = 0
	var quiet: int = Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() - quiet > STALL_MS:
				client.close()
				break
			OS.delay_usec(500)
			continue
		quiet = Time.get_ticks_msec()
		out.store_buffer(chunk)
		got += chunk.size()
		report.call(got)
	out.close()
	if code != 200:
		DirAccess.remove_absolute(part)
		return false
	return accept(part, final, entry)

static func _wait(client: HTTPClient, waiting: Array, want: int) -> bool:
	var began: int = Time.get_ticks_msec()
	while waiting.has(client.get_status()):
		if Time.get_ticks_msec() - began > STALL_MS:
			return false
		client.poll()
		OS.delay_usec(500)
	return want < 0 or client.get_status() == want

## Moves a verified .part into place. A wrong size or hash leaves nothing behind.
static func accept(part: String, final: String, entry: Array) -> bool:
	if Pack.size_of(part) != int(entry[1]) or Pack.blob_sha1(part) != str(entry[2]):
		DirAccess.remove_absolute(part)
		return false
	if FileAccess.file_exists(final):
		DirAccess.remove_absolute(final)
	return DirAccess.rename_absolute(part, final) == OK

func _finish() -> void:
	_over = true
	_halt()
	if not failed.is_empty():
		finished.emit(false)
		if not restart:
			queue_free()
			return
		_say("Some files could not be downloaded. Check your connection and retry.")
		if retry != null:
			retry.visible = true
		return
	Pack.mark_complete(manifest)
	finished.emit(true)
	if not restart or not visible:
		queue_free()
		return
	_say("Download complete. Restarting…")
	await get_tree().create_timer(0.8).timeout
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()

func _process(delta: float) -> void:
	if _over or total_bytes <= 0:
		return
	_mutex.lock()
	var now: int = done_bytes
	for bytes: int in _moving:
		now += bytes
	var live: int = _live
	_mutex.unlock()
	if live == 0:
		_finish()
		return
	now = mini(total_bytes, now)
	if bar == null:
		return
	bar.value = 100.0 * float(now) / float(total_bytes)
	_rate_clock += delta
	if _rate_clock >= 1.0:
		var step: float = float(now - _rate_bytes) / _rate_clock
		_rate = step if _rate <= 0.0 else lerpf(_rate, step, 0.4)
		_rate_bytes = now
		_rate_clock = 0.0
	var line: String = tr("%d of %d MB") % [now >> 20, total_bytes >> 20]
	if _rate > 0.0:
		line += "  ·  " + tr("%.1f MB/s") % (_rate / 1048576.0)
	status.text = line

func _say(line: String) -> void:
	if status != null and line != "":
		status.text = line

func _skip() -> void:
	restart = false
	visible = false

func _build() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.024, 0.034, 0.94)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title: Label = Label.new()
	title.text = "Downloading game assets"
	title.theme_type_variation = "Header"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note: Label = Label.new()
	note.text = "First launch only. The game restarts when the download finishes."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.75)
	column.add_child(note)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = true
	column.add_child(bar)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	retry = Button.new()
	retry.text = "Retry"
	retry.visible = false
	retry.pressed.connect(start)
	row.add_child(retry)
	play = Button.new()
	play.text = "Play now"
	play.tooltip_text = "Start with placeholder models and no sound. The download continues in the background."
	play.pressed.connect(_skip)
	row.add_child(play)
