extends RefCounted
## Production bay on a building's calibrated facade: a dark recessed bay, a hazard-striped frame and a
## door panel that rolls up while SMFactoryBay opens it. The door sits on the model's front from "fronts"
## in res://data/model_scale.json (unlisted structure models face -Z, see game/model_catalog.gd).

const HEIGHT_INFANTRY: float = 2.6
const HEIGHT_VEHICLE: float = 3.3
const RECESS: float = 1.8

static func node_of(host: Node3D, side: SMSide, id: StringName) -> Node3D:
	if host == null or not is_instance_valid(host):
		return null
	var node: Node3D = side.node_of(id) if side != null else null
	if node == null:
		node = host.get_node_or_null("Built_%s" % str(id)) as Node3D
	if node == null and side != null and side.hub_mesh != null and is_instance_valid(side.hub_mesh) and side.yard_id() == id:
		node = side.hub_mesh
	return node

static func move(host: Node3D, side: SMSide, id: StringName, open: float) -> void:
	var node: Node3D = node_of(host, side, id)
	if node == null:
		return
	var bay: Node3D = mount(node, side, id)
	_seat(node, bay)
	var panel: Node3D = bay.get_node("DoorPanel") as Node3D
	var h: float = float(bay.get_meta("door_h", HEIGHT_VEHICLE))
	var t: float = clampf(open, 0.0, 1.0)
	panel.scale.y = maxf(1.0 - t * 0.88, 0.05)
	panel.position.y = float(bay.get_meta("floor", 0.0)) + h * (1.0 - 0.5 * panel.scale.y)
	bay.set_meta("open", t)

static func mount(node: Node3D, side: SMSide, id: StringName) -> Node3D:
	var bay: Node3D = node.get_node_or_null("BayDoor") as Node3D
	if bay != null:
		return bay
	var role: String = side.role_of(id) if side != null else ""
	var tall: bool = role != "barracks"
	var h: float = HEIGHT_VEHICLE if tall else HEIGHT_INFANTRY
	var half: float = side.half_depth(id) if side != null else 3.0
	var size: Vector2i = SMBasePlan.size_of(str(id), role)
	var w: float = clampf(float(size.x) * SMBasePlan.cell_m() * 0.42, 2.2, 6.4)
	var floor_y: float = -SMPointer.BUILDING_SIZE.y * 0.5 + (0.25 if role == "naval" else 0.02)
	var face: float = SMMapPlan.front_yaw(str(id))
	bay = Node3D.new()
	bay.name = "BayDoor"
	bay.rotation_degrees.y = face
	bay.position = Vector3(sin(deg_to_rad(face)), 0.0, cos(deg_to_rad(face))) * (half - 0.05)
	bay.set_meta("door_h", h)
	bay.set_meta("floor", floor_y)
	bay.set_meta("open", 0.0)
	node.add_child(bay)
	var dark: StandardMaterial3D = _ink(Color(0.05, 0.05, 0.06))
	var steel: StandardMaterial3D = _ink(Color(0.42, 0.44, 0.46))
	steel.metallic = 0.6
	steel.roughness = 0.45
	var stripe: StandardMaterial3D = _ink(Color(0.95, 0.72, 0.12))
	var team: StandardMaterial3D = _ink(SMFront.primary())
	_box(bay, "BayRecess", Vector3(w * 0.96, h, RECESS), Vector3(0.0, floor_y + h * 0.5, -RECESS * 0.5 + 0.02), dark)
	_box(bay, "PostLeft", Vector3(0.32, h + 0.3, 0.4), Vector3(-w * 0.5 - 0.16, floor_y + (h + 0.3) * 0.5, 0.12), stripe)
	_box(bay, "PostRight", Vector3(0.32, h + 0.3, 0.4), Vector3(w * 0.5 + 0.16, floor_y + (h + 0.3) * 0.5, 0.12), stripe)
	_box(bay, "Lintel", Vector3(w + 0.64, 0.42, 0.44), Vector3(0.0, floor_y + h + 0.21, 0.12), team)
	var panel: Node3D = _box(bay, "DoorPanel", Vector3(w, h, 0.16), Vector3(0.0, floor_y + h * 0.5, 0.1), steel)
	var ribs: int = 4
	for i: int in ribs:
		_box(panel, "Rib%d" % i, Vector3(w * 0.98, 0.07, 0.04), Vector3(0.0, -h * 0.5 + (float(i) + 0.5) * h / float(ribs), 0.1), dark)
	_box(bay, "ExitPad", Vector3(w + 0.4, 0.05, 2.4), Vector3(0.0, floor_y + 0.03, 1.4), stripe).transparency = 0.55
	return bay

## Pulls the door onto the mounted model's front wall when the model sits inside the footprint.
static func _seat(node: Node3D, bay: Node3D) -> void:
	if bool(bay.get_meta("seated", false)) or node.get_node_or_null("Model") == null:
		return
	var inv: Transform3D = node.global_transform.affine_inverse()
	var dir: Vector3 = bay.position.normalized()
	var reach: float = 0.0
	for found: Node in node.find_children("*", "VisualInstance3D", true, false):
		if bay.is_ancestor_of(found):
			continue
		var vi: VisualInstance3D = found as VisualInstance3D
		var box: AABB = inv * vi.global_transform * vi.get_aabb()
		for i: int in 8:
			reach = maxf(reach, box.get_endpoint(i).dot(dir))
	if reach > 1.0:
		bay.position = dir * minf(reach + 0.04, bay.position.length())
	bay.set_meta("seated", true)

static func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, ink: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = ink
	parent.add_child(mesh)
	return mesh

static func _ink(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
