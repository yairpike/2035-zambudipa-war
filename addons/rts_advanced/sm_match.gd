class_name SMMatch
extends RefCounted
## Headless match: faction pipeline, channel crossing, abilities, passive enemy, bots.

signal site_made(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, form: String)
signal plate_sunk(host: Node3D, node_name: String)
signal deck_fit(host: Node3D, deck_name: String, north_up: bool, south_up: bool)

var economy: RTSEconomy = RTSEconomy.new()
var grid: SMDomainGrid
var yard: SMBuildYard
var goods: SMCommodityNet = SMCommodityNet.new()
var tech: SMTechNet = SMTechNet.new()
var abilities: SMAbilities = SMAbilities.new()
var ew: SMEwField = SMEwField.new()
var protocols: SMProtocols = SMProtocols.new()
var audio: SMAudioDirector = SMAudioDirector.new()
var player: int = 0
var enemy: int = 1
var enemy_hp: float = 50.0
var finished: bool = false
var winner: int = -1
var domain_log: Array[int] = []
var trained: Array[StringName] = []
var f_smart: int = -1
var f_toggles: int = 0
var pipeline_ok: bool = false
var claimed: bool = false
var faction_id: String = "gtfc"
var spans: Dictionary = {}

func setup_phillips(faction: String = "gtfc") -> void:
	faction_id = faction
	economy.set_credits(player, 5000)
	economy.set_credits(enemy, 200)
	grid = SMDomainGrid.phillips_layout()
	grid.domain_changed.connect(_on_domain)
	yard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.team = player
	yard.economy = economy
	yard.center = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(6, 12)))
	yard.radius = 36.0
	yard.drain_per_sec = 5
	yard.tech_order = [&"scaffold_yard", &"barracks"]
	yard.building_time[&"scaffold_yard"] = 4.0
	yard.building_time[&"barracks"] = 3.0
	yard.building_tier[&"scaffold_yard"] = 1
	yard.building_tier[&"barracks"] = 1
	goods = SMCommodityNet.new()
	tech = SMTechNet.new()
	_sites_phillips()
	abilities = SMAbilities.new()
	ew = SMEwField.new()
	ew.center = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(10, 6)))
	protocols = SMProtocols.new()
	audio = SMAudioDirector.new()
	domain_log.clear()
	trained.clear()
	f_smart = -1
	f_toggles = 0
	pipeline_ok = false
	claimed = false
	finished = false
	winner = -1
	enemy_hp = 50.0

func _on_domain(_unit_id: int, from_domain: int, to_domain: int) -> void:
	domain_log.append(from_domain)
	domain_log.append(to_domain)

func has_two_lands() -> bool:
	if grid == null:
		return false
	var west: int = grid.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(8, 4)))
	var east: int = grid.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(30, 12)))
	var deep: int = grid.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(20, 12)))
	var shallow: int = grid.domain_at_cell(SMDomainGrid.at("phillips", Vector2i(16, 5)))
	return west == SMDomainGrid.Domain.LAND and east == SMDomainGrid.Domain.LAND and deep == SMDomainGrid.Domain.DEEP and shallow == SMDomainGrid.Domain.SHALLOW

func run_player_pipeline() -> bool:
	if yard == null:
		return false
	if not yard.begin_scaffold(&"scaffold_yard", yard.center, 300.0):
		return false
	yard.advance(4.0)
	if yard.vulnerable or not yard.finished.has(&"scaffold_yard"):
		return false
	if yard.drained <= 0:
		return false
	if not yard.can_build(&"barracks"):
		return false
	if not yard.begin_scaffold(&"barracks", yard.center + Vector3(4.0, 0.0, 0.0), 200.0):
		return false
	yard.advance(3.0)
	if not yard.finished.has(&"barracks"):
		return false
	if not goods.snap_refinery(&"slag_west", player):
		return false
	claimed = goods.has_collector(&"slag_west")
	goods.advance(4.0, economy)
	trained.append(&"channel_skiff")
	trained.append(&"militia")
	trained.append(&"ruby_lancer")
	abilities.add_unit(10, yard.center, SMAbilities.TOGGLE, 2.0, 0.6)
	abilities.add_unit(11, yard.center + Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	abilities.add_unit(12, yard.center + Vector3(8.0, 0.0, 1.0), SMAbilities.SMART, 3.0, 0.6)
	pipeline_ok = claimed and goods.paid_of(&"slag_west") > 0
	return pipeline_ok

func cross_channel() -> bool:
	var pts: Array[Vector3] = [
		grid.cell_center(SMDomainGrid.at("phillips", Vector2i(12, 5))),
		grid.cell_center(SMDomainGrid.at("phillips", Vector2i(16, 5))),
		grid.cell_center(SMDomainGrid.at("phillips", Vector2i(22, 5))),
		grid.cell_center(SMDomainGrid.at("phillips", Vector2i(26, 5))),
	]
	for p: Vector3 in pts:
		if not grid.move_unit(12, p, SMDomainGrid.Loco.AMPHIBIOUS):
			return false
	var deep: Vector3 = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(20, 12)))
	if grid.move_unit(99, deep, SMDomainGrid.Loco.GROUND):
		return false
	return domain_log.size() >= 2 and grid.unit_domain(12) == SMDomainGrid.Domain.LAND

func use_f() -> bool:
	var ids: Array[int] = [10, 11, 12]
	var aim: Vector3 = yard.center + Vector3(2.0, 0.0, 0.0)
	f_toggles = abilities.group_toggle(ids)
	f_smart = abilities.smart_cast(ids, aim)
	return f_toggles == 1 and f_smart == 11 and abilities.fired_count(12) == 0

func fight_passive() -> bool:
	audio.set_combat(true)
	var guard: int = 0
	while enemy_hp > 0.0 and guard < 20:
		enemy_hp -= 10.0 * protocols.damage_mult
		audio.advance(0.5)
		guard += 1
	if enemy_hp <= 0.0:
		finished = true
		winner = player
		return true
	return false

func script_phillips() -> bool:
	setup_phillips(faction_id if faction_id != "" else "gtfc")
	if not has_two_lands():
		return false
	if not run_player_pipeline():
		return false
	if not cross_channel():
		return false
	if not use_f():
		return false
	return fight_passive()

func run_bot(bot: SMBot) -> Dictionary:
	economy.set_credits(player, 4000)
	economy.set_credits(enemy, 80)
	grid = SMDomainGrid.phillips_layout()
	goods = SMCommodityNet.new()
	goods.add_node(&"a", SMCommodityNet.KIND_SLAG, grid.cell_center(Vector2i(4, 4)), 10, false)
	goods.add_node(&"b", SMCommodityNet.KIND_BULLION, grid.cell_center(Vector2i(8, 6)), 10, false)
	goods.add_node(&"w", SMCommodityNet.KIND_RARE, grid.cell_center(Vector2i(13, 5)), 0, true)
	goods.add_node(&"g", SMCommodityNet.KIND_RUBY, grid.cell_center(Vector2i(6, 16)), 12, false)
	tech = SMTechNet.new()
	tech.add_site(&"site", bot.tech_kind, grid.cell_center(Vector2i(7, 8)))
	abilities = SMAbilities.new()
	protocols = SMProtocols.new()
	audio = SMAudioDirector.new()
	var refineries: int = 0
	if goods.snap_refinery(&"a", player):
		refineries += 1
	if goods.snap_refinery(&"b", player):
		refineries += 1
	var water: bool = goods.snap_refinery(&"w", player)
	var gem: bool = goods.snap_refinery(&"g", player)
	var night: bool = goods.set_night_shift(&"g", true)
	var captured: bool = tech.capture(&"site", player)
	var fired: bool = false
	var frozen: bool = false
	var naval: bool = false
	var flew: bool = false
	if bot.ability == &"smart_cast":
		abilities.add_unit(1, Vector3.ZERO, SMAbilities.SMART, 1.0, 0.5)
		abilities.add_unit(2, Vector3(10.0, 0.0, 0.0), SMAbilities.SMART, 1.0, 0.5)
		fired = abilities.smart_cast([1, 2], Vector3.ZERO) == 1 and abilities.fired_count(2) == 0
	elif bot.ability == &"channeled_beam":
		abilities.add_unit(1, Vector3.ZERO, SMAbilities.BEAM, 1.0, 0.5)
		abilities.add_unit(2, Vector3(3.0, 0.0, 0.0), SMAbilities.TOGGLE, 1.0, 0.5)
		fired = abilities.begin_beam(1, 2)
		abilities.advance(2.0)
		frozen = abilities.status_of(2) == SMAbilities.ST_FROZEN
	if bot.personality == &"iskandar":
		naval = grid.move_unit(7, grid.cell_center(SMDomainGrid.at("phillips", Vector2i(20, 12))), SMDomainGrid.Loco.NAVAL)
	if bot.personality == &"tran":
		flew = grid.move_unit(8, grid.cell_center(Vector2i(19, 10)), SMDomainGrid.Loco.AIR)
		frozen = frozen or abilities.status_of(2) == SMAbilities.ST_FROZEN
	if bot.personality == &"bo_mya":
		var drone_cost: int = int(roundf(100.0 * tech.discount(player, "drone")))
		fired = fired and drone_cost == 80
	audio.set_combat(true)
	audio.advance(1.1)
	var target: int = 2 if abilities.index_of(2) >= 0 else -1
	var proto: bool = protocols.cast(&"logistics", economy, player, abilities, target)
	proto = protocols.cast(&"arsenal", economy, player, abilities, target) and proto
	proto = protocols.cast(&"oracle", economy, player, abilities, target) and proto
	proto = proto and not protocols.can_cast(&"logistics")
	if bot.personality == &"tran":
		frozen = abilities.status_of(2) == SMAbilities.ST_FROZEN or protocols.cryo_applied
	return {
		"refineries": refineries,
		"water": water,
		"gem": gem and night,
		"captured": captured,
		"fired": fired,
		"frozen": frozen,
		"naval": naval,
		"flew": flew,
		"protocols": proto,
		"audio_combat": audio.stem == &"combat" and audio.combat > audio.exploration,
		"silent": audio.silent_placeholder,
		"faction": bot.faction_id,
		"refinery_target": bot.refinery_target,
	}

func place_sites(map_id: String, p_grid: SMDomainGrid) -> void:
	grid = p_grid
	goods = SMCommodityNet.new()
	tech = SMTechNet.new()
	if SMMapPlan.exists(map_id):
		_sites_plan(SMMapPlan.of(map_id))
	elif map_id == "sop_ruak":
		_sites_sop()
	else:
		_sites_phillips()

func tick_live(delta: float, purse: RTSEconomy, squad: SMPointer, foe_purse: RTSEconomy = null) -> void:
	goods.advance(delta, purse)
	tech.advance(delta, purse, SMPointer.ENEMY)
	var bank: RTSEconomy = purse if foe_purse == null else foe_purse
	tech.skim_bazaar(purse, bank, SMPointer.PLAYER, SMPointer.ENEMY, delta)
	if squad == null:
		return
	for u: RTSUnit in squad.units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		goods.claim_at(u.global_position, u.team, 2.4)
		tech.capture_at(u.global_position, u.team, 2.4)
	if _owns(SMTechNet.CLINIC):
		for u: RTSUnit in squad.units_of(SMPointer.PLAYER):
			if squad.is_infantry(u) and u.hp < u.max_hp:
				u.hp = minf(u.max_hp, u.hp + 2.0 * delta)
	for u: RTSUnit in squad.units:
		if not is_instance_valid(u) or not u.is_alive() or not squad.is_infantry(u):
			continue
		var harm: float = goods.harm_infantry(u.global_position, bool(u.get_meta("shielded", false)), delta)
		if harm > 0.0:
			u.take_damage(harm)

func show_collectors(host: Node3D) -> void:
	if host == null:
		return
	for node: Dictionary in goods.nodes:
		var node_name: String = "Collector_%s" % str(node.get("id", ""))
		var have: Node = host.get_node_or_null(node_name)
		if bool(node.get("collector", false)):
			if have == null:
				var spot: Vector3 = node.get("pos", Vector3.ZERO) as Vector3
				_site_mesh(host, node_name, spot + Vector3(0.0, 0.85, 0.0), Vector3(0.38, 0.7, 0.38), Color(0.95, 0.82, 0.28))
		elif have != null:
			have.queue_free()

func paint_sites(host: Node3D) -> void:
	if host == null:
		return
	for node: Dictionary in goods.nodes:
		var spot: Vector3 = node.get("pos", Vector3.ZERO) as Vector3
		var goods_kind: StringName = StringName(str(node.get("kind", "")))
		_site_mesh(host, "Node_%s" % str(node.get("id", "")), spot, Vector3(1.15, 0.4, 1.15), _node_color(goods_kind), _goods_form(goods_kind))
	for site: Dictionary in tech.sites:
		var kind: StringName = StringName(str(site.get("kind", "")))
		var spot: Vector3 = site.get("pos", Vector3.ZERO) as Vector3
		var node_name: String = "%s%s" % [_site_prefix(kind), str(site.get("id", ""))]
		var size: Vector3 = Vector3(1.3, 1.5, 1.3)
		var lift: float = 0.0
		if kind == SMTechNet.BRIDGE:
			size = Vector3(2.6, 0.28, 1.1)
			lift = 0.16
		elif kind == SMTechNet.DERRICK:
			size = Vector3(0.36, 2.3, 0.36)
		elif kind == SMTechNet.SALVAGE:
			size = Vector3(1.8, 0.45, 1.1)
		_site_mesh(host, node_name, spot + Vector3(0.0, lift, 0.0), size, _site_color(kind), _tech_form(kind))

func collapse_bridge(id: StringName, squad: SMPointer, host: Node3D) -> void:
	var span: Rect2i = _bridge_span(id)
	if grid != null and span.size.x > 0 and span.size.y > 0:
		grid.fill_rect(span, SMDomainGrid.Domain.DEEP)
	if squad != null and grid != null:
		squad.use_domain(grid)
	if host == null:
		return
	plate_sunk.emit(host, "Bridge_%s" % str(id))
	_fit_deck(host, id)

func _bridge_span(id: StringName) -> Rect2i:
	if spans.has(id):
		return spans[id] as Rect2i
	return Rect2i()

func _fit_deck(host: Node3D, id: StringName) -> void:
	var west: bool = str(id) == "bridge_a" or str(id) == "bridge_b"
	var deck_name: String = "BridgeWest" if west else "BridgeEast"
	var north_id: StringName = &"bridge_a" if west else &"bridge_c"
	var south_id: StringName = &"bridge_b" if west else &"bridge_d"
	deck_fit.emit(host, deck_name, tech.bridge_alive(north_id), tech.bridge_alive(south_id))

func _owns(kind: StringName) -> bool:
	for site: Dictionary in tech.sites:
		if StringName(str(site.get("kind", ""))) == kind and int(site.get("owner", -1)) == player:
			return true
	return false

func _sites_phillips() -> void:
	_node(&"slag_west", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("phillips", Vector2i(8, 8)), 20, false)
	_node(&"slag_north", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("phillips", Vector2i(6, 4)), 12, false)
	_node(&"slag_south", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("phillips", Vector2i(4, 16)), 12, false)
	_node(&"slag_mid", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("phillips", Vector2i(10, 14)), 12, false)
	_node(&"bullion_east", SMCommodityNet.KIND_BULLION, SMDomainGrid.at("phillips", Vector2i(32, 16)), 25, false)
	_node(&"bullion_north", SMCommodityNet.KIND_BULLION, SMDomainGrid.at("phillips", Vector2i(34, 6)), 18, false)
	_node(&"rare_shore", SMCommodityNet.KIND_RARE, SMDomainGrid.at("phillips", Vector2i(13, 12)), 0, true)
	_node(&"rare_ford", SMCommodityNet.KIND_RARE, SMDomainGrid.at("phillips", Vector2i(14, 18)), 0, true)
	tech.add_site(&"cyber", SMTechNet.CYBER, grid.cell_center(SMDomainGrid.at("phillips", Vector2i(28, 18))))
	tech.add_site(&"cyber_north", SMTechNet.CYBER, grid.cell_center(SMDomainGrid.at("phillips", Vector2i(24, 4))))
	tech.add_site(&"salvage_wreck", SMTechNet.SALVAGE, grid.cell_center(SMDomainGrid.at("phillips", Vector2i(18, 12))))

func _sites_sop() -> void:
	_node(&"slag_a", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("sop_ruak", Vector2i(4, 20)), 14, false)
	_node(&"slag_b", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("sop_ruak", Vector2i(8, 30)), 14, false)
	_node(&"slag_c", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("sop_ruak", Vector2i(12, 32)), 12, false)
	_node(&"slag_d", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("sop_ruak", Vector2i(2, 28)), 12, false)
	_node(&"slag_e", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("sop_ruak", Vector2i(14, 24)), 12, false)
	_node(&"slag_f", SMCommodityNet.KIND_SLAG, SMDomainGrid.at("sop_ruak", Vector2i(6, 34)), 12, false)
	_node(&"jade_a", SMCommodityNet.KIND_JADE, SMDomainGrid.at("sop_ruak", Vector2i(4, 6)), 15, false)
	_node(&"jade_b", SMCommodityNet.KIND_JADE, SMDomainGrid.at("sop_ruak", Vector2i(8, 4)), 15, false)
	_node(&"jade_c", SMCommodityNet.KIND_JADE, SMDomainGrid.at("sop_ruak", Vector2i(12, 8)), 15, false)
	_node(&"bullion_a", SMCommodityNet.KIND_BULLION, SMDomainGrid.at("sop_ruak", Vector2i(24, 28)), 20, false)
	_node(&"bullion_b", SMCommodityNet.KIND_BULLION, SMDomainGrid.at("sop_ruak", Vector2i(30, 24)), 20, false)
	_node(&"bullion_c", SMCommodityNet.KIND_BULLION, SMDomainGrid.at("sop_ruak", Vector2i(32, 30)), 18, false)
	tech.add_site(&"cyber_a", SMTechNet.CYBER, grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(10, 26))))
	tech.add_site(&"cyber_b", SMTechNet.CYBER, grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(28, 32))))
	tech.add_site(&"cyber_c", SMTechNet.CYBER, grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(6, 10))))
	tech.add_site(&"bazaar", SMTechNet.BAZAAR, grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(12, 22))))

func _sites_plan(plan: SMMapPlan) -> void:
	spans.clear()
	for row: Dictionary in plan.nodes:
		_node(row["id"] as StringName, SMMapPlan.goods_kind(row["kind"] as StringName), row["cell"] as Vector2i, int(row["rate"]), bool(row["water"]))
	for row: Dictionary in plan.sites:
		tech.add_site(row["id"] as StringName, SMMapPlan.site_kind(row["kind"] as StringName), grid.cell_center(row["cell"] as Vector2i))
		var span: Rect2i = row["span"] as Rect2i
		if span.size != Vector2i.ZERO:
			spans[row["id"] as StringName] = span

func _node(id: StringName, kind: StringName, cell: Vector2i, rate: int, water: bool) -> void:
	goods.add_node(id, kind, grid.cell_center(cell), rate, water)

func _node_color(kind: StringName) -> Color:
	if kind == SMCommodityNet.KIND_SLAG:
		return Color(0.88, 0.62, 0.12)
	if kind == SMCommodityNet.KIND_RARE:
		return Color(0.2, 0.62, 0.58)
	if kind == SMCommodityNet.KIND_RUBY:
		return Color(0.72, 0.12, 0.18)
	if kind == SMCommodityNet.KIND_JADE:
		return Color(0.2, 0.62, 0.36)
	return Color(0.86, 0.74, 0.28)

func _site_prefix(kind: StringName) -> String:
	if kind == SMTechNet.SALVAGE:
		return "Salvage_"
	if kind == SMTechNet.DERRICK:
		return "Derrick_"
	if kind == SMTechNet.BRIDGE:
		return "Bridge_"
	if kind == SMTechNet.GARRISON:
		return "Garrison_"
	return "Tech_"

func _site_color(kind: StringName) -> Color:
	if kind == SMTechNet.CYBER:
		return Color(0.45, 0.25, 0.72)
	if kind == SMTechNet.BAZAAR:
		return Color(0.72, 0.4, 0.12)
	if kind == SMTechNet.CLINIC:
		return Color(0.75, 0.82, 0.86)
	if kind == SMTechNet.RADAR:
		return Color(0.25, 0.55, 0.78)
	if kind == SMTechNet.DERRICK:
		return Color(0.35, 0.32, 0.28)
	if kind == SMTechNet.BRIDGE:
		return Color(0.42, 0.38, 0.32)
	if kind == SMTechNet.GARRISON:
		return Color(0.62, 0.58, 0.5)
	return Color(0.4, 0.28, 0.18)

func _goods_form(kind: StringName) -> String:
	if kind == SMCommodityNet.KIND_SLAG:
		return "slag"
	if kind == SMCommodityNet.KIND_RARE:
		return "rare"
	if kind == SMCommodityNet.KIND_RUBY:
		return "ruby"
	if kind == SMCommodityNet.KIND_JADE:
		return "jade"
	if kind == SMCommodityNet.KIND_BULLION:
		return "bullion"
	return "slag"

func _tech_form(kind: StringName) -> String:
	if kind == SMTechNet.CYBER:
		return "cyber"
	if kind == SMTechNet.BAZAAR:
		return "bazaar"
	if kind == SMTechNet.CLINIC:
		return "clinic"
	if kind == SMTechNet.RADAR:
		return "radar"
	if kind == SMTechNet.DERRICK:
		return "derrick"
	if kind == SMTechNet.SALVAGE:
		return "salvage"
	if kind == SMTechNet.BRIDGE:
		return "bridge"
	if kind == SMTechNet.GARRISON:
		return "garrison"
	return "salvage"

func _site_mesh(host: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, form: String = "") -> void:
	site_made.emit(host, node_name, pos, size, color, form)
