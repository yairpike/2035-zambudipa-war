extends Node3D
## Holds a dead unit's Body after the sim frees the unit, plays the death, then clears itself.
## Rigged bodies play their die clip. Hulls flash, burn, throw the turret, and settle. Aircraft drop and burst.

const FX = preload("res://game/motion_fx.gd")

const RIGGED_HOLD: float = 4.0
const HULL_HOLD: float = 7.0
const SINK: float = 1.4

var body: Node3D
var player: AnimationPlayer
var form: String = ""
var age: float = 0.0
var hold: float = HULL_HOLD
var turret: Node3D
var turret_vel: Vector3 = Vector3.ZERO
var turret_spin: Vector3 = Vector3.ZERO
var fall_vel: float = 0.0
var tilt: Vector3 = Vector3.ZERO

func begin(p_body: Node3D, p_player: AnimationPlayer) -> void:
	body = p_body
	player = p_player
	form = str(body.get_meta("form", "")) if body != null else ""
	var r: RandomNumberGenerator = FX.rng()
	if player != null:
		hold = RIGGED_HOLD
		var clip: StringName = _clip(player, "die")
		if clip != &"":
			player.speed_scale = 1.0
			player.play(clip, 0.12)
		else:
			tilt = Vector3(-PI * 0.5, 0.0, 0.0)
		return
	if form == "figure":
		hold = RIGGED_HOLD
		tilt = Vector3(-PI * 0.5 * (1.0 if r.randf() < 0.5 else -1.0), 0.0, r.randf_range(-0.3, 0.3))
		return
	var size: float = _size()
	FX.blast(self, Vector3(0, size * 0.35, 0), clampf(size * 0.35, 0.6, 2.0))
	FX.fire(self, Vector3(0, size * 0.3, 0), clampf(size * 0.3, 0.5, 1.6))
	FX.smoke(self, Vector3(0, size * 0.45, 0), clampf(size * 0.35, 0.6, 2.0))
	FX.coat(body, FX.char_coat(0.62))
	for foam_name: String in ["Wake", "BowSpray"]:
		var foam_node: Node3D = body.get_node_or_null(foam_name) as Node3D
		if foam_node != null:
			foam_node.visible = false
	turret = body.get_node_or_null("Turret") as Node3D
	if turret != null:
		turret_vel = Vector3(r.randf_range(-1.0, 1.0), r.randf_range(4.5, 6.5), r.randf_range(-1.0, 1.0))
		turret_spin = Vector3(r.randf_range(-2.0, 2.0), r.randf_range(-5.0, 5.0), r.randf_range(-2.0, 2.0))
	tilt = Vector3(r.randf_range(-0.08, 0.08), r.randf_range(-0.15, 0.15), r.randf_range(-0.1, 0.1))
	if form == "boat" or form == "sub":
		tilt = Vector3(0.25, 0.0, 0.45 * (1.0 if r.randf() < 0.5 else -1.0))

func _clip(p: AnimationPlayer, key: String) -> StringName:
	for clip: StringName in p.get_animation_list():
		var name: String = str(clip)
		if name.get_slice("/", name.get_slice_count("/") - 1).to_lower() == key:
			return clip
	return &""

func _size() -> float:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in body.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = node as VisualInstance3D
		if vi is CPUParticles3D:
			continue
		var b: AABB = body.global_transform.affine_inverse() * vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return maxf(box.size.length() * 0.5, 1.0)

func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		queue_free()
		return
	age += delta
	if player == null:
		_settle(delta)
	if age > hold - SINK:
		body.position.y -= delta * 0.9
	if age >= hold:
		queue_free()

func _settle(delta: float) -> void:
	if form == "heli" or form == "jet" or form == "airship":
		fall_vel += 18.0 * delta
		var ground: float = -global_position.y
		if body.position.y > ground:
			body.position.y = maxf(ground, body.position.y - fall_vel * delta)
			body.rotate_y(delta * 4.0)
			body.rotation.z = lerpf(body.rotation.z, 0.6, delta * 2.0)
			if body.position.y <= ground + 0.01:
				FX.blast(self, Vector3(0, 0.4, 0), 1.2)
	else:
		body.rotation = body.rotation.lerp(tilt, minf(1.0, delta * 7.0))
	if turret != null and is_instance_valid(turret):
		turret_vel.y -= 14.0 * delta
		turret.position += turret.get_parent_node_3d().global_basis.inverse() * turret_vel * delta
		turret.rotation += turret_spin * delta
		if turret.global_position.y < global_position.y + 0.2 and turret_vel.y < 0.0:
			turret_vel = Vector3.ZERO
			turret_spin = Vector3.ZERO
