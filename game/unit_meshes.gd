extends RefCounted
## Low-poly silhouettes made from boxes and cylinders.
## A file in game/models replaces the silhouette. Turrets, rotors, and wakes stay separate draws.

const METAL: Color = Color(0.22, 0.23, 0.26)
const RUBBER: Color = Color(0.12, 0.12, 0.13)
const GLASS: Color = Color(0.55, 0.75, 0.85)
const Models = preload("res://game/model_registry.gd")
const Motion = preload("res://game/unit_motion.gd")
const Scale = preload("res://game/model_scale.gd")

static var _ink: StandardMaterial3D
static var _foam: StandardMaterial3D
static var _blob: Texture2D
static var _cache: Dictionary = {}

static func dress_unit(kind: String, role: String, loco: String, accent: Color, primary: Color = Color.WHITE, trim: Color = Color.WHITE, faction: String = "") -> MeshInstance3D:
	var form: String = unit_form(kind, role, loco)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = unit_mesh(form, accent)
	body.set_meta("form", form)
	body.set_meta("paint", accent)
	_shadow(body, form)
	if form == "tank":
		_part(body, "Turret", "tank_top", accent, Vector3(0.0, 0.98, -0.1))
	elif form == "tube":
		_part(body, "Turret", "tube_top", accent, Vector3(0.0, 0.82, 0.35))
	elif form == "heli":
		_part(body, "Rotor", "rotor", accent, Vector3(0.0, 1.28, -0.1))
	elif form == "boat":
		var wake: MeshInstance3D = _part(body, "Wake", "wake", accent, Vector3(0.0, 0.05, 1.85))
		wake.visible = false
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body_ink: Color = primary if not primary.is_equal_approx(Color.WHITE) or accent.is_equal_approx(Color.WHITE) else accent
	var trim_ink: Color = trim if not trim.is_equal_approx(Color.WHITE) or accent.is_equal_approx(Color.WHITE) else accent
	var model_id: String = kind
	if kind == "raider" or kind == "wave":
		var side: String = faction if faction != "" else Models.enemy_look("")
		model_id = Models.fallback_unit(role, loco, side)
	body.set_meta("unit_kind", model_id)
	body.set_meta("unit_role", role)
	body.set_meta("unit_loco", loco)
	body.set_meta("trim_ink", trim_ink)
	Models.apply_unit(body, model_id, body_ink, trim_ink)
	ensure_hull_parts(body, model_id, form, role, loco, trim_ink)
	_seat_shadow(body)
	return body

static func dress_structure(mi: MeshInstance3D, size: Vector3, accent: Color) -> bool:
	var form: String = structure_form(str(mi.name))
	if form == "":
		return false
	var role: String = _catalog_role(Models.model_id_for(str(mi.name)))
	var plot: Vector2 = Vector2.ZERO if form == "super" else Scale.structure_footprint(str(mi.name), role if role != "" else form)
	mi.mesh = _to_plot(structure_mesh(form, accent, size.y), plot, -size.y * 0.5)
	mi.material_override = null
	mi.set_meta("footprint_m", plot)
	mi.set_meta("form", form)
	mi.set_meta("paint", accent)
	Models.apply_structure(mi, Models.structure_id(str(mi.name)), SMFront.primary(), SMFront.accent())
	return true

static func animate(u: RTSUnit, delta: float) -> void:
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	Motion.pose(u, delta)
	var wake: MeshInstance3D = body.get_node_or_null("Wake") as MeshInstance3D
	if wake != null:
		wake.visible = u.is_moving()
	var spray: MeshInstance3D = body.get_node_or_null("BowSpray") as MeshInstance3D
	if spray != null:
		spray.visible = u.is_moving()

static func is_vehicle_unit(kind: String, role: String, form: String) -> bool:
	var cls: String = Scale.unit_class(kind)
	if cls != "":
		return cls == "light_vehicle" or cls == "armour" or cls == "heavy_vehicle"
	return form == "tank" or form == "tube" or form == "truck" or role == "armor" or role == "vehicle" or role == "artillery" or role == "hauler"

static func is_air_unit(kind: String, role: String, loco: String, form: String) -> bool:
	var cls: String = Scale.unit_class(kind)
	if cls == "small_drone" or cls == "uav" or cls == "helicopter" or cls == "jet" or cls == "airship":
		return true
	if loco == "air":
		return true
	if cls != "":
		return false
	return form == "heli" or form == "jet" or form == "airship" or role == "air" or role == "drone"

static func is_boat_unit(kind: String, role: String, loco: String, form: String) -> bool:
	var cls: String = Scale.unit_class(kind)
	if cls == "skiff" or cls == "warship" or cls == "capital_ship":
		return true
	if cls != "":
		return false
	return form == "boat" or form == "sub" or role == "boat" or role == "amphibious" or loco == "naval"

static func ensure_hull_parts(body: MeshInstance3D, kind: String, form: String, role: String, loco: String, accent: Color) -> void:
	if body == null or bool(body.get_meta("hull_parts_ready", false)):
		return
	body.set_meta("hull_parts_ready", true)
	if bool(body.get_meta("model_rigged", false)):
		return
	var cls: String = Scale.unit_class(kind)
	if cls == "infantry" or cls == "hero" or cls == "dog" or cls == "walker" or cls == "mobile_yard":
		return
	if cls == "" and (form == "figure" or form == "hero"):
		return
	var hull_box: AABB = _hull_bounds(body)
	var center: Vector3 = hull_box.get_center()
	if is_vehicle_unit(kind, role, form):
		_ensure_wheels(body, hull_box, cls == "armour" or cls == "heavy_vehicle" or form == "tank" or form == "tube")
		_ensure_turret_and_barrel(body, hull_box, form, accent, Vector3(center.x, maxf(hull_box.end.y * 0.86, 0.85), center.z - hull_box.size.z * 0.04))
		if loco == "amphibious":
			_ensure_water_foam(body, hull_box, accent)
	elif is_air_unit(kind, role, loco, form):
		var rotor: MeshInstance3D = body.get_node_or_null("Rotor") as MeshInstance3D
		if rotor == null:
			rotor = _part(body, "Rotor", "rotor", accent, Vector3(center.x, maxf(hull_box.end.y + 0.06, 1.1), center.z))
		else:
			rotor.position = Vector3(center.x, maxf(hull_box.end.y * 0.96, 0.9), center.z)
		rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var air_turret: Node3D = body.get_node_or_null("Turret") as Node3D
		if air_turret != null:
			_ensure_barrel(air_turret, accent)
	elif is_boat_unit(kind, role, loco, form):
		_ensure_water_foam(body, hull_box, accent)
		_ensure_turret_and_barrel(body, hull_box, "tank", accent, Vector3(center.x, maxf(hull_box.end.y * 0.78, 0.65), center.z - hull_box.size.z * 0.16))

static func _hull_bounds(body: MeshInstance3D) -> AABB:
	var model: Node3D = body.get_node_or_null("Model") as Node3D
	if model != null:
		var local: AABB = Models._merged_aabb(model)
		if local.size.length() > 0.01:
			return model.transform * local
	if body.mesh != null:
		return body.mesh.get_aabb()
	return AABB(Vector3(-0.8, 0.0, -1.5), Vector3(1.6, 1.2, 3.0))

static func _ensure_wheels(body: MeshInstance3D, hull_box: AABB, tracked: bool) -> void:
	var existing: Node = body.get_node_or_null("Wheels")
	if existing != null:
		body.remove_child(existing)
		existing.free()
	var holder: Node3D = Node3D.new()
	holder.name = "Wheels"
	var r: float = clampf(hull_box.size.y * 0.17, 0.22, 0.42)
	var wx: float = maxf(hull_box.size.x * 0.46, 0.55)
	var cz: float = hull_box.get_center().z
	var z_span: float = maxf(hull_box.size.z * 0.3, 0.75)
	var axles: PackedFloat32Array = PackedFloat32Array([-z_span, 0.0, z_span]) if tracked else PackedFloat32Array([-z_span, z_span])
	var w_mesh: ArrayMesh = wheel_mesh(r)
	var idx: int = 0
	for dz: float in axles:
		for side_sign: float in [-1.0, 1.0]:
			var w: MeshInstance3D = MeshInstance3D.new()
			w.name = "Wheel%d" % idx
			w.mesh = w_mesh
			w.position = Vector3(side_sign * wx, r, cz + dz)
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.set_meta("rest_y", r)
			w.set_meta("wheel_r", r)
			holder.add_child(w)
			idx += 1
	body.add_child(holder)

static func _ensure_turret_and_barrel(body: MeshInstance3D, _hull_box: AABB, form: String, accent: Color, fallback_pos: Vector3) -> void:
	var turret: Node3D = body.get_node_or_null("Turret") as Node3D
	if turret == null:
		var top_form: String = "tube_top" if form == "tube" else "tank_top"
		turret = _part(body, "Turret", top_form, accent, fallback_pos)
	_ensure_barrel(turret, accent)

static func _ensure_barrel(turret: Node3D, accent: Color) -> void:
	if turret == null or turret.get_node_or_null("Barrel") != null:
		return
	var barrel: MeshInstance3D = MeshInstance3D.new()
	barrel.name = "Barrel"
	barrel.mesh = unit_mesh("barrel", accent)
	barrel.position = Vector3(0.0, 0.18, -0.55)
	turret.add_child(barrel)

static func _ensure_water_foam(body: MeshInstance3D, hull_box: AABB, accent: Color) -> void:
	var cx: float = hull_box.get_center().x
	var wake: MeshInstance3D = body.get_node_or_null("Wake") as MeshInstance3D
	if wake == null:
		wake = _part(body, "Wake", "wake", accent, Vector3(cx, 0.05, maxf(hull_box.end.z + 0.25, 1.85)))
		wake.visible = false
		wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		wake.position = Vector3(cx, 0.05, maxf(hull_box.end.z + 0.2, 1.6))
	var spray: MeshInstance3D = body.get_node_or_null("BowSpray") as MeshInstance3D
	if spray == null:
		spray = _part(body, "BowSpray", "bow_spray", accent, Vector3(cx, 0.08, minf(hull_box.position.z - 0.15, -1.4)))
		spray.visible = false
		spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		spray.position = Vector3(cx, 0.08, minf(hull_box.position.z - 0.15, -1.4))

static func wheel_mesh(radius: float) -> ArrayMesh:
	var key: String = "wheel|%.2f" % radius
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_opaque())
	_wheel(st, Vector3.ZERO, radius, maxf(radius * 0.65, 0.16))
	_box(st, Vector3.ZERO, Vector3(maxf(radius * 0.72, 0.18), radius * 0.45, radius * 1.35), METAL)
	var mesh: ArrayMesh = _commit(st)
	_cache[key] = mesh
	return mesh

static func paint_status(body: MeshInstance3D, mat: Material) -> void:
	if body == null:
		return
	if str(body.get_meta("model", "")) != "":
		_paint_overlay(body, mat)
		return
	body.material_override = mat
	var turret: MeshInstance3D = body.get_node_or_null("Turret") as MeshInstance3D
	if turret != null:
		turret.material_override = mat
	var rotor: MeshInstance3D = body.get_node_or_null("Rotor") as MeshInstance3D
	if rotor != null:
		rotor.material_override = mat

static func _paint_overlay(node: Node, mat: Material) -> void:
	_coat(node, mat)
	if mat != null:
		return
	_clear_coats(node)

static func _coat(node: Node, mat: Material) -> void:
	if str(node.name) == "IceCoat":
		return
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node != null:
		var node_name: String = str(mesh_node.name)
		if node_name != "Wake" and node_name != "BowSpray" and node_name != "ContactShadow":
			mesh_node.material_overlay = mat
			if mesh_node.mesh != null and mat != null:
				var coat: MeshInstance3D = mesh_node.get_node_or_null("IceCoat") as MeshInstance3D
				if coat == null:
					coat = MeshInstance3D.new()
					coat.name = "IceCoat"
					coat.mesh = mesh_node.mesh
					coat.scale = Vector3(1.03, 1.03, 1.03)
					coat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					mesh_node.add_child(coat)
				coat.material_override = mat
	for child: Node in node.get_children():
		if str(child.name) == "IceCoat":
			continue
		_coat(child, mat)

static func _clear_coats(node: Node) -> void:
	var coats: Array[Node] = []
	for child: Node in node.get_children():
		if str(child.name) == "IceCoat":
			coats.append(child)
		else:
			_clear_coats(child)
	for coat: Node in coats:
		coat.free()

static func unit_form(kind: String, role: String, loco: String) -> String:
	var id: String = kind.to_lower()
	if id == "ruby_mortar" or id == "relay_van" or id == "packer_escort" or role == "hero":
		return "hero"
	if id == "sampan" or id.contains("sub"):
		return "sub"
	if id == "scaffold_rig":
		return "airship"
	if _jet_kind(id):
		return "jet"
	if role == "infantry":
		return "figure"
	if role == "air" or role == "drone" or loco == "air":
		return "heli"
	if role == "core" or id == "packer":
		return "truck"
	if role == "armor":
		return "tank"
	if role == "artillery":
		return "tube"
	if role == "boat" or loco == "naval" or role == "amphibious":
		return "boat"
	return "truck"

static func structure_form(node_name: String) -> String:
	var n: String = node_name.to_lower()
	if n.begins_with("super_"):
		return "super"
	if n == "hubshell" or n == "packercore" or n == "playeryard" or n == "enemyyard" or n == "enemybase":
		return "yard"
	if n.begins_with("built_"):
		return _building_form(n.trim_prefix("built_"))
	if n.begins_with("foebuilt_"):
		return _building_form(n.trim_prefix("foebuilt_"))
	return ""

static func muzzle_pos(form: String) -> Vector3:
	if form == "figure":
		return Vector3(0.32, 1.22, -0.9)
	if form == "tank" or form == "tube":
		return Vector3(0.0, 1.25, -1.85)
	if form == "boat":
		return Vector3(0.0, 0.9, -1.6)
	if form == "heli":
		return Vector3(0.0, 0.9, -1.25)
	if form == "jet":
		return Vector3(0.0, 0.72, -2.0)
	if form == "hero":
		return Vector3(0.42, 1.35, -0.9)
	if form == "sub":
		return Vector3(0.0, 0.55, -1.7)
	if form == "airship":
		return Vector3(0.0, 1.35, -1.8)
	return Vector3(0.0, 0.95, -1.6)

static func _jet_kind(id: String) -> bool:
	return id == "cyan_gunship" or id == "siege_tube" or id == "su30" or id == "jade_mortar" or id == "jade_skiff" or id == "amber_welder" or id.contains("fighter") or id.contains("bomber")

static func unit_mesh(form: String, accent: Color) -> ArrayMesh:
	var key: String = "%s|%s|0" % [form, accent.to_html(false)]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_opaque())
	if form == "figure":
		_figure(st, accent)
	elif form == "truck":
		_truck(st, accent)
	elif form == "tank":
		_tank_hull(st, accent)
	elif form == "tank_top":
		_tank_top(st, accent)
	elif form == "tube":
		_tube_hull(st, accent)
	elif form == "tube_top":
		_tube_top(st, accent)
	elif form == "boat":
		_boat(st, accent)
	elif form == "wake":
		st = _begin(_foam_ink())
		_wake(st)
	elif form == "bow_spray":
		st = _begin(_foam_ink())
		_bow_spray(st)
	elif form == "barrel":
		_barrel_shape(st, accent)
	elif form == "heli":
		_heli(st, accent)
	elif form == "rotor":
		_rotor(st)
	elif form == "hero":
		_hero(st, accent)
	elif form == "sub":
		_sub(st, accent)
	elif form == "airship":
		_airship(st, accent)
	else:
		_jet(st, accent)
	var mesh: ArrayMesh = _commit(st)
	_cache[key] = mesh
	return mesh

static func structure_mesh(form: String, accent: Color, height: float) -> ArrayMesh:
	var key: String = "%s|%s|%.2f" % [form, accent.to_html(false), height]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var st: SurfaceTool = _begin(_opaque())
	var ground: float = -height * 0.5
	if form == "power":
		_power(st, ground, accent)
	elif form == "refinery":
		_refinery(st, ground, accent)
	elif form == "barracks":
		_barracks(st, ground, accent)
	elif form == "factory":
		_factory(st, ground, accent)
	elif form == "naval":
		_naval(st, ground, accent)
	elif form == "airfield":
		_airfield(st, ground, accent)
	elif form == "defense":
		_bunker(st, ground, accent)
	elif form == "mast":
		_mast(st, ground, accent)
	elif form == "tech":
		_radar(st, ground, accent)
	elif form == "super":
		_needle(st, ground, accent, height)
	else:
		_yard(st, ground, accent, height)
	var mesh: ArrayMesh = _commit(st)
	_cache[key] = mesh
	return mesh

## The stand-in silhouette grows to the plot so a base reads at the right size before its model downloads.
static func _to_plot(mesh: ArrayMesh, plot: Vector2, ground: float) -> ArrayMesh:
	var box: AABB = mesh.get_aabb()
	var span: float = maxf(box.size.x, box.size.z)
	if span < 0.001 or plot == Vector2.ZERO:
		return mesh
	var s: float = minf(plot.x, plot.y) * Scale.fill() / span
	var key: String = "plot|%d|%.2f|%.2f" % [mesh.get_instance_id(), plot.x, plot.y]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(0.0, ground - ground * s, 0.0))
	var st := SurfaceTool.new()
	st.append_from(mesh, 0, xf)
	st.set_material(mesh.surface_get_material(0))
	var out: ArrayMesh = st.commit()
	_cache[key] = out
	return out

static func _building_form(id: String) -> String:
	if id.contains("mast") or id.contains("flak") or id.contains("prism") or id.contains("multigunner"):
		return "mast"
	var role: String = _catalog_role(id)
	if role == "power":
		return "power"
	if role == "refinery":
		return "refinery"
	if role == "barracks":
		return "barracks"
	if role == "factory":
		return "factory"
	if role == "naval":
		return "naval"
	if role == "air":
		return "airfield"
	if role == "defense":
		return "defense"
	if role == "tech":
		return "tech"
	return "yard"

static func _catalog_role(id: String) -> String:
	var factions: PackedStringArray = PackedStringArray(["gtfc", "mvd", "nmrf"])
	for faction: String in factions:
		var data: Dictionary = SMCatalog.faction(faction)
		var raw: Variant = data.get("buildings", [])
		if raw is Array:
			for item: Variant in raw:
				if item is Dictionary and str((item as Dictionary).get("id", "")) == id:
					return str((item as Dictionary).get("role", ""))
	return ""

static func _part(body: MeshInstance3D, node_name: String, form: String, accent: Color, at: Vector3) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	part.mesh = unit_mesh(form, accent)
	part.position = at
	body.add_child(part)
	return part

## Vertex color multiplies an albedo texture when one is assigned later.
static func _opaque() -> StandardMaterial3D:
	if _ink == null:
		_ink = StandardMaterial3D.new()
		_ink.vertex_color_use_as_albedo = true
		_ink.roughness = 0.78
		_ink.metallic = 0.06
		_ink.cull_mode = BaseMaterial3D.CULL_BACK
	return _ink

static func _foam_ink() -> StandardMaterial3D:
	if _foam == null:
		_foam = StandardMaterial3D.new()
		_foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_foam.albedo_color = Color(0.78, 0.9, 0.96, 0.45)
		_foam.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _foam

static func _begin(mat: Material) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	return st

static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _box(st: SurfaceTool, c: Vector3, s: Vector3, color: Color) -> void:
	var hx: float = s.x * 0.5
	var hy: float = s.y * 0.5
	var hz: float = s.z * 0.5
	var x0: float = c.x - hx
	var x1: float = c.x + hx
	var y0: float = c.y - hy
	var y1: float = c.y + hy
	var z0: float = c.z - hz
	var z1: float = c.z + hz
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), color)
	_quad(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), color)
	_quad(st, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), color)
	_quad(st, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), color)
	_quad(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), color)
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), color)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(b)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(c)
	st.set_color(color)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(c)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(d)

static func _wheel(st: SurfaceTool, c: Vector3, radius: float, length: float) -> void:
	var sides: int = 6
	var hx: float = length * 0.5
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var y0: float = cos(a0) * radius
		var z0: float = sin(a0) * radius
		var y1: float = cos(a1) * radius
		var z1: float = sin(a1) * radius
		var p0: Vector3 = c + Vector3(-hx, y0, z0)
		var p1: Vector3 = c + Vector3(hx, y0, z0)
		var q1: Vector3 = c + Vector3(hx, y1, z1)
		var q0: Vector3 = c + Vector3(-hx, y1, z1)
		_quad(st, p0, q0, q1, p1, RUBBER)
		_tri(st, c + Vector3(hx, 0.0, 0.0), p1, q1, RUBBER)
		_tri(st, c + Vector3(-hx, 0.0, 0.0), q0, p0, RUBBER)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(a)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(b)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(c)

static func _shadow(body: MeshInstance3D, form: String) -> void:
	var quad := MeshInstance3D.new()
	quad.name = "ContactShadow"
	var plane := PlaneMesh.new()
	plane.size = _shadow_size(form)
	quad.mesh = plane
	quad.position = Vector3(0.0, 0.25, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	mat.albedo_texture = _blob_tex()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material_override = mat
	body.add_child(quad)

static func _blob_tex() -> Texture2D:
	if _blob != null:
		return _blob
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in 64:
		for x: int in 64:
			var d: float = Vector2(float(x) - 31.5, float(y) - 31.5).length() / 31.5
			var t: float = clampf((d - 0.05) / 0.95, 0.0, 1.0)
			var a: float = (1.0 - t) * (1.0 - t) * 0.92
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	_blob = ImageTexture.create_from_image(img)
	return _blob

static func _seat_shadow(body: MeshInstance3D) -> void:
	var shadow: MeshInstance3D = body.get_node_or_null("ContactShadow") as MeshInstance3D
	var model: Node3D = body.get_node_or_null("Model") as Node3D
	if shadow == null or model == null:
		return
	var local: AABB = Models._merged_aabb(model)
	if local.size.length() < 0.01:
		return
	var placed: AABB = model.transform * local
	var plane: PlaneMesh = shadow.mesh as PlaneMesh
	if plane == null:
		return
	plane.size = Vector2(maxf(placed.size.x, 0.7) * 1.45, maxf(placed.size.z, 0.7) * 1.45)
	shadow.position = Vector3(placed.get_center().x, 0.25, placed.get_center().z)

static func _shadow_size(form: String) -> Vector2:
	if form == "figure" or form == "hero":
		return Vector2(0.8, 0.8)
	if form == "tank" or form == "tube":
		return Vector2(2.3, 3.4)
	if form == "boat" or form == "sub":
		return Vector2(1.6, 3.8)
	if form == "heli" or form == "jet" or form == "airship":
		return Vector2(2.6, 3.4)
	return Vector2(1.8, 3.6)

static func _figure(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(-0.16, 0.42, 0.0), Vector3(0.22, 0.84, 0.24), METAL)
	_box(st, Vector3(0.16, 0.42, 0.0), Vector3(0.22, 0.84, 0.24), METAL)
	_box(st, Vector3(0.0, 1.18, 0.0), Vector3(0.62, 0.72, 0.34), METAL)
	_box(st, Vector3(0.0, 1.22, -0.18), Vector3(0.64, 0.08, 0.06), accent)
	_box(st, Vector3(0.0, 1.74, -0.02), Vector3(0.3, 0.3, 0.3), Color(0.55, 0.42, 0.34))
	_box(st, Vector3(0.0, 1.76, -0.16), Vector3(0.22, 0.06, 0.06), accent)
	_box(st, Vector3(-0.42, 1.2, -0.05), Vector3(0.16, 0.52, 0.16), METAL)
	_box(st, Vector3(0.4, 1.16, -0.2), Vector3(0.16, 0.16, 0.55), METAL)
	_box(st, Vector3(0.4, 1.16, -0.62), Vector3(0.08, 0.08, 0.55), RUBBER)

static func _truck(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.46, 0.15), Vector3(1.55, 0.36, 3.3), METAL)
	_box(st, Vector3(0.0, 1.05, -0.95), Vector3(1.45, 0.85, 1.15), METAL)
	_box(st, Vector3(0.0, 1.05, -1.5), Vector3(1.48, 0.08, 0.08), accent)
	_box(st, Vector3(0.0, 1.22, -1.48), Vector3(1.15, 0.38, 0.08), GLASS)
	_box(st, Vector3(0.0, 0.88, 0.85), Vector3(1.5, 0.5, 1.65), METAL)
	_wheel(st, Vector3(-0.78, 0.32, -1.05), 0.32, 0.22)
	_wheel(st, Vector3(0.78, 0.32, -1.05), 0.32, 0.22)
	_wheel(st, Vector3(-0.78, 0.32, 1.15), 0.32, 0.22)
	_wheel(st, Vector3(0.78, 0.32, 1.15), 0.32, 0.22)

static func _tank_hull(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.4, 0.05), Vector3(1.55, 0.42, 2.7), METAL)
	_box(st, Vector3(0.0, 0.72, 0.05), Vector3(1.25, 0.28, 1.9), METAL)
	_box(st, Vector3(0.0, 0.86, 0.05), Vector3(1.28, 0.06, 1.92), accent)
	_box(st, Vector3(-0.95, 0.36, 0.05), Vector3(0.32, 0.5, 3.05), RUBBER)
	_box(st, Vector3(0.95, 0.36, 0.05), Vector3(0.32, 0.5, 3.05), RUBBER)

static func _tank_top(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.22, 0.05), Vector3(0.95, 0.42, 1.15), METAL)
	_box(st, Vector3(0.0, 0.22, -0.48), Vector3(0.98, 0.1, 0.12), accent)
	_box(st, Vector3(0.0, 0.24, -1.05), Vector3(0.16, 0.16, 1.55), METAL)

static func _tube_hull(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.42, 0.2), Vector3(1.4, 0.36, 2.9), METAL)
	_box(st, Vector3(0.0, 0.88, -0.95), Vector3(1.25, 0.62, 0.85), accent)
	_box(st, Vector3(0.0, 1.02, -1.32), Vector3(0.9, 0.28, 0.08), GLASS)
	_wheel(st, Vector3(-0.72, 0.3, -0.85), 0.3, 0.2)
	_wheel(st, Vector3(0.72, 0.3, -0.85), 0.3, 0.2)
	_wheel(st, Vector3(-0.72, 0.3, 1.15), 0.3, 0.2)
	_wheel(st, Vector3(0.72, 0.3, 1.15), 0.3, 0.2)

static func _tube_top(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.16, 0.0), Vector3(0.4, 0.28, 0.55), accent)
	_box(st, Vector3(0.0, 0.34, -1.35), Vector3(0.18, 0.18, 2.5), METAL)

static func _boat(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.28, 0.1), Vector3(1.2, 0.32, 3.5), METAL)
	_box(st, Vector3(0.0, 0.46, 0.1), Vector3(1.24, 0.06, 3.2), accent)
	_box(st, Vector3(0.0, 0.5, 0.25), Vector3(0.95, 0.18, 2.5), METAL)
	_box(st, Vector3(0.0, 0.32, -1.7), Vector3(0.62, 0.22, 0.7), METAL)
	_box(st, Vector3(0.0, 0.86, -0.25), Vector3(0.72, 0.48, 0.9), METAL)
	_box(st, Vector3(0.0, 1.0, -0.68), Vector3(0.6, 0.22, 0.08), GLASS)

static func _wake(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.0, 0.35), Vector3(0.35, 0.04, 0.9), Color.WHITE)
	_box(st, Vector3(0.0, 0.0, 1.15), Vector3(0.9, 0.04, 0.7), Color.WHITE)

static func _bow_spray(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.04, -0.2), Vector3(0.42, 0.08, 0.38), Color.WHITE)
	_box(st, Vector3(-0.38, 0.02, 0.15), Vector3(0.28, 0.06, 0.65), Color.WHITE)
	_box(st, Vector3(0.38, 0.02, 0.15), Vector3(0.28, 0.06, 0.65), Color.WHITE)

static func _barrel_shape(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.0, -0.05), Vector3(0.24, 0.2, 0.28), accent)
	_box(st, Vector3(0.0, 0.0, -0.58), Vector3(0.12, 0.12, 0.95), METAL)

static func _heli(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.82, 0.05), Vector3(0.72, 0.48, 1.7), METAL)
	_box(st, Vector3(0.0, 1.02, 0.05), Vector3(0.76, 0.06, 1.4), accent)
	_box(st, Vector3(0.0, 0.9, -0.85), Vector3(0.58, 0.38, 0.7), GLASS)
	_box(st, Vector3(0.0, 0.88, 1.35), Vector3(0.18, 0.16, 1.35), METAL)
	_box(st, Vector3(0.0, 1.15, 1.9), Vector3(0.08, 0.42, 0.32), accent)
	_box(st, Vector3(-0.28, 0.38, 0.1), Vector3(0.08, 0.1, 1.3), RUBBER)
	_box(st, Vector3(0.28, 0.38, 0.1), Vector3(0.08, 0.1, 1.3), RUBBER)

static func _rotor(st: SurfaceTool) -> void:
	_box(st, Vector3(0.0, 0.06, 0.0), Vector3(2.7, 0.05, 0.16), METAL)
	_box(st, Vector3(0.0, 0.06, 0.0), Vector3(0.16, 0.05, 2.7), METAL)
	_box(st, Vector3(0.0, 0.02, 0.0), Vector3(0.22, 0.1, 0.22), RUBBER)

static func _hero(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(-0.18, 0.46, 0.0), Vector3(0.24, 0.92, 0.26), METAL)
	_box(st, Vector3(0.18, 0.46, 0.0), Vector3(0.24, 0.92, 0.26), METAL)
	_box(st, Vector3(0.0, 1.28, 0.0), Vector3(0.78, 0.82, 0.4), METAL)
	_box(st, Vector3(0.0, 1.42, -0.2), Vector3(0.8, 0.08, 0.06), accent)
	_box(st, Vector3(-0.48, 1.48, 0.0), Vector3(0.28, 0.22, 0.36), accent)
	_box(st, Vector3(0.48, 1.48, 0.0), Vector3(0.28, 0.22, 0.36), accent)
	_box(st, Vector3(0.0, 1.9, -0.02), Vector3(0.32, 0.32, 0.32), Color(0.55, 0.42, 0.34))
	_box(st, Vector3(0.46, 1.22, -0.35), Vector3(0.12, 0.12, 0.7), METAL)

static func _sub(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.42, 0.15), Vector3(0.72, 0.48, 3.4), METAL)
	_box(st, Vector3(0.0, 0.62, 0.15), Vector3(0.76, 0.06, 2.4), accent)
	_box(st, Vector3(0.0, 0.72, -0.35), Vector3(0.42, 0.28, 0.9), METAL)
	_box(st, Vector3(0.0, 0.95, -0.2), Vector3(0.08, 0.42, 0.08), METAL)
	_box(st, Vector3(0.0, 0.38, -1.85), Vector3(0.28, 0.28, 0.55), RUBBER)
	_box(st, Vector3(0.0, 0.55, 1.55), Vector3(0.9, 0.08, 0.55), METAL)

static func _airship(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 1.35, 0.1), Vector3(0.85, 0.7, 3.6), METAL)
	_box(st, Vector3(0.0, 1.55, 0.1), Vector3(0.9, 0.08, 2.2), accent)
	_box(st, Vector3(0.0, 1.35, -1.55), Vector3(0.45, 0.4, 0.7), METAL)
	_box(st, Vector3(0.0, 0.72, 0.35), Vector3(0.55, 0.38, 0.9), METAL)
	_box(st, Vector3(0.0, 1.02, 0.35), Vector3(0.06, 0.5, 0.06), RUBBER)

static func _jet(st: SurfaceTool, accent: Color) -> void:
	_box(st, Vector3(0.0, 0.72, 0.05), Vector3(0.42, 0.32, 3.1), METAL)
	_box(st, Vector3(0.0, 0.84, -0.2), Vector3(0.46, 0.06, 1.6), accent)
	_box(st, Vector3(0.0, 0.72, -1.7), Vector3(0.26, 0.2, 0.55), METAL)
	_box(st, Vector3(0.0, 0.78, -1.15), Vector3(0.28, 0.16, 0.35), GLASS)
	_box(st, Vector3(0.0, 0.7, 0.05), Vector3(2.9, 0.07, 0.85), METAL)
	_box(st, Vector3(0.0, 0.95, 1.35), Vector3(1.15, 0.06, 0.32), METAL)
	_box(st, Vector3(0.0, 1.05, 1.3), Vector3(0.08, 0.48, 0.38), accent)

static func _yard(st: SurfaceTool, ground: float, accent: Color, height: float) -> void:
	var h: float = height * 0.9
	var posts: Array[Vector3] = [Vector3(-0.62, 0.0, -0.62), Vector3(0.62, 0.0, -0.62), Vector3(-0.62, 0.0, 0.62), Vector3(0.62, 0.0, 0.62)]
	for p: Vector3 in posts:
		_box(st, Vector3(p.x, ground + h * 0.5, p.z), Vector3(0.16, h, 0.16), METAL)
	_box(st, Vector3(0.0, ground + 0.85, 0.0), Vector3(1.35, 0.12, 1.35), accent)
	_box(st, Vector3(0.4, ground + h * 0.62, 0.0), Vector3(0.14, h * 0.7, 0.14), accent)
	_box(st, Vector3(0.0, ground + h * 0.96, 0.0), Vector3(1.2, 0.08, 0.12), METAL)

static func _power(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(-0.25, ground + 0.7, 0.0), Vector3(2.2, 1.3, 1.7), METAL)
	_box(st, Vector3(0.85, ground + 2.15, 0.15), Vector3(0.55, 3.5, 0.55), accent)
	_box(st, Vector3(0.85, ground + 3.95, 0.15), Vector3(0.7, 0.12, 0.7), RUBBER)

static func _refinery(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.55, -0.48), Vector3(3.3, 0.7, 0.7), METAL)
	_box(st, Vector3(0.0, ground + 0.55, 0.48), Vector3(3.3, 0.7, 0.7), accent)
	_box(st, Vector3(0.0, ground + 1.15, 0.0), Vector3(0.22, 0.55, 1.3), METAL)
	_box(st, Vector3(1.35, ground + 1.05, 0.0), Vector3(0.35, 0.7, 0.35), accent)

static func _barracks(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.55, 0.0), Vector3(3.6, 1.0, 1.45), METAL)
	_box(st, Vector3(0.0, ground + 1.15, 0.0), Vector3(3.8, 0.18, 1.65), accent)
	_box(st, Vector3(0.0, ground + 0.4, -0.74), Vector3(0.45, 0.7, 0.08), accent)

static func _factory(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.55, 0.0), Vector3(3.0, 1.0, 2.1), METAL)
	_box(st, Vector3(-0.85, ground + 1.25, 0.0), Vector3(0.7, 0.45, 2.0), accent)
	_box(st, Vector3(0.05, ground + 1.5, 0.0), Vector3(0.7, 0.7, 2.0), METAL)
	_box(st, Vector3(0.95, ground + 1.25, 0.0), Vector3(0.7, 0.45, 2.0), accent)

static func _naval(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.22, 0.0), Vector3(1.15, 0.28, 4.4), METAL)
	_box(st, Vector3(-0.75, ground + 0.45, -0.3), Vector3(0.14, 0.5, 2.4), accent)
	_box(st, Vector3(0.75, ground + 0.45, -0.3), Vector3(0.14, 0.5, 2.4), accent)
	_box(st, Vector3(0.0, ground + 0.7, 1.45), Vector3(1.35, 0.7, 0.9), accent)

static func _airfield(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.08, 0.0), Vector3(5.4, 0.12, 1.15), RUBBER)
	_box(st, Vector3(0.0, ground + 0.1, 0.0), Vector3(0.12, 0.04, 1.05), Color(0.85, 0.82, 0.7))
	_box(st, Vector3(1.7, ground + 1.05, 0.85), Vector3(0.4, 1.9, 0.4), METAL)
	_box(st, Vector3(1.7, ground + 2.1, 0.85), Vector3(0.75, 0.32, 0.75), GLASS)
	_box(st, Vector3(1.7, ground + 2.28, 0.85), Vector3(0.9, 0.08, 0.9), accent)

static func _bunker(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.4, 0.15), Vector3(2.2, 0.75, 1.55), METAL)
	_box(st, Vector3(0.0, ground + 0.95, -0.25), Vector3(0.5, 0.38, 0.55), accent)
	_box(st, Vector3(0.0, ground + 1.0, -0.95), Vector3(0.12, 0.12, 0.95), RUBBER)

static func _mast(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 2.15, 0.0), Vector3(0.2, 4.2, 0.2), METAL)
	_box(st, Vector3(0.0, ground + 3.7, 0.0), Vector3(1.15, 0.1, 1.15), accent)
	_box(st, Vector3(-0.35, ground + 3.85, 0.0), Vector3(0.35, 0.12, 0.12), RUBBER)
	_box(st, Vector3(0.35, ground + 3.85, 0.0), Vector3(0.12, 0.12, 0.35), RUBBER)

static func _radar(st: SurfaceTool, ground: float, accent: Color) -> void:
	_box(st, Vector3(0.0, ground + 0.35, 0.0), Vector3(1.6, 0.6, 1.6), METAL)
	_box(st, Vector3(0.0, ground + 1.35, 0.0), Vector3(0.16, 1.5, 0.16), METAL)
	_box(st, Vector3(0.0, ground + 2.15, 0.15), Vector3(1.7, 0.1, 1.7), accent)
	_box(st, Vector3(0.0, ground + 2.0, -0.55), Vector3(0.12, 0.35, 0.12), RUBBER)

static func _needle(st: SurfaceTool, ground: float, accent: Color, height: float) -> void:
	_box(st, Vector3(0.0, ground + 0.28, 0.0), Vector3(1.35, 0.4, 1.35), METAL)
	_box(st, Vector3(0.0, ground + height * 0.46, 0.0), Vector3(0.32, height * 0.78, 0.32), accent)
	_box(st, Vector3(0.0, ground + height * 0.9, 0.0), Vector3(0.14, height * 0.12, 0.14), Color(0.95, 0.55, 0.2))
