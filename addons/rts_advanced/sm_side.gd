class_name SMSide
extends RefCounted

const Power = preload("res://addons/rts_advanced/sm_power.gd")
## Build-style buttons for the faction chosen on the boot screen.

signal slab_made(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color)
signal line_voiced(text: String)
signal super_launched
signal defense_fired(building_id: StringName, at: Vector3)

var faction_id: String = "gtfc"
var yard: SMBuildYard = SMBuildYard.new()
var economy: RTSEconomy = RTSEconomy.new()
var packer_mesh: MeshInstance3D
var hub_mesh: MeshInstance3D
var host: Node3D
var status: Label
var building_hp: Dictionary[StringName, float] = {}
var building_names: Dictionary[StringName, String] = {}
var repair_armed: bool = false
var sell_armed: bool = false
var defender_air: bool = false
var occupants: Dictionary = {}
var gun_units: Dictionary = {}
var gun_cool: Dictionary = {}
var plan: SMBasePlan = SMBasePlan.new()

var building_yaw: Dictionary[StringName, float] = {}
## This side's own building nodes. The raider names its buildings the same way, so look them up here.
var building_nodes: Dictionary[StringName, Node3D] = {}
var rally_of: Dictionary[StringName, Vector3] = {}
var placement: SMPlacement = SMPlacement.new()
var bays: SMFactoryBay = SMFactoryBay.new()

## Footprint-sized plot for `id`, ringed out from `around`. Falls back to `around` when nothing fits on land.
## Naval structures return Vector3.INF when no water with an open bay is in reach.
func plot_of(id: StringName, around: Vector3) -> Vector3:
	plan.radius = yard.radius
	plan.center = around
	var role: String = str(yard.building_role.get(id, ""))
	return plan.plot(id, role, floats(id), bool(yard.water_marked.get(id, false)))

func floats(id: StringName) -> bool:
	return SMBasePlan.must_float(str(yard.building_role.get(id, "")), bool(yard.water_marked.get(id, false)))

func role_of(id: StringName) -> String:
	if id == yard_id():
		return "yard"
	return str(yard.building_role.get(id, ""))

## The construction yard id: the scaffold yard, the command hub, or the packer.
func yard_id() -> StringName:
	if yard.style == SMBuildYard.Style.MOBILE:
		return &"packer"
	if not yard.tech_order.is_empty():
		return yard.tech_order[0]
	return &""

func prepare(p_host: Node3D, p_status: Label, grid: SMDomainGrid, center: Vector3, purse: RTSEconomy, p_faction: String = "") -> void:
	host = p_host
	status = p_status
	faction_id = p_faction if p_faction != "" else SMFront.current()
	economy = purse
	var data: Dictionary = SMCatalog.faction(faction_id)
	yard.team = 0
	yard.economy = purse
	yard.center = center
	yard.radius = float(data.get("yard_radius", 14))
	yard.drain_per_sec = 5
	plan = SMBasePlan.new(grid, center, yard.radius)
	_load_buildings(data)
	_load_order(data)
	var style_name: String = str(data.get("build_style", "scaffold"))
	if style_name == "internal":
		yard.style = SMBuildYard.Style.INTERNAL
		yard.clearance = 1
		yard.radius = 25.0
		hub_mesh = _slab("HubShell", SMPointer.building_at(plot_of(&"command_hub", center)), SMPointer.BUILDING_SIZE, Color.html("#26BFD1"))
		if hub_mesh != null and not bool(hub_mesh.get_meta("standin_held", false)):
			hub_mesh.visible = false
	elif style_name == "mobile":
		yard.style = SMBuildYard.Style.MOBILE
		yard.grid = grid
		yard.packer_pos = center
		packer_mesh = _slab("PackerCore", SMPointer.building_at(center), SMPointer.BUILDING_SIZE, Color.html("#1F9E66"))
	else:
		yard.style = SMBuildYard.Style.SCAFFOLD

func order_building(id: StringName) -> String:
	if id == &"defender_vx" and yard != null and yard.finished.has(id):
		defender_air = not defender_air
		var mode: String = "defender air" if defender_air else "defender ground"
		_say(mode)
		return mode
	var role: String = str(yard.building_role.get(id, ""))
	if not Power.allows(yard, role):
		_say("low power")
		return "low power"
	if yard.style == SMBuildYard.Style.SCAFFOLD:
		return _order_scaffold(id)
	if yard.style == SMBuildYard.Style.INTERNAL:
		return _order_internal(id)
	return _order_mobile(id)

## True when the player should pick a spot and a facing before `id` is raised.
## Yards deploy where they stand, and a packed NMRF core unpacks in place.
func needs_spot(id: StringName) -> bool:
	if yard == null or id == &"" or yard.finished.has(id) or role_of(id) == "yard" or id == &"packer":
		return false
	if not yard.building_time.has(id) or not Power.allows(yard, role_of(id)):
		return false
	if yard.style == SMBuildYard.Style.SCAFFOLD:
		return not yard.scaffold_active and yard.can_build(id)
	if yard.style == SMBuildYard.Style.INTERNAL:
		return not (yard.queue.has(id) or yard.ready.has(id) or yard.placed.has(id)) and not yard.placed.is_empty()
	return yard.unpacked

## Where the build radius for `id` is measured from.
func placement_center(id: StringName) -> Vector3:
	if yard.style == SMBuildYard.Style.MOBILE and yard.unpacked and id != &"packer":
		return yard.packer_pos
	return yard.center

## Why `id` cannot stand at `pos` facing `yaw`, or "" when it can.
func placement_reason(id: StringName, pos: Vector3, yaw: float) -> String:
	if pos == Vector3.INF:
		return "no ground under the cursor"
	if id == yard_id() and yard.finished.has(id) or id == &"packer":
		return _redeploy_reason(id, pos, yaw)
	plan.radius = yard.radius
	plan.center = placement_center(id)
	var why: String = plan.check_at(id, role_of(id), pos, yaw, floats(id))
	if why == "" and _enemy_on(plan.rect_at(snap_spot(id, pos, yaw), footprint_at(id, yaw))):
		return "an enemy unit is in the way"
	return why

## Streets from the map's plan, or from the mission dressing when the map has no skirmish plan.
func keep_streets_of(map_id: String) -> void:
	var source: SMMapPlan = SMMapPlan.of(map_id) if SMMapPlan.exists(map_id) else SMMapPlan.dressing(map_id)
	plan.streets = source.paved if source != null else {}

func _enemy_on(rect: Rect2i) -> bool:
	var field: SMPointer = host.get("field") as SMPointer if host != null else null
	if field == null or plan.grid == null:
		return false
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.is_alive() and u.team != SMPointer.PLAYER and rect.has_point(plan.grid.cell_at(u.global_position)):
			return true
	return false

## Grid-aligned centre `id` would take at `pos` facing `yaw`.
func snap_spot(id: StringName, pos: Vector3, yaw: float) -> Vector3:
	if pos == Vector3.INF or plan.grid == null:
		return pos
	return plan.rect_center(plan.rect_at(pos, footprint_at(id, yaw)))

## Footprint in cells once turned by `yaw`.
func footprint_at(id: StringName, yaw: float) -> Vector2i:
	return SMBasePlan.turned(SMBasePlan.size_of(str(id), role_of(id)), yaw)

## Raises `id` at the player's chosen spot, its exit bay facing `yaw` (degrees).
func place_building(id: StringName, pos: Vector3, yaw: float) -> String:
	var why: String = placement_reason(id, pos, yaw)
	if why != "":
		_say(why)
		return why
	if id == yard_id() and yard.finished.has(id) or id == &"packer":
		return redeploy_yard(pos, yaw)
	var role: String = role_of(id)
	if not Power.allows(yard, role):
		_say("low power")
		return "low power"
	var spot: Vector3 = snap_spot(id, pos, yaw)
	plan.claim(id, plan.rect_at(spot, footprint_at(id, yaw)), yaw)
	var out: String = ""
	if yard.style == SMBuildYard.Style.SCAFFOLD:
		out = _order_scaffold(id, spot)
	elif yard.style == SMBuildYard.Style.INTERNAL:
		out = _order_internal(id, spot)
	else:
		out = _order_mobile(id, spot)
	if not ["built", "placed", "unpacked"].has(out):
		plan.release(id)
	return out

## Packs the construction yard and redeploys it at `pos` facing `yaw`. Other buildings stay.
func redeploy_yard(pos: Vector3, yaw: float) -> String:
	var id: StringName = yard_id()
	var why: String = _redeploy_reason(id, pos, yaw)
	if why != "":
		_say(why)
		return why
	var spot: Vector3 = snap_spot(id, pos, yaw)
	if id == &"packer":
		if not yard.move_packer(spot):
			_say("packer stayed packed")
			return "packer stayed packed"
		plan.release(&"packer")
		plan.claim(&"packer", plan.rect_at(spot, footprint_at(id, yaw)), yaw)
		yard.center = spot
		_face(&"packer", packer_mesh, yaw)
		if packer_mesh != null:
			packer_mesh.position = SMPointer.building_at(spot)
		_say("packer redeployed")
		return "redeployed"
	plan.release(id)
	plan.claim(id, plan.rect_at(spot, footprint_at(id, yaw)), yaw)
	yard.center = spot
	yard.structure_pos[id] = spot
	var node: Node3D = node_of(id)
	if node == null and host != null:
		node = host.get_node_or_null("Built_%s" % str(id)) as Node3D
	if node == null and yard.style == SMBuildYard.Style.INTERNAL:
		node = hub_mesh
	if node != null:
		node.position = SMPointer.building_at(spot)
	_face(id, node, yaw)
	_say("%s redeployed" % building_label(id))
	return "redeployed"

func can_redeploy() -> bool:
	if yard.style == SMBuildYard.Style.MOBILE:
		return not yard.unpacked and yard.grid != null
	var id: StringName = yard_id()
	return id != &"" and yard.finished.has(id) and yard.structure_alive(id)

func _redeploy_reason(id: StringName, pos: Vector3, yaw: float) -> String:
	if not can_redeploy():
		return "the yard cannot pack up"
	if plan.grid == null:
		return ""
	plan.center = yard.center
	plan.radius = yard.radius * 2.0
	var why: String = plan.check_at(id, "yard", pos, yaw, false)
	plan.radius = yard.radius
	if why == "outside the build radius":
		return "too far for the yard to drive"
	return why

func front_of(id: StringName) -> float:
	return float(building_yaw.get(id, plan.yaw_of(id)))

## Half the depth of `id` along its front, in metres.
func half_depth(id: StringName) -> float:
	return float(SMBasePlan.size_of(str(id), role_of(id)).y) * SMBasePlan.cell_m() * 0.5

## Recessed spawn point just inside the front bay of `id`.
func bay_point(id: StringName) -> Vector3:
	var at: Vector3 = yard.position_of(id)
	return at + SMBasePlan.front_dir(front_of(id)) * maxf(half_depth(id) - SMBasePlan.cell_m() * 0.7, 0.6)

## Exit pad on the street (or water) in front of `id`.
func exit_point(id: StringName) -> Vector3:
	var at: Vector3 = yard.position_of(id)
	return at + SMBasePlan.front_dir(front_of(id)) * (half_depth(id) + SMBasePlan.cell_m() * 0.9)

## Production building that rolls out a unit of `category` (infantry, vehicle, boat, aircraft), or &"".
func producer_for(category: String) -> StringName:
	var want: PackedStringArray = PackedStringArray(["factory"])
	if category == "infantry":
		want = PackedStringArray(["barracks"])
	elif category == "boat":
		want = PackedStringArray(["naval"])
	elif category == "aircraft":
		want = PackedStringArray(["air", "factory"])
	for role: String in want:
		for id: StringName in yard.finished:
			if role_of(id) == role and yard.structure_alive(id):
				return id
	return &""

func is_producer(id: StringName) -> bool:
	return ["barracks", "factory", "naval", "air"].has(role_of(id)) and yard.finished.has(id)

## Pins the rally point of production building `id`.
func set_rally_for(id: StringName, at: Vector3) -> bool:
	if not is_producer(id) or at == Vector3.INF:
		return false
	rally_of[id] = at
	return true

func rally_for(id: StringName, fallback: Vector3) -> Vector3:
	return rally_of.get(id, fallback) as Vector3

## Living finished building whose footprint covers `at`, or &"".
func building_at(at: Vector3) -> StringName:
	if at == Vector3.INF:
		return &""
	for id: StringName in yard.finished:
		if not yard.structure_alive(id):
			continue
		var size: Vector2 = Vector2(footprint_at(id, front_of(id))) * SMBasePlan.cell_m()
		var c: Vector3 = yard.position_of(id)
		if absf(at.x - c.x) <= size.x * 0.5 and absf(at.z - c.z) <= size.y * 0.5:
			return id
	return &""

## This side's node for building `id`, or null.
func node_of(id: StringName) -> Node3D:
	var raw: Variant = building_nodes.get(id, null)
	if raw == null or not is_instance_valid(raw):
		return null
	return raw as Node3D

func _face(id: StringName, node: Node3D, yaw: float) -> void:
	building_yaw[id] = fposmod(yaw, 360.0)
	if node == null:
		return
	building_nodes[id] = node
	node.rotation_degrees.y = SMMapPlan.turn_for(str(id), building_yaw[id])
	node.set_meta("front_yaw", building_yaw[id])
	node.set_meta("building_id", str(id))

func move_packer() -> bool:
	if faction_id != "nmrf":
		return false
	var dest: Vector3 = yard.packer_pos + Vector3(8.0, 0.0, 0.0)
	var ok: bool = yard.move_packer(dest)
	if ok and packer_mesh != null:
		packer_mesh.position = SMPointer.building_at(dest)
	_say("packer sailed" if ok else "packer stayed packed")
	return ok

func unpack_core() -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.unpack(&"gun_wharf")
	_say("wharf unpacked" if ok else "already unpacked")
	return ok

func upgrade_wharf() -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.upgrade_factory(&"gun_wharf")
	_say("wharf level %d" % yard.factory_level(&"gun_wharf") if ok else "wharf not ready")
	return ok

func queue_hub() -> bool:
	if faction_id != "mvd":
		return false
	var ok: bool = yard.queue_internal(&"command_hub")
	if ok:
		yard.advance(5.0)
	_say("hub ready to place" if ok and yard.ready.has(&"command_hub") else "hub not queued")
	return ok and yard.ready.has(&"command_hub")

func cancel_order() -> String:
	var was_scaffold: bool = yard.scaffold_active
	yard.abort_scaffold()
	if was_scaffold or yard.cancel_internal() != &"":
		_say("cancelled")
		return "cancelled"
	_say("nothing to cancel")
	return "nothing to cancel"

func buy_clearance() -> bool:
	if faction_id != "mvd":
		return false
	var level: int = yard.clearance + 1
	var ok: bool = yard.buy_clearance(level, 200)
	_say("clearance %d" % yard.clearance if ok else "clearance refused")
	return ok

func place_hub() -> bool:
	if faction_id != "mvd":
		return false
	var pos: Vector3 = plot_of(&"command_hub", yard.center)
	var ok: bool = yard.place_finished(&"command_hub", pos)
	if ok and hub_mesh != null:
		hub_mesh.position = SMPointer.building_at(pos)
		hub_mesh.set_meta("hub_placed", true)
		if not bool(hub_mesh.get_meta("standin_held", false)):
			hub_mesh.visible = true
	_say("hub placed" if ok else "hub not ready")
	return ok

func _order_scaffold(id: StringName, at: Vector3 = Vector3.INF) -> String:
	var pos: Vector3 = at if at != Vector3.INF else plot_of(id, yard.center)
	if pos == Vector3.INF:
		_say("no open water in reach")
		return "no open water in reach"
	if not yard.inside_for(id, pos):
		if floats(id):
			_say("no open water in reach")
			return "no open water in reach"
		pos = yard.center
	var hp: float = float(building_hp.get(id, 200.0))
	if not yard.begin_scaffold(id, pos, hp):
		_say("build blocked")
		return "build blocked"
	yard.advance(float(yard.building_time.get(id, 4.0)))
	if not yard.finished.has(id):
		_say("scaffold stalled")
		return "scaffold stalled"
	var node: MeshInstance3D = _slab("Built_%s" % str(id), SMPointer.building_at(pos), SMPointer.BUILDING_SIZE, SMFront.primary())
	_face(id, node, plan.yaw_of(id))
	_say("%s built" % building_label(id))
	return "built"

func _order_internal(id: StringName, at: Vector3 = Vector3.INF) -> String:
	var pos: Vector3 = at if at != Vector3.INF else plot_of(id, yard.center)
	if pos == Vector3.INF:
		_say("no open water in reach")
		return "no open water in reach"
	if not yard.queue_internal(id):
		var tier: int = int(yard.building_tier.get(id, 1))
		if tier > yard.clearance and buy_clearance() and yard.queue_internal(id):
			pass
		else:
			_say("hub not queued")
			return "hub not queued"
	yard.advance(float(yard.building_time.get(id, 4.0)) + 0.1)
	if not yard.ready.has(id):
		_say("hub not queued")
		return "hub not queued"
	if not yard.place_finished(id, pos):
		if floats(id):
			_say("no open water in reach")
			return "no open water in reach"
		pos = yard.center
		if not yard.place_finished(id, pos):
			_say("hub not ready")
			return "hub not ready"
	if hub_mesh != null and yard.placed.size() == 1:
		hub_mesh.position = SMPointer.building_at(pos)
		hub_mesh.set_meta("hub_placed", true)
		if not bool(hub_mesh.get_meta("standin_held", false)):
			hub_mesh.visible = true
		_face(id, hub_mesh, plan.yaw_of(id))
	else:
		var node: MeshInstance3D = _slab("Built_%s" % str(id), SMPointer.building_at(pos), SMPointer.BUILDING_SIZE, SMFront.accent())
		_face(id, node, plan.yaw_of(id))
	_say("hub placed")
	return "placed"

func _order_mobile(id: StringName, at: Vector3 = Vector3.INF) -> String:
	if str(id) == "packer":
		return "packer sailed" if move_packer() else "packer stayed packed"
	if yard.unpacked and yard.finished.has(id):
		var raised: bool = upgrade_factory_named(id)
		return "upgraded" if raised else "wharf not ready"
	if yard.unpacked:
		if yard.finished.has(id) or not yard.building_time.has(id):
			_say("packer already unpacked")
			return "packer already unpacked"
		var spot: Vector3 = at if at != Vector3.INF else plot_of(id, yard.packer_pos)
		if spot == Vector3.INF:
			_say("no open water in reach")
			return "no open water in reach"
		if yard.place_annex(id):
			yard.structure_pos[id] = spot
			var node: MeshInstance3D = _slab("Built_%s" % str(id), SMPointer.building_at(spot), SMPointer.BUILDING_SIZE, SMFront.accent())
			_face(id, node, plan.yaw_of(id))
			_say("%s built" % building_label(id))
			return "built"
		_say("packer already unpacked")
		return "packer already unpacked"
	move_packer()
	plan.release(&"packer")
	plot_of(&"packer", yard.packer_pos)
	var ok: bool = yard.unpack(id)
	if ok:
		var core: MeshInstance3D = _slab("Built_%s" % str(id), SMPointer.building_at(yard.packer_pos), SMPointer.BUILDING_SIZE, SMFront.accent())
		_face(id, core, plan.yaw_of(&"packer"))
	_say("wharf unpacked" if ok else "already unpacked")
	return "unpacked" if ok else "already unpacked"

func upgrade_factory_named(id: StringName) -> bool:
	if faction_id != "nmrf":
		return false
	var ok: bool = yard.upgrade_factory(id)
	_say("wharf level %d" % yard.factory_level(id) if ok else "wharf not ready")
	return ok

func building_label(id: StringName) -> String:
	if building_names.has(id):
		return building_names[id]
	return str(id)

func fire_super(field: SMPointer) -> int:
	if field == null or yard.super_damage <= 0.0 or yard.super_left > 0.0:
		_say("superweapon cooling")
		return 0
	var foes: Array[RTSUnit] = field.units_of(SMPointer.ENEMY)
	if foes.is_empty():
		_say("no target")
		return 0
	var aim: Vector3 = foes[0].global_position
	var n: int = 0
	for u: RTSUnit in foes:
		if is_instance_valid(u) and u.is_alive() and u.global_position.distance_to(aim) <= yard.super_radius:
			u.take_damage(yard.super_damage)
			n += 1
	if n <= 0:
		return 0
	yard.super_left = yard.super_cooldown
	var size: Vector3 = Vector3(2.2, 7.4, 2.2)
	_slab("Super_%s" % str(yard.super_id), aim + Vector3(0.0, size.y * 0.5, 0.0), size, Color(0.92, 0.32, 0.12))
	_say(yard.super_name)
	super_launched.emit()
	return n

func _load_order(data: Dictionary) -> void:
	if not yard.tech_order.is_empty():
		return
	var raw: Variant = data.get("tech_order", [])
	if not (raw is Array):
		return
	for step: Variant in raw:
		yard.tech_order.append(StringName(str(step)))

func _load_buildings(data: Dictionary) -> void:
	yard.load_catalog(data)
	var raw: Variant = data.get("buildings", [])
	if not (raw is Array):
		return
	for item: Variant in raw:
		if item is Dictionary:
			var row: Dictionary = item
			var id: StringName = StringName(str(row.get("id", "")))
			building_hp[id] = float(row.get("hp", 200.0))
			var label: String = str(row.get("display_name", ""))
			building_names[id] = label if label != "" else str(id)

func _say(text: String) -> void:
	if status != null:
		status.text = text
	line_voiced.emit(text)

func toggle_repair() -> void:
	repair_armed = not repair_armed
	if repair_armed:
		sell_armed = false
	elif yard != null:
		yard.stop_repair()

func toggle_sell() -> void:
	sell_armed = not sell_armed
	if sell_armed:
		repair_armed = false
		if yard != null:
			yard.stop_repair()

func sell_structure(id: StringName) -> int:
	if yard == null:
		return 0
	SMGuns.unload(self, id)
	var refund: int = yard.sell(id)
	if refund > 0:
		plan.release(id)
		rally_of.erase(id)
		building_yaw.erase(id)
	if refund > 0 and host != null:
		var built: Node = node_of(id)
		building_nodes.erase(id)
		if built == null:
			built = host.get_node_or_null("Built_%s" % str(id))
		if built != null:
			built.queue_free()
	return refund

func tick_modes(delta: float) -> void:
	if repair_armed and yard != null:
		yard.tick_repair(delta)

func _slab(node_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if host == null:
		return null
	slab_made.emit(host, node_name, pos, size, color)
	return host.get_node_or_null(node_name) as MeshInstance3D
