extends RefCounted
## View-only work a unit can skip on the web, on Low, or once the web frame budget is strained.
## Off camera, a unit skips procedural motion and parks its AnimationPlayer and hand IK; the skipped
## seconds are replayed (capped) when it comes back into view. Zoomed far out, motion runs every
## third frame and small parts (wheels, barrels, packs, contact shadows) stop drawing.
## Nothing here reads or writes sim state.

const Settings = preload("res://game/match_settings.gd")

## RTSCamera.zoom_ratio() at and beyond which the view counts as far.
const FAR_ZOOM: float = 0.7
const FAR_EVERY: int = 3
## Metres a unit may sit outside the frustum and still pose, so it never pops in mid-stride.
const MARGIN: float = 4.0
const MAX_DEBT: float = 0.5
## Camera distance past which small unit parts stop drawing (zoom_max is 60).
## Trim carries the team colour and rotors read as aircraft from above, so both always draw.
const PART_RANGE: float = 46.0
const SMALL_PARTS: PackedStringArray = ["Wheel", "Barrel", "Weapon", "Pack", "ContactShadow"]

## Tests and the perf probe: 1 forces the budget on, 0 off, -1 follows the platform and settings.
static var force: int = -1

static var _planes: Array[Plane] = []
static var _frame: int = -1
static var _cam: Camera3D

static func active() -> bool:
	if force >= 0:
		return force == 1
	return OS.has_feature("web") or Settings.lean()

## Seconds of motion to pose this frame, or -1.0 to skip the unit this frame.
static func motion_step(u: RTSUnit, body: Node3D, delta: float) -> float:
	if body == null:
		return delta
	var debt: float = minf(float(body.get_meta("pose_debt", 0.0)) + delta, MAX_DEBT)
	var cam: Camera3D = u.get_viewport().get_camera_3d() if active() and u.is_alive() and u.is_inside_tree() else null
	if cam == null:
		park(body, false)
		body.set_meta("pose_debt", 0.0)
		return debt
	_range_parts(body)
	if not on_screen(cam, u.global_position):
		park(body, true)
		body.set_meta("pose_debt", debt)
		return -1.0
	park(body, false)
	var rts: RTSCamera = cam as RTSCamera
	if rts != null and rts.zoom_ratio() >= FAR_ZOOM and (u.get_instance_id() + Engine.get_process_frames()) % FAR_EVERY != 0:
		body.set_meta("pose_debt", debt)
		return -1.0
	body.set_meta("pose_debt", 0.0)
	return debt

static func on_screen(cam: Camera3D, at: Vector3) -> bool:
	var frame: int = Engine.get_process_frames()
	if frame != _frame or cam != _cam or _planes.is_empty():
		_planes = cam.get_frustum()
		_frame = frame
		_cam = cam
	var mid: Vector3 = at + Vector3(0.0, 1.0, 0.0)
	for plane: Plane in _planes:
		if plane.distance_to(mid) > MARGIN:
			return false
	return true

## Stops or restarts the unit's skeletal animation and hand IK. Cheap when nothing changes.
static func park(body: Node3D, on: bool) -> void:
	if body == null or bool(body.get_meta("parked", false)) == on:
		return
	body.set_meta("parked", on)
	if body.has_meta("anim_player"):
		var player: AnimationPlayer = body.get_meta("anim_player") as AnimationPlayer
		if is_instance_valid(player):
			player.active = not on
	for node: Node in body.find_children("*", "SkeletonModifier3D", true, false):
		(node as SkeletonModifier3D).active = not on

static func _range_parts(body: Node3D) -> void:
	var key: String = "%s:%d" % [str(body.get_meta("anim_seen", "")), body.get_child_count()]
	if str(body.get_meta("parts_ranged", "")) == key:
		return
	body.set_meta("parts_ranged", key)
	for node: Node in body.find_children("*", "GeometryInstance3D", true, false):
		var stem: String = String(node.name).rstrip("0123456789")
		if SMALL_PARTS.has(stem):
			(node as GeometryInstance3D).visibility_range_end = PART_RANGE
