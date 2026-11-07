extends Node
## Frame profiler for one match. Idle unless asked.
## Desktop: godot --path . -- --perf burma_road [--crowd 60] [--warm 8] [--time 20] [--gfx medium] [--models 12] [--out report.json]
## Web: index.html?perf=burma_road&crowd=60&warm=8&time=20&gfx=medium
## `campaign:<mission id>` opens that campaign mission. Prints one `PERF {json}` line; the web page also sets window.__perf.

const Settings = preload("res://game/match_settings.gd")
const CROWD_KINDS: Array[StringName] = [&"militia", &"amber_tank", &"ruby_lancer", &"monsoon_tube", &"crimson_sapper", &"slag_hauler"]

var _args: Dictionary = {}
var _phase: String = ""
var _clock: float = 0.0
var _last_us: int = 0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _sums: Dictionary = {}
var _peaks: Dictionary = {}
var _samples: int = 0
var _load_ms: float = 0.0
var _hitches: int = 0
var _worst_ms: float = 0.0

func _ready() -> void:
	_args = _read_args()
	if not _args.has("perf"):
		set_process(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gfx: String = str(_args.get("gfx", ""))
	if gfx != "":
		Settings.set_graphics(gfx)
	_phase = "boot"
	call_deferred("_open")

func _read_args() -> Dictionary:
	var out: Dictionary = {}
	if OS.has_feature("web"):
		var search: String = str(JavaScriptBridge.eval("window.location.search", true))
		if search == "" or search == "null" or search == "<null>":
			return out
		for pair: String in search.trim_prefix("?").split("&"):
			var cut: int = pair.find("=")
			if cut > 0:
				out[pair.substr(0, cut)] = pair.substr(cut + 1).uri_decode()
		return out
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		var key: String = raw[i].trim_prefix("--")
		var value: String = raw[i + 1] if i + 1 < raw.size() else ""
		out[key] = value
		i += 2
	return out

func _open() -> void:
	var target: String = str(_args["perf"])
	var path: String = "res://game/%s.tscn" % target
	if target.begins_with("campaign:"):
		SMCampaign.selected = target.trim_prefix("campaign:")
		path = "res://game/campaign_mission.tscn"
	else:
		SMFront.faction_id = str(_args.get("faction", "gtfc"))
	var started: int = Time.get_ticks_usec()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_load_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_phase = "warm"
	_clock = 0.0
	_last_us = Time.get_ticks_usec()
	_crowd()

func _crowd() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var hud: SMHud = scene.get("hud") as SMHud
	if hud != null and hud.guide_panel != null:
		hud.guide_panel.visible = false
	var count: int = int(_args.get("crowd", "0"))
	var field: SMPointer = scene.get("field") as SMPointer
	var cam: RTSCamera = scene.get_node_or_null("Camera") as RTSCamera
	if cam != null:
		cam.set_meta("edge_authored", 0.0)
		cam.edge_pan_px = 0.0
	if field == null or cam == null or count <= 0:
		return
	var cols: int = 10
	var step: float = 1.8
	var origin: Vector3 = cam.focus - Vector3(float(cols) * step * 0.5, 0.0, 6.0)
	for i: int in count:
		var at: Vector3 = origin + Vector3(float(i % cols) * step, 0.0, float(int(i / cols)) * step)
		field.spawn(SMPointer.PLAYER, at, CROWD_KINDS[i % CROWD_KINDS.size()])

func _process(_delta: float) -> void:
	if _phase == "" or _phase == "boot" or _phase == "done":
		return
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	_clock += ms / 1000.0
	if _phase == "warm":
		if _clock >= float(_args.get("warm", "8")):
			_phase = "sample"
			_clock = 0.0
		return
	_frames.append(ms)
	if ms > 50.0:
		_hitches += 1
	_worst_ms = maxf(_worst_ms, ms)
	_add("draw_calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_add("primitives", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_add("objects", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_add("process_ms", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_samples += 1
	if _clock >= float(_args.get("time", "20")):
		_finish()

func _add(key: String, value: float) -> void:
	_sums[key] = float(_sums.get(key, 0.0)) + value
	_peaks[key] = maxf(float(_peaks.get(key, 0.0)), value)

func _finish() -> void:
	_phase = "done"
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	var total: float = 0.0
	for ms: float in _frames:
		total += ms
	var n: int = maxi(1, _frames.size())
	var report: Dictionary = {
		"scene": str(_args["perf"]),
		"platform": "web" if OS.has_feature("web") else OS.get_name().to_lower(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"graphics": Settings.effective(),
		"crowd": int(_args.get("crowd", "0")),
		"scene_load_ms": snappedf(_load_ms, 0.1),
		"fps": snappedf(1000.0 * float(n) / maxf(total, 0.001), 0.1),
		"frame_ms_avg": snappedf(total / float(n), 0.01),
		"frame_ms_p95": snappedf(sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))], 0.01) if not sorted.is_empty() else 0.0,
		"frame_ms_max": snappedf(_worst_ms, 0.1),
		"hitches_over_50ms": _hitches,
		"video_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_mem_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	for key: String in _sums.keys():
		report[key + "_avg"] = snappedf(float(_sums[key]) / float(maxi(1, _samples)), 0.01)
		report[key + "_max"] = snappedf(float(_peaks[key]), 0.01)
	if _args.has("models"):
		report["model_parse"] = _bench_models(int(_args["models"]))
	if _args.has("breakdown"):
		report["triangles_by_group"] = _breakdown(get_tree().current_scene)
	var line: String = JSON.stringify(report)
	print("PERF " + line)
	if _args.has("out"):
		var file: FileAccess = FileAccess.open(str(_args["out"]), FileAccess.WRITE)
		if file != null:
			file.store_line(line)
			file.close()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__perf = %s; console.log('PERF_DONE');" % line, true)
	elif not _args.has("stay"):
		preload("res://game/render_budget.gd").shutdown(get_tree())
		get_tree().quit()

## Scene triangles (before culling) per top-level child, grouped by name prefix.
func _breakdown(scene: Node) -> Dictionary:
	var out: Dictionary = {}
	if scene == null:
		return out
	var tris: Dictionary = {}
	for child: Node in scene.get_children():
		var group: String = String(child.name).get_slice("_", 0).rstrip("0123456789@")
		if child is RTSUnit:
			group = "units"
		var total: int = 0
		for node: Node in [child] + child.find_children("*", "GeometryInstance3D", true, false):
			var geo: GeometryInstance3D = node as GeometryInstance3D
			if geo == null or not geo.is_visible_in_tree():
				continue
			if geo is MultiMeshInstance3D:
				var mm: MultiMesh = (geo as MultiMeshInstance3D).multimesh
				if mm != null and mm.mesh != null:
					var shown: int = mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
					total += _mesh_tris(mm.mesh) * shown
			elif geo is MeshInstance3D and (geo as MeshInstance3D).mesh != null:
				total += _mesh_tris((geo as MeshInstance3D).mesh)
		if total > 0:
			tris[group] = int(tris.get(group, 0)) + total
	for key: String in tris.keys():
		if int(tris[key]) >= 5000:
			out[key] = tris[key]
	return out

static var _tri_cache: Dictionary = {}

func _mesh_tris(mesh: Mesh) -> int:
	var id: int = mesh.get_instance_id()
	if _tri_cache.has(id):
		return int(_tri_cache[id])
	var n: int = mesh.get_faces().size() / 3
	_tri_cache[id] = n
	return n

## Parse time for the GLBs this run already cached or ships beside the binary.
func _bench_models(limit: int) -> Dictionary:
	var base: String = OS.get_executable_path().get_base_dir()
	var dirs: PackedStringArray = PackedStringArray([
		"user://models/tripo",
		base.path_join("models"),
		base.get_base_dir().path_join("Resources/models"),
		ProjectSettings.globalize_path("res://game/models/tripo"),
	])
	var files: PackedStringArray = PackedStringArray()
	for dir: String in dirs:
		if not files.is_empty():
			break
		for name: String in DirAccess.get_files_at(dir):
			if name.ends_with(".glb") and files.size() < limit:
				files.append(dir.path_join(name))
	if files.is_empty():
		return {}
	var spent: float = 0.0
	var worst: float = 0.0
	for path: String in files:
		var started: int = Time.get_ticks_usec()
		var doc: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			var node: Node = doc.generate_scene(state)
			if node != null:
				node.free()
		var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
		spent += ms
		worst = maxf(worst, ms)
	return {"files": files.size(), "avg_ms": snappedf(spent / float(files.size()), 0.1), "max_ms": snappedf(worst, 0.1), "from": files[0].get_base_dir()}
