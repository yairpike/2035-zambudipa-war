class_name SMGuns
extends RefCounted
## Defense buildings fire while the base has power.
## A pillbox holds five infantry and shoots their rifles.
## A multigunner holds one infantry and fires that weapon.

const Power = preload("res://addons/rts_advanced/sm_power.gd")

const PILLBOX: StringName = &"slag_pillbox"
const MULTI: StringName = &"multigunner"
const FLAK: StringName = &"flak_slag_mast"
const WAVE: StringName = &"wave_force"
const DEFENDER: StringName = &"defender_vx"
const PRISM: StringName = &"spectrum_prism"
const REACH: float = 3.2
const INTERVAL: float = 1.1
const PILLBOX_CAP: int = 5
const MULTI_BASE: float = 9.0
const FLAK_DAMAGE: float = 14.0
const WAVE_DAMAGE: float = 16.0
const DEFENDER_DAMAGE: float = 12.0
const PRISM_DAMAGE: float = 9.0
const GROUND_RANGE: float = 11.0
const AA_RANGE: float = 14.0

static func capacity(id: StringName) -> int:
	if id == PILLBOX:
		return PILLBOX_CAP
	if id == MULTI:
		return 1
	return 0

static func holds(id: StringName) -> bool:
	return capacity(id) > 0

static func try_enter(side: SMSide, field: SMPointer, ground: Vector3) -> int:
	if side == null or field == null or side.yard == null or ground == Vector3.INF:
		return 0
	var id: StringName = _nearest_hold(side, ground)
	if id == &"":
		return 0
	var room: int = capacity(id) - _living(side, id).size()
	if room <= 0:
		side._say("pillbox full" if id == PILLBOX else "multigunner full")
		return 0
	var taken: int = 0
	var picked: Array[RTSUnit] = field.selection.units.duplicate()
	for u: RTSUnit in picked:
		if taken >= room:
			break
		if not _infantry(u) or u.team != side.yard.team or bool(u.get_meta("garrisoned", false)):
			continue
		_house(side, field, id, u)
		taken += 1
	if taken > 0:
		side._say("garrison %d" % taken)
	return taken

static func unload(side: SMSide, id: StringName) -> int:
	if side == null or side.yard == null:
		return 0
	var housed: Array[RTSUnit] = _living(side, id)
	if housed.is_empty():
		return 0
	var origin: Vector3 = side.yard.position_of(id)
	var i: int = 0
	for u: RTSUnit in housed:
		u.visible = true
		u.set_meta("garrisoned", false)
		u.remove_meta("garrison_id")
		u.position = origin + Vector3(1.4 * float(i), 0.0, 1.6)
		side.gun_units.erase(u.get_instance_id())
		i += 1
	side.occupants.erase(id)
	side._say("unloaded %d" % housed.size())
	return housed.size()

static func tick(side: SMSide, field: SMPointer, delta: float) -> void:
	if side == null or field == null or side.yard == null:
		return
	var powered: bool = Power.online(side.yard)
	for id: StringName in side.yard.finished:
		if not _is_gun(id):
			continue
		var left: float = float(side.gun_cool.get(id, 0.0)) - delta
		if left > 0.0:
			side.gun_cool[id] = left
			continue
		if not powered:
			side.gun_cool[id] = 0.0
			continue
		var shots: int = _fire(side, field, id)
		if shots > 0:
			side.gun_cool[id] = INTERVAL
			side.defense_fired.emit(id, side.yard.position_of(id))

static func _fire(side: SMSide, field: SMPointer, id: StringName) -> int:
	var at: Vector3 = side.yard.position_of(id)
	if id == PILLBOX:
		var rifles: Array[RTSUnit] = _living(side, id)
		if rifles.is_empty():
			return 0
		var damage: float = 0.0
		for u: RTSUnit in rifles:
			damage += u.attack_damage
		return _hit_one(field, at, side.yard.team, false, GROUND_RANGE, damage)
	if id == MULTI:
		var crew: Array[RTSUnit] = _living(side, id)
		var damage: float = MULTI_BASE
		if not crew.is_empty():
			damage = crew[0].attack_damage
		return _hit_one(field, at, side.yard.team, false, GROUND_RANGE, damage)
	if id == FLAK:
		return _hit_one(field, at, side.yard.team, true, AA_RANGE, FLAK_DAMAGE)
	if id == WAVE:
		return _hit_one(field, at, side.yard.team, false, GROUND_RANGE, WAVE_DAMAGE)
	if id == DEFENDER:
		var air: bool = side.defender_air
		var reach: float = AA_RANGE if air else GROUND_RANGE
		return _hit_one(field, at, side.yard.team, air, reach, DEFENDER_DAMAGE)
	if id == PRISM:
		return _hit_chain(field, at, side.yard.team, GROUND_RANGE, PRISM_DAMAGE, 3)
	return 0

static func _hit_one(field: SMPointer, at: Vector3, team: int, air: bool, reach: float, damage: float) -> int:
	var foe: RTSUnit = _nearest(field, at, team, air, reach)
	if foe == null or damage <= 0.0:
		return 0
	foe.take_damage(damage)
	return 1

static func _hit_chain(field: SMPointer, at: Vector3, team: int, reach: float, damage: float, limit: int) -> int:
	var hits: Array[RTSUnit] = _within(field, at, team, false, reach)
	var n: int = 0
	for foe: RTSUnit in hits:
		if n >= limit:
			break
		foe.take_damage(damage)
		n += 1
	return n

static func _nearest(field: SMPointer, at: Vector3, team: int, air: bool, reach: float) -> RTSUnit:
	var hits: Array[RTSUnit] = _within(field, at, team, air, reach)
	if hits.is_empty():
		return null
	return hits[0]

static func _within(field: SMPointer, at: Vector3, team: int, air: bool, reach: float) -> Array[RTSUnit]:
	var found: Array[RTSUnit] = []
	var best: Array[float] = []
	for u: RTSUnit in field.units:
		if not _target(field, u, team, air):
			continue
		var d: float = Vector2(at.x, at.z).distance_to(Vector2(u.global_position.x, u.global_position.z))
		if d > reach:
			continue
		var placed: int = found.size()
		var i: int = 0
		while i < best.size():
			if d < best[i]:
				placed = i
				break
			i += 1
		found.insert(placed, u)
		best.insert(placed, d)
	return found

static func _target(field: SMPointer, u: RTSUnit, team: int, air: bool) -> bool:
	if not is_instance_valid(u) or not u.is_alive() or bool(u.get_meta("garrisoned", false)):
		return false
	if not field.teams.are_enemies(team, u.team):
		return false
	var flying: bool = str(u.get_meta("locomotion", "ground")) == "air"
	return flying == air

static func _is_gun(id: StringName) -> bool:
	return id == PILLBOX or id == MULTI or id == FLAK or id == WAVE or id == DEFENDER or id == PRISM

static func _nearest_hold(side: SMSide, ground: Vector3) -> StringName:
	var best: StringName = &""
	var best_d: float = REACH
	for id: StringName in side.yard.finished:
		if capacity(id) <= 0:
			continue
		var at: Vector3 = side.yard.position_of(id)
		var d: float = Vector2(ground.x, ground.z).distance_to(Vector2(at.x, at.z))
		if d <= best_d:
			best_d = d
			best = id
	return best

static func _living(side: SMSide, id: StringName) -> Array[RTSUnit]:
	var housed: Array[RTSUnit] = []
	var raw: Variant = side.occupants.get(id, [])
	var keep: Array[int] = []
	if raw is Array:
		for item: Variant in raw:
			var key: int = int(item)
			var u: RTSUnit = side.gun_units.get(key, null) as RTSUnit
			if is_instance_valid(u) and u.is_alive() and bool(u.get_meta("garrisoned", false)):
				housed.append(u)
				keep.append(key)
			else:
				side.gun_units.erase(key)
	side.occupants[id] = keep
	return housed

static func _house(side: SMSide, field: SMPointer, id: StringName, u: RTSUnit) -> void:
	u.stop()
	u.selected = false
	u.visible = false
	u.set_meta("garrisoned", true)
	u.set_meta("garrison_id", str(id))
	u.position = side.yard.position_of(id)
	var key: int = u.get_instance_id()
	side.gun_units[key] = u
	var raw: Variant = side.occupants.get(id, [])
	var keep: Array[int] = []
	if raw is Array:
		for item: Variant in raw:
			keep.append(int(item))
	keep.append(key)
	side.occupants[id] = keep
	field.selection.units.erase(u)

static func _infantry(u: RTSUnit) -> bool:
	return is_instance_valid(u) and u.is_alive() and str(u.get_meta("role", "")) == "infantry"
