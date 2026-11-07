extends RefCounted
## View-only unit motion. Rigged models play idle, walk, run, shoot, ability, flinch, deploy and die clips; hulls get recoil,
## bob, banking and ability moves. Every body turns smoothly toward its path; soldiers face what they shoot, turrets track it.
## Everything here reads RTSUnit state and writes only under the unit's Body node, so the sim stays deterministic.

const FX = preload("res://game/motion_fx.gd")
const DeathFx = preload("res://game/death_fx.gd")

const WALK_PACE: float = 5.0
const RUN_PACE: float = 7.5
## Ground speed (speed × speed_scale) at which a rigged unit switches from walk to run.
const RUN_AT: float = 6.2
const SHOT_HOLD: float = 0.7
const FLINCH_HOLD: float = 0.45
const BLEND: float = 0.18
const TURRET_RATE: float = 9.0
const TURN_FOOT: float = 8.0
const TURN_HULL: float = 3.4
const TURN_AIR: float = 4.6
## Seconds a stopped tube or mech waits before it braces (deploys).
const BRACE_AFTER: float = 1.2
const DRAW_RATE: float = 4.0
const LOOPED: PackedStringArray = ["idle", "walk", "shoot", "run"]
## A clip a unit lacks falls back to the next name here.
const STAND_IN: Dictionary = {"ability": "deploy", "run": "walk", "flinch": "", "deploy": ""}

## Wires a freshly dressed unit. Safe to call again after the model swaps in.
static func attach(u: RTSUnit, body: MeshInstance3D) -> void:
	if u == null or body == null:
		return
	if not u.fired.is_connected(on_fired):
		u.fired.connect(on_fired)
	if not u.died.is_connected(on_died):
		u.died.connect(on_died)

static func player_of(body: Node) -> AnimationPlayer:
	if body == null:
		return null
	var model: String = str(body.get_meta("model", ""))
	var seen: String = "%s:%d" % [model, body.get_node_or_null("Model").get_instance_id() if body.get_node_or_null("Model") != null else 0]
	if str(body.get_meta("anim_seen", "-")) == seen:
		var cached: Variant = body.get_meta("anim_player") if body.has_meta("anim_player") else null
		return cached as AnimationPlayer if is_instance_valid(cached) else null
	body.set_meta("anim_seen", seen)
	var found: AnimationPlayer = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	body.set_meta("anim_player", found)
	if found != null:
		_prime(found)
		_rig_sockets(body as Node3D)
	return found

static func _prime(player: AnimationPlayer) -> void:
	for clip: StringName in player.get_animation_list():
		var anim: Animation = player.get_animation(clip)
		var key: String = _clip_key(str(clip))
		anim.loop_mode = Animation.LOOP_LINEAR if LOOPED.has(key) else Animation.LOOP_NONE
	player.playback_default_blend_time = BLEND

static func _clip_key(clip: String) -> String:
	return clip.get_slice("/", clip.get_slice_count("/") - 1).to_lower()

static func _find_clip(player: AnimationPlayer, key: String) -> StringName:
	for clip: StringName in player.get_animation_list():
		if _clip_key(str(clip)) == key:
			return clip
	return &""

static func has_clip(player: AnimationPlayer, key: String) -> bool:
	return player != null and _find_clip(player, key) != &""

## The clip key this unit can actually play for `key`, following STAND_IN, or "" when it has none.
static func resolve(player: AnimationPlayer, key: String) -> String:
	var want: String = key
	var guard: int = 0
	while want != "" and guard < 4:
		if has_clip(player, want):
			return want
		want = str(STAND_IN.get(want, ""))
		guard += 1
	return ""

## Picks the action a unit is showing right now: die, ability, flinch, run, walk, shoot, deploy or idle.
static func clip_for(u: RTSUnit, body: Node) -> String:
	if not u.is_alive():
		return "die"
	var player: AnimationPlayer = player_of(body)
	if float(body.get_meta("anim_ability", 0.0)) > 0.0 and (player == null or resolve(player, "ability") != ""):
		return "ability"
	if float(body.get_meta("anim_flinch", 0.0)) > 0.0 and (player == null or has_clip(player, "flinch")):
		return "flinch"
	if u.is_moving():
		if u.speed * u.speed_scale >= RUN_AT and (player == null or has_clip(player, "run")):
			return "run"
		return "walk"
	if float(body.get_meta("anim_shot", 0.0)) > 0.0 or engaged(u):
		return "shoot"
	if float(body.get_meta("anim_still", 0.0)) >= BRACE_AFTER and str(u.unit_type) == "packer" and has_clip(player, "deploy"):
		return "deploy"
	return "idle"

static func engaged(u: RTSUnit) -> bool:
	var foe: RTSUnit = u.attack_target
	if foe == null or not is_instance_valid(foe) or not foe.is_alive():
		return false
	var a: Vector3 = u.global_position
	var b: Vector3 = foe.global_position
	return Vector2(a.x - b.x, a.z - b.z).length() <= u.attack_range * 1.05

static func play(player: AnimationPlayer, key: String, pace: float = 1.0) -> bool:
	var clip: StringName = _find_clip(player, key)
	if clip == &"":
		return false
	if player.current_animation != clip:
		player.play(clip)
	player.speed_scale = pace
	return true

## World yaw (game convention, forward -Z) from `from` toward `to`.
static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2(-d.x, -d.z)

## Called every view frame per unit (SMPointer.unit_posed).
static func pose(u: RTSUnit, delta: float) -> void:
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	_tick(body, "anim_shot", delta)
	_tick(body, "anim_flinch", delta)
	_tick(body, "anim_ability", delta)
	body.set_meta("anim_t", float(body.get_meta("anim_t", 0.0)) + delta)
	var still: float = 0.0 if u.is_moving() else float(body.get_meta("anim_still", 0.0)) + delta
	body.set_meta("anim_still", still)
	var player: AnimationPlayer = player_of(body)
	_watch(u, body, player)
	_turn(u, body, player, delta)
	if player != null:
		var key: String = clip_for(u, body)
		var clip: String = resolve(player, key)
		var pace: float = 1.0
		if key == "walk":
			pace = clampf(u.speed * u.speed_scale / WALK_PACE, 0.6, 1.8)
		elif key == "run":
			pace = clampf(u.speed * u.speed_scale / RUN_PACE, 0.8, 1.6)
		if clip == "" and has_clip(player, "walk"):
			# Dogs ship with walk only: hold the first stride frame and move the body instead.
			play(player, "walk", 0.0)
			player.seek(0.0, true)
		else:
			play(player, clip, pace)
		_creature(u, body, player, key, delta)
		_weapon(body, delta, key)
		return
	_hull(u, body, delta)

static func _tick(body: Node, key: String, delta: float) -> void:
	body.set_meta(key, maxf(0.0, float(body.get_meta(key, 0.0)) - delta))

## Reads sim state for actions it does not signal: a cast (cooldown jumps up), a hit (hp drops), a garrison exit.
static func _watch(u: RTSUnit, body: MeshInstance3D, player: AnimationPlayer) -> void:
	var cooldown: float = float(u.get_meta("f_ready", 0.0))
	var was_cooldown: float = float(body.get_meta("anim_f_ready", cooldown))
	body.set_meta("anim_f_ready", cooldown)
	var channel: bool = bool(u.get_meta("channeling", false))
	var was_channel: bool = bool(body.get_meta("anim_channel", false))
	body.set_meta("anim_channel", channel)
	if cooldown > was_cooldown + 0.5 or (channel and not was_channel):
		start_ability(u, body, player)
	var hp: float = u.hp
	var was_hp: float = float(body.get_meta("anim_hp", hp))
	body.set_meta("anim_hp", hp)
	if hp < was_hp - 0.01 and u.is_alive() and float(body.get_meta("anim_ability", 0.0)) <= 0.0:
		body.set_meta("anim_flinch", FLINCH_HOLD)
	var housed: bool = bool(u.get_meta("garrisoned", false))
	var was_housed: bool = bool(body.get_meta("anim_housed", false))
	body.set_meta("anim_housed", housed)
	var stage: Node3D = u.get_parent() as Node3D
	if housed != was_housed and stage != null:
		FX.dust(stage, u.global_position + Vector3(0, 0.1, 0), 0.9, 10)
		if not housed:
			body.set_meta("anim_pop", 0.0)

## Starts the ability action. Rigged units play their ability clip; hulls get a move keyed to the ability's effect.
static func start_ability(u: RTSUnit, body: MeshInstance3D, player: AnimationPlayer = null) -> void:
	var hold: float = 1.2
	if player != null:
		var clip: StringName = _find_clip(player, resolve(player, "ability"))
		if clip != &"":
			hold = clampf(player.get_animation(clip).length, 0.6, 2.4)
			player.stop()
	body.set_meta("anim_ability", hold)
	body.set_meta("anim_ability_len", hold)
	body.set_meta("anim_ability_kind", _ability_move(u))
	var stage: Node3D = u.get_parent() as Node3D
	if stage != null:
		FX.ring(stage, u.global_position + Vector3(0, 0.15, 0), 1.6, Color(0.55, 0.9, 1.0) if u.team != 0 else Color(1.0, 0.75, 0.3))

## Which body move a procedural unit makes for its F ability. Read from the metas SMCast sets.
static func _ability_move(u: RTSUnit) -> String:
	if bool(u.get_meta("jump", false)):
		return "hop"
	if bool(u.get_meta("ram", false)) or bool(u.get_meta("charge", false)) or bool(u.get_meta("harpoon", false)):
		return "lunge"
	if bool(u.get_meta("shielded", false)) or bool(u.get_meta("aegis", false)):
		return "dome"
	if bool(u.get_meta("afterburner", false)) or bool(u.get_meta("chopper", false)) or bool(u.get_meta("sky", false)):
		return "rise"
	if str(u.get_meta("beam_kind", "")) != "":
		return "beam"
	return "pulse"

## The body's rendered heading follows the sim heading at a turn rate. Soldiers and dogs face a target they shoot.
static func _turn(u: RTSUnit, body: MeshInstance3D, player: AnimationPlayer, delta: float) -> void:
	var form: String = str(body.get_meta("form", ""))
	var footed: bool = player != null or form == "figure" or form == "hero"
	var want: float = u.rotation.y
	if footed and not u.is_moving() and engaged(u):
		want = yaw_to(u.global_position, u.attack_target.global_position)
	var rate: float = TURN_HULL
	if footed:
		rate = TURN_FOOT
	elif form == "heli" or form == "jet" or form == "airship":
		rate = TURN_AIR
	var heading: float = float(body.get_meta("anim_heading", u.rotation.y))
	heading = rotate_toward(heading, want, rate * delta)
	body.set_meta("anim_heading", heading)
	body.rotation.y = wrapf(heading - u.rotation.y, -PI, PI)

## World yaw the body is drawn at.
static func heading_of(u: RTSUnit) -> float:
	var body: Node3D = u.get_node_or_null("Body") as Node3D
	if body == null:
		return u.rotation.y
	return float(body.get_meta("anim_heading", u.rotation.y))

## The direction the model visibly faces, measured from the model itself: hips and shoulders for rigged bipeds,
## head over tail for dogs, the corrected body axis for everything else.
static func rendered_forward(body: Node3D) -> Vector3:
	var skel: Skeleton3D = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		var f: Vector3 = Vector3.ZERO
		for pair: Array in [["L_Thigh", "R_Thigh"], ["L_Upperarm", "R_Upperarm"]]:
			var a: int = skel.find_bone(str(pair[0]))
			var b: int = skel.find_bone(str(pair[1]))
			if a >= 0 and b >= 0:
				var right: Vector3 = (skel.global_transform * skel.get_bone_global_pose(b).origin) - (skel.global_transform * skel.get_bone_global_pose(a).origin)
				f += Vector3.UP.cross(right).normalized()
		var head: int = skel.find_bone("tripo__Head_0")
		var tail: int = skel.find_bone("tripo__Tail_0")
		if f == Vector3.ZERO and head >= 0 and tail >= 0:
			f = (skel.global_transform * skel.get_bone_global_pose(head).origin) - (skel.global_transform * skel.get_bone_global_pose(tail).origin)
		f.y = 0.0
		if f.length() > 0.001:
			return f.normalized()
	var axis: Vector3 = -body.global_basis.z
	axis.y = 0.0
	return axis.normalized()

## Dogs and mechs: lunge on a shot, rear up on an ability, breathe at rest.
static func _creature(u: RTSUnit, body: MeshInstance3D, player: AnimationPlayer, key: String, delta: float) -> void:
	var t: float = float(body.get_meta("anim_t", 0.0))
	var pitch: float = 0.0
	var push: float = 0.0
	var lift: float = 0.0
	var pop: float = float(body.get_meta("anim_pop", 1.0))
	if pop < 1.0:
		pop = minf(1.0, pop + delta * 3.0)
		body.set_meta("anim_pop", pop)
	if not has_clip(player, "idle"):
		if key == "idle":
			lift = sin(t * 2.4) * 0.015
		elif key == "shoot":
			push = maxf(0.0, sin(t * 9.0)) * 0.22
			pitch = -0.08 * maxf(0.0, sin(t * 9.0))
		elif key == "ability":
			pitch = 0.45 * sin(PI * _ability_k(body))
		elif key == "flinch":
			push = -0.1
	if bool(u.get_meta("locomotion", "") == "air") and str(u.unit_type) == "wharf_gun":
		lift = 1.6 + sin(t * 2.0) * 0.1
	body.rotation.x = lerpf(body.rotation.x, pitch, minf(1.0, delta * 10.0))
	var fwd: Vector3 = Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y)) * -1.0
	body.position = body.position.lerp(fwd * push + Vector3(0, lift, 0), minf(1.0, delta * 12.0))
	body.scale = Vector3.ONE * (0.75 + 0.25 * _ease_kick(pop))

static func _ability_k(body: Node) -> float:
	var hold: float = maxf(float(body.get_meta("anim_ability_len", 1.0)), 0.01)
	return clampf(1.0 - float(body.get_meta("anim_ability", 0.0)) / hold, 0.0, 1.0)

## Socketed props on rigged units: recoil along the barrel, off-hand IK on the grip.
static func _weapon(body: MeshInstance3D, delta: float, key: String) -> void:
	var kick: float = move_toward(float(body.get_meta("anim_kick", 0.0)), 0.0, delta * 7.0)
	body.set_meta("anim_kick", kick)
	var sling: Node3D = sling_of(body)
	var drawn: float = 1.0
	if sling != null:
		drawn = move_toward(float(body.get_meta("anim_draw", 0.0)), 1.0 if key == "shoot" else 0.0, delta * DRAW_RATE)
		body.set_meta("anim_draw", drawn)
	for weapon: MeshInstance3D in weapons_of(body):
		var muzzle: Node3D = weapon.get_node_or_null("Muzzle") as Node3D
		if muzzle == null:
			continue
		if not weapon.has_meta("anim_rest"):
			weapon.set_meta("anim_rest", weapon.transform)
			weapon.set_meta("anim_holder", weapon.get_parent())
		var stowed: bool = sling != null and drawn <= 0.0 and weapon.name == "Weapon"
		var holder: Node = sling if stowed else weapon.get_meta("anim_holder") as Node
		if holder != null and weapon.get_parent() != holder:
			weapon.reparent(holder, false)
		if stowed:
			weapon.transform = Transform3D.IDENTITY
			continue
		var rest: Transform3D = weapon.get_meta("anim_rest")
		var grip: Vector3 = weapon.get_aabb().get_center()
		var axis: Vector3 = muzzle.position - grip
		var back: Vector3 = rest.basis * (-axis.normalized()) * axis.length() * 0.12
		weapon.transform = Transform3D(rest.basis, rest.origin + back * _ease_kick(kick))
		if sling != null and drawn < 1.0 and weapon.name == "Weapon":
			weapon.global_transform = weapon.global_transform.interpolate_with(sling.global_transform, 1.0 - drawn)
	_brace_shields(body, delta, key)
	var ik: SkeletonModifier3D = null
	if body.has_meta("anim_ik") and is_instance_valid(body.get_meta("anim_ik")):
		ik = body.get_meta("anim_ik") as SkeletonModifier3D
	if ik != null:
		var hold: bool = key == "idle" or key == "walk" or key == "run" or key == "shoot"
		var want: float = drawn if sling != null else (1.0 if hold else 0.0)
		ik.influence = move_toward(ik.influence, want, delta * 5.0)

## A rifle carried on the back: the WeaponSling marker on the spine holds its slung place, and it is drawn into the
## hands only to fire.
static func sling_of(body: Node) -> Node3D:
	var model: Node = body.get_node_or_null("Model")
	if model == null:
		return null
	var stamp: int = model.get_instance_id()
	if int(body.get_meta("anim_sling_of", -1)) != stamp:
		body.set_meta("anim_sling_of", stamp)
		body.set_meta("anim_sling", model.find_child("WeaponSling", true, false))
	var found: Variant = body.get_meta("anim_sling")
	return found as Node3D if found != null and is_instance_valid(found) else null

static func weapons_of(body: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var model: Node = body.get_node_or_null("Model")
	var stamp: int = model.get_instance_id() if model != null else 0
	if int(body.get_meta("anim_weapons_of", -1)) == stamp:
		for item: Variant in body.get_meta("anim_weapons", []):
			if is_instance_valid(item):
				out.append(item as MeshInstance3D)
		return out
	if model != null:
		for node: Node in model.find_children("Weapon*", "MeshInstance3D", true, false):
			out.append(node as MeshInstance3D)
	body.set_meta("anim_weapons_of", stamp)
	body.set_meta("anim_weapons", out.duplicate())
	return out

## The barrel tip of the first socketed weapon that has one, or null.
static func muzzle_of(body: Node) -> Node3D:
	for weapon: MeshInstance3D in weapons_of(body):
		var muzzle: Node3D = weapon.get_node_or_null("Muzzle") as Node3D
		if muzzle != null:
			return muzzle
	return null

## Two-handed weapons: the off hand reaches for the Grip socket the Blender pass placed on the weapon.
static func _rig_sockets(body: Node3D) -> void:
	if body == null:
		return
	var skel: Skeleton3D = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or skel.get_node_or_null("OffHandIK") != null:
		return
	for weapon: MeshInstance3D in weapons_of(body):
		var grip: Node3D = weapon.get_node_or_null("Grip") as Node3D
		var holder: Node = weapon.get_parent()
		if grip == null or not (holder is BoneAttachment3D):
			continue
		var side: String = "L" if str((holder as BoneAttachment3D).bone_name).begins_with("R") else "R"
		if skel.find_bone("%s_Upperarm" % side) < 0 or skel.find_bone("%s_Hand" % side) < 0:
			continue
		if _carries_shield(body, side):
			continue
		var ik: OffHandIK = OffHandIK.make(skel, side, grip)
		if ik == null:
			continue
		body.set_meta("anim_ik", ik)
		return

## Firing clips raise the shield forearm, which would lay the shield flat overhead. While firing, the shield keeps
## the place and facing it has beside the standing body, lowered by however far the hips drop.
static func _brace_shields(body: MeshInstance3D, delta: float, key: String) -> void:
	var model: Node = body.get_node_or_null("Model")
	if model == null:
		return
	if not body.has_meta("anim_shields"):
		body.set_meta("anim_shields", model.find_children("Shield*", "MeshInstance3D", true, false))
	var shields: Array = body.get_meta("anim_shields")
	if shields.is_empty():
		return
	var hip: float = _hip_height(body)
	for node: Variant in shields:
		var shield: MeshInstance3D = node as MeshInstance3D
		if shield == null or not is_instance_valid(shield) or not shield.is_inside_tree():
			continue
		if not shield.has_meta("anim_rest_xf"):
			shield.set_meta("anim_rest_xf", shield.transform)
		var rest: Transform3D = shield.get_meta("anim_rest_xf")
		shield.transform = rest
		var centre: Vector3 = shield.get_aabb().get_center()
		if key != "shoot" and key != "die" and not shield.has_meta("anim_stand"):
			shield.set_meta("anim_stand", body.global_transform.affine_inverse() * shield.global_transform)
			shield.set_meta("anim_stand_hip", hip)
		var w: float = move_toward(float(shield.get_meta("anim_brace", 0.0)), 1.0 if key == "shoot" else 0.0, delta * 4.0)
		shield.set_meta("anim_brace", w)
		if w <= 0.0 or not shield.has_meta("anim_stand"):
			continue
		var stand: Transform3D = body.global_transform * (shield.get_meta("anim_stand") as Transform3D)
		stand.origin += Vector3.UP * (hip - float(shield.get_meta("anim_stand_hip")))
		var now: Transform3D = shield.global_transform
		var pin: Vector3 = (now * centre).lerp(stand * centre, w)
		var turned: Transform3D = now.interpolate_with(stand, w)
		turned.origin += pin - turned * centre
		shield.global_transform = turned

## World height of the hips (the thighs' midpoint) above the body, or 0 for models without thighs.
static func _hip_height(body: Node3D) -> float:
	var skel: Skeleton3D = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return 0.0
	var a: int = skel.find_bone("L_Thigh")
	var b: int = skel.find_bone("R_Thigh")
	if a < 0 or b < 0:
		return 0.0
	var mid: Vector3 = (skel.get_bone_global_pose(a).origin + skel.get_bone_global_pose(b).origin) * 0.5
	return (skel.global_transform * mid).y - body.global_position.y

## A shield arm keeps the shield up front instead of reaching for the weapon grip.
static func _carries_shield(body: Node3D, side: String) -> bool:
	var model: Node = body.get_node_or_null("Model")
	if model == null:
		return false
	for node: Node in model.find_children("Shield*", "MeshInstance3D", true, false):
		var holder: Node = node.get_parent()
		if holder is BoneAttachment3D and str((holder as BoneAttachment3D).bone_name).begins_with(side):
			return true
	return false

static func _hull(u: RTSUnit, body: MeshInstance3D, delta: float) -> void:
	var form: String = str(body.get_meta("form", ""))
	var kind_id: String = str(body.get_meta("unit_kind", u.unit_type))
	var role_id: String = str(body.get_meta("unit_role", u.get_meta("role", "")))
	var loco_id: String = str(u.get_meta("locomotion", body.get_meta("unit_loco", "ground")))
	var forms_script: GDScript = load("res://game/unit_meshes.gd") as GDScript
	if not bool(body.get_meta("hull_parts_ready", false)):
		forms_script.call("ensure_hull_parts", body, kind_id, form, role_id, loco_id, body.get_meta("trim_ink", Color.WHITE))
	var t: float = float(body.get_meta("anim_t", 0.0))
	var moving: bool = u.is_moving()
	var was_moving: bool = bool(body.get_meta("anim_was_moving", false))
	body.set_meta("anim_was_moving", moving)
	var accel: float = float(body.get_meta("anim_accel", 0.0))
	if moving and not was_moving:
		accel = 1.0
	elif moving:
		accel = move_toward(accel, 0.35, delta * 1.6)
	else:
		accel = move_toward(accel, 0.0, delta * 3.0)
	body.set_meta("anim_accel", accel)
	var heading: float = float(body.get_meta("anim_heading", u.rotation.y))
	var wheels: Node3D = body.get_node_or_null("Wheels") as Node3D
	if wheels != null:
		var spin: float = float(body.get_meta("anim_wheel_spin", 0.0))
		if moving:
			spin += (u.speed * u.speed_scale * delta) / 0.28
			body.set_meta("anim_wheel_spin", spin)
		for idx: int in wheels.get_child_count():
			var w: Node3D = wheels.get_child(idx) as Node3D
			if w == null:
				continue
			var r: float = float(w.get_meta("wheel_r", 0.28))
			var rest_y: float = float(w.get_meta("rest_y", r))
			w.rotation.x = -spin * (0.28 / maxf(r, 0.1))
			var bounce: float = sin(spin * 1.8 + float(idx) * 1.1) * 0.016 if moving else 0.0
			w.position.y = lerpf(w.position.y, rest_y + bounce, minf(1.0, delta * 14.0))
	var kick: float = float(body.get_meta("anim_kick", 0.0))
	kick = move_toward(kick, 0.0, delta * 5.0)
	body.set_meta("anim_kick", kick)
	var braced: bool = form == "tube" and float(body.get_meta("anim_still", 0.0)) >= BRACE_AFTER
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	var target_elev: float = 0.0
	if turret != null:
		if not turret.has_meta("anim_rest_pitch"):
			turret.set_meta("anim_rest_pitch", turret.rotation.x)
		var want: float = 0.0
		var foe: RTSUnit = u.attack_target
		if foe != null and is_instance_valid(foe) and foe.is_alive():
			var u_pos: Vector3 = u.global_position if u.is_inside_tree() else u.position
			var f_pos: Vector3 = foe.global_position if foe.is_inside_tree() else foe.position
			want = wrapf(yaw_to(u_pos, f_pos) - heading, -PI, PI)
			var dx: float = f_pos.x - u_pos.x
			var dz: float = f_pos.z - u_pos.z
			var flat_d: float = maxf(sqrt(dx * dx + dz * dz), 0.5)
			var foe_air: bool = str(foe.get_meta("locomotion", "")) == "air" or str(foe.get_meta("role", "")) == "air" or str(foe.get_meta("role", "")) == "drone"
			var dy: float = (f_pos.y + (1.8 if foe_air else 0.0)) - u_pos.y
			target_elev = clampf(atan2(dy, flat_d), -0.35, 0.55)
			if form == "tube":
				target_elev += 0.22 + (0.10 if braced else 0.0)
			elif absf(target_elev) < 0.04:
				target_elev = 0.06
		turret.rotation.y = rotate_toward(turret.rotation.y, want, TURRET_RATE * delta)
		var turret_rest_pitch: float = float(turret.get_meta("anim_rest_pitch", 0.0))
		var want_turret_pitch: float = turret_rest_pitch + target_elev * 0.6 + _ease_kick(kick) * 0.08
		turret.rotation.x = lerpf(turret.rotation.x, want_turret_pitch, minf(1.0, delta * 8.0))
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
	if barrel != null:
		if not barrel.has_meta("anim_rest"):
			barrel.set_meta("anim_rest", barrel.position)
			barrel.set_meta("anim_rest_pitch", barrel.rotation.x)
		var rest: Vector3 = barrel.get_meta("anim_rest")
		barrel.position = rest + barrel.basis.z.normalized() * _ease_kick(kick) * 0.45
		var elevate: float = target_elev + (0.12 if braced and engaged(u) else 0.0) + _ease_kick(kick) * 0.1
		barrel.rotation.x = lerpf(barrel.rotation.x, float(barrel.get_meta("anim_rest_pitch", 0.0)) + elevate, minf(1.0, delta * 6.0))
	var yaw_was: float = float(body.get_meta("anim_yaw", heading))
	var turn_rate: float = wrapf(heading - yaw_was, -PI, PI) / maxf(delta, 0.0001)
	var turn_err: float = wrapf(u.rotation.y - heading, -PI, PI)
	body.set_meta("anim_yaw", heading)
	var rotor: Node3D = body.get_node_or_null("Rotor") as Node3D
	if rotor != null:
		rotor.rotate_y(delta * (30.0 if moving else 22.0))
	var wake: MeshInstance3D = body.get_node_or_null("Wake") as MeshInstance3D
	if wake != null:
		wake.visible = moving
		if moving:
			wake.scale = Vector3.ONE * (0.92 + 0.12 * sin(t * 9.0))
	var spray: MeshInstance3D = body.get_node_or_null("BowSpray") as MeshInstance3D
	if spray != null:
		spray.visible = moving
		if moving:
			spray.scale = Vector3.ONE * (0.88 + 0.14 * cos(t * 11.0))
	var lift: float = 0.0
	var pitch: float = 0.0
	var roll: float = 0.0
	var recoil_z: float = 0.0
	var airborne: bool = bool(forms_script.call("is_air_unit", kind_id, role_id, loco_id, form))
	var boat_hull: bool = not airborne and bool(forms_script.call("is_boat_unit", kind_id, role_id, loco_id, form))
	if airborne:
		var base: float = 0.0 if form == "heli" or form == "jet" or form == "airship" else 1.8
		lift = base + sin(t * 2.2) * 0.14 + cos(t * 3.7) * 0.03
		pitch = (-0.16 - accel * 0.08 if moving else sin(t * 1.5) * 0.025) + _ease_kick(kick) * 0.16
		roll = clampf(-turn_rate * 0.28 - turn_err * 0.45, -0.58, 0.58) + (sin(t * 2.4) * 0.04 if moving else sin(t * 1.4) * 0.02)
		recoil_z = _ease_kick(kick) * 0.14
	elif boat_hull and loco_id != "ground" and not bool(u.get_meta("legs", false)):
		lift = sin(t * 1.8) * 0.06 + (0.04 if moving else 0.0)
		pitch = (0.07 + accel * 0.05 if moving else 0.0) + sin(t * 1.4) * 0.035 + _ease_kick(kick) * 0.08
		roll = sin(t * 1.3 + 0.5) * 0.05 + clampf(-turn_rate * 0.14 - turn_err * 0.25, -0.22, 0.22)
		recoil_z = _ease_kick(kick) * 0.14
		if form == "sub" and not moving and not engaged(u):
			lift -= 0.35
	else:
		if moving:
			lift = absf(sin(t * 15.0)) * 0.028
			pitch = sin(t * 7.0) * 0.01 - 0.012 + accel * 0.04
			roll = clampf(-turn_rate * 0.06 - turn_err * 0.1, -0.08, 0.08)
		pitch += _ease_kick(kick) * 0.09
		recoil_z = _ease_kick(kick) * 0.18
		if braced:
			lift -= 0.06
		if form == "boat":
			lift += 0.22
	var move: String = str(body.get_meta("anim_ability_kind", "pulse"))
	if float(body.get_meta("anim_ability", 0.0)) > 0.0:
		var k: float = _ability_k(body)
		var arc: float = sin(PI * k)
		if move == "hop":
			lift += arc * 1.6
			pitch -= arc * 0.2
		elif move == "lunge":
			pitch += arc * 0.12
			body.position.z = lerpf(body.position.z, -arc * 0.8, minf(1.0, delta * 12.0))
		elif move == "rise":
			lift += arc * 0.9
			pitch -= arc * 0.15
		elif move == "dome":
			_dome(body, arc)
		else:
			lift += arc * 0.15
	else:
		body.position.z = lerpf(body.position.z, recoil_z, minf(1.0, delta * (14.0 if kick > 0.1 else 6.0)))
		_dome(body, 0.0)
	body.position.y = lerpf(body.position.y, lift, minf(1.0, delta * 10.0))
	body.rotation.x = lerpf(body.rotation.x, pitch, minf(1.0, delta * 8.0))
	body.rotation.z = lerpf(body.rotation.z, roll, minf(1.0, delta * 5.0))

## A translucent shield bubble for riot shields, hydro-shields and domes.
static func _dome(body: MeshInstance3D, amount: float) -> void:
	var dome: MeshInstance3D = body.get_node_or_null("AbilityDome") as MeshInstance3D
	if amount <= 0.01:
		if dome != null:
			dome.visible = false
		return
	if dome == null:
		dome = MeshInstance3D.new()
		dome.name = "AbilityDome"
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 1.8
		sphere.height = 2.4
		sphere.radial_segments = 16
		sphere.rings = 8
		dome.mesh = sphere
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.35, 0.8, 1.0, 0.25)
		dome.material_override = mat
		dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dome.position = Vector3(0, 0.6, 0)
		body.add_child(dome)
	dome.visible = true
	dome.scale = Vector3.ONE * (0.6 + 0.4 * amount)

static func _ease_kick(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

static func on_fired(unit: RTSUnit, _target: RTSUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	body.set_meta("anim_shot", SHOT_HOLD)
	body.set_meta("anim_kick", 1.0)
	var stage: Node3D = unit.get_parent() as Node3D
	if stage == null:
		return
	if player_of(body) != null:
		FX.flash(stage, _muzzle(body, null), 0.45)
		return
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
	var muzzle: Vector3 = _muzzle(body, barrel)
	FX.flash(stage, muzzle, 1.2 if barrel != null else 0.6)

static func _muzzle(body: MeshInstance3D, barrel: Node3D) -> Vector3:
	if barrel != null:
		var box: AABB = _bounds(barrel)
		var tip: Vector3 = Vector3(box.get_center().x, box.get_center().y, box.position.z)
		return barrel.global_transform * tip
	var socket: Node3D = muzzle_of(body)
	if socket != null:
		return socket.global_position
	var skel: Skeleton3D = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null:
		var hand: int = skel.find_bone("R_Hand")
		if hand >= 0:
			return skel.global_transform * skel.get_bone_global_pose(hand).origin
		var head: int = skel.find_bone("tripo__Head_0")
		if head >= 0:
			return skel.global_transform * skel.get_bone_global_pose(head).origin + rendered_forward(body) * 0.15
	var form: String = "figure" if player_of(body) != null else str(body.get_meta("form", ""))
	var local: Vector3 = (load("res://game/unit_meshes.gd") as GDScript).call("muzzle_pos", form)
	return body.global_transform * local

static func _bounds(node: Node3D) -> AABB:
	var vi: VisualInstance3D = node as VisualInstance3D
	if vi != null:
		return vi.get_aabb()
	for child: Node in node.get_children():
		if child is VisualInstance3D:
			return (child as Node3D).transform * (child as VisualInstance3D).get_aabb()
	return AABB(Vector3(-0.1, -0.1, -1.0), Vector3(0.2, 0.2, 1.0))

## The sim frees a dead unit on its next tick. Lift its Body out first so the death can play on.
static func on_died(unit: RTSUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var body: MeshInstance3D = unit.get_node_or_null("Body") as MeshInstance3D
	var stage: Node3D = unit.get_parent() as Node3D
	if body == null or stage == null:
		return
	var rig: DeathFx = DeathFx.new()
	rig.name = "Dying_%d" % unit.get_instance_id()
	stage.add_child(rig)
	rig.global_transform = unit.global_transform
	body.reparent(rig, true)
	rig.begin(body, player_of(body))
