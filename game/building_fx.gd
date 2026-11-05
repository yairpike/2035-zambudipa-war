extends Node3D
## View-only life of one structure: rises out of a scaffold when placed, runs a working loop while powered, smokes and
## burns as it loses health, and breaks apart by material into rubble when the sim hides it.
## The sim never reads anything this node writes.

const FX = preload("res://game/motion_fx.gd")
const Debris = preload("res://game/building_debris.gd")
const Catalog = preload("res://game/model_catalog.gd")

enum Phase { RAISE, STAND, COLLAPSE, RUBBLE }

const RAISE_TIME: float = 2.8
const COLLAPSE_TIME: float = 1.8
const RUBBLE_TIME: float = 14.0
const SMOKE_AT: float = 0.66
const FIRE_AT: float = 0.33

var phase: int = Phase.RAISE
var age: float = 0.0
var target: Node3D
var rest: Transform3D
var box: AABB
var cage: Node3D
var health: float = 1.0
var smoke_fx: CPUParticles3D
var fire_fx: CPUParticles3D
var proxy: Node3D
var debris: Node3D
var lean: Vector3 = Vector3.ZERO
var chunks: Array[MeshInstance3D] = []
var heap: MeshInstance3D
var materials: PackedStringArray = PackedStringArray()
var ink: PackedColorArray = PackedColorArray()
var powered: bool = true
var repairing: bool = false
var work: Node3D
var repair_fx: CPUParticles3D

## Hooks a structure node. `raise` false skips the construction rise (buildings present at load).
static func attach(structure: Node3D, raise: bool = true) -> Node3D:
	if structure == null or structure.get_node_or_null("BuildingFx") != null:
		return null
	var fx: Node3D = (load("res://game/building_fx.gd") as GDScript).new() as Node3D
	fx.name = "BuildingFx"
	fx.set("phase", Phase.RAISE if raise else Phase.STAND)
	structure.add_child(fx)
	return fx

## Powered structures run their working loop; low power stops it. Repair throws welding sparks.
static func set_state(structure: Node3D, p_powered: bool, p_repairing: bool) -> void:
	if structure == null:
		return
	var fx: Node = structure.get_node_or_null("BuildingFx")
	if fx != null:
		fx.call("show_state", p_powered, p_repairing)

## Model id and material tags this structure breaks into.
static func materials_for(structure: Node3D) -> PackedStringArray:
	var id: String = str(structure.get_meta("model_id", ""))
	if id == "":
		id = str(structure.name).to_lower().trim_prefix("built_")
	return Catalog.materials_of(id, str(structure.get_meta("form", "")))

static func set_health(structure: Node3D, fraction: float) -> void:
	if structure == null:
		return
	var fx: Node = structure.get_node_or_null("BuildingFx")
	if fx != null:
		fx.call("show_health", fraction)

func _ready() -> void:
	target = get_parent() as Node3D
	if target == null:
		return
	rest = target.transform
	box = _bounds(target)
	target.visibility_changed.connect(_on_visibility)
	materials = materials_for(target)
	if phase == Phase.RAISE:
		_apply_rise(0.0)
		_start_raise.call_deferred()
	else:
		_start_work.call_deferred()

func _bounds(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var inv: Transform3D = root.global_transform.affine_inverse()
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		if node is CPUParticles3D or node.name == "ContactShadow":
			continue
		var vi: VisualInstance3D = node as VisualInstance3D
		var b: AABB = inv * vi.global_transform * vi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	var own: VisualInstance3D = root as VisualInstance3D
	if own != null and (root as MeshInstance3D).mesh != null:
		out = own.get_aabb() if first else out.merge(own.get_aabb())
		first = false
	if first:
		out = AABB(Vector3(-2, 0, -2), Vector3(4, 3, 4))
	return out

func _stage() -> Node3D:
	return target.get_parent() as Node3D

func _start_raise() -> void:
	var stage: Node3D = _stage()
	if stage == null:
		phase = Phase.STAND
		return
	if not target.visible or bool(target.get_meta("standin_held", false)):
		return
	cage = _scaffold(box)
	cage.name = "Scaffold_%s" % target.name
	stage.add_child(cage)
	cage.transform = rest.translated_local(Vector3(0, box.position.y, 0))
	cage.scale = Vector3(1.0, 0.01, 1.0)
	FX.dust(stage, rest.origin + Vector3(0, box.position.y + 0.1, 0), maxf(box.size.x, box.size.z) * 0.6, 20)

func _apply_rise(k: float) -> void:
	var h: float = box.size.y
	var eased: float = 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)
	var xf: Transform3D = rest
	xf.origin.y = rest.origin.y - h * (1.0 - eased)
	target.transform = xf

func _process(delta: float) -> void:
	if target == null:
		return
	age += delta
	if phase == Phase.RAISE:
		_step_raise()
	elif phase == Phase.STAND:
		_step_work(delta)
	elif phase == Phase.COLLAPSE or phase == Phase.RUBBLE:
		_step_collapse(delta)

func _step_raise() -> void:
	var cage_k: float = clampf(age / 0.45, 0.0, 1.0)
	if cage != null:
		cage.scale = Vector3(1.0, maxf(cage_k, 0.01), 1.0)
	_apply_rise((age - 0.3) / (RAISE_TIME - 0.8))
	if age >= RAISE_TIME - 0.5 and cage != null:
		var fade: float = clampf((RAISE_TIME - age) / 0.5, 0.0, 1.0)
		cage.scale = Vector3(1.0 + (1.0 - fade) * 0.04, maxf(fade, 0.01), 1.0 + (1.0 - fade) * 0.04)
	if age >= RAISE_TIME:
		target.transform = rest
		if cage != null:
			cage.queue_free()
			cage = null
		FX.dust(_stage(), rest.origin + Vector3(0, box.position.y + 0.1, 0), maxf(box.size.x, box.size.z) * 0.7, 26)
		phase = Phase.STAND
		age = 0.0
		_start_work()

func show_health(fraction: float) -> void:
	health = clampf(fraction, 0.0, 1.0)
	var roof: Vector3 = Vector3(box.get_center().x, box.position.y + box.size.y * 0.85, box.get_center().z)
	var span: float = clampf(maxf(box.size.x, box.size.z) * 0.22, 0.8, 3.0)
	if health < SMOKE_AT and smoke_fx == null:
		smoke_fx = FX.smoke(self, roof + Vector3(box.size.x * 0.18, 0, 0), span, 18)
		smoke_fx.emitting = true
	if health < FIRE_AT and fire_fx == null:
		fire_fx = FX.fire(self, roof - Vector3(box.size.x * 0.15, box.size.y * 0.2, 0), span * 0.8, 20)
		fire_fx.emitting = true
	if smoke_fx != null:
		smoke_fx.emitting = health < SMOKE_AT
	if fire_fx != null:
		fire_fx.emitting = health < FIRE_AT

## Fog of war hides these markers while they stand; only a destroyed one (SMOutcome marks it) collapses.
const FOGGED: PackedStringArray = ["EnemyYard", "EnemyClaim"]

func _on_visibility() -> void:
	if target.visible or phase == Phase.COLLAPSE or phase == Phase.RUBBLE:
		return
	if bool(target.get_meta("standin_held", false)):
		return
	if not bool(target.get_meta("destroyed", false)) and (FOGGED.has(str(target.name)) or str(target.name) == "HubShell"):
		return
	if not is_inside_tree() or _stage() == null:
		return
	collapse()

## Leaves a breaking copy of the structure in its place. The original stays hidden for the sim.
## The copy is cut into textured chunks when the model is within budget; pieces, effects and rubble follow its materials.
func collapse() -> void:
	var stage: Node3D = _stage()
	if stage == null:
		return
	if phase == Phase.RAISE:
		target.transform = rest
		if cage != null:
			cage.queue_free()
			cage = null
	_stop_work()
	var id: String = str(target.get_meta("model_id", ""))
	var husk: Node3D = Node3D.new()
	husk.name = "Ruin_%s" % target.name
	stage.add_child(husk)
	husk.transform = rest
	proxy = target.duplicate() as Node3D
	for child: Node in proxy.get_children():
		if child.name == "BuildingFx" or child is CPUParticles3D:
			proxy.remove_child(child)
			child.free()
	proxy.transform = Transform3D.IDENTITY
	proxy.visible = true
	husk.add_child(proxy)
	var r: RandomNumberGenerator = FX.rng()
	lean = Vector3(r.randf_range(-0.12, 0.12), 0.0, r.randf_range(-0.12, 0.12))
	var span: float = maxf(box.size.x, box.size.z)
	ink = Debris.palette(proxy, id, target.get_meta("paint", Color(0.45, 0.4, 0.35)) as Color)
	chunks = Debris.chunk(proxy, box, id)
	if not chunks.is_empty():
		var held: Node3D = Node3D.new()
		held.name = "Chunks"
		husk.add_child(held)
		for mi: MeshInstance3D in chunks:
			held.add_child(mi)
		Debris.launch(chunks, box, r)
		proxy.visible = false
	FX.blast(husk, Vector3(0, box.position.y + box.size.y * 0.5, 0), clampf(span * 0.28, 1.0, 3.0))
	FX.smoke(husk, Vector3(0, box.position.y + box.size.y * 0.4, 0), clampf(span * 0.3, 1.0, 3.0), 22).emitting = true
	Debris.effects(husk, materials, ink, box)
	if not materials.has(Catalog.BAMBOO):
		FX.fire(husk, Vector3(0, box.position.y + box.size.y * 0.25, 0), clampf(span * 0.25, 0.8, 2.4), 18).emitting = true
	debris = Debris.pieces(husk, materials, ink, box, 18)
	heap = Debris.mound(husk, box, ink)
	var coat: StandardMaterial3D = FX.char_coat(0.0)
	FX.coat(proxy, coat)
	for mi: MeshInstance3D in chunks:
		mi.material_overlay = coat
	proxy.set_meta("coat", coat)
	reparent(husk, false)
	position = Vector3.ZERO
	target = husk
	phase = Phase.COLLAPSE
	age = 0.0

func _step_collapse(delta: float) -> void:
	FX.step_debris(debris, delta)
	if not chunks.is_empty():
		Debris.step_chunks(chunks, delta)
	var k: float = clampf(age / COLLAPSE_TIME, 0.0, 1.0)
	if heap != null:
		heap.scale.y = maxf(0.01, float(heap.get_meta("height", 1.0)) * (1.0 - pow(1.0 - k, 2.0)))
	if proxy == null:
		return
	var fall: float = k * k
	if chunks.is_empty():
		var shake: float = (1.0 - k) * 0.06 * sin(age * 55.0)
		proxy.position = Vector3(shake, -box.size.y * 0.55 * fall, shake * 0.6)
		proxy.rotation = lean * fall
		proxy.scale = Vector3(1.0 + 0.08 * fall, 1.0 - 0.55 * fall, 1.0 + 0.08 * fall)
	var coat: StandardMaterial3D = proxy.get_meta("coat") as StandardMaterial3D
	if coat != null:
		coat.albedo_color.a = 0.55 * k
	if phase == Phase.COLLAPSE and age >= COLLAPSE_TIME:
		phase = Phase.RUBBLE
	if phase == Phase.RUBBLE and age >= COLLAPSE_TIME + RUBBLE_TIME:
		target.queue_free()

func show_state(p_powered: bool, p_repairing: bool) -> void:
	powered = p_powered
	repairing = p_repairing
	if work != null:
		work.visible = powered
		for node: Node in work.find_children("*", "CPUParticles3D", true, false):
			(node as CPUParticles3D).emitting = powered
	if repairing and repair_fx == null and phase == Phase.STAND:
		repair_fx = Debris.sparks(self, Vector3(box.get_center().x, box.position.y + box.size.y * 0.7, box.end.z * 0.9), 0.6)
		repair_fx.one_shot = false
		repair_fx.amount = 16
	if repair_fx != null:
		repair_fx.emitting = repairing

## A small loop per role so a working building reads as busy: a stack that smokes, a beacon that turns, a light that pulses.
func _start_work() -> void:
	if work != null or target == null:
		return
	var form: String = str(target.get_meta("form", ""))
	work = Node3D.new()
	work.name = "Working"
	add_child(work)
	var top: Vector3 = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	var span: float = maxf(box.size.x, box.size.z)
	if form == "refinery" or form == "factory" or form == "power":
		var stack: CPUParticles3D = FX.smoke(work, top + Vector3(box.size.x * 0.25, 0.0, box.size.z * 0.2), clampf(span * 0.12, 0.35, 1.0), 8)
		stack.emitting = true
		stack.color_ramp = FX._ramp([Color(0.75, 0.74, 0.72, 0.0), Color(0.75, 0.74, 0.72, 0.35), Color(0.8, 0.8, 0.8, 0.0)])
	var beacon: OmniLight3D = OmniLight3D.new()
	beacon.name = "Beacon"
	beacon.light_color = Color(1.0, 0.55, 0.15) if form != "airfield" and form != "naval" else Color(1.0, 0.2, 0.15)
	beacon.omni_range = clampf(span * 0.6, 2.0, 6.0)
	beacon.light_energy = 0.0
	beacon.shadow_enabled = false
	beacon.position = top + Vector3(0, 0.3, 0)
	work.add_child(beacon)
	var lamp: MeshInstance3D = MeshInstance3D.new()
	lamp.name = "Lamp"
	var bulb: SphereMesh = SphereMesh.new()
	bulb.radius = clampf(span * 0.03, 0.06, 0.18)
	bulb.height = bulb.radius * 2.0
	bulb.radial_segments = 8
	bulb.rings = 4
	lamp.mesh = bulb
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = beacon.light_color
	lamp.material_override = glow
	lamp.position = beacon.position
	work.add_child(lamp)
	work.set_meta("form", form)

func _step_work(delta: float) -> void:
	if work == null or not powered:
		return
	var beat: float = 0.5 + 0.5 * sin(age * (5.0 if str(work.get_meta("form", "")) == "airfield" else 2.6))
	var beacon: OmniLight3D = work.get_node_or_null("Beacon") as OmniLight3D
	if beacon != null:
		beacon.light_energy = 1.4 * beat
	var lamp: MeshInstance3D = work.get_node_or_null("Lamp") as MeshInstance3D
	if lamp != null:
		lamp.scale = Vector3.ONE * (0.6 + 0.6 * beat)

func _stop_work() -> void:
	if work != null:
		work.queue_free()
		work = null
	if repair_fx != null:
		repair_fx.queue_free()
		repair_fx = null

## Bamboo-and-pipe scaffold drawn as thin bars around the footprint.
func _scaffold(b: AABB) -> Node3D:
	var root: Node3D = Node3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.52, 0.3)
	mat.roughness = 0.9
	var pad: float = 0.25
	var x0: float = b.position.x - pad
	var x1: float = b.end.x + pad
	var z0: float = b.position.z - pad
	var z1: float = b.end.z + pad
	var top: float = b.size.y + 0.3
	var bar: float = clampf(maxf(b.size.x, b.size.z) * 0.012, 0.05, 0.16)
	var cols: int = 4
	for i: int in cols + 1:
		var f: float = float(i) / float(cols)
		for z: float in [z0, z1]:
			_bar(root, mat, Vector3(lerpf(x0, x1, f), top * 0.5, z), Vector3(bar, top, bar))
		for x: float in [x0, x1]:
			_bar(root, mat, Vector3(x, top * 0.5, lerpf(z0, z1, f)), Vector3(bar, top, bar))
	var decks: int = maxi(2, int(top / 1.6))
	for j: int in decks + 1:
		var y: float = top * float(j) / float(decks)
		_bar(root, mat, Vector3((x0 + x1) * 0.5, y, z0), Vector3(x1 - x0, bar, bar))
		_bar(root, mat, Vector3((x0 + x1) * 0.5, y, z1), Vector3(x1 - x0, bar, bar))
		_bar(root, mat, Vector3(x0, y, (z0 + z1) * 0.5), Vector3(bar, bar, z1 - z0))
		_bar(root, mat, Vector3(x1, y, (z0 + z1) * 0.5), Vector3(bar, bar, z1 - z0))
	return root

func _bar(root: Node3D, mat: Material, at: Vector3, size: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
