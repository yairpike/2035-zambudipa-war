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

## Footprint-sized plot for `id`, ringed out from `around`. Falls back to `around` when nothing fits.
func plot_of(id: StringName, around: Vector3) -> Vector3:
	plan.radius = yard.radius
	plan.center = around
	var role: String = str(yard.building_role.get(id, ""))
	return plan.plot(id, role, role == "naval" or bool(yard.water_marked.get(id, false)))

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

func _order_scaffold(id: StringName) -> String:
	var pos: Vector3 = plot_of(id, yard.center)
	if not yard.inside(pos):
		pos = yard.center
	var hp: float = float(building_hp.get(id, 200.0))
	if not yard.begin_scaffold(id, pos, hp):
		_say("build blocked")
		return "build blocked"
	yard.advance(float(yard.building_time.get(id, 4.0)))
	if not yard.finished.has(id):
		_say("scaffold stalled")
		return "scaffold stalled"
	_slab("Built_%s" % str(id), SMPointer.building_at(pos), SMPointer.BUILDING_SIZE, SMFront.primary())
	_say("%s built" % building_label(id))
	return "built"

func _order_internal(id: StringName) -> String:
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
	var pos: Vector3 = plot_of(id, yard.center)
	if not yard.place_finished(id, pos):
		pos = yard.center
		if not yard.place_finished(id, pos):
			_say("hub not ready")
			return "hub not ready"
	if hub_mesh != null and yard.placed.size() == 1:
		hub_mesh.position = SMPointer.building_at(pos)
		hub_mesh.set_meta("hub_placed", true)
		if not bool(hub_mesh.get_meta("standin_held", false)):
			hub_mesh.visible = true
	else:
		_slab("Built_%s" % str(id), SMPointer.building_at(pos), SMPointer.BUILDING_SIZE, SMFront.accent())
	_say("hub placed")
	return "placed"

func _order_mobile(id: StringName) -> String:
	if str(id) == "packer":
		return "packer sailed" if move_packer() else "packer stayed packed"
	if yard.unpacked and yard.finished.has(id):
		var raised: bool = upgrade_factory_named(id)
		return "upgraded" if raised else "wharf not ready"
	if yard.unpacked:
		if yard.place_annex(id):
			var at: Vector3 = plot_of(id, yard.packer_pos)
			yard.structure_pos[id] = at
			_slab("Built_%s" % str(id), SMPointer.building_at(at), SMPointer.BUILDING_SIZE, SMFront.accent())
			_say("%s built" % building_label(id))
			return "built"
		_say("packer already unpacked")
		return "packer already unpacked"
	move_packer()
	plan.release(&"packer")
	plot_of(&"packer", yard.packer_pos)
	var ok: bool = yard.unpack(id)
	if ok:
		_slab("Built_%s" % str(id), SMPointer.building_at(yard.packer_pos), SMPointer.BUILDING_SIZE, SMFront.accent())
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
	if refund > 0 and host != null:
		var built: Node = host.get_node_or_null("Built_%s" % str(id))
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
