extends RefCounted
## Match presentation: props, fog sheet, sites, and decks. Sim scripts call this.

const Forms = preload("res://game/unit_meshes.gd")
const Ground = preload("res://game/ground_view.gd")
const Settings = preload("res://game/match_settings.gd")
const BuildingFx = preload("res://game/building_fx.gd")

static func sync(host: Node3D, sight: SMSight, cam: RTSCamera) -> void:
	paint_fog(sight, host)
	Ground.apply_sky(host, sight)
	Ground.cull_props(host, cam)
	quiet_crowd(host)

static func quiet_crowd(host: Node3D) -> void:
	if host == null:
		return
	var low: bool = Settings.low()
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return
	for u: RTSUnit in field.units:
		if not is_instance_valid(u):
			continue
		var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
		if body != null:
			var shadow: MeshInstance3D = body.get_node_or_null("ContactShadow") as MeshInstance3D
			if shadow != null:
				shadow.visible = not low
			body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var bar: MeshInstance3D = u.get_node_or_null("HealthBar") as MeshInstance3D
		if bar == null:
			continue
		if not low or u.selected or u.hp < u.max_hp - 0.4:
			bar.visible = true
		else:
			bar.visible = false

static func paint_fog(sight: SMSight, host: Node3D) -> void:
	if host == null or sight == null or sight.grid == null:
		return
	var grid: SMDomainGrid = sight.grid
	if grid.cols <= 0 or grid.rows <= 0 or sight.explored.size() != grid.cols * grid.rows:
		return
	var veil: MeshInstance3D = host.get_node_or_null("FogVeil") as MeshInstance3D
	if veil == null:
		veil = MeshInstance3D.new()
		veil.name = "FogVeil"
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = _veil_shader()
		veil.material_override = mat
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(veil)
	var span: Vector2 = Vector2(float(grid.cols), float(grid.rows)) * grid.cell_size
	var plane: PlaneMesh = veil.mesh as PlaneMesh
	if plane == null or not plane.size.is_equal_approx(span):
		plane = PlaneMesh.new()
		plane.size = span
		veil.mesh = plane
		veil.position = grid.origin + Vector3(span.x * 0.5, 0.42, span.y * 0.5)
		veil.set_meta("hash", -1)
	var sig: int = hash([sight.seers, sight.radii, sight.river_lit, sight.explored, grid.origin, grid.cell_size])
	if int(veil.get_meta("hash", -1)) == sig:
		return
	veil.set_meta("hash", sig)
	var lit: Image = _lit_mask(sight, grid, veil)
	var known: Image = Image.create_from_data(grid.cols, grid.rows, false, Image.FORMAT_R8, sight.explored)
	var mat_now: ShaderMaterial = veil.material_override as ShaderMaterial
	mat_now.set_shader_parameter("seen", _texture(veil, "seen_tex", lit))
	mat_now.set_shader_parameter("explored", _texture(veil, "known_tex", known))

## Cells whose centre is inside a seer's circle, matching SMSight.cell_state. Stamped one row span at a time.
static func _lit_mask(sight: SMSight, grid: SMDomainGrid, veil: Node) -> Image:
	var lit: Image
	if sight.river_lit:
		lit = (_corridor(grid, veil)).duplicate() as Image
	else:
		lit = Image.create(grid.cols, grid.rows, false, Image.FORMAT_R8)
	var on: Color = Color(1.0, 0.0, 0.0)
	var cs: float = grid.cell_size
	var ox: float = grid.origin.x
	var oz: float = grid.origin.z
	for i: int in mini(sight.seers.size(), sight.radii.size()):
		var at: Vector3 = sight.seers[i]
		var r: float = sight.radii[i]
		var y0: int = maxi(0, ceili((at.z - r - oz) / cs - 0.5))
		var y1: int = mini(grid.rows - 1, floori((at.z + r - oz) / cs - 0.5))
		for y: int in range(y0, y1 + 1):
			var dz: float = oz + (float(y) + 0.5) * cs - at.z
			var reach: float = r * r - dz * dz
			if reach < 0.0:
				continue
			var half: float = sqrt(reach)
			var x0: int = maxi(0, ceili((at.x - half - ox) / cs - 0.5))
			var x1: int = mini(grid.cols - 1, floori((at.x + half - ox) / cs - 0.5))
			if x1 >= x0:
				lit.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), on)
	return lit

## Water cells and their four neighbours, lit while the radar holds the river.
static func _corridor(grid: SMDomainGrid, veil: Node) -> Image:
	var kept: Image = veil.get_meta("corridor") as Image if veil.has_meta("corridor") else null
	if kept != null and kept.get_width() == grid.cols and kept.get_height() == grid.rows:
		return kept
	var img: Image = Image.create(grid.cols, grid.rows, false, Image.FORMAT_R8)
	var on: Color = Color(1.0, 0.0, 0.0)
	var steps: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y: int in grid.rows:
		for x: int in grid.cols:
			for step: Vector2i in steps:
				var c: Vector2i = Vector2i(x, y) + step
				if not grid.in_bounds(c):
					continue
				var d: int = grid.domain_at_cell(c)
				if d == SMDomainGrid.Domain.SHALLOW or d == SMDomainGrid.Domain.DEEP:
					img.set_pixel(x, y, on)
					break
	veil.set_meta("corridor", img)
	return img

static func _texture(veil: Node, key: String, img: Image) -> ImageTexture:
	var tex: ImageTexture = veil.get_meta(key) as ImageTexture if veil.has_meta(key) else null
	if tex != null and tex.get_width() == img.get_width() and tex.get_height() == img.get_height():
		tex.update(img)
		return tex
	tex = ImageTexture.create_from_image(img)
	veil.set_meta(key, tex)
	return tex

static var _shader: Shader

static func _veil_shader() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D seen : filter_nearest, repeat_disable;
uniform sampler2D explored : filter_nearest, repeat_disable;
void fragment() {
	vec4 ink = texture(explored, UV).r > 0.0 ? vec4(0.04, 0.05, 0.07, 0.28) : vec4(0.03, 0.04, 0.05, 0.78);
	ALBEDO = ink.rgb;
	ALPHA = texture(seen, UV).r > 0.5 ? 0.0 : ink.a;
}
"""
	return _shader

static func place_site(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, form: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	if form != "":
		Ground.dress_site(mi, form, color)
	else:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat
	host.add_child(mi)

static func sink_named(host: Node3D, node_name: String) -> void:
	if host == null:
		return
	var plate: MeshInstance3D = host.get_node_or_null(node_name) as MeshInstance3D
	if plate == null:
		return
	plate.position.y = -0.55
	var sunk: StandardMaterial3D = StandardMaterial3D.new()
	sunk.albedo_color = Color(0.08, 0.07, 0.06)
	plate.material_override = sunk

static func fit_deck(host: Node3D, deck_name: String, north_up: bool, south_up: bool) -> void:
	if host == null:
		return
	var deck: MeshInstance3D = host.get_node_or_null(deck_name) as MeshInstance3D
	if deck == null:
		return
	var box: BoxMesh = deck.mesh as BoxMesh
	if not north_up and not south_up:
		deck.visible = false
		return
	deck.visible = true
	if box == null:
		return
	var x: float = deck.position.x
	if north_up and south_up:
		deck.position = Vector3(x, 0.15, 0.0)
		box.size = Vector3(14.0, 0.28, 16.0)
	elif north_up:
		deck.position = Vector3(x, 0.15, -4.0)
		box.size = Vector3(14.0, 0.28, 8.0)
	else:
		deck.position = Vector3(x, 0.15, 4.0)
		box.size = Vector3(14.0, 0.28, 8.0)

static func slab(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.position = pos
	if not Forms.dress_structure(mi, size, color):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mi.material_override = mat
	if host != null:
		host.add_child(mi)
		BuildingFx.attach(mi)
	return mi

static func plain_slab(host: Node3D, node_name: String, at: Vector3, size: Vector3, color: Color) -> void:
	if host == null or host.get_node_or_null(node_name) != null:
		return
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	body.mesh = mesh
	body.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat
	host.add_child(body)

static func billboard(parent: Node3D, node_name: String, text: String, size: int, pixel: float, at: Vector3) -> void:
	if parent == null or parent.get_node_or_null(node_name) != null:
		return
	var tag: Label3D = Label3D.new()
	tag.name = node_name
	tag.text = text
	tag.font_size = size
	tag.pixel_size = pixel
	tag.position = at
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	parent.add_child(tag)

static func dress_spawn(u: RTSUnit, team: int, label: String) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.05
	ring.mesh = torus
	ring.position = Vector3(0, 0.08, 0)
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.85, 0.35)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.visible = false
	u.add_child(ring)
	var tag: Label3D = Label3D.new()
	tag.name = "NameTag"
	tag.text = label
	tag.font_size = 32
	tag.pixel_size = 0.008
	tag.outline_size = 8
	tag.outline_modulate = Color(0.02, 0.02, 0.03)
	tag.position = Vector3(0, 3.35, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(0.97, 0.94, 0.84)
	tag.visible = false
	u.add_child(tag)
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.name = "HealthBar"
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = Vector3(2.0, 0.16, 0.1)
	bar.mesh = slab_mesh
	bar.position = Vector3(0.0, 2.9, 0.0)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.35, 0.82, 0.38) if team == 0 else Color(0.86, 0.24, 0.2)
	bar.material_override = ink
	u.add_child(bar)
	var muzzle: MeshInstance3D = MeshInstance3D.new()
	muzzle.name = "Muzzle"
	var flash: BoxMesh = BoxMesh.new()
	flash.size = Vector3(0.22, 0.22, 0.5)
	muzzle.mesh = flash
	muzzle.position = Forms.muzzle_pos(str(u.get_node("Body").get_meta("form", "truck")))
	muzzle.visible = false
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.82, 0.35)
	muzzle.material_override = glow
	u.add_child(muzzle)
	var reach: MeshInstance3D = MeshInstance3D.new()
	reach.name = "RangeRing"
	var band: TorusMesh = TorusMesh.new()
	band.inner_radius = 0.97
	band.outer_radius = 1.0
	band.rings = 48
	band.ring_segments = 4
	reach.mesh = band
	reach.position = Vector3(0.0, 0.06, 0.0)
	reach.visible = false
	reach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach_ink: StandardMaterial3D = StandardMaterial3D.new()
	reach_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reach_ink.albedo_color = Color(0.95, 0.55, 0.22, 0.55)
	reach_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reach.material_override = reach_ink
	u.add_child(reach)

static func place_beacon(host: Node3D, at: Vector3) -> void:
	if host == null:
		return
	var pole: MeshInstance3D = host.get_node_or_null("GoalBeacon") as MeshInstance3D
	if at == Vector3.INF:
		if pole != null:
			pole.visible = false
		return
	if pole == null:
		pole = MeshInstance3D.new()
		pole.name = "GoalBeacon"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.1, 2.4, 0.1)
		pole.mesh = box
		pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.albedo_color = Color(0.98, 0.82, 0.28, 0.4)
		pole.material_override = ink
		var halo: MeshInstance3D = MeshInstance3D.new()
		halo.name = "GoalHalo"
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.82
		ring.outer_radius = 0.98
		halo.mesh = ring
		halo.position = Vector3(0.0, -1.14, 0.0)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo_ink: StandardMaterial3D = StandardMaterial3D.new()
		halo_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_ink.albedo_color = Color(0.98, 0.82, 0.28, 0.45)
		halo.material_override = halo_ink
		pole.add_child(halo)
		host.add_child(pole)
	var wave: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
	var ink_now: StandardMaterial3D = pole.material_override as StandardMaterial3D
	if ink_now != null:
		ink_now.albedo_color = Color(0.98, 0.82, 0.28, 0.18 + 0.32 * wave)
	var halo_now: MeshInstance3D = pole.get_node_or_null("GoalHalo") as MeshInstance3D
	if halo_now != null:
		var halo_ink_now: StandardMaterial3D = halo_now.material_override as StandardMaterial3D
		if halo_ink_now != null:
			halo_ink_now.albedo_color = Color(0.98, 0.82, 0.28, 0.22 + 0.4 * wave)
		halo_now.scale = Vector3(0.85 + 0.35 * wave, 1.0, 0.85 + 0.35 * wave)
	pole.scale = Vector3(0.75 + 0.25 * wave, 1.0, 0.75 + 0.25 * wave)
	pole.position = Vector3(at.x, 1.2, at.z)
	pole.visible = true

static func place_rally(host: Node3D, at: Vector3) -> void:
	if host == null or at == Vector3.INF:
		return
	var flag: MeshInstance3D = host.get_node_or_null("RallyFlag") as MeshInstance3D
	if flag == null:
		flag = MeshInstance3D.new()
		flag.name = "RallyFlag"
		var pole: BoxMesh = BoxMesh.new()
		pole.size = Vector3(0.08, 1.5, 0.08)
		flag.mesh = pole
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.25, 0.85, 0.45)
		flag.material_override = ink
		var cloth: MeshInstance3D = MeshInstance3D.new()
		cloth.name = "RallyCloth"
		var sheet: BoxMesh = BoxMesh.new()
		sheet.size = Vector3(0.7, 0.38, 0.06)
		cloth.mesh = sheet
		cloth.position = Vector3(0.35, 0.5, 0.0)
		cloth.material_override = ink
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flag.add_child(cloth)
		host.add_child(flag)
	flag.position = Vector3(at.x, 0.8, at.z)
	flag.visible = true

static func path_mark(host: Node3D, show: bool, step: Vector3) -> void:
	if host == null:
		return
	var mark: MeshInstance3D = host.get_node_or_null("PathMark") as MeshInstance3D
	if not show:
		if mark != null:
			mark.visible = false
		return
	if mark == null:
		mark = MeshInstance3D.new()
		mark.name = "PathMark"
		var gem: BoxMesh = BoxMesh.new()
		gem.size = Vector3(0.55, 0.14, 0.55)
		mark.mesh = gem
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = Color(0.95, 0.82, 0.28)
		mark.material_override = ink
		host.add_child(mark)
	mark.position = Vector3(step.x, 0.22, step.z)
	mark.visible = true

static func wreck(host: Node3D, at: Vector3) -> MeshInstance3D:
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Wreck"
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.08
	body.mesh = disc
	body.position = Vector3(at.x, 0.08, at.z)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.15, 0.05, 0.04)
	body.material_override = ink
	if host != null:
		host.add_child(body)
	return body

static func order_ping(host: Node3D, at: Vector3, order: String) -> MeshInstance3D:
	var ping: MeshInstance3D = MeshInstance3D.new()
	ping.name = "OrderPing"
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.82
	ping.mesh = ring
	ping.position = Vector3(at.x, 0.15, at.z)
	ping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.95, 0.28, 0.22) if order == "attack" else Color(0.95, 0.78, 0.28)
	ping.material_override = ink
	if host != null:
		host.add_child(ping)
	return ping

static func damage_pop(u: RTSUnit, amount: float) -> void:
	var pop: Label3D = u.get_node_or_null("DamagePop") as Label3D
	if pop == null:
		pop = Label3D.new()
		pop.name = "DamagePop"
		pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pop.font_size = 64
		pop.pixel_size = 0.005
		pop.outline_size = 10
		pop.no_depth_test = true
		pop.position = Vector3(0.0, 2.4, 0.0)
		u.add_child(pop)
	pop.text = "-%d" % maxi(1, int(round(amount)))
	pop.modulate = Color(1.0, 0.45, 0.32, 1.0) if u.team == 0 else Color(1.0, 0.86, 0.35, 1.0)
	pop.position = Vector3(0.0, 2.4, 0.0)
	pop.visible = true
