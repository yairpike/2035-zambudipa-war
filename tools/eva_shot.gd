extends SceneTree
## Windowed screenshots of the deployment aura and blocked pills, the objective beacon, ping and transmission banner,
## and a street assault wave on Phillips Channel. Not part of the test suite.
## godot --path . --resolution 1280x720 -s res://tools/eva_shot.gd -- --out /tmp/eva

var _args: Dictionary = {}
var _clock: float = 0.0
var _beat: int = 0
var _next: float = 2.4

func _initialize() -> void:
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		_args[raw[i].trim_prefix("--")] = raw[i + 1] if i + 1 < raw.size() else ""
		i += 2
	SMFront.faction_id = "gtfc"
	change_scene_to_file("res://game/phillips_channel.tscn")

func _process(delta: float) -> bool:
	_clock += delta
	var scene: Node3D = current_scene as Node3D
	if scene == null or _clock < _next:
		return false
	var field: SMPointer = scene.get("field") as SMPointer
	var side: SMSide = scene.get("side") as SMSide
	var stages: SMStages = scene.get("stages") as SMStages
	var view: Node = scene.get_node_or_null("StageView")
	if field == null or side == null or stages == null or view == null:
		quit()
		return false
	var out: String = str(_args.get("out", "/tmp/eva"))
	var placing: SMPlacement = side.placement
	if _beat == 0:
		var dismiss: Button = scene.find_child("BriefingDismiss", true, false) as Button
		if dismiss != null:
			dismiss.pressed.emit()
		_look(scene, view.call("objective_at") as Vector3, 30.0)
		_next = _clock + 0.8
	elif _beat == 1:
		_save(out + "-1-transmission-beacon.png")
		(scene.find_child("Build_scaffold_yard", true, false) as Button).pressed.emit()
		for id: String in ["salween_hydro", "slag_refinery"]:
			side.order_building(StringName(id))
		(scene.find_child("Build_barracks", true, false) as Button).pressed.emit()
		var road: Vector3 = _find(side, &"barracks", "blocked by a road")
		_look(scene, road, 22.0)
		placing.face(0.0)
		placing.hover(road)
		_next = _clock + 0.8
	elif _beat == 2:
		_save(out + "-2-blocked-road.png")
		var wet: Vector3 = _find(side, &"barracks", "needs dry ground")
		_look(scene, wet, 22.0)
		placing.hover(wet)
		placing.confirm()
		_next = _clock + 0.3
	elif _beat == 3:
		_save(out + "-3-blocked-water-flash.png")
		var fit: Vector3 = _find(side, &"barracks", "")
		_look(scene, fit, 22.0)
		placing.hover(fit)
		_next = _clock + 0.8
	elif _beat == 4:
		_save(out + "-4-open-plot.png")
		placing.cancel()
		side.order_building(&"barracks")
		side.order_building(&"war_factory")
		(scene.find_child("Build_naval_yard", true, false) as Button).pressed.emit()
		var dry: Vector3 = _find(side, &"naval_yard", "naval structures go on water")
		_look(scene, dry, 24.0)
		placing.hover(dry)
		_next = _clock + 0.8
	elif _beat == 5:
		_save(out + "-5-naval-on-land.png")
		var sea: Vector3 = _find(side, &"naval_yard", "")
		_look(scene, sea, 24.0)
		placing.hover(sea)
		_next = _clock + 0.8
	elif _beat == 6:
		_save(out + "-6-naval-on-water.png")
		placing.cancel()
		_look(scene, side.yard.center, 30.0)
		_next = _clock + 0.6
	elif _beat == 7:
		view.call("ping_objective")
		_next = _clock + 0.5
	elif _beat == 8:
		_save(out + "-7-ping-objective.png")
		stages.call("_raid_tick", float(stages.pressure["first_wave"]) + 1.0)
		for i: int in 40:
			field.tick(0.1)
		var lead: RTSUnit = null
		for u: RTSUnit in field.units_of(SMPointer.ENEMY):
			if lead == null and str(u.get_meta("duty", "")) == "raider":
				lead = u
		_look(scene, lead.global_position if lead != null else stages.rally, 26.0)
		_next = _clock + 1.0
	elif _beat == 9:
		_save(out + "-8-assault-wave.png")
		quit()
	_beat += 1
	return false

func _find(side: SMSide, id: StringName, want: String) -> Vector3:
	var grid: SMDomainGrid = side.plan.grid
	var c0: Vector2i = grid.cell_at(side.yard.center)
	for r: int in range(0, 30):
		for y: int in range(c0.y - r, c0.y + r + 1):
			for x: int in range(c0.x - r, c0.x + r + 1):
				if maxi(absi(x - c0.x), absi(y - c0.y)) != r:
					continue
				var at: Vector3 = grid.cell_center(Vector2i(x, y))
				if side.placement_reason(id, at, 0.0) == want:
					return at
	return side.yard.center

func _look(scene: Node, at: Vector3, distance: float) -> void:
	var cam: RTSCamera = scene.find_child("Camera", true, false) as RTSCamera
	if cam == null or at == Vector3.INF:
		return
	cam.focus = Vector3(at.x, 0.0, at.z)
	cam.distance = distance
	cam.apply()

func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
