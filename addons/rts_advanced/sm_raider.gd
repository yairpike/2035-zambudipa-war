class_name SMRaider
extends RefCounted
## The skirmish enemy builds a base, trains from income, and sends larger waves.
## A wiped squad does not raze the base. Destroyed production is not rebuilt.

signal marker_made(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color)
signal banner_made(parent: Node3D, node_name: String, text: String, size: int, pixel: float, at: Vector3)

const Power = preload("res://addons/rts_advanced/sm_power.gd")
const ALIVE_CAP: int = 18
const THREAT_M: float = 14.0
const BASE_PURSE: int = 3000
const BASE_WAVE_AT: Array[float] = [0.0, 150.0, 270.0, 390.0, 510.0, 660.0]
const BASE_WAVE_N: Array[int] = [1, 2, 2, 3, 4, 18]

var yard: SMBuildYard = SMBuildYard.new()
var goods: SMCommodityNet = SMCommodityNet.new()
var economy: RTSEconomy = RTSEconomy.new()
var field: SMPointer
var built: bool = false
var expanded: bool = false
var attacked: bool = false
var node_id: StringName = &"enemy_ruby"
var personality_name: String = "Bo Mya"
var plan_goods: SMCommodityNet
var plan_tech: SMTechNet
var plan_a: StringName = &""
var plan_b: StringName = &""
var plan_site: StringName = &""
var opened_nodes: int = 0
var took_tech: bool = false
var used_f: bool = false
var brain: SMBot
var _step: float = 0.0
var clock: float = 0.0
var fielded: int = 0
var armed: bool = false
var power_id: StringName = &""
var barracks_id: StringName = &""
var factory_id: StringName = &""
var naval_id: StringName = &""
var air_id: StringName = &""
var tech_id: StringName = &""
var infantry_id: StringName = &""
var factory_unit: StringName = &""
var naval_unit: StringName = &""
var hero_id: StringName = &""
var jet_id: StringName = &""
var sub_id: StringName = &""
var mix: int = 0
var wave_i: int = 0
var raising: StringName = &""
var plan: SMBasePlan
var macro_ids: Array[StringName] = []
var wave_at: Array[float] = [0.0, 150.0, 270.0, 390.0, 510.0, 660.0]
var wave_n: Array[int] = [1, 2, 2, 3, 4, 18]
var queue: RTSProductionQueue
var train_catalog: Dictionary[StringName, Dictionary] = {}
var unit_rows: Dictionary[StringName, Dictionary] = {}
var committed: Dictionary[int, bool] = {}
var wrecked: Dictionary[StringName, bool] = {}
var income_scale: float = 1.0
var react_scale: float = 1.0
var _income_frac: float = 0.0
## A human guest owns this seat. The bot does not build, train, or attack.
var human: bool = false
## The team this bot spends, builds, and trains for. The other side is the foe.
var seat: int = SMPointer.ENEMY
var foe: int = SMPointer.PLAYER
var trained: Dictionary = {}

func attach(p_field: SMPointer, center: Vector3, p_seat: int = SMPointer.ENEMY) -> void:
	field = p_field
	seat = p_seat
	foe = SMPointer.PLAYER if p_seat != SMPointer.PLAYER else SMPointer.ENEMY
	economy = RTSEconomy.new()
	economy.set_credits(seat, 3000)
	yard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.team = seat
	yard.economy = economy
	yard.center = center
	yard.radius = 36.0
	yard.drain_per_sec = 4
	yard.tech_order = [&"enemy_yard"]
	yard.building_time[&"enemy_yard"] = 2.0
	yard.building_tier[&"enemy_yard"] = 1
	goods = SMCommodityNet.new()
	goods.add_node(node_id, SMCommodityNet.KIND_RUBY, center + Vector3(3.0, 0.0, 2.0), 12, false)
	built = false
	expanded = false
	attacked = false
	clock = 0.0
	armed = false
	fielded = 0
	if field != null:
		fielded = field.units_of(seat).size()
	power_id = &""
	barracks_id = &""
	factory_id = &""
	naval_id = &""
	air_id = &""
	tech_id = &""
	infantry_id = &""
	factory_unit = &""
	naval_unit = &""
	hero_id = &""
	jet_id = &""
	sub_id = &""
	mix = 0
	wave_i = 0
	raising = &""
	macro_ids.clear()
	train_catalog.clear()
	unit_rows.clear()
	committed.clear()
	wrecked.clear()
	trained.clear()
	queue = RTSProductionQueue.new(seat, {})
	queue.produced.connect(_on_trained)

func bind_faction(id: String) -> void:
	_ensure_brain()
	if id == "gtfc" or id == "nmrf" or id == "mvd" or id == "black_market":
		brain.faction_id = id

func set_seed(n: int) -> void:
	mix = posmod(n, 10)

func bind_plan(goods_net: SMCommodityNet, tech: SMTechNet, first: StringName, second: StringName, site: StringName, who: String) -> void:
	plan_goods = goods_net
	plan_tech = tech
	plan_a = first
	plan_b = second
	plan_site = site
	personality_name = who
	brain = SMBot.new(SMBot.id_of(who))

func apply_pace(income: float, wave_time: float, wave_size: float, react: float) -> void:
	income_scale = clampf(income, 0.25, 4.0)
	react_scale = clampf(react, 0.25, 3.0)
	var time_scale: float = clampf(wave_time, 0.08, 3.0)
	var size_scale: float = clampf(wave_size, 0.25, 4.0)
	wave_at.clear()
	wave_n.clear()
	for i: int in BASE_WAVE_AT.size():
		wave_at.append(BASE_WAVE_AT[i] * time_scale)
		wave_n.append(maxi(1, int(round(float(BASE_WAVE_N[i]) * size_scale))))
	if economy != null:
		economy.set_credits(seat, int(round(float(BASE_PURSE) * income_scale)))
	if brain != null:
		brain.react_scale = react_scale
	_retune_units()

func tick(delta: float) -> void:
	if human or field == null:
		return
	_step = delta
	clock += delta
	_ensure_brain()
	if brain != null:
		brain.react_scale = react_scale
	_grant_income(delta)
	_arm_macro()
	_build()
	_bury()
	_raise()
	_expand()
	_rebuild()
	_open()
	_train()
	_release()
	_attack()

func show_markers(host: Node3D) -> void:
	if built and host.get_node_or_null("EnemyYard") == null:
		_marker(host, "EnemyYard", SMPointer.building_at(yard.center), SMPointer.BUILDING_SIZE, Color(0.45, 0.16, 0.14))
	var yard_node: Node3D = host.get_node_or_null("EnemyYard") as Node3D
	banner_made.emit(yard_node, "Personality", personality_name, 48, 0.02, Vector3(0, 3.4, 0))
	if expanded and host.get_node_or_null("EnemyClaim") == null:
		var spot: Vector3 = yard.center + Vector3(3.0, 0.5, 2.0)
		_marker(host, "EnemyClaim", spot, Vector3(1.2, 0.8, 1.2), Color(0.7, 0.12, 0.22))
	for id: StringName in macro_ids:
		if not yard.structure_alive(id):
			continue
		var node_name: String = "Built_%s" % str(id)
		if host.get_node_or_null(node_name) != null:
			continue
		_marker(host, node_name, SMPointer.building_at(yard.position_of(id)), SMPointer.BUILDING_SIZE, _pad_color(id))

func _build() -> void:
	if yard.finished.has(&"enemy_yard"):
		built = true
		return
	if not yard.scaffold_active:
		yard.begin_scaffold(&"enemy_yard", yard.center, 220.0)
	yard.advance(2.5)
	built = yard.finished.has(&"enemy_yard")

func _arm_macro() -> void:
	if armed or brain == null:
		return
	armed = true
	var data: Dictionary = SMCatalog.faction(brain.faction_id)
	var need: Array[String] = ["power", "barracks", "factory"]
	if _has_water():
		need.append("naval")
	need.append("air")
	need.append("tech")
	var found: Dictionary = {}
	var raw: Variant = data.get("buildings", [])
	if raw is Array:
		for item: Variant in raw:
			if not (item is Dictionary):
				continue
			var row: Dictionary = item
			var role: String = str(row.get("role", ""))
			if not need.has(role) or found.has(role):
				continue
			found[role] = row
	var tier: int = 2
	for role: String in need:
		if not found.has(role):
			continue
		var row: Dictionary = found[role]
		var id: StringName = StringName(str(row.get("id", "")))
		if id == &"":
			continue
		yard.tech_order.append(id)
		yard.building_tier[id] = tier
		yard.building_time[id] = float(row.get("time", 5.0)) * _tempo()
		yard.building_role[id] = role
		yard.structure_max[id] = float(row.get("hp", 220.0))
		macro_ids.append(id)
		tier += 1
		if role == "power":
			power_id = id
		elif role == "barracks":
			barracks_id = id
		elif role == "factory":
			factory_id = id
		elif role == "naval":
			naval_id = id
		elif role == "air":
			air_id = id
		elif role == "tech":
			tech_id = id
	var best_inf: int = 999999
	var best_fac: int = 999999
	var best_nav: int = 999999
	var best_hero: int = 999999
	var best_jet: int = 999999
	for unit: Dictionary in SMCatalog.units_of(data):
		var uid: StringName = StringName(str(unit.get("id", "")))
		var urole: String = str(unit.get("role", ""))
		var cost: int = int(unit.get("cost", 0))
		if uid == &"" or cost <= 0:
			continue
		unit_rows[uid] = unit
		var spec: Dictionary = {"cost": cost, "time": float(unit.get("time", 3.0)) * _tempo()}
		train_catalog[uid] = spec
		var hero: bool = SMCatalog.has_tag(unit, "hero")
		var jet: bool = SMCatalog.has_tag(unit, "jet")
		var sub: bool = SMCatalog.has_tag(unit, "sub")
		if hero and cost < best_hero:
			best_hero = cost
			hero_id = uid
		if jet and cost < best_jet:
			best_jet = cost
			jet_id = uid
		if sub:
			sub_id = uid
		if hero or jet or sub:
			continue
		if urole == "infantry" and cost < best_inf:
			best_inf = cost
			infantry_id = uid
		if (urole == "armor" or urole == "artillery") and cost < best_fac:
			best_fac = cost
			factory_unit = uid
		if (urole == "boat" or urole == "amphibious") and cost < best_nav:
			best_nav = cost
			naval_unit = uid
	_arm_import(data)
	if queue != null:
		queue.catalog = train_catalog

func _arm_import(data: Dictionary) -> void:
	if str(data.get("build_style", "")) != "none":
		return
	if infantry_id != &"" and barracks_id != &"":
		return
	barracks_id = &"enemy_yard"
	if air_id == &"":
		air_id = &"enemy_yard"
	var best: int = 999999
	var line: StringName = &""
	for key: Variant in unit_rows.keys():
		var uid: StringName = key as StringName
		var unit: Dictionary = unit_rows[uid]
		if SMCatalog.has_tag(unit, "jet") or SMCatalog.has_tag(unit, "hero") or SMCatalog.has_tag(unit, "sub"):
			continue
		var cost: int = int(unit.get("cost", 0))
		if cost < best:
			best = cost
			line = uid
	if line != &"":
		infantry_id = line

func _tempo() -> float:
	if is_equal_approx(income_scale, 1.0):
		return 1.0
	return clampf(1.0 / income_scale, 0.35, 2.4)

func _grant_income(delta: float) -> void:
	if economy == null or is_equal_approx(income_scale, 1.0):
		return
	_income_frac += 28.0 * (income_scale - 1.0) * delta
	if _income_frac >= 1.0:
		var grant: int = int(_income_frac)
		_income_frac -= float(grant)
		economy.earn(seat, grant)
	elif _income_frac <= -1.0:
		var drain: int = int(-_income_frac)
		_income_frac += float(drain)
		economy.try_spend(seat, drain)

func _retune_units() -> void:
	if field == null:
		return
	for u: RTSUnit in field.units_of(seat):
		if is_instance_valid(u):
			_pace_interval(u)

func _pace_interval(u: RTSUnit) -> void:
	if u == null:
		return
	if not u.has_meta(&"base_interval"):
		u.set_meta(&"base_interval", u.attack_interval)
	u.attack_interval = float(u.get_meta(&"base_interval")) * react_scale

func _has_water() -> bool:
	if field == null or field.domain == null:
		return false
	var grid: SMDomainGrid = field.domain
	var y: int = 0
	while y < grid.rows:
		var x: int = 0
		while x < grid.cols:
			var domain: int = grid.domain_at_cell(Vector2i(x, y))
			if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP:
				return true
			x += 1
		y += 1
	return false

func _bury() -> void:
	if raising != &"" and not yard.scaffold_active and not yard.structure_alive(raising):
		wrecked[raising] = true
	raising = &""
	for id: StringName in yard.finished:
		if not yard.structure_alive(id):
			wrecked[id] = true
	if yard.scaffold_active:
		raising = yard.scaffold_id

func _raise() -> void:
	if yard.scaffold_active:
		yard.advance(_step)
		return
	for id: StringName in macro_ids:
		if wrecked.has(id) or yard.finished.has(id) or not yard.can_build(id):
			continue
		var pos: Vector3 = _plot(id)
		var hp: float = float(yard.structure_max.get(id, 220.0))
		if yard.begin_scaffold(id, pos, hp):
			raising = id
			yard.advance(_step)
		return

func _plot(id: StringName) -> Vector3:
	if field == null or field.domain == null:
		var ang: float = float(macro_ids.find(id)) * 0.9
		return yard.center + Vector3(cos(ang) * 6.0, 0.0, sin(ang) * 6.0)
	if plan == null or plan.grid != field.domain:
		plan = SMBasePlan.new(field.domain, yard.center, yard.radius)
		plan.plot(&"enemy_yard", "yard")
		plan.keep_nets(plan_goods, plan_tech)
	plan.center = yard.center
	plan.radius = yard.radius
	var role: String = str(yard.building_role.get(id, ""))
	return plan.plot(id, role, role == "naval" or bool(yard.water_marked.get(id, false)))

func _train() -> void:
	if queue == null or field == null:
		return
	queue.advance(_step)
	if infantry_id == &"" or barracks_id == &"":
		return
	if not yard.structure_alive(barracks_id) or not Power.online(yard):
		return
	if field.units_of(seat).size() >= ALIVE_CAP:
		return
	if not queue.items.is_empty():
		return
	var pick: StringName = _pick_train()
	if pick == &"":
		return
	queue.enqueue(pick, economy)

func _pick_train() -> StringName:
	mix += 1
	if hero_id != &"" and tech_id != &"" and yard.structure_alive(tech_id) and mix % 11 == 0 and _hero_room():
		return hero_id
	if jet_id != &"" and air_id != &"" and yard.structure_alive(air_id) and mix % 7 == 0:
		return jet_id
	if sub_id != &"" and naval_id != &"" and yard.structure_alive(naval_id) and mix % 6 == 0:
		return sub_id
	if factory_unit != &"" and factory_id != &"" and yard.structure_alive(factory_id) and mix % 4 == 0:
		return factory_unit
	if naval_unit != &"" and naval_id != &"" and yard.structure_alive(naval_id) and mix % 5 == 0:
		return naval_unit
	return infantry_id

func _hero_room() -> bool:
	if field == null:
		return false
	for u: RTSUnit in field.units_of(seat):
		if bool(u.get_meta("hero", false)):
			return false
	return true

func _on_trained(kind: StringName, _rally: Vector3) -> void:
	if field == null:
		return
	var spin: float = float(fielded) * 0.7
	var at: Vector3 = yard.center + Vector3(cos(spin) * 10.0, 0.0, sin(spin) * 10.0)
	var u: RTSUnit = field.spawn(seat, at, kind)
	_paint_unit(u, kind)
	fielded += 1
	trained[kind] = int(trained.get(kind, 0)) + 1

func _paint_unit(u: RTSUnit, kind: StringName) -> void:
	if not unit_rows.has(kind):
		return
	var row: Dictionary = unit_rows[kind]
	u.max_hp = float(row.get("hp", u.max_hp))
	u.hp = u.max_hp
	u.speed = float(row.get("speed", u.speed))
	u.attack_damage = float(row.get("weapon_damage", u.attack_damage))
	u.set_meta("weapon", str(row.get("weapon", "")))
	u.set_meta("secondary", str(row.get("secondary", "")))
	u.set_meta("guidance", str(row.get("guidance", "none")))
	u.set_meta("locomotion", str(row.get("locomotion", "ground")))
	u.set_meta("role", str(row.get("role", "")))
	u.set_meta("ability", str(row.get("ability", "")))
	u.set_meta("f_stat", str(row.get("f_stat", "damage")))
	SMCatalog.mark_unit(u, row)
	_pace_interval(u)

func _release() -> void:
	if _player_at_base():
		_commit_all()
		return
	while wave_i < wave_at.size() and clock + 0.001 >= wave_at[wave_i]:
		var count: int = wave_n[wave_i]
		wave_i += 1
		_commit_some(count)

func _player_at_base() -> bool:
	for u: RTSUnit in field.units_of(foe):
		if u.global_position.distance_to(yard.center) <= THREAT_M:
			return true
	return false

func _commit_all() -> void:
	for u: RTSUnit in field.units_of(seat):
		committed[u.get_instance_id()] = true

func _commit_some(count: int) -> void:
	var given: int = 0
	for u: RTSUnit in field.units_of(seat):
		if given >= count:
			return
		var id: int = u.get_instance_id()
		if committed.has(id):
			continue
		committed[id] = true
		given += 1

func _expand() -> void:
	if goods.has_collector(node_id):
		expanded = true
		return
	expanded = goods.snap_refinery(node_id, seat)

func _open() -> void:
	if plan_goods != null and plan_a != &"" and plan_b != &"":
		if not plan_goods.has_collector(plan_a):
			plan_goods.snap_refinery(plan_a, seat)
		if not plan_goods.has_collector(plan_b):
			plan_goods.snap_refinery(plan_b, seat)
		opened_nodes = 0
		if plan_goods.has_collector(plan_a):
			opened_nodes += 1
		if plan_goods.has_collector(plan_b):
			opened_nodes += 1
	if plan_tech != null and plan_site != &"":
		if plan_tech.owner_of(plan_site) < 0:
			took_tech = plan_tech.capture(plan_site, seat)
		elif plan_tech.owner_of(plan_site) == seat:
			took_tech = true
	if used_f or field == null:
		return
	var foes: Array[RTSUnit] = field.units_of(seat)
	if foes.is_empty():
		return
	used_f = field.apply_named_f(foes[0])

func _ensure_brain() -> void:
	if brain == null:
		brain = SMBot.new(SMBot.id_of(personality_name))

func _rebuild() -> void:
	if brain == null or brain.rebuilt > 0:
		return
	if goods.has_collector(node_id):
		brain.restore_node(goods, node_id, seat)

func _attack() -> void:
	var friends: Array[RTSUnit] = []
	for friend: RTSUnit in field.units_of(foe):
		if not bool(friend.get_meta("garrisoned", false)):
			friends.append(friend)
	var foes: Array[RTSUnit] = []
	for u: RTSUnit in field.units_of(seat):
		if not committed.has(u.get_instance_id()):
			continue
		if u.hp <= u.max_hp * 0.3:
			if bool(u.get_meta("falling_back", false)):
				u.set_meta("falling_back", false)
				u.path = PackedVector3Array()
				u.attack_target = null
			continue
		foes.append(u)
	if friends.is_empty() or foes.is_empty() or brain == null:
		return
	brain.direct(foes, friends, field.domain, Callable(self, "_nav_for"), yard.center, field.teams, _step)
	if brain.scouted:
		attacked = true
	if brain.wave_sent and brain.protocols_cast == 0:
		_cast_wave(foes)

func _nav_for(u: RTSUnit) -> RTSGridNav:
	if field == null:
		return null
	return field.nav_for_unit(u)

func _cast_wave(foes: Array[RTSUnit]) -> void:
	var book: SMProtocols = SMProtocols.new()
	var powers: SMAbilities = SMAbilities.new()
	if not brain.cast_arsenal(book, economy, seat, powers):
		return
	var scale: float = book.damage_mult
	for u: RTSUnit in foes:
		if is_instance_valid(u) and not bool(u.get_meta("rocket_pods", false)):
			u.damage_mult *= scale
			u.set_meta("rocket_pods", true)

func _pad_color(id: StringName) -> Color:
	if id == power_id:
		return Color(0.95, 0.82, 0.28)
	if id == barracks_id:
		return Color(0.55, 0.18, 0.16)
	if id == factory_id:
		return Color(0.45, 0.42, 0.38)
	return Color(0.2, 0.38, 0.55)

func _marker(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	marker_made.emit(host, node_name, pos, size, color)
