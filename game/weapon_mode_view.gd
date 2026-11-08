extends RefCounted
## Active weapon slot on the 3D unit: a small tinted chevron over the unit (I primary, II secondary) and a
## barrel stance (the secondary raises the barrel's rest pitch so siege, flak and AA modes read at a glance).
## Muzzle flashes take the same tint in unit_motion.gd.

const SECONDARY_PITCH: float = 0.22

static func show(u: RTSUnit, slot: String, tint: Color) -> void:
	if u == null or not is_instance_valid(u):
		return
	var body: Node3D = u.get_node_or_null("Body") as Node3D
	var chevron: Label3D = u.get_node_or_null("WeaponChevron") as Label3D
	if chevron == null:
		chevron = Label3D.new()
		chevron.name = "WeaponChevron"
		chevron.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		chevron.font_size = 30
		chevron.pixel_size = 0.022
		chevron.outline_size = 8
		chevron.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		chevron.position = Vector3(0.9, 2.8, 0.0)
		u.add_child(chevron)
	var second: bool = slot == SMArms.SECONDARY
	chevron.text = "II" if second else "I"
	chevron.modulate = tint
	chevron.set_meta("slot", slot)
	if body == null:
		return
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	var barrel: Node3D = turret.get_node_or_null("Barrel") as Node3D if turret != null else null
	if barrel == null:
		return
	if not barrel.has_meta("arms_rest_pitch"):
		barrel.set_meta("arms_rest_pitch", float(barrel.get_meta("anim_rest_pitch", barrel.rotation.x)))
	var rest: float = float(barrel.get_meta("arms_rest_pitch"))
	barrel.set_meta("anim_rest_pitch", rest + (SECONDARY_PITCH if second else 0.0))
