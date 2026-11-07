class_name OffHandIK
extends SkeletonModifier3D
## Analytic two-bone IK that puts the off hand on a weapon's Grip socket. TwoBoneIK3D runs but leaves the hand where
## the clip put it on these Tripo rigs, so the solve is done here.
## The elbow keeps the side it bends to in the clip. The grip is read relative to the bone that carries the weapon
## and re-applied to that bone's pose from this pass: BoneAttachment3D only syncs after modifiers run, so reading the
## Grip node directly would aim at last frame's hand.

var upper: int = -1
var lower: int = -1
var hand: int = -1
var target: Node3D

## Builds the modifier for one arm ("L" or "R") under `skel`, aimed at `grip`. Returns null if the rig lacks the bones.
static func make(skel: Skeleton3D, side: String, grip: Node3D) -> OffHandIK:
	var ik: OffHandIK = OffHandIK.new()
	ik.upper = skel.find_bone("%s_Upperarm" % side)
	ik.lower = skel.find_bone("%s_Forearm" % side)
	ik.hand = skel.find_bone("%s_Hand" % side)
	if ik.upper < 0 or ik.lower < 0 or ik.hand < 0 or skel.get_bone_parent(ik.hand) != ik.lower or skel.get_bone_parent(ik.lower) != ik.upper:
		ik.free()
		return null
	ik.name = "OffHandIK"
	ik.target = grip
	ik.influence = 0.0
	skel.add_child(ik)
	return ik

## The grip in skeleton space for this pass's pose of whichever bone carries the weapon.
func grip_point(skel: Skeleton3D) -> Vector3:
	var carrier: Node = target.get_parent()
	while carrier != null and carrier != skel and not (carrier is BoneAttachment3D):
		carrier = carrier.get_parent()
	if carrier is BoneAttachment3D:
		var attach: BoneAttachment3D = carrier as BoneAttachment3D
		var rel: Vector3 = attach.global_transform.affine_inverse() * target.global_position
		return skel.get_bone_global_pose(attach.get_bone_idx()) * rel
	return skel.global_transform.affine_inverse() * target.global_position

func _process_modification() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null or target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var a: Transform3D = skel.get_bone_global_pose(upper)
	var b: Transform3D = skel.get_bone_global_pose(lower)
	var c: Transform3D = skel.get_bone_global_pose(hand)
	var len_a: float = a.origin.distance_to(b.origin)
	var len_b: float = b.origin.distance_to(c.origin)
	if len_a < 0.0001 or len_b < 0.0001:
		return
	var goal: Vector3 = grip_point(skel)
	var to_goal: Vector3 = goal - a.origin
	var dist: float = clampf(to_goal.length(), absf(len_a - len_b) + 0.0001, len_a + len_b - 0.0001)
	if to_goal.length() < 0.0001:
		return
	var dir: Vector3 = to_goal.normalized()
	var bend: Vector3 = (b.origin - a.origin) - dir * (b.origin - a.origin).dot(dir)
	if bend.length() < 0.0001:
		bend = (c.origin - a.origin) - dir * (c.origin - a.origin).dot(dir)
	if bend.length() < 0.0001:
		bend = dir.cross(Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.FORWARD)
	bend = bend.normalized()
	var cos_a: float = clampf((len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist), -1.0, 1.0)
	var elbow: Vector3 = a.origin + (dir * cos_a + bend * sqrt(1.0 - cos_a * cos_a)) * len_a
	var q1: Quaternion = _arc(b.origin - a.origin, elbow - a.origin)
	var wrist: Vector3 = a.origin + q1 * (c.origin - a.origin)
	var q2: Quaternion = _arc(wrist - elbow, a.origin + dir * dist - elbow)
	skel.set_bone_global_pose(upper, Transform3D(Basis(q1) * a.basis, a.origin))
	skel.set_bone_global_pose(lower, Transform3D(Basis(q2 * q1) * b.basis, elbow))
	skel.set_bone_global_pose(hand, Transform3D(Basis(q2 * q1) * c.basis, a.origin + dir * dist))

static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return Quaternion.IDENTITY
	var f: Vector3 = from.normalized()
	var t: Vector3 = to.normalized()
	if f.dot(t) < -0.9999:
		var axis: Vector3 = f.cross(Vector3.UP if absf(f.y) < 0.9 else Vector3.RIGHT).normalized()
		return Quaternion(axis, PI)
	return Quaternion(f, t)
