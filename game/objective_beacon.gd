extends RefCounted
## World-space objective marker: a gold light pillar, a bobbing down-arrow and a turning ground ring over the
## current primary objective, labelled OBJECTIVE, plus a red chevron over every living stage target (capped).
## StageView moves it every frame; it never touches the camera.

const GOLD: Color = Color(1.0, 0.8, 0.22)
const RED: Color = Color(1.0, 0.28, 0.22)
const PILLAR_H: float = 16.0
const MAX_CHEVRONS: int = 8

static func place(host: Node3D, at: Vector3, targets: Array[RTSUnit], clock: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var beacon: Node3D = host.get_node_or_null("ObjectiveBeacon") as Node3D
	if at == Vector3.INF:
		if beacon != null:
			beacon.visible = false
	else:
		if beacon == null:
			beacon = _build(host)
		beacon.visible = true
		beacon.position = Vector3(at.x, 0.0, at.z)
		var arrow: Node3D = beacon.get_node("Arrow") as Node3D
		arrow.position.y = 7.5 + 0.9 * sin(clock * 3.2)
		arrow.rotation.y = clock * 1.4
		var ring: Node3D = beacon.get_node("Ring") as Node3D
		ring.rotation.y = -clock * 0.8
		var s: float = 1.0 + 0.12 * sin(clock * 4.0)
		ring.scale = Vector3(s, 1.0, s)
		var pillar: MeshInstance3D = beacon.get_node("Pillar") as MeshInstance3D
		var glow: StandardMaterial3D = pillar.material_override as StandardMaterial3D
		glow.albedo_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.16 + 0.1 * (0.5 + 0.5 * sin(clock * 2.6)))
	_chevrons(host, targets, clock)

static func _build(host: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ObjectiveBeacon"
	var pillar: MeshInstance3D = MeshInstance3D.new()
	pillar.name = "Pillar"
	var tube: CylinderMesh = CylinderMesh.new()
	tube.top_radius = 0.35
	tube.bottom_radius = 0.6
	tube.height = PILLAR_H
	pillar.mesh = tube
	pillar.position = Vector3(0.0, PILLAR_H * 0.5, 0.0)
	pillar.material_override = _ink(Color(GOLD.r, GOLD.g, GOLD.b, 0.2), true)
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pillar)
	var arrow: Node3D = Node3D.new()
	arrow.name = "Arrow"
	var head: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(2.4, 2.2, 0.5)
	head.mesh = prism
	head.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	head.material_override = _ink(GOLD, false)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(head)
	var cross: MeshInstance3D = head.duplicate() as MeshInstance3D
	cross.rotation_degrees = Vector3(180.0, 90.0, 0.0)
	arrow.add_child(cross)
	root.add_child(arrow)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.6
	torus.outer_radius = 3.0
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.15, 0.0)
	ring.material_override = _ink(Color(GOLD.r, GOLD.g, GOLD.b, 0.75), true)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var tag: Label3D = Label3D.new()
	tag.name = "Tag"
	tag.text = "Objective"
	tag.uppercase = true
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 44
	tag.pixel_size = 0.03
	tag.outline_size = 12
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.modulate = GOLD
	tag.position = Vector3(0.0, 10.4, 0.0)
	root.add_child(tag)
	host.add_child(root)
	return root

static func _chevrons(host: Node3D, targets: Array[RTSUnit], clock: float) -> void:
	var holder: Node3D = host.get_node_or_null("TargetChevrons") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "TargetChevrons"
		host.add_child(holder)
	var shown: int = 0
	for u: RTSUnit in targets:
		if shown >= MAX_CHEVRONS:
			break
		if u == null or not is_instance_valid(u) or not u.is_alive() or not u.is_inside_tree():
			continue
		var mark: MeshInstance3D = holder.get_node_or_null("Chevron%d" % shown) as MeshInstance3D
		if mark == null:
			mark = MeshInstance3D.new()
			mark.name = "Chevron%d" % shown
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(1.1, 1.0, 0.25)
			mark.mesh = prism
			mark.rotation_degrees = Vector3(180.0, 0.0, 0.0)
			mark.material_override = _ink(RED, false)
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mark)
		mark.visible = true
		mark.position = u.global_position + Vector3(0.0, 4.2 + 0.35 * sin(clock * 5.0 + float(shown)), 0.0)
		mark.rotation.y = clock * 2.0
		shown += 1
	for i: int in range(shown, holder.get_child_count()):
		(holder.get_child(i) as Node3D).visible = false

static func _ink(color: Color, see_through: bool) -> StandardMaterial3D:
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = color
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	if see_through or color.a < 1.0:
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.no_depth_test = see_through
	return ink
