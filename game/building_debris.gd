extends RefCounted
## Material-aware destruction for structures: a palette sampled from the model's own texture, the model cut into
## textured chunks, low-poly pieces per material, per-material effects, and a rubble mound in the same palette.
## View only. Chunk meshes and palettes are built once per model id and shared.

const FX = preload("res://game/motion_fx.gd")
const Catalog = preload("res://game/model_catalog.gd")

## Above this many triangles the model is not cut; pieces and the pancaking husk carry the collapse instead.
const CHUNK_BUDGET: int = 40000
const GRID: Vector3i = Vector3i(3, 3, 3)
const SAMPLES: int = 360
const GRAVITY: float = 13.0

static var _palettes: Dictionary = {}
static var _chunks: Dictionary = {}

## Five colours from dark to light, read off the albedo texture at the model's own vertex UVs.
static func palette(root: Node3D, id: String, fallback: Color = Color(0.45, 0.4, 0.35)) -> PackedColorArray:
	if id != "" and _palettes.has(id):
		return _palettes[id] as PackedColorArray
	var samples: Array[Color] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or mi.name == "ContactShadow":
			continue
		for s: int in mi.mesh.get_surface_count():
			_sample_surface(mi, s, samples)
	var out: PackedColorArray = PackedColorArray()
	if samples.size() < 10:
		for k: int in 5:
			out.append(fallback.darkened(0.45 - 0.18 * float(k)) if k < 3 else fallback.lightened(0.12 * float(k - 2)))
	else:
		samples.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
		var band: int = samples.size() / 5
		for k: int in 5:
			var sum: Color = Color(0, 0, 0, 0)
			for i: int in range(k * band, (k + 1) * band):
				sum += samples[i]
			out.append(Color(sum.r / band, sum.g / band, sum.b / band, 1.0))
	if id != "":
		_palettes[id] = out
	return out

static func _sample_surface(mi: MeshInstance3D, s: int, samples: Array[Color]) -> void:
	var mat: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
	if mat == null:
		mat = mi.mesh.surface_get_material(s) as BaseMaterial3D
	if mat == null:
		return
	var tint: Color = mat.albedo_color
	var img: Image = null
	if mat.albedo_texture != null:
		img = mat.albedo_texture.get_image()
		if img != null and img.is_compressed():
			img = img.duplicate() as Image
			if img.decompress() != OK:
				img = null
	var arrays: Array = mi.mesh.surface_get_arrays(s)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if img == null or uvs.is_empty():
		samples.append(tint)
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var step: int = maxi(1, uvs.size() / SAMPLES)
	var i: int = 0
	while i < uvs.size():
		var uv: Vector2 = uvs[i]
		var px: int = clampi(int(fposmod(uv.x, 1.0) * w), 0, w - 1)
		var py: int = clampi(int(fposmod(uv.y, 1.0) * h), 0, h - 1)
		samples.append(img.get_pixel(px, py) * tint)
		i += step

## The model cut into up to 27 textured pieces along a grid. Each chunk is positioned at its cell centre.
## Returns an empty array when the model is over budget or has no mesh.
static func chunk(proxy: Node3D, box: AABB, id: String) -> Array[MeshInstance3D]:
	var made: Array[MeshInstance3D] = []
	var parts: Array = _chunks.get(id, []) if id != "" else []
	if parts.is_empty():
		parts = _cut(proxy, box)
		if id != "" and not parts.is_empty():
			_chunks[id] = parts
	for part: Variant in parts:
		var d: Dictionary = part as Dictionary
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Chunk"
		mi.mesh = d["mesh"] as Mesh
		mi.position = d["at"] as Vector3
		mi.set_meta("cell_y", float(d["cell_y"]))
		made.append(mi)
	return made

static func _cut(proxy: Node3D, box: AABB) -> Array:
	var sources: Array[MeshInstance3D] = []
	var tris: int = 0
	for node: Node in proxy.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or mi.name == "ContactShadow" or mi.name == "IceCoat" or not mi.is_visible_in_tree():
			continue
		sources.append(mi)
		for s: int in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_len(s) / 3 if mi.mesh.surface_get_array_index_len(s) <= 0 else mi.mesh.surface_get_array_index_len(s) / 3
	if sources.is_empty() or tris > CHUNK_BUDGET:
		return []
	var size: Vector3 = box.size.max(Vector3(0.01, 0.01, 0.01))
	# cell -> material key -> [verts, normals, uvs]
	var cells: Dictionary = {}
	var mats: Dictionary = {}
	for mi: MeshInstance3D in sources:
		var xf: Transform3D = _to_root(proxy, mi)
		var nb: Basis = xf.basis.inverse().transposed()
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			var mkey: int = mat.get_instance_id() if mat != null else 0
			mats[mkey] = mat
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var placed: PackedVector3Array = PackedVector3Array()
			placed.resize(verts.size())
			for v: int in verts.size():
				placed[v] = xf * verts[v]
			var count: int = idx.size() if not idx.is_empty() else verts.size()
			var t: int = 0
			while t + 2 < count:
				var a: int = idx[t] if not idx.is_empty() else t
				var b: int = idx[t + 1] if not idx.is_empty() else t + 1
				var c: int = idx[t + 2] if not idx.is_empty() else t + 2
				var centre: Vector3 = (placed[a] + placed[b] + placed[c]) / 3.0
				var rel: Vector3 = (centre - box.position) / size
				var cell: Vector3i = Vector3i(clampi(int(rel.x * GRID.x), 0, GRID.x - 1), clampi(int(rel.y * GRID.y), 0, GRID.y - 1), clampi(int(rel.z * GRID.z), 0, GRID.z - 1))
				if not cells.has(cell):
					cells[cell] = {}
				var bins: Dictionary = cells[cell]
				if not bins.has(mkey):
					bins[mkey] = [[], [], []]
				var bin: Array = bins[mkey]
				var bv: Array = bin[0]
				var bn: Array = bin[1]
				var bu: Array = bin[2]
				for k: int in [a, b, c]:
					bv.append(placed[k])
					bn.append((nb * norms[k]).normalized() if not norms.is_empty() else Vector3.UP)
					bu.append(uvs[k] if not uvs.is_empty() else Vector2.ZERO)
				t += 3
	var parts: Array = []
	for cell: Vector3i in cells.keys():
		var centre: Vector3 = box.position + Vector3((float(cell.x) + 0.5) / GRID.x, (float(cell.y) + 0.5) / GRID.y, (float(cell.z) + 0.5) / GRID.z) * size
		var mesh: ArrayMesh = ArrayMesh.new()
		var bins: Dictionary = cells[cell]
		for mkey: int in bins.keys():
			var bin: Array = bins[mkey]
			var local: PackedVector3Array = PackedVector3Array(bin[0] as Array)
			if local.is_empty():
				continue
			for v: int in local.size():
				local[v] -= centre
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = local
			arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(bin[1] as Array)
			arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(bin[2] as Array)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats.get(mkey, null) as Material)
		if mesh.get_surface_count() == 0:
			continue
		parts.append({"mesh": mesh, "at": centre, "cell_y": float(cell.y) / float(maxi(GRID.y - 1, 1))})
	return parts

static func _to_root(root: Node3D, node: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var walk: Node3D = node
	while walk != null and walk != root:
		xf = walk.transform * xf
		walk = walk.get_parent() as Node3D
	return xf

## Sets each chunk flying: upper cells topple outward first, the base slumps in place.
static func launch(chunks: Array[MeshInstance3D], box: AABB, rng: RandomNumberGenerator) -> void:
	var centre: Vector3 = box.get_center()
	for mi: MeshInstance3D in chunks:
		var up: float = float(mi.get_meta("cell_y", 0.5))
		var out: Vector3 = mi.position - centre
		out.y = 0.0
		if out.length() < 0.01:
			out = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		out = out.normalized() * rng.randf_range(0.6, 2.2) * (0.4 + up)
		mi.set_meta("vel", out + Vector3(0, rng.randf_range(0.0, 1.6) * up, 0))
		mi.set_meta("spin", Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.8, 0.8), rng.randf_range(-1.6, 1.6)) * (0.3 + up))
		mi.set_meta("wait", (1.0 - up) * 0.25 + rng.randf_range(0.0, 0.15))
		mi.set_meta("floor", box.position.y + rng.randf_range(0.05, 0.22) * box.size.y * (0.4 + 0.6 * (1.0 - up)))

## Steps chunks made by `launch`. Returns false once all have settled.
static func step_chunks(chunks: Array[MeshInstance3D], delta: float) -> bool:
	var moving: bool = false
	for mi: MeshInstance3D in chunks:
		if not is_instance_valid(mi):
			continue
		var wait: float = float(mi.get_meta("wait", 0.0))
		if wait > 0.0:
			mi.set_meta("wait", wait - delta)
			moving = true
			continue
		var vel: Vector3 = mi.get_meta("vel", Vector3.ZERO)
		if vel == Vector3.ZERO:
			continue
		vel.y -= GRAVITY * delta
		mi.position += vel * delta
		mi.rotation += (mi.get_meta("spin", Vector3.ZERO) as Vector3) * delta
		var ground: float = float(mi.get_meta("floor", 0.0))
		if mi.position.y <= ground and vel.y < 0.0:
			mi.position.y = ground
			vel = Vector3(vel.x * 0.25, -vel.y * 0.15, vel.z * 0.25)
			mi.set_meta("spin", (mi.get_meta("spin", Vector3.ZERO) as Vector3) * 0.3)
			if absf(vel.y) < 0.7:
				vel = Vector3.ZERO
		mi.set_meta("vel", vel)
		moving = moving or vel != Vector3.ZERO
	return moving

static func _mat(ink: Color, kind: String) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ink
	mat.roughness = 0.9
	if kind == Catalog.STEEL:
		mat.metallic = 0.6
		mat.roughness = 0.45
	elif kind == Catalog.GLASS:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(ink.r, ink.g, ink.b, 0.55).lightened(0.3)
		mat.roughness = 0.1
		mat.metallic = 0.3
		mat.emission_enabled = true
		mat.emission = ink.lightened(0.2) * 0.35
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## One low-poly piece in the shape this material breaks into.
static func piece_mesh(kind: String, s: float, rng: RandomNumberGenerator) -> Mesh:
	if kind == Catalog.TIMBER:
		var plank: BoxMesh = BoxMesh.new()
		plank.size = Vector3(s * 0.22, s * 0.12, s * rng.randf_range(1.2, 2.2))
		return plank
	if kind == Catalog.BAMBOO:
		var pole: CylinderMesh = CylinderMesh.new()
		pole.top_radius = s * 0.08
		pole.bottom_radius = s * 0.08
		pole.height = s * rng.randf_range(1.4, 2.6)
		pole.radial_segments = 5
		pole.rings = 1
		return pole
	if kind == Catalog.BRICK:
		var brick: BoxMesh = BoxMesh.new()
		brick.size = Vector3(s * 0.5, s * 0.25, s * 0.25) * rng.randf_range(0.8, 1.4)
		return brick
	if kind == Catalog.CONCRETE:
		if rng.randf() < 0.3:
			var bar: CylinderMesh = CylinderMesh.new()
			bar.top_radius = s * 0.03
			bar.bottom_radius = s * 0.03
			bar.height = s * rng.randf_range(1.2, 2.0)
			bar.radial_segments = 4
			bar.rings = 1
			return bar
		var slab: BoxMesh = BoxMesh.new()
		slab.size = Vector3(s * rng.randf_range(0.6, 1.1), s * rng.randf_range(0.25, 0.45), s * rng.randf_range(0.5, 0.9))
		return slab
	if kind == Catalog.STEEL:
		var sheet: BoxMesh = BoxMesh.new()
		sheet.size = Vector3(s * rng.randf_range(0.7, 1.3), s * 0.04, s * rng.randf_range(0.5, 1.0))
		return sheet
	if kind == Catalog.GLASS:
		var pane: PrismMesh = PrismMesh.new()
		pane.size = Vector3(s * rng.randf_range(0.3, 0.6), s * rng.randf_range(0.4, 0.8), s * 0.02)
		pane.left_to_right = rng.randf()
		return pane
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = s * 0.4
	rock.height = s * 0.6
	rock.radial_segments = 5
	rock.rings = 3
	return rock

## Pieces of each material, coloured from the palette, thrown out of the footprint. Steps with FX.step_debris.
static func pieces(parent: Node3D, kinds: PackedStringArray, ink: PackedColorArray, box: AABB, count: int) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Debris"
	parent.add_child(root)
	var r: RandomNumberGenerator = FX.rng()
	var span: float = maxf(box.size.x, box.size.z)
	var mats: Dictionary = {}
	for i: int in count:
		var kind: String = kinds[0] if kinds.size() < 2 or r.randf() < 0.65 else kinds[1]
		var shade: int = r.randi_range(0, ink.size() - 1)
		var key: String = "%s/%d" % [kind, shade]
		if not mats.has(key):
			mats[key] = _mat(ink[shade], kind)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = piece_mesh(kind, span * r.randf_range(0.07, 0.14), r)
		mi.material_override = mats[key] as Material
		mi.set_meta("material", kind)
		var ang: float = r.randf() * TAU
		var out: float = r.randf_range(0.3, 1.0) * span * (1.4 if kind == Catalog.GLASS else 1.0)
		mi.set_meta("vel", Vector3(cos(ang) * out, r.randf_range(2.5, 6.5), sin(ang) * out))
		mi.set_meta("spin", Vector3(r.randf_range(-7, 7), r.randf_range(-7, 7), r.randf_range(-7, 7)))
		mi.position = Vector3(r.randf_range(-0.3, 0.3) * box.size.x, r.randf_range(0.2, 0.8) * box.size.y, r.randf_range(-0.3, 0.3) * box.size.z) + Vector3(box.get_center().x, box.position.y, box.get_center().z)
		root.add_child(mi)
	return root

## The effect each material throws off as it fails.
static func effects(parent: Node3D, kinds: PackedStringArray, ink: PackedColorArray, box: AABB) -> void:
	var span: float = maxf(box.size.x, box.size.z)
	var mid: Vector3 = Vector3(box.get_center().x, box.position.y + box.size.y * 0.45, box.get_center().z)
	var seen: Dictionary = {}
	for kind: String in kinds:
		if seen.has(kind):
			continue
		seen[kind] = true
		if kind == Catalog.BRICK or kind == Catalog.CONCRETE or kind == Catalog.STONE:
			var dust: CPUParticles3D = FX.dust(parent, Vector3(mid.x, box.position.y + 0.3, mid.z), span * 1.1, 40)
			var light: Color = ink[ink.size() - 1] if not ink.is_empty() else Color(0.6, 0.55, 0.45)
			dust.color_ramp = FX._ramp([Color(light.r, light.g, light.b, 0.0), Color(light.r, light.g, light.b, 0.75), Color(light.r, light.g, light.b, 0.0)])
			dust.lifetime = 2.6
		elif kind == Catalog.TIMBER:
			splinters(parent, mid, span, ink)
		elif kind == Catalog.BAMBOO:
			embers(parent, mid, span)
			FX.fire(parent, Vector3(mid.x, box.position.y + box.size.y * 0.2, mid.z), clampf(span * 0.35, 0.8, 3.0), 26).emitting = true
		elif kind == Catalog.STEEL:
			sparks(parent, mid, span)
		elif kind == Catalog.GLASS:
			glass(parent, mid, span, ink)

static func splinters(parent: Node3D, at: Vector3, span: float, ink: PackedColorArray) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Splinters"
	p.amount = 40
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var shard: BoxMesh = BoxMesh.new()
	shard.size = Vector3(0.04, 0.04, 0.32) * clampf(span * 0.25, 0.6, 2.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ink[2] if ink.size() > 2 else Color(0.5, 0.35, 0.2)
	shard.material = mat
	p.mesh = shard
	p.position = at
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, -12, 0)
	p.initial_velocity_min = span * 0.8
	p.initial_velocity_max = span * 1.8
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.particle_flag_rotate_y = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = span * 0.3
	parent.add_child(p)
	p.emitting = true
	return p

static func embers(parent: Node3D, at: Vector3, span: float) -> CPUParticles3D:
	var p: CPUParticles3D = FX._emitter("Embers", 60, 3.2, true, 0.18)
	p.position = at
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0.4, 1.2, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(span * 0.4, span * 0.3, span * 0.4)
	p.color_ramp = FX._ramp([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.4, 0.08, 0.9), Color(0.4, 0.08, 0.02, 0.0)])
	parent.add_child(p)
	p.emitting = true
	return p

static func sparks(parent: Node3D, at: Vector3, span: float) -> CPUParticles3D:
	var p: CPUParticles3D = FX._emitter("Sparks", 70, 0.9, true, 0.12)
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.75
	p.direction = Vector3.UP
	p.spread = 75.0
	p.gravity = Vector3(0, -16, 0)
	p.initial_velocity_min = span * 1.2
	p.initial_velocity_max = span * 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = span * 0.25
	p.color_ramp = FX._ramp([Color(1.0, 1.0, 0.8, 1.0), Color(1.0, 0.7, 0.2, 1.0), Color(1.0, 0.3, 0.05, 0.0)])
	parent.add_child(p)
	p.emitting = true
	return p

static func glass(parent: Node3D, at: Vector3, span: float, ink: PackedColorArray) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "Glass"
	p.amount = 48
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var pane: QuadMesh = QuadMesh.new()
	pane.size = Vector2(0.14, 0.2) * clampf(span * 0.25, 0.6, 2.0)
	var tint: Color = ink[ink.size() - 1] if not ink.is_empty() else Color(0.6, 0.85, 1.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.6).lightened(0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.9, 1.0) * 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.metallic = 0.4
	mat.roughness = 0.05
	pane.material = mat
	p.mesh = pane
	p.position = at
	p.direction = Vector3.UP
	p.spread = 85.0
	p.gravity = Vector3(0, -14, 0)
	p.initial_velocity_min = span * 1.0
	p.initial_velocity_max = span * 2.2
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.particle_flag_rotate_y = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = span * 0.35
	parent.add_child(p)
	p.emitting = true
	return p

## A low heap over the footprint, shaded with the palette, that grows as the building comes down.
static func mound(parent: Node3D, box: AABB, ink: PackedColorArray) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "RubbleMound"
	var heap: SphereMesh = SphereMesh.new()
	heap.radius = 0.5
	heap.height = 1.0
	heap.radial_segments = 9
	heap.rings = 4
	heap.is_hemisphere = true
	mi.mesh = heap
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ink[1] if ink.size() > 1 else Color(0.3, 0.27, 0.24)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.position = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	mi.scale = Vector3(box.size.x * 1.15, 0.01, box.size.z * 1.15)
	mi.set_meta("height", box.size.y * 0.28)
	parent.add_child(mi)
	return mi
