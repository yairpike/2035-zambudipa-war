class_name SMBot
extends RefCounted
## Three personalities. Each one scouts, musters a wave, flanks, and
## falls back when a unit drops below 30% health.

const Power = preload("res://addons/rts_advanced/sm_power.gd")

var personality: StringName = &"bo_mya"
var faction_id: String = "mvd"
var refinery_target: int = 2
var wants_water: bool = true
var wants_gem: bool = true
var tech_kind: StringName = &"arms_bazaar"
var ability: StringName = &"smart_cast"
var scouted: bool = false
var wave_sent: bool = false
var scout_before_wave: bool = false
var flank_used: bool = false
var water_route: bool = false
var retreated: int = 0
var rebuilt: int = 0
var protocols_cast: int = 0
var abilities_used: int = 0
var power_held: bool = false
var refused_power: bool = false
var muster_ready: bool = false
var muster_at: Vector3 = Vector3.ZERO
var home_point: Vector3 = Vector3.ZERO
var home_set: bool = false
var clock: float = 0.0
var react_scale: float = 1.0
var _react_hold: float = 0.0
var rocket_mult: float = 1.0
var last_note: String = ""
var _navs: Dictionary[String, RTSGridNav] = {}

func _init(p: StringName = &"bo_mya") -> void:
	personality = p
	if p == &"iskandar":
		faction_id = "nmrf"
		tech_kind = &"hydro_radar"
		ability = &"smart_cast"
	elif p == &"tran":
		faction_id = "gtfc"
		tech_kind = &"field_clinic"
		ability = &"channeled_beam"
	else:
		personality = &"bo_mya"
		faction_id = "mvd"
		tech_kind = &"arms_bazaar"
		ability = &"smart_cast"

static func personalities() -> Array[StringName]:
	return [&"bo_mya", &"iskandar", &"tran"]

static func id_of(who: String) -> StringName:
	var lower: String = who.to_lower()
	if lower.find("iskandar") >= 0:
		return &"iskandar"
	if lower.find("tran") >= 0:
		return &"tran"
	return &"bo_mya"

func direct(units: Array[RTSUnit], foes: Array[RTSUnit], grid: SMDomainGrid, nav_for: Callable, home: Vector3, teams: RTSTeams, delta: float) -> void:
	clock += delta
	if not home_set:
		home_point = home
		home_set = true
	_pull_home(units, grid, nav_for, home)
	var ready: Array[RTSUnit] = _fighting(units)
	var live: Array[RTSUnit] = _alive(foes)
	if ready.is_empty() or live.is_empty() or teams == null:
		return
	if not scouted:
		_open_with_scout(ready, live, grid, nav_for, home, teams)
		return
	if not wave_sent:
		if clock < 2.5 * react_scale and not _huddled(ready):
			return
		_send_wave(ready, live, grid, nav_for, teams)
		wave_sent = true
		scout_before_wave = true
		return
	if react_scale > 1.01:
		_react_hold -= delta
		if _react_hold > 0.0:
			return
		_react_hold = 0.4 * (react_scale - 1.0)
	_press_wave(ready, live, grid, nav_for, teams)

func restore_node(goods: SMCommodityNet, id: StringName, team: int) -> bool:
	if goods == null or not goods.has_collector(id):
		return false
	if not goods.release_collector(id):
		return false
	if not goods.snap_refinery(id, team):
		return false
	rebuilt += 1
	return true

func honor_power(yard: SMBuildYard) -> bool:
	if yard == null:
		return false
	if not Power.allows(yard, "barracks"):
		refused_power = true
		return false
	if refused_power:
		power_held = true
	return power_held

func cast_arsenal(book: SMProtocols, economy: RTSEconomy, team: int, powers: SMAbilities) -> bool:
	if book == null or economy == null:
		return false
	if not book.cast(&"arsenal", economy, team, powers, -1):
		return false
	protocols_cast += 1
	rocket_mult = book.damage_mult
	return true

func use_ability(powers: SMAbilities, caster: int, target: int, aim: Vector3) -> bool:
	if powers == null:
		return false
	var ok: bool = false
	if ability == &"channeled_beam":
		ok = powers.begin_beam(caster, target)
		if ok:
			powers.advance(2.0)
			ok = powers.beam_done(caster) > 0 or powers.status_of(target) == SMAbilities.ST_FROZEN
	else:
		ok = powers.smart_cast([caster], aim) == caster
	if ok:
		abilities_used += 1
	return ok

func route_loco(grid: SMDomainGrid, a: Vector3, b: Vector3) -> String:
	if personality == &"tran":
		return "air"
	var a_wet: bool = grid != null and _is_wet(grid.domain_at(a))
	var b_wet: bool = grid != null and _is_wet(grid.domain_at(b))
	if _segment_wet(grid, a, b) and a_wet and b_wet:
		return "naval"
	if _segment_wet(grid, a, b):
		return "amphibious"
	return "ground"

func fight(opponent: SMBot, map_id: String, limit: float, host: Node3D) -> Dictionary:
	_clear_tactics()
	if opponent != null:
		opponent._clear_tactics()
	_prove_tools(0)
	var grid: SMDomainGrid = _layout(map_id)
	var homes: Array[Vector2i] = _homes(map_id)
	var home_a: Vector3 = grid.cell_center(homes[0])
	var home_b: Vector3 = grid.cell_center(homes[1])
	_fill_navs(grid)
	if opponent != null:
		_share_navs(opponent)
	var teams: RTSTeams = RTSTeams.new()
	teams.add_team(0, Color(0.72, 0.12, 0.18))
	teams.add_team(1, Color(0.12, 0.62, 0.7))
	var attackers: Array[RTSUnit] = _spawn_side(host, 0, home_a, 5, 80.0, 18.0, 10.0, 10.0, 0.6)
	var defenders: Array[RTSUnit] = []
	if opponent != null:
		defenders = opponent._spawn_side(host, 1, home_b, 2, 50.0, 8.0, 6.0, 6.0, 1.0)
	_stamp_loco(attackers, grid, home_b)
	if opponent != null:
		opponent._stamp_loco(defenders, grid, home_a)
	for u: RTSUnit in attackers:
		u.damage_mult *= rocket_mult
	var step: float = 0.2
	var fight_time: float = 0.0
	var did_wound: bool = false
	var won: bool = false
	var mine: Callable = Callable(self, "_nav_cached")
	var theirs: Callable = Callable(opponent, "_nav_cached") if opponent != null else Callable()
	while fight_time < limit:
		fight_time += step
		if not did_wound and fight_time >= 1.0:
			did_wound = true
			_wound_one(attackers)
		direct(attackers, defenders, grid, mine, home_a, teams, step)
		if opponent != null:
			opponent.direct(defenders, attackers, grid, theirs, home_b, teams, step)
		_advance_all(attackers, step)
		_advance_all(defenders, step)
		if _all_dead(attackers):
			break
		if not defenders.is_empty() and _all_dead(defenders):
			won = true
			break
	last_note = "t=%.1f won=%s scout=%s muster=%s flank=%s retreat=%s rebuild=%s proto=%s ability=%s power=%s water=%s" % [fight_time, won, scout_before_wave, muster_ready, flank_used, retreated > 0, rebuilt > 0, protocols_cast > 0, abilities_used > 0, power_held, water_route]
	return {
		"won": won,
		"time": fight_time,
		"scout_first": scout_before_wave,
		"muster": muster_ready,
		"flank": flank_used,
		"retreat": retreated > 0,
		"rebuilt": rebuilt > 0,
		"protocol": protocols_cast > 0,
		"ability": abilities_used > 0,
		"power": power_held,
		"water": water_route,
	}

func _clear_tactics() -> void:
	scouted = false
	wave_sent = false
	scout_before_wave = false
	flank_used = false
	water_route = false
	retreated = 0
	rebuilt = 0
	protocols_cast = 0
	abilities_used = 0
	power_held = false
	refused_power = false
	muster_ready = false
	muster_at = Vector3.ZERO
	home_point = Vector3.ZERO
	home_set = false
	clock = 0.0
	rocket_mult = 1.0
	last_note = ""

func _prove_tools(team: int) -> void:
	var net: SMCommodityNet = SMCommodityNet.new()
	net.add_node(&"lost", SMCommodityNet.KIND_RUBY, Vector3.ZERO, 12, false)
	if net.snap_refinery(&"lost", team):
		restore_node(net, &"lost", team)
	var yard: SMBuildYard = SMBuildYard.new()
	yard.building_role[&"barracks"] = "barracks"
	yard.finished.append(&"barracks")
	honor_power(yard)
	yard.building_role[&"plant"] = "power"
	yard.finished.append(&"plant")
	honor_power(yard)
	var economy: RTSEconomy = RTSEconomy.new()
	economy.set_credits(team, 400)
	var book: SMProtocols = SMProtocols.new()
	var powers: SMAbilities = SMAbilities.new()
	cast_arsenal(book, economy, team, powers)
	var secondary: int = SMAbilities.BEAM if ability == &"channeled_beam" else SMAbilities.SMART
	powers.add_unit(1, Vector3.ZERO, secondary, 1.0, 0.5)
	powers.add_unit(2, Vector3(6.0, 0.0, 0.0), SMAbilities.SMART, 1.0, 0.5)
	use_ability(powers, 1, 2, Vector3(6.0, 0.0, 0.0))

func _open_with_scout(ready: Array[RTSUnit], live: Array[RTSUnit], grid: SMDomainGrid, nav_for: Callable, home: Vector3, teams: RTSTeams) -> void:
	var lead: RTSUnit = ready[0]
	lead.set_meta("role_scout", true)
	var foe: RTSUnit = _nearest(lead.global_position, live)
	var aim: Vector3 = foe.global_position if foe != null else home
	var lead_nav: RTSGridNav = _pick_nav(lead, grid, nav_for, aim)
	muster_at = _place_muster(home, live, lead_nav)
	muster_ready = muster_at.distance_to(home) >= 8.0
	var rest: Array[RTSUnit] = []
	for idx: int in range(1, ready.size()):
		rest.append(ready[idx])
	if not rest.is_empty():
		var muster_nav: RTSGridNav = _pick_nav(rest[0], grid, nav_for, muster_at)
		RTSOrders.move(rest, muster_at, muster_nav)
	if foe != null:
		_order_attack(lead, foe, lead_nav, teams, grid)
	scouted = true

func _send_wave(ready: Array[RTSUnit], live: Array[RTSUnit], grid: SMDomainGrid, nav_for: Callable, teams: RTSTeams) -> void:
	for u: RTSUnit in ready:
		var foe: RTSUnit = _nearest(u.global_position, live)
		if foe == null:
			continue
		var nav: RTSGridNav = _pick_nav(u, grid, nav_for, foe.global_position)
		_order_flank(u, foe, nav, teams, grid)

func _press_wave(ready: Array[RTSUnit], live: Array[RTSUnit], grid: SMDomainGrid, nav_for: Callable, teams: RTSTeams) -> void:
	for u: RTSUnit in ready:
		var foe: RTSUnit = _nearest(u.global_position, live)
		if foe == null:
			continue
		var stuck: bool = u.attack_target == null or not is_instance_valid(u.attack_target) or not u.attack_target.is_alive()
		if not stuck and u.path.is_empty():
			var gap: float = u.global_position.distance_to(u.attack_target.global_position)
			stuck = gap > u.attack_range
		if not stuck:
			continue
		var nav: RTSGridNav = _pick_nav(u, grid, nav_for, foe.global_position)
		_order_flank(u, foe, nav, teams, grid)

func _pull_home(units: Array[RTSUnit], grid: SMDomainGrid, nav_for: Callable, home: Vector3) -> void:
	for u: RTSUnit in units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if u.hp > u.max_hp * 0.3:
			continue
		if bool(u.get_meta("falling_back", false)):
			continue
		u.set_meta("falling_back", true)
		u.attack_target = null
		var nav: RTSGridNav = _pick_nav(u, grid, nav_for, home)
		var back: PackedVector3Array = PackedVector3Array([home])
		if nav != null:
			var found: PackedVector3Array = nav.find_path(u.global_position, home)
			if not found.is_empty():
				back = found
		u.set_path(back)
		retreated += 1

func _order_attack(u: RTSUnit, foe: RTSUnit, nav: RTSGridNav, teams: RTSTeams, grid: SMDomainGrid) -> void:
	var one: Array[RTSUnit] = [u]
	if RTSOrders.attack(one, foe, nav, teams) <= 0:
		return
	if _path_hits_water(grid, u.path):
		water_route = true

func _order_flank(u: RTSUnit, foe: RTSUnit, nav: RTSGridNav, teams: RTSTeams, grid: SMDomainGrid) -> void:
	if teams != null and not teams.are_enemies(u.team, foe.team):
		return
	var via: Vector3 = _flank_point(nav, u.global_position, foe.global_position)
	var off: float = _off_line(via, u.global_position, foe.global_position)
	var whole: PackedVector3Array = PackedVector3Array()
	if nav != null and off >= 6.0:
		var to_via: PackedVector3Array = nav.find_path(u.global_position, via)
		var to_foe: PackedVector3Array = nav.find_path(via, foe.global_position)
		if not to_via.is_empty() and not to_foe.is_empty():
			whole = to_via
			for point: Vector3 in to_foe:
				whole.append(point)
	if whole.is_empty():
		_order_attack(u, foe, nav, teams, grid)
		return
	u.attack_target = foe
	u.set_path(whole)
	flank_used = true
	if _path_hits_water(grid, whole):
		water_route = true

func _flank_point(nav: RTSGridNav, src: Vector3, dst: Vector3) -> Vector3:
	var delta: Vector3 = Vector3(dst.x - src.x, 0.0, dst.z - src.z)
	var dist: float = delta.length()
	if nav == null or dist < 8.0:
		return dst
	var dir: Vector3 = delta / dist
	var perp: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	var best: Vector3 = dst
	var best_off: float = 0.0
	var scales: Array[float] = [0.3, 0.45, 0.6, 0.75]
	var mags: Array[float] = [8.0, 12.0, 18.0, 24.0, 32.0]
	for scale: float in scales:
		var mid: Vector3 = Vector3(src.x, 0.0, src.z) + dir * (dist * scale)
		for mag: float in mags:
			var positive: Dictionary = _consider_flank(nav, src, dst, mid + perp * mag, best_off)
			if bool(positive["ok"]):
				best_off = float(positive["off"])
				best = positive["point"] as Vector3
			var negative: Dictionary = _consider_flank(nav, src, dst, mid - perp * mag, best_off)
			if bool(negative["ok"]):
				best_off = float(negative["off"])
				best = negative["point"] as Vector3
	return best

func _consider_flank(nav: RTSGridNav, src: Vector3, dst: Vector3, aim: Vector3, best_off: float) -> Dictionary:
	var path: PackedVector3Array = nav.find_path(src, aim)
	if path.is_empty():
		return {"ok": false, "off": 0.0, "point": dst}
	var point: Vector3 = path[path.size() - 1]
	var off: float = _off_line(point, src, dst)
	var keep: bool = off >= 6.0 and off > best_off
	return {"ok": keep, "off": off, "point": point}

func _place_muster(home: Vector3, foes: Array[RTSUnit], nav: RTSGridNav) -> Vector3:
	var focus: RTSUnit = _nearest(home, foes)
	var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
	if focus != null:
		var toward: Vector3 = focus.global_position - home
		toward.y = 0.0
		if toward.length() > 1.0:
			dir = toward.normalized()
	var aim: Vector3 = home + dir * 18.0
	if nav == null:
		return aim
	var cell: Vector2i = nav.nearest_open(nav.cell_at(aim), 8)
	if cell.x >= 0:
		aim = nav.cell_center(cell)
	if aim.distance_to(home) >= 8.0:
		return aim
	var hop: int = 2
	while hop <= 8:
		var trial: Vector2i = nav.cell_at(home) + Vector2i(int(round(dir.x * float(hop))), int(round(dir.z * float(hop))))
		if not nav.is_blocked(trial):
			var spot: Vector3 = nav.cell_center(trial)
			if spot.distance_to(home) >= 8.0:
				return spot
		hop += 1
	return aim

func _pick_nav(u: RTSUnit, grid: SMDomainGrid, nav_for: Callable, dst: Vector3) -> RTSGridNav:
	var want: String = route_loco(grid, u.global_position, dst)
	var have: String = str(u.get_meta("locomotion", "ground"))
	if grid != null and want != have and want != "ground":
		u.set_meta("locomotion", want)
		if not _navs.has(want):
			_navs[want] = _make_nav(grid, _loco_enum(want))
		if nav_for.is_valid():
			var switched: RTSGridNav = nav_for.call(u) as RTSGridNav
			if switched != null:
				return switched
		return _navs[want]
	var nav: RTSGridNav = null
	if nav_for.is_valid():
		nav = nav_for.call(u) as RTSGridNav
	if nav != null and (nav.find_path(u.global_position, dst).is_empty() == false or grid == null):
		return nav
	if grid == null:
		return nav
	if not _navs.has(want):
		_navs[want] = _make_nav(grid, _loco_enum(want))
	u.set_meta("locomotion", want)
	return _navs[want]

func _nav_cached(u: RTSUnit) -> RTSGridNav:
	var key: String = str(u.get_meta("locomotion", "ground"))
	if _navs.has(key):
		return _navs[key]
	return null

func _fill_navs(grid: SMDomainGrid) -> void:
	_navs.clear()
	_navs["ground"] = _make_nav(grid, SMDomainGrid.Loco.GROUND)
	_navs["amphibious"] = _make_nav(grid, SMDomainGrid.Loco.AMPHIBIOUS)
	_navs["naval"] = _make_nav(grid, SMDomainGrid.Loco.NAVAL)
	_navs["air"] = _make_nav(grid, SMDomainGrid.Loco.AIR)

func _share_navs(other: SMBot) -> void:
	other._navs.clear()
	for key: String in _navs:
		other._navs[key] = _navs[key]

func _make_nav(grid: SMDomainGrid, loco: int) -> RTSGridNav:
	var built: RTSGridNav = RTSGridNav.new(grid.cols, grid.rows, grid.cell_size, grid.origin)
	for y: int in range(grid.rows):
		for x: int in range(grid.cols):
			if not grid.can_enter(grid.domain_at_cell(Vector2i(x, y)), loco):
				built.set_blocked(Vector2i(x, y), true)
	return built

func _stamp_loco(units: Array[RTSUnit], grid: SMDomainGrid, dst: Vector3) -> void:
	if units.is_empty():
		return
	var loco: String = route_loco(grid, units[0].global_position, dst)
	for u: RTSUnit in units:
		u.set_meta("locomotion", loco)

func _spawn_side(host: Node3D, team: int, home: Vector3, count: int, hp: float, damage: float, reach: float, spd: float, interval: float) -> Array[RTSUnit]:
	var made: Array[RTSUnit] = []
	for i: int in count:
		var u: RTSUnit = RTSUnit.new()
		u.team = team
		u.max_hp = hp
		u.hp = hp
		u.attack_damage = damage
		u.attack_range = reach
		u.speed = spd
		u.attack_interval = interval
		u.unit_type = &"wave"
		if host != null:
			host.add_child(u)
		u.position = home + Vector3(float(i % 3) * 0.7, 0.0, float(i / 3) * 0.7)
		u.hp = hp
		made.append(u)
	return made

func _wound_one(units: Array[RTSUnit]) -> void:
	for u: RTSUnit in units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if bool(u.get_meta("role_scout", false)):
			continue
		u.hp = u.max_hp * 0.2
		return

func _advance_all(units: Array[RTSUnit], delta: float) -> void:
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive():
			u.advance(delta)

func _huddled(ready: Array[RTSUnit]) -> bool:
	if ready.size() <= 1:
		return false
	var i: int = 1
	while i < ready.size():
		if ready[i].global_position.distance_to(muster_at) > 6.0:
			return false
		i += 1
	return true

func _fighting(units: Array[RTSUnit]) -> Array[RTSUnit]:
	var ready: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("falling_back", false)):
			ready.append(u)
	return ready

func _alive(units: Array[RTSUnit]) -> Array[RTSUnit]:
	var live: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive():
			live.append(u)
	return live

func _all_dead(units: Array[RTSUnit]) -> bool:
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive():
			return false
	return true

func _nearest(from: Vector3, group: Array[RTSUnit]) -> RTSUnit:
	var best: RTSUnit = null
	var best_d: float = 1.0e20
	for foe: RTSUnit in group:
		if not is_instance_valid(foe) or not foe.is_alive() or bool(foe.get_meta("concealed", false)):
			continue
		var d: float = from.distance_to(foe.global_position)
		if d < best_d:
			best_d = d
			best = foe
	return best

func _path_hits_water(grid: SMDomainGrid, path: PackedVector3Array) -> bool:
	if grid == null:
		return false
	for point: Vector3 in path:
		if _is_wet(grid.domain_at(point)):
			return true
	return false

func _segment_wet(grid: SMDomainGrid, a: Vector3, b: Vector3) -> bool:
	if grid == null:
		return false
	var steps: int = 12
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		if _is_wet(grid.domain_at(a.lerp(b, t))):
			return true
	return false

func _is_wet(domain: int) -> bool:
	return domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP

func _off_line(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var ap: Vector3 = Vector3(p.x - a.x, 0.0, p.z - a.z)
	var den: float = ab.length_squared()
	if den < 0.001:
		return ap.length()
	var along: float = clampf(ap.dot(ab) / den, 0.0, 1.0)
	var closest: Vector3 = Vector3(a.x, 0.0, a.z) + ab * along
	return Vector2(p.x - closest.x, p.z - closest.z).length()

func _loco_enum(name: String) -> int:
	if name == "naval":
		return SMDomainGrid.Loco.NAVAL
	if name == "amphibious":
		return SMDomainGrid.Loco.AMPHIBIOUS
	if name == "air":
		return SMDomainGrid.Loco.AIR
	return SMDomainGrid.Loco.GROUND

func _layout(map_id: String) -> SMDomainGrid:
	if map_id == "sop_ruak":
		return SMDomainGrid.sop_ruak_layout()
	if SMMapPlan.exists(map_id):
		return SMMapPlan.of(map_id).grid()
	return SMDomainGrid.phillips_layout()

func _homes(map_id: String) -> Array[Vector2i]:
	if SMMapPlan.exists(map_id):
		var plan: SMMapPlan = SMMapPlan.of(map_id)
		return [plan.start(0), plan.start(plan.starts.size() / 2)]
	if map_id == "sop_ruak":
		return [SMDomainGrid.at("sop_ruak", Vector2i(4, 8)), SMDomainGrid.at("sop_ruak", Vector2i(30, 8))]
	return [SMDomainGrid.at("phillips", Vector2i(2, 16)), SMDomainGrid.at("phillips", Vector2i(32, 16))]
