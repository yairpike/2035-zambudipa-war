extends CanvasLayer
## First-launch download of the sidecar files a small installer leaves out, with a progress bar.
## Each file lands as .part and only takes its real name once size and blob SHA-1 match, so an
## interrupted run resumes where it stopped. When every file is in, the game restarts so every
## loader starts from the full set. Play now hides the screen and finishes the download quietly.

const Pack = preload("res://game/asset_pack.gd")
const LANES: int = 6
const ROUNDS: int = 3

signal finished(ok: bool)

var manifest: Dictionary = {}
var restart: bool = true
var total_bytes: int = 0
var done_bytes: int = 0
var failed: Array = []
var _queue: Array = []
var _jobs: Dictionary = {}
var _lanes: Array[HTTPRequest] = []
var _rate: float = 0.0
var _rate_bytes: int = 0
var _rate_clock: float = 0.0
var _over: bool = false
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

func start() -> void:
	_over = false
	failed.clear()
	_queue = Pack.pending(manifest)
	total_bytes = Pack.bytes_of(manifest.get("files", []) as Array)
	done_bytes = total_bytes - Pack.bytes_of(_queue)
	if retry != null:
		retry.visible = false
	_say("")
	while _lanes.size() < LANES:
		var lane: HTTPRequest = HTTPRequest.new()
		lane.use_threads = true
		lane.timeout = 120.0
		lane.request_completed.connect(_landed.bind(lane))
		add_child(lane)
		_lanes.append(lane)
	for lane: HTTPRequest in _lanes:
		if not _jobs.has(lane):
			_next(lane)

func _next(lane: HTTPRequest) -> void:
	if _queue.is_empty():
		if _jobs.is_empty():
			_finish()
		return
	_send(lane, _queue.pop_front() as Array, 0, 0)

func _send(lane: HTTPRequest, entry: Array, source: int, pass_no: int) -> void:
	var rel: String = str(entry[0])
	var final: String = Pack.root().path_join(rel)
	DirAccess.make_dir_recursive_absolute(final.get_base_dir())
	lane.download_file = final + ".part"
	_jobs[lane] = [entry, source, pass_no]
	var urls: Array = manifest.get("urls", []) as Array
	if lane.request(Pack.url_for(str(urls[source]), rel)) != OK:
		_landed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), lane)

func _landed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, lane: HTTPRequest) -> void:
	if not _jobs.has(lane):
		return
	var job: Array = _jobs[lane] as Array
	_jobs.erase(lane)
	var entry: Array = job[0] as Array
	var final: String = Pack.root().path_join(str(entry[0]))
	var part: String = final + ".part"
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and accept(part, final, entry):
		done_bytes += int(entry[1])
		_next(lane)
		return
	DirAccess.remove_absolute(part)
	var source: int = int(job[1]) + 1
	var pass_no: int = int(job[2])
	if source >= (manifest.get("urls", []) as Array).size():
		source = 0
		pass_no += 1
	if pass_no < ROUNDS:
		_send(lane, entry, source, pass_no)
		return
	failed.append(entry)
	_next(lane)

## Moves a verified .part into place. A wrong size or hash leaves nothing behind.
static func accept(part: String, final: String, entry: Array) -> bool:
	if Pack.size_of(part) != int(entry[1]) or Pack.blob_sha1(part) != str(entry[2]):
		DirAccess.remove_absolute(part)
		return false
	if FileAccess.file_exists(final):
		DirAccess.remove_absolute(final)
	return DirAccess.rename_absolute(part, final) == OK

func _finish() -> void:
	if _over:
		return
	_over = true
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
	if bar == null or total_bytes <= 0:
		return
	var moving: int = 0
	for lane: HTTPRequest in _jobs.keys():
		moving += maxi(0, lane.get_downloaded_bytes())
	var now: int = mini(total_bytes, done_bytes + moving)
	bar.value = 100.0 * float(now) / float(total_bytes)
	_rate_clock += delta
	if _rate_clock >= 1.0:
		var step: float = float(now - _rate_bytes) / _rate_clock
		_rate = step if _rate <= 0.0 else lerpf(_rate, step, 0.4)
		_rate_bytes = now
		_rate_clock = 0.0
	if not _over:
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
