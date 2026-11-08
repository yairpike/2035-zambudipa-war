extends RefCounted
## Building placement ghost: a translucent copy of the building turned to its facing, its footprint cells
## (green where they fit, red where they break a rule), the exit cells and an arrow out of the front bay.

const Forms = preload("res://game/unit_meshes.gd")
const OK_INK: Color = Color(0.32, 0.95, 0.55, 0.42)
const BAD_INK: Color = Color(0.95, 0.26, 0.2, 0.46)
const EXIT_INK: Color = Color(0.35, 0.82, 1.0, 0.62)
const BODY_OK: Color = Color(0.45, 0.9, 1.0, 0.38)
const BODY_BAD: Color = Color(1.0, 0.35, 0.3, 0.38)

static func paint(host: Node3D, plan: SMPlacement) -> void:
	if host == null or not is_instance_valid(host) or plan == null:
		return
	var ghost: Node3D = host.get_node_or_null("PlacementGhost") as Node3D
	if not plan.active or plan.spot == Vector3.INF:
		if ghost != null:
			ghost.free()
		return
	if ghost == null:
		ghost = Node3D.new()
		ghost.name = "PlacementGhost"
		host.add_child(ghost)
	var grid: SMDomainGrid = plan.side.plan.grid
	var ok: bool = plan.valid()
	ghost.set_meta("valid", ok)
	ghost.set_meta("yaw", plan.yaw)
	_body(ghost, plan, ok)
	_cells(ghost, "GhostCells", plan.cells(), grid, plan, false)
	_cells(ghost, "GhostExit", plan.exit_cells(), grid, plan, true)
	_arrow(ghost, plan, ok)
	var why: Label3D = ghost.get_node_or_null("GhostReason") as Label3D
	if why == null:
		why = Label3D.new()
		why.name = "GhostReason"
		why.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		why.font_size = 40
		why.pixel_size = 0.028
		why.outline_size = 10
		why.outline_modulate = Color(0, 0, 0, 0.9)
		why.no_depth_test = true
		ghost.add_child(why)
	why.text = "" if not ok else "Click to place  ·  drag to face  ·  R turns"
	why.modulate = Color(1.0, 0.55, 0.45) if not ok else Color(0.85, 1.0, 0.9)
	why.position = plan.spot + Vector3(0.0, SMPointer.BUILDING_SIZE.y + 3.2, 0.0)

static func _body(ghost: Node3D, plan: SMPlacement, ok: bool) -> void:
	var body: MeshInstance3D = ghost.get_node_or_null("GhostBody") as MeshInstance3D
	if body != null and str(body.get_meta("ghost_of", "")) != str(plan.id):
		body.free()
		body = null
	if body == null:
		body = MeshInstance3D.new()
		body.name = "Built_%s" % str(plan.id)
		if not Forms.dress_structure(body, SMPointer.BUILDING_SIZE, SMFront.accent()):
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(plan.size_m().x * 0.8, SMPointer.BUILDING_SIZE.y, plan.size_m().y * 0.8)
			body.mesh = box
		body.name = "GhostBody"
		body.set_meta("ghost_of", str(plan.id))
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(body)
	body.position = SMPointer.building_at(plan.spot)
	body.rotation_degrees.y = SMMapPlan.turn_for(str(plan.id), plan.yaw)
	var ink: Color = BODY_OK if ok else BODY_BAD
	if body.get_meta("ink", Color.BLACK) != ink:
		body.set_meta("ink", ink)
		var glass: StandardMaterial3D = StandardMaterial3D.new()
		glass.albedo_color = ink
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		body.material_override = glass
		for node: Node in body.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = glass
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _cells(ghost: Node3D, node_name: String, cells: Array[Vector2i], grid: SMDomainGrid, plan: SMPlacement, exit: bool) -> void:
	var tiles: MultiMeshInstance3D = ghost.get_node_or_null(node_name) as MultiMeshInstance3D
	if tiles == null:
		tiles = MultiMeshInstance3D.new()
		tiles.name = node_name
		tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var quad: PlaneMesh = PlaneMesh.new()
		var cell: float = grid.cell_size if grid != null else 4.0
		quad.size = Vector2(cell * 0.9, cell * 0.9)
		mm.mesh = quad
		tiles.multimesh = mm
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.vertex_color_use_as_albedo = true
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.no_depth_test = true
		tiles.material_override = ink
		ghost.add_child(tiles)
	var mm_now: MultiMesh = tiles.multimesh
	mm_now.instance_count = 0
	if grid == null:
		return
	mm_now.instance_count = cells.size()
	var floats: bool = plan.side.floats(plan.id) and not plan.redeploy
	for i: int in cells.size():
		var c: Vector2i = cells[i]
		var at: Vector3 = grid.cell_center(c) + Vector3(0.0, 0.12 if exit else 0.08, 0.0)
		mm_now.set_instance_transform(i, Transform3D(Basis(), at))
		var fits: bool = grid.in_bounds(c) and not grid.holding(c)
		var domain: int = grid.domain_at_cell(c)
		if floats:
			fits = fits and SMBasePlan.is_water(domain)
		else:
			fits = fits and domain == SMDomainGrid.Domain.LAND
		var ink: Color = EXIT_INK if exit else OK_INK
		if not fits:
			ink = BAD_INK
		elif not exit and not plan.valid():
			ink = Color(0.95, 0.75, 0.25, 0.42)
		mm_now.set_instance_color(i, ink)

static func _arrow(ghost: Node3D, plan: SMPlacement, ok: bool) -> void:
	var arrow: Node3D = ghost.get_node_or_null("GhostArrow") as Node3D
	if arrow == null:
		arrow = Node3D.new()
		arrow.name = "GhostArrow"
		ghost.add_child(arrow)
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.4, 0.9, 1.0)
		ink.no_depth_test = true
		var shaft: MeshInstance3D = MeshInstance3D.new()
		shaft.name = "Shaft"
		var stick: BoxMesh = BoxMesh.new()
		stick.size = Vector3(1.2, 0.16, 4.6)
		shaft.mesh = stick
		shaft.position = Vector3(0.0, 0.0, 2.3)
		shaft.material_override = ink
		arrow.add_child(shaft)
		var head: MeshInstance3D = MeshInstance3D.new()
		head.name = "Head"
		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(3.4, 2.4, 0.18)
		head.mesh = prism
		head.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		head.position = Vector3(0.0, 0.0, 5.8)
		head.material_override = ink
		arrow.add_child(head)
	var front: Vector3 = plan.front()
	var depth: float = plan.size_m().y if SMBasePlan.quarter(plan.yaw) % 2 == 0 else plan.size_m().x
	arrow.position = plan.spot + front * (depth * 0.5 + 0.2) + Vector3(0.0, 0.6, 0.0)
	arrow.rotation.y = atan2(front.x, front.z)
	var tint: Color = Color(0.4, 0.9, 1.0) if ok else Color(1.0, 0.45, 0.35)
	for part: Node in arrow.get_children():
		var mesh: MeshInstance3D = part as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D:
			(mesh.material_override as StandardMaterial3D).albedo_color = tint
