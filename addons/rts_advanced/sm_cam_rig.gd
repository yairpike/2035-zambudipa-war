class_name SMCamRig
extends RefCounted
## Smooth 360-degree orbit for an RTSCamera: eased yaw turns (Q/E, compass), north reset, tilt, and
## camera-relative keyboard panning. One rig per camera, kept in the camera's "rig" meta.
## Direct `cam.orbit()` calls from a mouse drag are followed, so the eased target never fights them.

const TURN_RATE: float = 120.0
const TURN_STEP: float = 45.0
const EASE: float = 9.0
const TILT_MIN: float = -20.0
const TILT_MAX: float = 22.0
const KEY_PAN: float = 1.1

var cam: RTSCamera
var target_yaw: float = 0.0
var seen_yaw: float = 0.0
var tilt: float = 0.0
var base_near: float = 45.0
var base_far: float = 60.0

static func of(camera: RTSCamera) -> SMCamRig:
	if camera == null:
		return null
	if camera.has_meta("rig"):
		var kept: Variant = camera.get_meta("rig")
		if kept is SMCamRig:
			return kept as SMCamRig
	var rig: SMCamRig = SMCamRig.new()
	rig.cam = camera
	rig.target_yaw = camera.yaw_degrees
	rig.seen_yaw = camera.yaw_degrees
	rig.base_near = camera.pitch_near
	rig.base_far = camera.pitch_far
	camera.set_meta("rig", rig)
	return rig

## Eases the yaw by `degrees` (positive turns the view clockwise seen from above).
func turn(degrees: float) -> void:
	_follow()
	target_yaw += degrees

## Eases back to north (yaw 0) the short way round.
func north() -> void:
	_follow()
	target_yaw = roundf(cam.yaw_degrees / 360.0) * 360.0

## Held keys: -1 left, +1 right.
func hold(dir: float, delta: float) -> void:
	if dir == 0.0:
		return
	_follow()
	target_yaw += dir * TURN_RATE * delta

## Mouse drag orbit: x yaws at once, y tilts.
func drag(relative: Vector2) -> void:
	_follow()
	cam.orbit(relative.x * 0.25)
	target_yaw += relative.x * 0.25
	seen_yaw = cam.yaw_degrees
	tilt_by(-relative.y * 0.15)

func tilt_by(degrees: float) -> void:
	tilt = clampf(tilt + degrees, TILT_MIN, TILT_MAX)
	cam.pitch_near = clampf(base_near + tilt, 20.0, 82.0)
	cam.pitch_far = clampf(base_far + tilt, 25.0, 85.0)
	cam.apply()

## Camera-relative pan: x right, y forward, in screen terms at any yaw.
func pan_keys(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	cam.pan(dir.normalized() * KEY_PAN, delta)

## Compass heading in degrees, 0 = north, growing clockwise.
func heading() -> float:
	return fposmod(-cam.yaw_degrees, 360.0)

func settled() -> bool:
	return absf(target_yaw - cam.yaw_degrees) < 0.05

func step(delta: float) -> void:
	if cam == null:
		return
	_follow()
	var gap: float = target_yaw - cam.yaw_degrees
	if absf(gap) < 0.05:
		if gap != 0.0:
			cam.orbit(gap)
	else:
		cam.orbit(gap * (1.0 - exp(-EASE * delta)))
	seen_yaw = cam.yaw_degrees

## Settles at once. Tests and screenshots use it.
func snap() -> void:
	_follow()
	cam.orbit(target_yaw - cam.yaw_degrees)
	seen_yaw = cam.yaw_degrees

func _follow() -> void:
	var moved: float = cam.yaw_degrees - seen_yaw
	if moved != 0.0:
		target_yaw += moved
		seen_yaw = cam.yaw_degrees
