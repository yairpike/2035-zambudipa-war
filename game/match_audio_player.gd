extends Node
## Starts faction music after the match has chosen a side, then a sting at the end.
## On the web, playback waits for the first click so the audio context can resume.

const Clips = preload("res://game/match_audio.gd")

var _started: bool = false
var _stung: bool = false
var _open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_fetch_list.call_deferred()

func _input(event: InputEvent) -> void:
	if _open or not OS.has_feature("web") or not _gesture(event):
		return
	_open = true
	Clips.unlock()

func _gesture(event: InputEvent) -> bool:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		return mouse.pressed
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key.pressed and not key.echo
	return false

func _process(_delta: float) -> void:
	if OS.has_feature("web") and not _open:
		var state: String = str(JavaScriptBridge.eval("window.__aseanAudioState || ''", true))
		if state == "running":
			_open = true
			Clips.unlock()
	Clips.pump()
	var host: Node = get_parent()
	if host == null:
		return
	if get_tree().paused:
		Clips.tick(host)
		return
	Clips.drive(host)
	if not _started:
		_started = true
		if str(get_meta("mode", "match")) == "menu":
			Clips.play_menu(host)
		else:
			var faction: String = "gtfc"
			var field: SMPointer = host.get("field") as SMPointer
			if field != null:
				faction = field.faction_id
			Clips.play_faction(host, faction)
		return
	if not _stung and str(get_meta("mode", "match")) != "menu":
		var ended: bool = false
		var won: bool = false
		var outcome: SMOutcome = host.get("outcome") as SMOutcome
		if outcome != null and outcome.over:
			ended = true
			won = outcome.victory
		var story: SMStory = host.get("story") as SMStory
		if story != null and (story.done or story.lost):
			ended = true
			won = story.done and not story.lost
		if ended:
			_stung = true
			Clips.play_sting(host, won)
	Clips.tick(host)

func _fetch_list() -> void:
	if not is_inside_tree():
		_fetch_list.call_deferred()
		return
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 30.0
	http.accept_gzip = false
	http.name = "ClipList"
	http.ready.connect(_start_list.bind(http), CONNECT_ONE_SHOT)
	add_child.call_deferred(http)

func _start_list(http: HTTPRequest) -> void:
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return
	http.request_completed.connect(_got_list.bind(http))
	var err: Error = http.request(Clips.page_base() + "audio/clips.txt")
	if err != OK:
		http.queue_free()

func _got_list(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if is_instance_valid(http):
		http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var lines: PackedStringArray = body.get_string_from_utf8().split("\n")
	for line: String in lines:
		var rel: String = line.strip_edges()
		if rel == "" or Clips.is_lazy(rel):
			continue
		Clips.remember(rel)
		if not Clips.is_retired(rel):
			Clips.prefetch(self, rel)
