class_name SMBuildYard
extends RefCounted
## Three construction styles. State only; the scene supplies the meshes.
## SCAFFOLD drains credits while the frame is vulnerable and unlocks the next
## building in a line. INTERNAL builds inside the hub, then places the finished
## shell inside the radius. MOBILE is an amphibious packer that unpacks.

signal super_ready
signal super_fired

enum Style { SCAFFOLD, INTERNAL, MOBILE }

var style: int = Style.SCAFFOLD
var team: int = 0
var economy: RTSEconomy
var center: Vector3 = Vector3.ZERO
var radius: float = 12.0
var clearance: int = 1
var drain_per_sec: int = 5
var tech_order: Array[StringName] = []
var building_tier: Dictionary[StringName, int] = {}
var building_time: Dictionary[StringName, float] = {}
var building_cost: Dictionary[StringName, int] = {}
var building_role: Dictionary[StringName, String] = {}
var building_optional: Dictionary[StringName, bool] = {}
var finished: Array[StringName] = []
var scaffold_id: StringName = &""
var scaffold_pos: Vector3 = Vector3.ZERO
var scaffold_progress: float = 0.0
var scaffold_time: float = 0.0
var scaffold_hp: float = 0.0
var scaffold_max_hp: float = 0.0
var scaffold_active: bool = false
var vulnerable: bool = false
var drained: int = 0
var scaffold_spent: int = 0
var queue: Array[StringName] = []
var queue_progress: float = 0.0
var ready: Array[StringName] = []
var placed: Array[StringName] = []
var packer_pos: Vector3 = Vector3.ZERO
var packer_id: int = 1
var unpacked: bool = false
var factory_tier: Dictionary[StringName, int] = {}
var grid: SMDomainGrid
var structure_hp: Dictionary[StringName, float] = {}
var repairing: Dictionary[StringName, bool] = {}
var structure_max: Dictionary[StringName, float] = {}
var structure_pos: Dictionary[StringName, Vector3] = {}
var structure_water: Dictionary[StringName, bool] = {}
var water_marked: Dictionary[StringName, bool] = {}
var super_id: StringName = &""
var super_name: String = ""
var super_damage: float = 0.0
var super_radius: float = 8.0
var super_cooldown: float = 20.0
var super_left: float = 0.0
var super_water: bool = false

func load_catalog(data: Dictionary) -> void:
	tech_order.clear()
	building_optional.clear()
	var order: Variant = data.get("tech_order", [])
	if order is Array:
		for step: Variant in order:
			tech_order.append(StringName(str(step)))
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				var row: Dictionary = item
				var id: StringName = StringName(str(row.get("id", "")))
				building_tier[id] = int(row.get("tier", 1))
				building_time[id] = float(row.get("time", 4.0))
				building_cost[id] = int(row.get("cost", 0))
				building_role[id] = str(row.get("role", ""))
				building_optional[id] = bool(row.get("optional", false))
				structure_max[id] = float(row.get("hp", 200.0))
				if bool(row.get("water", false)):
					water_marked[id] = true
	var weapon: Variant = data.get("superweapon", {})
	if weapon is Dictionary:
		var sw: Dictionary = weapon
		super_id = StringName(str(sw.get("id", "")))
		super_name = str(sw.get("display_name", ""))
		super_damage = float(sw.get("damage", 40.0))
		super_radius = float(sw.get("radius", 8.0))
		super_cooldown = float(sw.get("cooldown", 20.0))
		super_water = bool(sw.get("water", false))

func fire_super(at: Vector3, victims: Array[Dictionary]) -> int:
	if super_left > 0.0 or super_damage <= 0.0:
		return 0
	var hit: int = 0
	for victim: Dictionary in victims:
		var pos: Vector3 = victim.get("pos", Vector3.ZERO)
		if at.distance_to(pos) <= super_radius:
			victim["hp"] = float(victim.get("hp", 0.0)) - super_damage
			hit += 1
	if hit > 0:
		super_left = super_cooldown
		super_fired.emit()
	return hit

func cool_super(delta: float) -> void:
	var before: float = super_left
	super_left = maxf(0.0, super_left - delta)
	if before > 0.0 and super_left <= 0.0 and super_damage > 0.0:
		super_ready.emit()

func place_annex(id: StringName) -> bool:
	if style != Style.MOBILE or not unpacked or finished.has(id) or not building_time.has(id):
		return false
	finished.append(id)
	structure_pos[id] = packer_pos
	structure_hp[id] = _max_hp(id)
	_note_water(id)
	_mark_super(id)
	return true

func begin_repair(id: StringName) -> bool:
	if not finished.has(id):
		return false
	var hp: float = float(structure_hp.get(id, 0.0))
	if hp >= _max_hp(id) - 0.5:
		return false
	repairing[id] = true
	return true

func stop_repair() -> void:
	repairing.clear()

func tick_repair(delta: float) -> void:
	if delta <= 0.0 or repairing.is_empty():
		return
	var done: Array[StringName] = []
	for id: StringName in repairing.keys():
		if not finished.has(id):
			done.append(id)
			continue
		var hp: float = float(structure_hp.get(id, 0.0))
		var cap: float = _max_hp(id)
		if hp >= cap - 0.01:
			done.append(id)
			continue
		var heal: float = minf(25.0 * delta, cap - hp)
		var price: int = int(ceil(heal * 0.5))
		if price < 1:
			price = 1
		if economy == null or not economy.try_spend(team, price):
			continue
		structure_hp[id] = hp + heal
	for id: StringName in done:
		repairing.erase(id)

func sell(id: StringName) -> int:
	if not finished.has(id):
		return 0
	if scaffold_active and scaffold_id == id:
		return 0
	var refund: int = int(round(float(building_cost.get(id, 0)) * 0.5))
	finished.erase(id)
	structure_hp.erase(id)
	structure_pos.erase(id)
	repairing.erase(id)
	if economy != null and refund > 0:
		economy.earn(team, refund)
	return refund

func inside(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).distance_to(Vector2(center.x, center.z)) <= radius

func can_build(id: StringName) -> bool:
	if finished.has(id) or scaffold_id == id or queue.has(id) or ready.has(id) or placed.has(id):
		return false
	var tier: int = int(building_tier.get(id, 1))
	if style == Style.INTERNAL and tier > clearance:
		return false
	if style == Style.SCAFFOLD:
		var idx: int = tech_order.find(id)
		if idx < 0:
			return bool(building_optional.get(id, false)) and (tech_order.is_empty() or finished.has(tech_order[0]))
		if idx > 0 and not finished.has(tech_order[idx - 1]):
			return false
	return true

func begin_scaffold(id: StringName, pos: Vector3, hp: float) -> bool:
	if style != Style.SCAFFOLD or scaffold_active or not can_build(id) or not inside(pos):
		return false
	scaffold_id = id
	scaffold_pos = pos
	scaffold_time = float(building_time.get(id, 4.0))
	scaffold_progress = 0.0
	scaffold_max_hp = hp
	scaffold_hp = hp
	scaffold_active = true
	scaffold_spent = 0
	vulnerable = true
	return true

func damage_scaffold(amount: float) -> void:
	if not scaffold_active:
		return
	scaffold_hp = maxf(0.0, scaffold_hp - amount)
	if scaffold_hp <= 0.0:
		scaffold_active = false
		vulnerable = false
		scaffold_id = &""
		scaffold_spent = 0

func buy_clearance(level: int, cost: int) -> bool:
	if style != Style.INTERNAL:
		return false
	if level != clearance + 1 or level < 2 or level > 3:
		return false
	if economy == null or not economy.try_spend(team, cost):
		return false
	clearance = level
	if level == 2:
		radius = 45.0
	elif level == 3:
		radius = 65.0
	return true

func queue_internal(id: StringName) -> bool:
	if style != Style.INTERNAL or not can_build(id):
		return false
	queue.append(id)
	return true

func cancel_internal() -> StringName:
	if style != Style.INTERNAL or queue.is_empty():
		return &""
	var i: int = queue.size() - 1
	var id: StringName = queue[i]
	queue.remove_at(i)
	if i == 0:
		queue_progress = 0.0
	return id

func abort_scaffold() -> int:
	if not scaffold_active:
		return 0
	var refund: int = scaffold_spent
	if economy != null and refund > 0:
		economy.earn(team, refund)
	drained = maxi(0, drained - refund)
	scaffold_spent = 0
	scaffold_active = false
	vulnerable = false
	scaffold_id = &""
	return refund

func place_finished(id: StringName, pos: Vector3) -> bool:
	if style != Style.INTERNAL or not ready.has(id) or not inside(pos):
		return false
	ready.erase(id)
	placed.append(id)
	finished.append(id)
	structure_pos[id] = pos
	if not structure_hp.has(id):
		structure_hp[id] = _max_hp(id)
	_note_water(id)
	_mark_super(id)
	return true

func move_packer(to: Vector3) -> bool:
	if style != Style.MOBILE or unpacked or grid == null:
		return false
	if not grid.move_unit(packer_id, to, SMDomainGrid.Loco.AMPHIBIOUS):
		return false
	packer_pos = to
	return true

func unpack(factory: StringName) -> bool:
	if style != Style.MOBILE or unpacked:
		return false
	unpacked = true
	factory_tier[factory] = 1
	finished.append(factory)
	structure_pos[factory] = packer_pos
	if not structure_hp.has(factory):
		structure_hp[factory] = _max_hp(factory)
	_note_water(factory)
	_mark_super(factory)
	return true

func upgrade_factory(factory: StringName) -> bool:
	if not unpacked or not factory_tier.has(factory):
		return false
	if int(factory_tier[factory]) >= 3:
		return false
	factory_tier[factory] = int(factory_tier[factory]) + 1
	return true

func factory_level(factory: StringName) -> int:
	return int(factory_tier.get(factory, 0))

func advance(delta: float) -> void:
	if style == Style.SCAFFOLD and scaffold_active:
		_advance_scaffold(delta)
	elif style == Style.INTERNAL and not queue.is_empty():
		queue_progress += delta
		var need: float = float(building_time.get(queue[0], 4.0))
		if queue_progress >= need:
			var id: StringName = queue[0]
			queue.remove_at(0)
			queue_progress = 0.0
			ready.append(id)

func _advance_scaffold(delta: float) -> void:
	if economy == null:
		return
	var cost: int = int(roundf(float(drain_per_sec) * delta))
	if cost > 0:
		if not economy.try_spend(team, cost):
			return
		drained += cost
		scaffold_spent += cost
	scaffold_progress += delta
	if scaffold_progress >= scaffold_time and scaffold_time > 0.0:
		var done: StringName = scaffold_id
		finished.append(done)
		structure_pos[done] = scaffold_pos
		structure_hp[done] = maxf(scaffold_hp, 1.0)
		structure_max[done] = maxf(scaffold_max_hp, structure_hp[done])
		_note_water(done)
		_mark_super(done)
		scaffold_id = &""
		scaffold_active = false
		vulnerable = false
		scaffold_spent = 0

func living_count() -> int:
	var total: int = 0
	if scaffold_active and scaffold_hp > 0.0:
		total += 1
	for id: StringName in finished:
		if _stored_hp(id) > 0.0:
			total += 1
	if packer_alive():
		total += 1
	return total

func packer_alive() -> bool:
	if style != Style.MOBILE or unpacked:
		return false
	if not structure_hp.has(&"packer"):
		return true
	return structure_hp[&"packer"] > 0.0

func damage_structure(id: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	if scaffold_active and id == scaffold_id:
		damage_scaffold(amount)
		return
	if id == &"packer" and style == Style.MOBILE and not unpacked:
		if not structure_hp.has(&"packer"):
			structure_hp[&"packer"] = _max_hp(&"packer")
		structure_hp[&"packer"] = maxf(0.0, structure_hp[&"packer"] - amount)
		return
	if not finished.has(id):
		return
	if not structure_hp.has(id):
		structure_hp[id] = _max_hp(id)
	structure_hp[id] = maxf(0.0, structure_hp[id] - amount)

func nearest_living(from: Vector3) -> StringName:
	var best: StringName = &""
	var best_d: float = INF
	if scaffold_active and scaffold_hp > 0.0:
		var scaffold_d: float = from.distance_to(scaffold_pos)
		if scaffold_d < best_d:
			best_d = scaffold_d
			best = scaffold_id
	for id: StringName in finished:
		if _stored_hp(id) <= 0.0:
			continue
		var built_d: float = from.distance_to(position_of(id))
		if built_d < best_d:
			best_d = built_d
			best = id
	if packer_alive():
		var packer_d: float = from.distance_to(packer_pos)
		if packer_d < best_d:
			best = &"packer"
	return best

func structure_alive(id: StringName) -> bool:
	if id == &"packer":
		return packer_alive()
	if scaffold_active and id == scaffold_id and scaffold_hp > 0.0:
		return true
	if finished.has(id):
		return _stored_hp(id) > 0.0
	return false

func position_of(id: StringName) -> Vector3:
	if scaffold_active and id == scaffold_id:
		return scaffold_pos
	if id == &"packer":
		return packer_pos
	if structure_pos.has(id):
		return structure_pos[id]
	return center

## Half the narrow side of the footprint, so attackers stop at the wall rather than the centre.
func reach_of(id: StringName) -> float:
	var role: String = str(building_role.get(id, ""))
	if id == &"enemy_yard" or id == &"packer" or role == "yard":
		role = "yard"
	var size: Vector2 = SMBasePlan.footprint_m(str(id), role)
	return minf(size.x, size.y) * 0.5

func _stored_hp(id: StringName) -> float:
	if structure_hp.has(id):
		return structure_hp[id]
	return 1.0

func _note_water(id: StringName) -> void:
	if bool(water_marked.get(id, false)):
		structure_water[id] = true

func _mark_super(id: StringName) -> void:
	if id == &"" or id != super_id or super_damage <= 0.0:
		return
	if super_left <= 0.0:
		super_ready.emit()

func _max_hp(id: StringName) -> float:
	if structure_max.has(id):
		return maxf(structure_max[id], 1.0)
	if id == &"packer":
		return 400.0
	return 200.0
