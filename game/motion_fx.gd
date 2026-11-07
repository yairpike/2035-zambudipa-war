extends RefCounted
## Cheap one-shot and looping effects for unit and building motion: smoke, fire, dust, muzzle flash, debris.
## CPU particles only, small counts, so they run the same in the editor and in WebGL 2.

static var _puff: Texture2D
static var _mats: Dictionary = {}
static var _rng: RandomNumberGenerator

static func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = 2031
	return _rng

static func puff_texture() -> Texture2D:
	if _puff != null:
		return _puff
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	_puff = tex
	return _puff

static func puff_material(additive: bool) -> StandardMaterial3D:
	var key: String = "add" if additive else "mix"
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this, idle particles (zero scale) draw as full-size quads at the emitter.
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = puff_texture()
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats[key] = mat
	return mat

static func _emitter(node_name: String, amount: int, life: float, additive: bool, size: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = puff_material(additive)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _ramp(colors: Array[Color]) -> Gradient:
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var inks: PackedColorArray = PackedColorArray()
	for i: int in colors.size():
		offsets.append(float(i) / float(maxi(colors.size() - 1, 1)))
		inks.append(colors[i])
	var g: Gradient = Gradient.new()
	g.colors = inks
	g.offsets = offsets
	return g

static func _grow(from: float, to: float) -> Curve:
	var c: Curve = Curve.new()
	c.min_value = 0.0
	c.max_value = maxf(from, to)
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	return c

## A rising plume. `scale` widens it for buildings.
static func smoke(parent: Node3D, at: Vector3, scale: float = 1.0, amount: int = 14) -> CPUParticles3D:
	var p: CPUParticles3D = _emitter("Smoke", amount, 2.6, false, 1.5 * scale)
	p.position = at
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0.35, 0.9, 0.0)
	p.initial_velocity_min = 1.0 * scale
	p.initial_velocity_max = 1.9 * scale
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45 * scale
	p.scale_amount_curve = _grow(0.35, 1.0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	p.color_ramp = _ramp([Color(0.3, 0.29, 0.27, 0.0), Color(0.3, 0.29, 0.27, 0.42), Color(0.5, 0.49, 0.47, 0.0)])
	parent.add_child(p)
	return p

static func fire(parent: Node3D, at: Vector3, scale: float = 1.0, amount: int = 16) -> CPUParticles3D:
	var p: CPUParticles3D = _emitter("Fire", amount, 0.7, true, 0.95 * scale)
	p.position = at
	p.direction = Vector3.UP
	p.spread = 18.0
	p.gravity = Vector3(0.0, 2.2, 0.0)
	p.initial_velocity_min = 0.4 * scale
	p.initial_velocity_max = 1.1 * scale
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3 * scale
	p.scale_amount_curve = _grow(1.0, 0.2)
	p.color_ramp = _ramp([Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.45, 0.1, 0.8), Color(0.5, 0.1, 0.05, 0.0)])
	parent.add_child(p)
	return p

## A one-shot ring of dust at ground level, for a building settling or a heavy hull braking.
static func dust(parent: Node3D, at: Vector3, radius: float, amount: int = 24) -> CPUParticles3D:
	var p: CPUParticles3D = _emitter("Dust", amount, 1.6, false, 1.1 * maxf(radius * 0.35, 0.6))
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.85
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 90.0
	p.flatness = 0.8
	p.gravity = Vector3(0, -0.4, 0)
	p.initial_velocity_min = radius * 0.6
	p.initial_velocity_max = radius * 1.2
	p.damping_min = radius * 0.6
	p.damping_max = radius * 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.6
	p.emission_ring_inner_radius = radius * 0.3
	p.emission_ring_height = 0.1
	p.scale_amount_curve = _grow(0.6, 1.4)
	p.color_ramp = _ramp([Color(0.55, 0.48, 0.38, 0.0), Color(0.55, 0.48, 0.38, 0.65), Color(0.6, 0.55, 0.45, 0.0)])
	parent.add_child(p)
	p.emitting = true
	return p

## A fireball burst for a kill or a collapse.
static func blast(parent: Node3D, at: Vector3, scale: float = 1.0) -> CPUParticles3D:
	var p: CPUParticles3D = _emitter("Blast", 22, 0.55, true, 1.4 * scale)
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, 1.0, 0)
	p.initial_velocity_min = 1.5 * scale
	p.initial_velocity_max = 4.0 * scale
	p.damping_min = 3.0 * scale
	p.damping_max = 5.0 * scale
	p.scale_amount_curve = _grow(0.6, 1.4)
	p.color_ramp = _ramp([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.5, 0.12, 0.85), Color(0.25, 0.1, 0.06, 0.0)])
	parent.add_child(p)
	p.emitting = true
	return p

## A camera-facing flash at a muzzle that fades in a few frames.
static func flash(parent: Node3D, at: Vector3, size: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "MuzzleFlash"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat: StandardMaterial3D = puff_material(true).duplicate() as StandardMaterial3D
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = Color(1.0, 0.85, 0.45, 1.0)
	quad.material = mat
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	parent.add_child(mi)
	var tw: Tween = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.6, 0.07)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(mi.queue_free)
	return mi

## Dark translucent coat laid over every mesh in a subtree, for charred wrecks and rubble.
static func char_coat(strength: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.04, 0.035, 0.03, strength)
	return mat

static func coat(node: Node, mat: Material) -> void:
	if node.name == "ContactShadow" or node.name == "Wake" or node.name == "BowSpray" or node is CPUParticles3D:
		return
	var mesh_node: GeometryInstance3D = node as GeometryInstance3D
	if mesh_node != null:
		mesh_node.material_overlay = mat
	for child: Node in node.get_children():
		coat(child, mat)

## Chunks thrown out of a collapsing building or exploding hull. Each falls, spins and settles.
static func debris(parent: Node3D, at: Vector3, spread: float, count: int, ink: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Debris"
	root.position = at
	parent.add_child(root)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ink
	mat.roughness = 0.95
	var r: RandomNumberGenerator = rng()
	for i: int in count:
		var chunk: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var s: float = spread * r.randf_range(0.06, 0.16)
		box.size = Vector3(s, s * r.randf_range(0.4, 1.0), s * r.randf_range(0.6, 1.3))
		chunk.mesh = box
		chunk.material_override = mat
		var ang: float = r.randf() * TAU
		var out: float = r.randf_range(0.4, 1.0) * spread
		chunk.set_meta("vel", Vector3(cos(ang) * out, r.randf_range(2.5, 6.0), sin(ang) * out))
		chunk.set_meta("spin", Vector3(r.randf_range(-6, 6), r.randf_range(-6, 6), r.randf_range(-6, 6)))
		chunk.position = Vector3(r.randf_range(-0.3, 0.3) * spread, r.randf_range(0.3, 1.0) * spread * 0.5, r.randf_range(-0.3, 0.3) * spread)
		root.add_child(chunk)
	return root

## Steps debris made by `debris`. Returns false once every chunk has landed.
static func step_debris(root: Node3D, delta: float) -> bool:
	if root == null:
		return false
	var moving: bool = false
	for child: Node in root.get_children():
		var chunk: MeshInstance3D = child as MeshInstance3D
		if chunk == null:
			continue
		var vel: Vector3 = chunk.get_meta("vel", Vector3.ZERO)
		if vel == Vector3.ZERO:
			continue
		vel.y -= 14.0 * delta
		chunk.position += vel * delta
		var spin: Vector3 = chunk.get_meta("spin", Vector3.ZERO)
		chunk.rotation += spin * delta
		if chunk.position.y <= 0.05 and vel.y < 0.0:
			chunk.position.y = 0.05
			vel = Vector3(vel.x * 0.3, -vel.y * 0.25, vel.z * 0.3)
			chunk.set_meta("spin", spin * 0.4)
			if absf(vel.y) < 0.6:
				vel = Vector3.ZERO
		chunk.set_meta("vel", vel)
		moving = moving or vel != Vector3.ZERO
	return moving

## A flat expanding ring on the ground, for an ability cast.
static func ring(parent: Node3D, at: Vector3, radius: float, ink: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CastRing"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius * 0.86
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 4
	mi.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = ink
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = Vector3(0.3, 0.2, 0.3)
	parent.add_child(mi)
	var tw: Tween = mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.6, 0.2, 1.6), 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(mi.queue_free)
	return mi
