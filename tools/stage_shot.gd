extends SceneTree
## Windowed screenshots of a mission's stage arc: the escalation with allies arriving, the street counter-attack,
## the bonus payout and the climax. Not part of the test suite.
## godot --path . --resolution 1280x720 -s res://tools/stage_shot.gd -- --mission kokang --out /tmp/kokang

var _args: Dictionary = {}
var _clock: float = 0.0
var _beat: int = 0
var _next: float = 4.0

func _initialize() -> void:
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		_args[raw[i].trim_prefix("--")] = raw[i + 1] if i + 1 < raw.size() else ""
		i += 2
	var id: String = str(_args.get("mission", "kokang"))
	SMFront.faction_id = "gtfc"
	SMCampaign.selected = id
	var path: String = "res://game/campaign_mission.tscn"
	if id == "kokang":
		path = "res://game/mission_kokang.tscn"
	elif id == "sop_ruak":
		path = "res://game/sop_ruak.tscn"
	elif id == "phillips":
		path = "res://game/phillips_channel.tscn"
	change_scene_to_file(path)

func _process(delta: float) -> bool:
	_clock += delta
	var scene: Node3D = current_scene as Node3D
	if scene == null or _clock < _next:
		return false
	var arc: SMStages = _arc(scene)
	var field: SMPointer = scene.get("field") as SMPointer
	if arc == null or field == null:
		quit()
		return false
	var out: String = str(_args.get("out", "/tmp/stage"))
	if _beat == 0:
		var dismiss: Button = scene.find_child("BriefingDismiss", true, false) as Button
		if dismiss != null:
			dismiss.pressed.emit()
		_reveal(scene)
		for duty: String in arc.targets():
			_kill(field, duty)
		arc.tick(0.1, true)
		var dest: Vector3 = arc.rally + Vector3(-2.0, 0.0, 3.0)
		_look(scene, dest if str(arc.plan["allies"]) != "landing" else _landing_mid(arc, dest), 30.0)
		_next = _clock + 1.6
	elif _beat == 1:
		_save(out + "-1-escalation-allies.png")
		var lead: RTSUnit = _first(field, "counter")
		if lead != null:
			_look(scene, lead.global_position, 30.0)
		_next = _clock + 1.2
	elif _beat == 2:
		_save(out + "-2-counter-attack.png")
		_claim(scene, arc, field)
		_look(scene, arc.bonus_at(), 26.0)
		_next = _clock + 1.0
	elif _beat == 3:
		_save(out + "-3-bonus.png")
		_kill(field, "counter")
		arc.tick(0.1, true)
		var boss: RTSUnit = _first(field, "boss")
		var at: Vector3 = boss.global_position if boss != null else arc.rally
		_look(scene, at, 32.0)
		_next = _clock + 1.2
	elif _beat == 4:
		_save(out + "-4-climax.png")
		quit()
	_beat += 1
	_reveal(scene)
	return false

func _landing_mid(arc: SMStages, dest: Vector3) -> Vector3:
	var from: Vector3 = arc._point(arc.plan["allies_from"])
	return from.lerp(dest, 0.45)

func _arc(scene: Node) -> SMStages:
	var story: SMStory = scene.get("story") as SMStory
	if story != null:
		return story.stages
	return scene.get("stages") as SMStages

func _claim(scene: Node, arc: SMStages, field: SMPointer) -> void:
	var duty: String = arc.bonus_duty()
	if duty != "":
		_kill(field, duty)
	else:
		var spot: Vector3 = arc.bonus_at()
		var pinned: RTSUnit = _first(field, "pinned")
		if pinned != null:
			spot = pinned.global_position
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)):
				u.global_position = spot + Vector3(0.8, 0.0, 0.6)
				break
	var story: SMStory = scene.get("story") as SMStory
	if story != null:
		story.tick(0.05)
	arc.tick(0.05, true)

func _look(scene: Node, at: Vector3, distance: float) -> void:
	var cam: RTSCamera = scene.find_child("Camera", true, false) as RTSCamera
	if cam == null or at == Vector3.INF:
		return
	cam.focus = Vector3(at.x, 0.0, at.z)
	cam.distance = distance
	cam.apply()

## Lifts the fog so the counter-attack and the boss show in the shot.
func _reveal(scene: Node) -> void:
	var veil: Node3D = scene.get_node_or_null("FogVeil") as Node3D
	if veil != null:
		veil.visible = false
	var field: SMPointer = scene.get("field") as SMPointer
	if field == null:
		return
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive():
			u.visible = true

func _first(field: SMPointer, duty: String) -> RTSUnit:
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and str(u.get_meta("duty", "")) == duty:
			return u
	return null

func _kill(field: SMPointer, duty: String) -> void:
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and str(u.get_meta("duty", "")) == duty:
			u.take_damage(u.hp + 1.0)

func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
