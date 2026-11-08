extends RefCounted
## Pinned rally points of the selected production buildings: a faction flag at each rally point and a
## dashed line from the building's front exit pad to it. Hidden when no producer is selected.

const DASH: float = 0.9
const GAP: float = 0.6

static func show(host: Node3D, rows: Array[Dictionary]) -> void:
	if host == null or not is_instance_valid(host):
		return
	var root: Node3D = host.get_node_or_null("BuildingRallies") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "BuildingRallies"
		host.add_child(root)
	for old: Node in root.get_children():
		old.free()
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = SMFront.primary().lightened(0.25)
	var dash_ink: StandardMaterial3D = ink.duplicate() as StandardMaterial3D
	dash_ink.no_depth_test = true
	dash_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dash_ink.albedo_color.a = 0.85
	for row: Dictionary in rows:
		var id: String = str(row.get("id", ""))
		var from: Vector3 = row.get("from", Vector3.INF)
		var at: Vector3 = row.get("at", Vector3.INF)
		if at == Vector3.INF:
			continue
		root.add_child(_flag(id, at, ink))
		if from != Vector3.INF:
			root.add_child(_line(id, from, at, dash_ink))

static func _flag(id: String, at: Vector3, ink: Material) -> Node3D:
	var flag: Node3D = Node3D.new()
	flag.name = "RallyFlag_%s" % id
	flag.position = Vector3(at.x, 0.0, at.z)
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.name = "Pole"
	var stick: CylinderMesh = CylinderMesh.new()
	stick.top_radius = 0.05
	stick.bottom_radius = 0.07
	stick.height = 4.2
	pole.mesh = stick
	pole.position = Vector3(0.0, 2.1, 0.0)
	pole.material_override = ink
	flag.add_child(pole)
	var cloth: MeshInstance3D = MeshInstance3D.new()
	cloth.name = "Cloth"
	var sheet: BoxMesh = BoxMesh.new()
	sheet.size = Vector3(1.8, 1.0, 0.06)
	cloth.mesh = sheet
	cloth.position = Vector3(0.92, 3.6, 0.0)
	cloth.material_override = ink
	flag.add_child(cloth)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.06, 0.0)
	ring.material_override = ink
	flag.add_child(ring)
	return flag

static func _line(id: String, from: Vector3, at: Vector3, ink: Material) -> MultiMeshInstance3D:
	var line: MultiMeshInstance3D = MultiMeshInstance3D.new()
	line.name = "RallyLine_%s" % id
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flat: Vector3 = Vector3(at.x - from.x, 0.0, at.z - from.z)
	var length: float = flat.length()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bit: BoxMesh = BoxMesh.new()
	bit.size = Vector3(0.4, 0.08, DASH)
	mm.mesh = bit
	var count: int = int(floor(length / (DASH + GAP)))
	mm.instance_count = maxi(count, 0)
	if count > 0:
		var dir: Vector3 = flat / length
		var basis: Basis = Basis(Vector3.UP, atan2(dir.x, dir.z))
		for i: int in count:
			var s: float = (float(i) + 0.5) * (DASH + GAP)
			mm.set_instance_transform(i, Transform3D(basis, Vector3(from.x, 0.18, from.z) + dir * s))
	line.multimesh = mm
	line.material_override = ink
	line.set_meta("dashes", count)
	return line
