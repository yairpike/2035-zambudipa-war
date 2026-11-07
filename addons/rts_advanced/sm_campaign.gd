class_name SMCampaign
extends RefCounted
## Fifteen story missions. The old drills stay in debug_ids() and off the campaign tab.

static var selected: String = "tachileik"

var result_text: String = ""

static func ids() -> PackedStringArray:
	return PackedStringArray([
		"kokang",
		"tachileik",
		"shwe_kokko",
		"operation_1027",
		"andaman",
		"ghosts_of_patani",
		"kilometer_watch",
		"black_haze",
		"archipelago_rising",
		"wrath_of_the_garuda",
		"fog_over_pakbeng",
		"keng_tung",
		"plain_of_jars",
		"tonle_sap",
		"shattered_monsoon",
	])

static func debug_ids() -> PackedStringArray:
	return PackedStringArray([
		"mae_sai",
		"ruby_market",
		"rare_stock",
		"channel_crossing",
		"jammer_drill",
		"cyber_compound",
		"arms_bazaar",
		"field_clinic",
		"hydro_radar",
		"clearance_two",
		"packer_sail",
		"smart_cast",
		"beam_freeze",
		"protocol_bar",
	])

static func act_ids() -> PackedStringArray:
	return PackedStringArray(["act_1", "act_2", "act_3"])

static func act_title(act: String) -> String:
	if act == "act_1":
		return "Act I"
	if act == "act_2":
		return "Act II"
	if act == "act_3":
		return "Act III"
	return act

static func act_of(id: String) -> String:
	for act: String in act_ids():
		if act_missions(act).has(id):
			return act
	return ""

## Act I is played as GTFC, Act II as NMRF, Act III as MVD. Drills stay GTFC.
static func player_faction(id: String) -> String:
	var act: String = act_of(id)
	if act == "act_2":
		return "nmrf"
	if act == "act_3":
		return "mvd"
	return "gtfc"

## The opposition named in the briefing. A mixed fight still has one default skin;
## individual spawns can set look on the unit.
static func enemy_faction(id: String) -> String:
	if id == "operation_1027":
		return "black_market"
	if id == "tonle_sap":
		return "nmrf"
	if id == "ghosts_of_patani" or id == "kilometer_watch" or id == "black_haze" or id == "archipelago_rising" or id == "wrath_of_the_garuda":
		return "gtfc"
	if id == "fog_over_pakbeng" or id == "keng_tung" or id == "plain_of_jars" or id == "shattered_monsoon":
		return "gtfc"
	if id == "kokang" or id == "tachileik" or id == "shwe_kokko" or id == "andaman":
		return "nmrf"
	return "nmrf"

static func still_of(id: String) -> String:
	if id == "kokang":
		return "briefings/kokang.webp"
	if id == "ghosts_of_patani":
		return "briefings/ghosts_of_patani.webp"
	if id == "fog_over_pakbeng":
		return "briefings/fog_over_pakbeng.webp"
	return ""

static func company_of(faction: String) -> Array[StringName]:
	var kinds: Array[StringName] = []
	if faction == "nmrf":
		kinds.append(&"river_rifle")
		kinds.append(&"sampan")
		kinds.append(&"mangrove_skiff")
	elif faction == "mvd":
		kinds.append(&"clearance_trooper")
		kinds.append(&"hub_drone")
		kinds.append(&"cyan_ifv")
	else:
		kinds.append(&"militia")
		kinds.append(&"ruby_lancer")
		kinds.append(&"amber_tank")
	return kinds

static func act_missions(act: String) -> PackedStringArray:
	if act == "act_1":
		return PackedStringArray(["kokang", "tachileik", "shwe_kokko", "operation_1027", "andaman"])
	if act == "act_2":
		return PackedStringArray([
			"ghosts_of_patani",
			"kilometer_watch",
			"black_haze",
			"archipelago_rising",
			"wrath_of_the_garuda",
		])
	if act == "act_3":
		return PackedStringArray(["fog_over_pakbeng", "keng_tung", "plain_of_jars", "tonle_sap", "shattered_monsoon"])
	return PackedStringArray()

static func title_of(id: String) -> String:
	if id == "kokang":
		return "Kokang and Mogok night raid"
	if id == "tachileik":
		return "Tachileik caravan"
	if id == "shwe_kokko":
		return "Shwe Kokko capture"
	if id == "operation_1027":
		return "Operation 1027 drone wave"
	if id == "andaman":
		return "Andaman breakout"
	if id == "ghosts_of_patani":
		return "Ghosts of Patani"
	if id == "kilometer_watch":
		return "The 74-Kilometer Watch"
	if id == "black_haze":
		return "Black Haze"
	if id == "archipelago_rising":
		return "Archipelago Rising"
	if id == "wrath_of_the_garuda":
		return "Wrath of the Garuda"
	if id == "fog_over_pakbeng":
		return "Fog Over Pakbeng"
	if id == "keng_tung":
		return "Keng Tung Defoliation"
	if id == "plain_of_jars":
		return "Phantom of the Plain of Jars"
	if id == "tonle_sap":
		return "Thunder on the Tonle Sap"
	if id == "shattered_monsoon":
		return "Operation Shattered Monsoon"
	if id == "mae_sai":
		return "Mae Sai scaffold (mission)"
	if id == "ruby_market":
		return "Ruby night market (mission)"
	if id == "rare_stock":
		return "Rare-earth stock (mission)"
	if id == "channel_crossing":
		return "Channel crossing (mission)"
	if id == "jammer_drill":
		return "Jammer drill (mission)"
	if id == "cyber_compound":
		return "Cyber compound (mission)"
	if id == "arms_bazaar":
		return "Arms bazaar (mission)"
	if id == "field_clinic":
		return "Field clinic (mission)"
	if id == "hydro_radar":
		return "Hydro radar (mission)"
	if id == "clearance_two":
		return "Clearance two (mission)"
	if id == "packer_sail":
		return "Packer sail (mission)"
	if id == "smart_cast":
		return "Smart-cast drill (mission)"
	if id == "beam_freeze":
		return "Beam freeze (mission)"
	if id == "protocol_bar":
		return "Protocol bar (mission)"
	return id

static func briefing_of(id: String) -> String:
	if id == "kokang":
		return "Kokang and Mogok. Text briefing. Raise the yard, clear the Orlan recon over the pits, run the ruby night shift, and bring one rare-earth stock home. If the company dies, the raid fails. Rain hits, Orlans pass the pits, and the night shift starts. The side cache is optional."
	if id == "tachileik":
		return "Tachileik caravan. Text briefing. Break the ambush and the road relief, walk the jade caravan onto the bazaar, then snap the ruby pit and run the night shift until the purse fills. Stay with the wagon while drones harass it. If the wagon dies, the mission fails. The road ambush hits after that. The side cache is optional."
	if id == "shwe_kokko":
		return "Shwe Kokko. Text briefing. Destroy the garrison and the river gunboats, capture both server blocks, and siphon the enemy purse. Hold a server block for twenty seconds. If you are pushed off, the hack resets. The side cache is optional."
	if id == "operation_1027":
		return "Operation 1027. Text briefing. Knock out the junta EW jamming towers while the escorts press in, then destroy the parked Su-30 and CH-4 hangars. The drone swarm can help. Casting it does not end the mission. The hangars scramble, the swarm crosses, and two rifles arrive."
	if id == "andaman":
		return "Andaman breakout. Text briefing. Sink the channel boats and the second wave, then land an amphibious unit on the far shore. A mine line in the channel damages ships. The far shore opens, and a squall crosses. The side cache is optional."
	if id == "ghosts_of_patani":
		return "Ghosts of Patani. Text briefing. Destroy every ghost in the jammer, including the shipment guards. GPS guidance drops there. A fiber link does not. Losing the company fails the mission. GPS drops, ghosts close in, and then the guide turns. The side cache is optional."
	if id == "kilometer_watch":
		return "The 74-Kilometer Watch. Text briefing. Destroy the radar garrison and its relief squad, then hold the hydro radar so water shows. The radar pings, two rifles arrive, and the guide sells the watch."
	if id == "black_haze":
		return "Black Haze. Text briefing. Capture the hydro radar and hold it through the longer haze while a second raider wave attacks. The haze closes, a second wave comes through it, and you hold the radar."
	if id == "archipelago_rising":
		return "Archipelago Rising. Text briefing. Sink the boats and the second picket, sail the packer into shallow water, unpack the wharf, and upgrade it. The packer reaches the shallows, the wharf rises, and a squall hits."
	if id == "wrath_of_the_garuda":
		return "Wrath of the Garuda. Text briefing. Destroy the joint enemy fleet and its pickets. A napalm run can help. Calling it does not end the mission. Napalm is armed, pickets cross the bow, and two gunboats arrive."
	if id == "fog_over_pakbeng":
		return "Fog Over Pakbeng. Text briefing. Hold a hydro radar through the longer haze while a second raider wave attacks. An ally breaks first. The haze stays shut, and the radar has to be held. The side cache is optional."
	if id == "keng_tung":
		return "Keng Tung. Text briefing. Freeze the GTFC tank column, then destroy it. Infantry screens the tanks. Toxic Defoliation can freeze them. Casting it does not end the mission. A spray run comes down the road and has to be cut off. If it lands, it defoliates your line and the side cache is lost."
	if id == "plain_of_jars":
		return "Plain of Jars. Text briefing. Hold the beam until the phantom freezes, then destroy the phantom, both batteries, and the screen. The beam holds, the phantom stutters, and the batteries stay up."
	if id == "tonle_sap":
		return "Tonle Sap. Text briefing. Defend the ferry until the longer timer runs out. NMRF trimarans keep arriving. Cryogeddon can help. Casting it does not end the mission. The ferry has to survive the crossing. A squall hits the channel."
	if id == "shattered_monsoon":
		return "Operation Shattered Monsoon. Text briefing. Destroy both enemy superweapons. A garrison screens the citadel. Protocols can help. Casting them does not end the mission. The garrison comes out, then a countdown runs. Destroy both weapons before it hits zero or the mission fails."
	if id == "mae_sai":
		return "Mae Sai. Text briefing. Raise the scaffold yard and keep the drain running until the frame is finished."
	if id == "ruby_market":
		return "Ruby night market. Text briefing. Snap the ruby pit and run the night shift until the purse fills."
	if id == "rare_stock":
		return "Rare-earth stock. Text briefing. Claim the rare-earth node and bring one stock home."
	if id == "channel_crossing":
		return "Channel crossing. Text briefing. Send an amphibious unit across the deep water to the far shore."
	if id == "jammer_drill":
		return "Jammer drill. Text briefing. GPS guidance drops inside the jammer. A fiber link does not."
	if id == "cyber_compound":
		return "Cyber compound. Text briefing. Capture the compound and siphon the enemy purse."
	if id == "arms_bazaar":
		return "Arms bazaar. Text briefing. Capture the bazaar so infantry and drones draw a discount."
	if id == "field_clinic":
		return "Field clinic. Text briefing. Capture the clinic and let it heal the company."
	if id == "hydro_radar":
		return "Hydro radar. Text briefing. Capture the radar so water nodes show on the map."
	if id == "clearance_two":
		return "Clearance two. Text briefing. Buy clearance, then queue and place the drone bay inside the pad."
	if id == "packer_sail":
		return "Packer sail. Text briefing. Sail the packer into shallow water, unpack the wharf, and upgrade it."
	if id == "smart_cast":
		return "Smart-cast drill. Text briefing. Toggle the group. Only the closest ready unit fires."
	if id == "beam_freeze":
		return "Beam freeze. Text briefing. Hold the beam until the target freezes."
	if id == "protocol_bar":
		return "Protocol bar. Text briefing. Cast logistics, arsenal, and oracle once each. A second cast does nothing."
	return ""

func play(id: String) -> bool:
	var ok: bool = false
	if id == "kokang":
		ok = _kokang_story()
	elif id == "tachileik":
		ok = _ruby_market()
	elif id == "shwe_kokko":
		ok = _cyber_compound()
	elif id == "operation_1027":
		ok = _drone_wave()
	elif id == "andaman":
		ok = _channel_crossing()
	elif id == "ghosts_of_patani":
		ok = _jammer_drill()
	elif id == "kilometer_watch":
		ok = _hydro_radar()
	elif id == "black_haze":
		ok = _black_haze()
	elif id == "archipelago_rising":
		ok = _packer_sail()
	elif id == "wrath_of_the_garuda":
		ok = _garuda()
	elif id == "fog_over_pakbeng":
		ok = _fog_pakbeng()
	elif id == "keng_tung":
		ok = _defoliation()
	elif id == "plain_of_jars":
		ok = _beam_freeze()
	elif id == "tonle_sap":
		ok = _tonle()
	elif id == "shattered_monsoon":
		ok = _protocol_bar()
	elif id == "mae_sai":
		ok = _mae_sai()
	elif id == "ruby_market":
		ok = _ruby_market()
	elif id == "rare_stock":
		ok = _rare_stock()
	elif id == "channel_crossing":
		ok = _channel_crossing()
	elif id == "jammer_drill":
		ok = _jammer_drill()
	elif id == "cyber_compound":
		ok = _cyber_compound()
	elif id == "arms_bazaar":
		ok = _arms_bazaar()
	elif id == "field_clinic":
		ok = _field_clinic()
	elif id == "hydro_radar":
		ok = _hydro_radar()
	elif id == "clearance_two":
		ok = _clearance_two()
	elif id == "packer_sail":
		ok = _packer_sail()
	elif id == "smart_cast":
		ok = _smart_cast()
	elif id == "beam_freeze":
		ok = _beam_freeze()
	elif id == "protocol_bar":
		ok = _protocol_bar()
	result_text = "Objective complete" if ok else "Objective stalled"
	return ok

func _mae_sai() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	economy.set_credits(0, 2000)
	var yard: SMBuildYard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.SCAFFOLD
	yard.team = 0
	yard.economy = economy
	yard.center = Vector3.ZERO
	yard.radius = 16.0
	yard.drain_per_sec = 4
	yard.tech_order = [&"scaffold_yard"]
	yard.building_time[&"scaffold_yard"] = 3.0
	yard.building_tier[&"scaffold_yard"] = 1
	if not yard.begin_scaffold(&"scaffold_yard", Vector3(2.0, 0.0, 0.0), 250.0):
		return false
	yard.advance(3.0)
	return yard.finished.has(&"scaffold_yard") and yard.drained > 0

func _ruby_market() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	var goods: SMCommodityNet = SMCommodityNet.new()
	goods.add_node(&"ruby", SMCommodityNet.KIND_RUBY, Vector3(6.0, 0.0, 2.0), 30, false)
	if not goods.snap_refinery(&"ruby", 0):
		return false
	if not goods.set_night_shift(&"ruby", true):
		return false
	var before: int = economy.credits(0)
	goods.advance(2.0, economy)
	return economy.credits(0) - before >= 30

func _rare_stock() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	var goods: SMCommodityNet = SMCommodityNet.new()
	goods.add_node(&"rare", SMCommodityNet.KIND_RARE, Vector3(-6.0, 0.0, 4.0), 0, true)
	if not goods.snap_refinery(&"rare", 0):
		return false
	goods.advance(4.0, economy)
	return goods.stock_of(0) >= 1

func _channel_crossing() -> bool:
	var sim: SMMatch = SMMatch.new()
	sim.setup_phillips("gtfc")
	return sim.cross_channel()

func _jammer_drill() -> bool:
	var ew: SMEwField = SMEwField.new()
	ew.center = Vector3.ZERO
	ew.radius = 1000.0
	ew.penalty = 0.4
	var inside: Vector3 = Vector3(2.0, 0.0, 0.0)
	return ew.accuracy(inside, SMEwField.GPS) < 1.0 and ew.accuracy(inside, SMEwField.FIBER) == 1.0

func _cyber_compound() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	economy.set_credits(1, 80)
	var tech: SMTechNet = SMTechNet.new()
	tech.add_site(&"compound", SMTechNet.CYBER, Vector3.ZERO)
	if not tech.capture(&"compound", 0):
		return false
	tech.advance(2.0, economy, 1)
	return tech.income_of(&"compound") > 0 and tech.siphon_of(&"compound") > 0

func _arms_bazaar() -> bool:
	var tech: SMTechNet = SMTechNet.new()
	tech.add_site(&"bazaar", SMTechNet.BAZAAR, Vector3.ZERO)
	if not tech.capture(&"bazaar", 0):
		return false
	return is_equal_approx(tech.discount(0, "infantry"), 0.8) and is_equal_approx(tech.discount(0, "drone"), 0.8)

func _field_clinic() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	var tech: SMTechNet = SMTechNet.new()
	tech.add_site(&"clinic", SMTechNet.CLINIC, Vector3.ZERO)
	if not tech.capture(&"clinic", 0):
		return false
	tech.advance(2.0, economy, 1)
	return tech.clinic_healed(0) > 0.0

func _hydro_radar() -> bool:
	var tech: SMTechNet = SMTechNet.new()
	tech.add_site(&"radar", SMTechNet.RADAR, Vector3.ZERO)
	if not tech.capture(&"radar", 0):
		return false
	return tech.reveals_water(0)

func _clearance_two() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	economy.set_credits(0, 2000)
	var yard: SMBuildYard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.INTERNAL
	yard.team = 0
	yard.economy = economy
	yard.center = Vector3.ZERO
	yard.radius = 14.0
	yard.clearance = 1
	yard.building_tier[&"drone_bay"] = 2
	yard.building_time[&"drone_bay"] = 3.0
	if yard.queue_internal(&"drone_bay"):
		return false
	if not yard.buy_clearance(2, 200):
		return false
	if not yard.queue_internal(&"drone_bay"):
		return false
	yard.advance(3.0)
	return yard.clearance == 2 and yard.place_finished(&"drone_bay", Vector3(4.0, 0.0, 0.0))

func _packer_sail() -> bool:
	var grid: SMDomainGrid = SMDomainGrid.phillips_layout()
	var yard: SMBuildYard = SMBuildYard.new()
	yard.style = SMBuildYard.Style.MOBILE
	yard.grid = grid
	yard.packer_pos = grid.cell_center(SMDomainGrid.at("phillips", Vector2i(4, 8)))
	if not yard.move_packer(grid.cell_center(SMDomainGrid.at("phillips", Vector2i(18, 5)))):
		return false
	if grid.unit_domain(yard.packer_id) != SMDomainGrid.Domain.SHALLOW:
		return false
	if not yard.unpack(&"gun_wharf"):
		return false
	return yard.upgrade_factory(&"gun_wharf") and yard.factory_level(&"gun_wharf") == 2

func _smart_cast() -> bool:
	var abilities: SMAbilities = SMAbilities.new()
	abilities.add_unit(10, Vector3.ZERO, SMAbilities.TOGGLE, 2.0, 0.6)
	abilities.add_unit(11, Vector3(2.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	abilities.add_unit(12, Vector3(8.0, 0.0, 0.0), SMAbilities.SMART, 3.0, 0.6)
	var ids: Array[int] = [10, 11, 12]
	var toggles: int = abilities.group_toggle(ids)
	var smart: int = abilities.smart_cast(ids, Vector3(2.0, 0.0, 0.0))
	return toggles == 1 and smart == 11 and abilities.fired_count(12) == 0

func _beam_freeze() -> bool:
	var abilities: SMAbilities = SMAbilities.new()
	abilities.add_unit(1, Vector3.ZERO, SMAbilities.BEAM, 1.0, 1.0)
	abilities.add_unit(2, Vector3(3.0, 0.0, 0.0), SMAbilities.TOGGLE, 1.0, 1.0)
	if not abilities.begin_beam(1, 2):
		return false
	abilities.advance(2.0)
	return abilities.beam_done(1) >= 1 and abilities.status_of(2) == SMAbilities.ST_FROZEN

func _protocol_bar() -> bool:
	var economy: RTSEconomy = RTSEconomy.new()
	var abilities: SMAbilities = SMAbilities.new()
	abilities.add_unit(3, Vector3.ZERO, SMAbilities.TOGGLE, 1.0, 1.0)
	var protocols: SMProtocols = SMProtocols.new()
	var first: bool = protocols.cast(&"logistics", economy, 0, abilities, 3)
	var second: bool = protocols.cast(&"arsenal", economy, 0, abilities, 3)
	var third: bool = protocols.cast(&"oracle", economy, 0, abilities, 3)
	var again: bool = protocols.cast(&"logistics", economy, 0, abilities, 3)
	return first and second and third and not again and protocols.credits_bonus == 250 and is_equal_approx(protocols.damage_mult, 1.5) and abilities.status_of(3) == SMAbilities.ST_FROZEN

func _kokang_story() -> bool:
	return _mae_sai() and _ruby_market() and _rare_stock()

func _drone_wave() -> bool:
	var protocols: SMProtocols = SMProtocols.new()
	var economy: RTSEconomy = RTSEconomy.new()
	var abilities: SMAbilities = SMAbilities.new()
	var once: bool = protocols.cast_power(&"drone_swarm_23", economy, 0, abilities, -1)
	var twice: bool = protocols.cast_power(&"drone_swarm_23", economy, 0, abilities, -1)
	return once and not twice and protocols.swarm_count == 23

func _black_haze() -> bool:
	var sight: SMSight = SMSight.new()
	sight.force_weather(true)
	return sight.weather_name == "Strait Haze" and sight.unit_radius(false) < SMSight.UNIT_RADIUS and is_equal_approx(sight.unit_radius(true), SMSight.UNIT_RADIUS)

func _garuda() -> bool:
	var protocols: SMProtocols = SMProtocols.new()
	var economy: RTSEconomy = RTSEconomy.new()
	var abilities: SMAbilities = SMAbilities.new()
	var once: bool = protocols.cast_power(&"su30_napalm", economy, 0, abilities, -1)
	return once and protocols.napalm == 36 and not protocols.cast_power(&"su30_napalm", economy, 0, abilities, -1)

func _fog_pakbeng() -> bool:
	var tech: SMTechNet = SMTechNet.new()
	tech.add_site(&"radar", SMTechNet.RADAR, Vector3.ZERO)
	if not tech.capture(&"radar", 0) or not tech.reveals_water(0):
		return false
	var sight: SMSight = SMSight.new()
	sight.force_weather(true)
	return sight.unit_radius(false) < SMSight.UNIT_RADIUS and is_equal_approx(sight.unit_radius(true), SMSight.UNIT_RADIUS)

func _defoliation() -> bool:
	var protocols: SMProtocols = SMProtocols.new()
	var economy: RTSEconomy = RTSEconomy.new()
	var abilities: SMAbilities = SMAbilities.new()
	var once: bool = protocols.cast_power(&"toxic_defoliation", economy, 0, abilities, -1)
	return once and protocols.defoliation and not protocols.cast_power(&"toxic_defoliation", economy, 0, abilities, -1)

func _tonle() -> bool:
	var protocols: SMProtocols = SMProtocols.new()
	var economy: RTSEconomy = RTSEconomy.new()
	var abilities: SMAbilities = SMAbilities.new()
	abilities.add_unit(3, Vector3.ZERO, SMAbilities.TOGGLE, 1.0, 1.0)
	var once: bool = protocols.cast_power(&"cryogeddon", economy, 0, abilities, 3)
	return once and protocols.cryo_wave and abilities.status_of(3) == SMAbilities.ST_FROZEN and not protocols.cast_power(&"cryogeddon", economy, 0, abilities, 3)
