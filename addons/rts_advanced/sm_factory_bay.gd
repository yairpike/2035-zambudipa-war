class_name SMFactoryBay
extends RefCounted
## Production rollout. The bay door opens, the new unit waits in the recessed bay facing out, drives through
## the doorway onto the exit pad, the door shuts behind it, and the unit heads for the building's rally point.
## One unit per door at a time; later units wait their turn inside. No meshes: views follow `door_moved`.

signal door_moved(building_id: StringName, open: float)
signal door_cue(building_id: StringName, kind: String)

const OPEN_TIME: float = 0.45
const ROLL_TIME: float = 0.7
const CLOSE_TIME: float = 0.45

var side: SMSide
var field: SMPointer
var runs: Array[Dictionary] = []
var doors: Dictionary[StringName, float] = {}
var launched: int = 0

## Hands `u` (already spawned) to the door of `building`. It ends up walking to `rally`.
func launch(u: RTSUnit, building: StringName, rally: Vector3, p_side: SMSide, p_field: SMPointer) -> void:
	if not is_instance_valid(u) or p_side == null:
		return
	side = p_side
	field = p_field
	var from: Vector3 = _keep(u, side.bay_point(building))
	var to: Vector3 = _keep(u, side.exit_point(building))
	var face: Vector3 = SMBasePlan.front_dir(side.front_of(building))
	u.position = Vector3(from.x, u.position.y, from.z)
	u.rotation.y = atan2(-face.x, -face.z)
	u.path = PackedVector3Array()
	u.attack_target = null
	u.set_meta("rolling", true)
	u.set_meta("bay_of", str(building))
	var waiting: bool = busy(building)
	runs.append({"unit": u, "building": building, "phase": "waiting" if waiting else "opening", "t": 0.0, "from": from, "to": to, "rally": rally})
	launched += 1
	if not waiting:
		door_cue.emit(building, "open")

## True while a unit is coming out of `building`. A closing door does not block the next unit.
func busy(building: StringName) -> bool:
	for run: Dictionary in runs:
		if run["building"] == building and (str(run["phase"]) == "opening" or str(run["phase"]) == "rolling"):
			return true
	return false

func rolling(u: RTSUnit) -> bool:
	return is_instance_valid(u) and bool(u.get_meta("rolling", false))

func door_open(building: StringName) -> float:
	return float(doors.get(building, 0.0))

func phase_of(u: RTSUnit) -> String:
	for run: Dictionary in runs:
		if run["unit"] == u:
			return str(run["phase"])
	return ""

func tick(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for run: Dictionary in runs:
		if _step(run, delta):
			kept.append(run)
	runs = kept

func _step(run: Dictionary, delta: float) -> bool:
	var u: RTSUnit = run["unit"] as RTSUnit
	var building: StringName = run["building"] as StringName
	var phase: String = str(run["phase"])
	if not is_instance_valid(u) or not u.is_alive():
		if phase != "waiting":
			_set_door(building, 0.0)
		return false
	if phase == "waiting":
		if not busy(building):
			run["phase"] = "opening"
			run["t"] = door_open(building) * OPEN_TIME
			door_cue.emit(building, "open")
		return true
	var t: float = float(run["t"]) + delta
	run["t"] = t
	if phase == "closing":
		if busy(building):
			return false
		_set_door(building, clampf(1.0 - t / CLOSE_TIME, 0.0, 1.0))
		if t >= CLOSE_TIME:
			door_cue.emit(building, "close")
			return false
		return true
	u.path = PackedVector3Array()
	u.attack_target = null
	if phase == "opening":
		_set_door(building, clampf(t / OPEN_TIME, 0.0, 1.0))
		if t >= OPEN_TIME:
			run["phase"] = "rolling"
			run["t"] = 0.0
		return true
	if phase == "rolling":
		var k: float = clampf(t / ROLL_TIME, 0.0, 1.0)
		var ease_k: float = k * k * (3.0 - 2.0 * k)
		var from: Vector3 = run["from"] as Vector3
		var to: Vector3 = run["to"] as Vector3
		var at: Vector3 = from.lerp(to, ease_k)
		u.position = Vector3(at.x, u.position.y, at.z)
		if k >= 1.0:
			run["phase"] = "closing"
			run["t"] = 0.0
			u.set_meta("rolling", false)
			_send_to_rally(u, run["rally"] as Vector3)
		return true
	return false

func _send_to_rally(u: RTSUnit, rally: Vector3) -> void:
	if rally == Vector3.INF:
		return
	var goal: Vector3 = _keep(u, rally)
	if field == null:
		u.set_path(PackedVector3Array([goal]))
		return
	var route: PackedVector3Array = field.nav_for_unit(u).find_path(u.global_position, goal)
	if route.is_empty():
		route = PackedVector3Array([goal])
	u.set_path(route)

func _set_door(building: StringName, open: float) -> void:
	doors[building] = open
	door_moved.emit(building, open)

## Boats stay on navigable water and land units on open ground.
func _keep(u: RTSUnit, at: Vector3) -> Vector3:
	if field == null:
		return at
	return field.open_spot(u, at)
