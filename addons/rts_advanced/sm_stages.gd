class_name SMStages
extends RefCounted
## Red Alert 3 style mission arc laid over a story mission: a foothold, an escalation and a climax, plus one
## optional bonus that pays out on the battlefield.
## Stage 2 opens when the mission reports its foothold: a counter-attack drives in along the paved streets and
## allies arrive by helicopter, landing craft or armoured column. Stage 3 opens when the counter-attack breaks:
## the boss compound wakes (or a timed hold starts) and a street ambush springs near the company. From stage 2
## on, enemy elites, artillery and boats switch weapon slots. The arc is clear when stage 3 has no living
## counter-attackers or boss and any hold has run out.
## Events queue for the presentation layer (banner, minimap ping, drop visuals); nothing here builds a mesh.

const FOOTHOLD: int = 1
const ESCALATION: int = 2
const CLIMAX: int = 3
const REACH: float = 2.8
const ESCAPE: float = 4.0
const SWAP_EVERY: float = 4.0
const FUNDS: int = 600
const VET_HP: float = 1.25
const VET_DMG: float = 1.2
const HOLD_WAVE: float = 10.0
const EVENT_CAP: int = 48

const FOES: Dictionary = {
	"gtfc": {"line": [&"militia", &"amber_tank", &"militia"], "boss": &"amber_tank", "guns": &"ruby_mortar", "boat": &"channel_skiff", "convoy": &"slag_hauler"},
	"nmrf": {"line": [&"river_rifle", &"mangrove_skiff", &"river_rifle"], "boss": &"mangrove_skiff", "guns": &"jade_mortar", "boat": &"sampan", "convoy": &"sampan"},
	"mvd": {"line": [&"clearance_trooper", &"cyan_ifv", &"clearance_trooper"], "boss": &"cyan_ifv", "guns": &"charcoal_mortar", "boat": &"cyan_skiff", "convoy": &"charcoal_apc"},
}
const ALLIES: Dictionary = {
	"gtfc": {"heli": [&"militia", &"militia", &"ruby_mortar"], "landing": [&"channel_skiff", &"militia", &"militia"], "column": [&"amber_tank", &"amber_tank", &"militia"]},
	"nmrf": {"heli": [&"river_rifle", &"river_rifle", &"jade_mortar"], "landing": [&"sampan", &"river_rifle", &"river_rifle"], "column": [&"mangrove_skiff", &"mangrove_skiff", &"river_rifle"]},
	"mvd": {"heli": [&"clearance_trooper", &"clearance_trooper", &"charcoal_mortar"], "landing": [&"cyan_skiff", &"clearance_trooper", &"clearance_trooper"], "column": [&"cyan_ifv", &"charcoal_apc", &"clearance_trooper"]},
}

var mission_id: String = ""
var plan: Dictionary = {}
var stage: int = 0
var field: SMPointer
var economy: RTSEconomy
var protocols: SMProtocols
var grid: SMDomainGrid
var dress: SMMapPlan
var rally: Vector3 = Vector3.ZERO
var ally_faction: String = "gtfc"
var foe_faction: String = "nmrf"
var foe_hp: float = 1.0
var foe_dmg: float = 1.0
var hold_left: float = 0.0
var bonus_state: String = "open"
var reward_paid: String = ""
var foe_swaps: int = 0
var allies: Array[RTSUnit] = []
var history: PackedStringArray = PackedStringArray()
var events: Array[Dictionary] = []
var convoy_rolling: bool = false

var _swap_t: float = 0.0
var _wave_t: float = 0.0
var _hold_spawned: int = 0
var _convoy_seen: bool = false
var _held_at_start: int = -1

static func ids() -> PackedStringArray:
	var out: PackedStringArray = SMCampaign.ids()
	out.append("sop_ruak")
	out.append("phillips")
	return out

## Every mission's arc: stage goals, transmissions, counter-attack, allies, boss or hold, and the bonus.
## Points are world positions on the campaign grids, or Vector2i cells on the skirmish layouts (resolved
## through SMDomainGrid.at).
static func plan_of(id: String) -> Dictionary:
	var east_n: Vector3 = Vector3(30.0, 0.0, -22.0)
	var east_s: Vector3 = Vector3(30.0, 0.0, 22.0)
	if id == "kokang":
		return _plan("Raise the scaffold yard in Laukkai", "Junta trucks are rolling down the market street. Hold the yard. Gunships are inbound.", "Their command post sits in the old casino. Take it down.",
			Vector3(30.0, 0.0, -20.0), "heli", Vector3(-10.0, 0.0, 6.0), {"at": Vector3(18.0, 0.0, 6.0), "kind": "guns", "label": "Casino command post", "fixed": true}, 0.0,
			{"kind": "capture", "at": Vector3(12.0, 0.0, -8.0), "text": "Seize the jade cache on the side street", "reward": "funds"})
	if id == "tachileik":
		return _plan("Clear the caravan ambush", "Smugglers want the rubies back. A counter-raid is coming up the border road. Our armour is on the way.", "The ring boss is holed up in the river customs house. End it.",
			east_n, "column", Vector3(-40.0, 0.0, 30.0), {"at": Vector3(16.0, 0.0, 8.0), "kind": "boss", "label": "Customs house boss", "fixed": true}, 0.0,
			{"kind": "intercept", "at": Vector3(28.0, 0.0, -30.0), "to": Vector3(28.0, 0.0, 30.0), "text": "Stop the smuggler convoy before it crosses the bridge", "reward": "funds"})
	if id == "shwe_kokko":
		return _plan("Clear the compound garrison", "Guards from the next block are pushing in. Choppers are dropping a team on your flank.", "The syndicate director is in the server tower. Bring it down.",
			east_s, "heli", Vector3(-10.0, 0.0, 6.0), {"at": Vector3(16.0, 0.0, 4.0), "kind": "guns", "label": "Syndicate tower", "fixed": true}, 0.0,
			{"kind": "rescue", "at": Vector3(16.0, 0.0, -10.0), "text": "Free the captive runners", "reward": "reinforce"})
	if id == "operation_1027":
		return _plan("Drop the EW towers", "Junta armour is counter-attacking along the highway. Allied helicopters are inbound.", "The regional command bunker is exposed. Finish it.",
			east_n, "heli", Vector3(-10.0, 0.0, 6.0), {"at": Vector3(18.0, 0.0, 0.0), "kind": "guns", "label": "Regional command bunker", "fixed": true}, 0.0,
			{"kind": "jammer", "at": Vector3(16.0, 0.0, 10.0), "text": "Destroy the relay jammer", "reward": "strike"})
	if id == "andaman":
		return _plan("Clear the shore guns", "Patrol boats are closing on the channel. Landing craft are bringing marines in.", "The harbour fort is the last gun line. Silence it.",
			east_s, "landing", Vector3(-1.0, 0.0, 22.0), {"at": Vector3(16.0, 0.0, -4.0), "kind": "guns", "label": "Harbour fort", "fixed": true}, 0.0,
			{"kind": "rescue", "at": Vector3(-16.0, 0.0, 8.0), "text": "Rescue the stranded boat crew", "reward": "reinforce"})
	if id == "ghosts_of_patani":
		return _plan("Hunt the jammer ghost", "More ghosts are slipping through the rubber groves. Air cavalry is dropping in to help.", "Their safe house is in the old market hall. Clear it.",
			east_n, "heli", Vector3(-10.0, 0.0, 6.0), {"at": Vector3(16.0, 0.0, -6.0), "kind": "boss", "label": "Market hall safe house", "fixed": true}, 0.0,
			{"kind": "rescue", "at": Vector3(-14.0, 0.0, 8.0), "text": "Rescue the village scouts", "reward": "veteran"})
	if id == "kilometer_watch":
		return _plan("Clear the radar garrison", "An armoured push is coming down the river road. Our column is moving up.", "They are throwing everything at the radar. Hold for thirty seconds.",
			east_s, "column", Vector3(-40.0, 0.0, -30.0), {}, 30.0,
			{"kind": "capture", "at": Vector3(-16.0, 0.0, 10.0), "text": "Capture the relay mast", "reward": "veteran"})
	if id == "black_haze":
		return _plan("Capture the hydro radar", "Boats are landing raiders under the haze. Our landing craft are coming in.", "The haze flagship is in range. Sink it.",
			east_n, "landing", Vector3(-30.0, 0.0, 24.0), {"at": Vector3(18.0, 0.0, 4.0), "kind": "boat", "label": "Haze flagship", "fixed": false}, 0.0,
			{"kind": "intercept", "at": Vector3(28.0, 0.0, 30.0), "to": Vector3(28.0, 0.0, -30.0), "text": "Stop the haze convoy", "reward": "funds"})
	if id == "archipelago_rising":
		return _plan("Sink the shore boats", "Gunboats are counter-attacking the reef. Landing craft bring our crews.", "Their island battery covers the strait. Destroy it.",
			east_s, "landing", Vector3(-30.0, 0.0, 24.0), {"at": Vector3(16.0, 0.0, 8.0), "kind": "guns", "label": "Island battery", "fixed": true}, 0.0,
			{"kind": "capture", "at": Vector3(-18.0, 0.0, -10.0), "text": "Seize the fuel depot", "reward": "funds"})
	if id == "wrath_of_the_garuda":
		return _plan("Sink the joint picket", "The fleet is turning to fight. Landing craft carry our marines.", "The flagship is coming about. Sink it.",
			east_n, "landing", Vector3(-30.0, 0.0, 24.0), {"at": Vector3(18.0, 0.0, -2.0), "kind": "boat", "label": "Joint flagship", "fixed": false}, 0.0,
			{"kind": "rescue", "at": Vector3(18.0, 0.0, 8.0), "text": "Rescue the downed pilots", "reward": "veteran"})
	if id == "fog_over_pakbeng":
		return _plan("Capture the hydro radar", "Raiders are crossing the Mekong in the fog. Helicopters drop a team on the bank.", "Their last wave hits the radar now. Hold for thirty seconds.",
			east_s, "heli", Vector3(-10.0, 0.0, 6.0), {}, 30.0,
			{"kind": "capture", "at": Vector3(-14.0, 0.0, 8.0), "text": "Secure the field clinic", "reward": "reinforce"})
	if id == "keng_tung":
		return _plan("Freeze the tank column", "A second column is coming down the valley road. Our armour is moving up.", "Their forward command is dug in at the tea station. Take it.",
			east_n, "column", Vector3(-40.0, 0.0, 30.0), {"at": Vector3(18.0, 0.0, -4.0), "kind": "guns", "label": "Tea station command", "fixed": true}, 0.0,
			{"kind": "intercept", "duty": "spray", "at": Vector3(-16.0, 0.0, 12.0), "text": "Intercept the defoliant sprayer", "reward": "veteran"})
	if id == "plain_of_jars":
		return _plan("Fire the beam at the phantom", "Mortar teams are moving through the jar fields. Gunships are dropping support.", "The plateau command post is exposed. Destroy it.",
			east_s, "heli", Vector3(-10.0, 0.0, 6.0), {"at": Vector3(18.0, 0.0, 0.0), "kind": "boss", "label": "Plateau command post", "fixed": true}, 0.0,
			{"kind": "jammer", "at": Vector3(16.0, 0.0, -12.0), "text": "Destroy the battery radar jammer", "reward": "strike"})
	if id == "tonle_sap":
		return _plan("Get the ferry across", "Trimarans are circling the ferry. Landing craft are bringing reinforcements.", "Their floating fortress has moved in. Sink it.",
			east_n, "landing", Vector3(-30.0, 0.0, 24.0), {"at": Vector3(16.0, 0.0, 6.0), "kind": "boat", "label": "Floating fortress", "fixed": false}, 0.0,
			{"kind": "rescue", "at": Vector3(-18.0, 0.0, 6.0), "text": "Rescue the fishing crew", "reward": "reinforce"})
	if id == "shattered_monsoon":
		var arc: Dictionary = _plan("Break the citadel guard", "Citadel armour is counter-attacking along the ring road. Our column is coming in.", "The citadel command spire is open. Bring it down.",
			east_s, "column", Vector3(-40.0, 0.0, -30.0), {"at": Vector3(18.0, 0.0, 0.0), "kind": "guns", "label": "Command spire", "fixed": true}, 0.0,
			{"kind": "jammer", "at": Vector3(18.0, 0.0, -8.0), "text": "Destroy the citadel power grid", "reward": "veteran"})
		arc["guard"] = [Vector3(6.0, 0.0, 6.0), Vector3(6.0, 0.0, -6.0)]
		return arc
	if id == "sop_ruak":
		return _plan("Claim a site in the Golden Triangle", "Iskandar is sending a column down the river road. Our armour is coming in from the west.", "His command compound is open. Destroy it.",
			Vector2i(30, 24), "column", Vector2i(1, 24), {"at": Vector2i(27, 24), "kind": "guns", "label": "Iskandar's compound", "fixed": true}, 0.0,
			{"kind": "capture", "at": Vector2i(12, 22), "text": "Capture the bazaar", "reward": "funds"})
	if id == "phillips":
		return _plan("Claim a site on the channel", "Bo Mya is counter-attacking across the channel. Landing craft are bringing marines.", "His command compound is exposed. Destroy it.",
			Vector2i(33, 13), "landing", Vector2i(19, 8), {"at": Vector2i(32, 12), "kind": "guns", "label": "Bo Mya's compound", "fixed": true}, 0.0,
			{"kind": "rescue", "at": Vector2i(8, 12), "text": "Rescue the allied marines", "reward": "reinforce"})
	return {}

static func _plan(goal: String, call_two: String, call_three: String, counter_from: Variant, allies_mode: String, allies_from: Variant, boss: Dictionary, hold: float, bonus: Dictionary) -> Dictionary:
	return {
		"goal": goal,
		"calls": [call_two, call_three],
		"counter_from": counter_from,
		"allies": allies_mode,
		"allies_from": allies_from,
		"boss": boss,
		"hold": hold,
		"bonus": bonus,
		"guard": [],
	}

static func stage_title(n: int) -> String:
	if n == FOOTHOLD:
		return "Foothold"
	if n == ESCALATION:
		return "Escalation"
	return "Climax"

## Starts stage 1 and lays out the bonus. `foe` and `ally` are faction ids; black_market ground troops wear MVD kit.
func bind(id: String, p_field: SMPointer, p_economy: RTSEconomy, p_rally: Vector3, p_grid: SMDomainGrid, ally: String, foe: String) -> bool:
	plan = plan_of(id)
	if plan.is_empty() or p_field == null:
		return false
	mission_id = id
	field = p_field
	economy = p_economy
	rally = p_rally
	grid = p_grid
	dress = SMMapPlan.dressing(id)
	ally_faction = ally if ALLIES.has(ally) else "gtfc"
	foe_faction = foe if FOES.has(foe) else "mvd"
	stage = FOOTHOLD
	hold_left = float(plan.get("hold", 0.0))
	for at: Variant in plan["guard"]:
		var g: RTSUnit = _spawn_foe(_point(at), _kind("line", 1), "guard", "Citadel guard", 130.0, 4.0, 8.0)
		if g != null:
			g.set_meta("stage_unit", true)
	_lay_bonus()
	_mark("stage:1")
	_emit("stage", str(plan["goal"]), rally, FOOTHOLD)
	return true

## Goods nodes and tech sites the player holds on a skirmish map.
static func holdings(goods: SMCommodityNet, tech: SMTechNet) -> int:
	var n: int = 0
	if goods != null:
		for node: Dictionary in goods.nodes:
			if int(node.get("team", -1)) == SMPointer.PLAYER:
				n += 1
	if tech != null:
		for site: Dictionary in tech.sites:
			if int(site.get("owner", -1)) == SMPointer.PLAYER:
				n += 1
	return n

## Skirmish step: the foothold is one more node or site than the player held when the arc began.
func skirmish_tick(delta: float, goods: SMCommodityNet, tech: SMTechNet) -> void:
	var held: int = holdings(goods, tech)
	if _held_at_start < 0:
		_held_at_start = held
	tick(delta, held > _held_at_start)

## The far side's colours on a skirmish map: never the player's own faction.
static func rival_of(player: String, first: String, second: String) -> String:
	return second if player == first else first

func active() -> bool:
	return stage > 0

## One step. `foothold` is the mission's own stage-1 test (yard raised, garrison cleared, radar held...).
func tick(delta: float, foothold: bool) -> void:
	if stage <= 0 or field == null:
		return
	_bonus_tick()
	if stage == FOOTHOLD and foothold and not _any("guard"):
		_escalate()
	elif stage == ESCALATION and not _any("counter"):
		_climax()
	elif stage == CLIMAX:
		_climax_tick(delta)
	if stage >= ESCALATION:
		_swap_tick(delta)

func cleared() -> bool:
	return stage == CLIMAX and hold_left <= 0.0 and not _any("counter") and not _any("boss")

## Duties the current stage wants dead.
func targets() -> PackedStringArray:
	if stage == FOOTHOLD:
		return PackedStringArray(["guard"]) if _any("guard") else PackedStringArray()
	if stage == ESCALATION:
		return PackedStringArray(["counter"])
	if stage == CLIMAX:
		return PackedStringArray(["counter", "boss"])
	return PackedStringArray()

## A living stage target, or INF when the mission's own marker should lead.
func beacon() -> Vector3:
	for duty: String in targets():
		var u: RTSUnit = _first(duty)
		if u != null:
			return u.global_position
	return Vector3.INF

func goal_line() -> String:
	if stage == FOOTHOLD:
		return str(plan.get("goal", ""))
	if stage == ESCALATION:
		return "Break the counter-attack (%d)" % _count("counter")
	var boss: Dictionary = plan.get("boss", {}) as Dictionary
	if hold_left > 0.0:
		return "Hold the line: %d seconds (%d attackers)" % [int(ceil(hold_left)), _count("counter")]
	if not boss.is_empty() and _any("boss"):
		return "Destroy %s" % str(boss["label"])
	if _any("counter"):
		return "Clear the street ambush (%d)" % _count("counter")
	return "All stages clear"

func progress_line() -> String:
	if stage <= 0:
		return ""
	return "Stage %d/3: %s" % [stage, goal_line()]

func bonus_text() -> String:
	return str((plan.get("bonus", {}) as Dictionary).get("text", ""))

func bonus_line() -> String:
	if bonus_state == "done":
		return "Bonus done: %s" % bonus_text()
	if bonus_state == "failed":
		return "Bonus failed: %s" % bonus_text()
	return "Bonus: %s" % bonus_text()

func bonus_kind() -> String:
	return str((plan.get("bonus", {}) as Dictionary).get("kind", ""))

func bonus_at() -> Vector3:
	return _point((plan.get("bonus", {}) as Dictionary).get("at", Vector3.INF))

## Duty the bonus needs dead (jammer or convoy), or "" for reach bonuses.
func bonus_duty() -> String:
	var kind: String = bonus_kind()
	if kind == "jammer":
		return "jammer"
	if kind == "intercept":
		return str((plan.get("bonus", {}) as Dictionary).get("duty", "convoy"))
	return ""

func fail_bonus() -> void:
	if bonus_state != "open":
		return
	bonus_state = "failed"
	_mark("bonus:failed")
	_emit("bonus", "The bonus slipped away.", bonus_at(), stage)

## Pops queued events for the presentation layer.
func drain() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out

func _escalate() -> void:
	stage = ESCALATION
	_mark("stage:2")
	var from: Vector3 = _point(plan["counter_from"])
	var line: Array = (FOES[foe_faction] as Dictionary)["line"]
	for i: int in line.size():
		var u: RTSUnit = _spawn_foe(from + Vector3(0.0, 0.0, 1.6 * float(i)), line[i] as StringName, "counter", "Counter-attack", 110.0, 0.0, 8.0)
		if u != null:
			u.set_meta("road", true)
			u.set_path(route_for(u, u.global_position, rally))
	_mark("counter:%d" % line.size())
	var calls: Array = plan["calls"]
	_emit("stage", str(calls[0]), from, ESCALATION)
	_arrive()
	if bonus_kind() == "intercept" and bonus_state == "open":
		_roll_convoy()

func _climax() -> void:
	stage = CLIMAX
	_mark("stage:3")
	var calls: Array = plan["calls"]
	var boss: Dictionary = plan.get("boss", {}) as Dictionary
	var at: Vector3 = rally
	if not boss.is_empty():
		at = _point(boss["at"])
		var fixed: bool = bool(boss.get("fixed", false))
		var b: RTSUnit = _spawn_foe(at, _kind(str(boss["kind"]), 0), "boss", str(boss["label"]), 340.0, 0.0 if fixed else 2.5, 10.0)
		if b != null:
			b.set_meta("elite", true)
			b.attack_range = 12.0
			SMArms.equip(b, SMArms.SECONDARY)
		_mark("boss")
		_emit("boss", str(calls[1]), at, CLIMAX, {"label": str(boss["label"]), "fixed": fixed})
	else:
		_emit("stage", str(calls[1]), rally, CLIMAX)
	_ambush()

func _climax_tick(delta: float) -> void:
	if hold_left <= 0.0:
		return
	hold_left = maxf(0.0, hold_left - delta)
	_wave_t += delta
	if _wave_t >= HOLD_WAVE and hold_left > 0.0:
		_wave_t = 0.0
		_hold_spawned += 1
		var from: Vector3 = _point(plan["counter_from"])
		var u: RTSUnit = _spawn_foe(from, _kind("line", _hold_spawned % 3), "counter", "Counter-attack", 100.0, 0.0, 8.0)
		if u != null:
			u.set_meta("road", true)
			u.set_path(route_for(u, u.global_position, rally))
		_mark("wave:%d" % _hold_spawned)
		_emit("ping", "", from, CLIMAX)

## Two counter-attackers break out of the paved cells nearest the company, never on top of it.
func _ambush() -> void:
	var near: Vector3 = _company_center()
	var spots: Array[Vector3] = _street_spots(near, 6.0, 14.0, 2)
	if spots.is_empty():
		spots = [near + Vector3(9.0, 0.0, 4.0), near + Vector3(9.0, 0.0, -4.0)]
	for at: Vector3 in spots:
		var u: RTSUnit = _spawn_foe(at, _kind("line", 0), "counter", "Street ambush", 90.0, 0.0, 7.0)
		if u != null:
			u.set_meta("ambush", true)
	_mark("ambush:%d" % spots.size())
	_emit("ambush", "Ambush! Enemy troops in the side streets.", spots[0], CLIMAX)

func _arrive() -> void:
	var mode: String = str(plan.get("allies", "heli"))
	var kinds: Array = (ALLIES[ally_faction] as Dictionary)[mode]
	var from: Vector3 = _point(plan["allies_from"])
	var dest: Vector3 = rally + Vector3(-2.0, 0.0, 3.0)
	var drop: Vector3 = dest if mode == "heli" else from
	for i: int in kinds.size():
		var offset: Vector3 = Vector3(1.6 * float(i), 0.0, 0.8 * float(i % 2))
		var u: RTSUnit = field.spawn(SMPointer.PLAYER, drop + offset, kinds[i] as StringName, false)
		if u == null:
			continue
		u.position = field.open_spot(u, u.position)
		u.set_meta("arrived_by", mode)
		if mode == "column":
			u.set_path(route_for(u, u.global_position, dest + offset))
		elif mode == "landing":
			u.set_path(PackedVector3Array([dest + offset]))
		allies.append(u)
	_mark("allies:%s" % mode)
	var line: String = "Helicopters are dropping reinforcements."
	if mode == "landing":
		line = "Landing craft are coming ashore."
	elif mode == "column":
		line = "An armoured column is rolling in on the road."
	_emit("allies", line, drop, ESCALATION, {"mode": mode, "to": dest})

func _swap_tick(delta: float) -> void:
	_swap_t += delta
	if _swap_t < SWAP_EVERY:
		return
	_swap_t = 0.0
	var before: int = foe_swaps
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not _living(u) or not SMArms.armed(u) or not u.has_meta("stage_unit"):
			continue
		var prey: RTSUnit = u.attack_target
		if _living(prey) and SMArms.auto_pick(u, field.category_of(prey.unit_type)):
			foe_swaps += 1
			continue
		if _commanded(u) and SMArms.toggle(u) != "":
			foe_swaps += 1
	if foe_swaps > before and not history.has("swap:%d" % stage):
		_mark("swap:%d" % stage)
		_emit("swap", "Enemy commanders are switching weapon modes.", _swap_at(), stage)

## Elites, artillery and boats get slot orders from their commander; line troops only auto-pick.
func _commanded(u: RTSUnit) -> bool:
	if bool(u.get_meta("elite", false)):
		return true
	var kind: String = str(u.unit_type)
	return kind.ends_with("_mortar") or kind.ends_with("_tube") or field.category_of(u.unit_type) == "boat"

func _swap_at() -> Vector3:
	var b: RTSUnit = _first("boss")
	if b != null:
		return b.global_position
	var c: RTSUnit = _first("counter")
	return c.global_position if c != null else rally

func _lay_bonus() -> void:
	var b: Dictionary = plan.get("bonus", {}) as Dictionary
	var kind: String = str(b.get("kind", ""))
	var at: Vector3 = bonus_at()
	if kind == "rescue":
		var kinds: Array = (ALLIES[ally_faction] as Dictionary)["heli"]
		for i: int in 2:
			var u: RTSUnit = field.spawn(SMPointer.PLAYER, at + Vector3(1.4 * float(i), 0.0, 0.0), kinds[i] as StringName, false)
			if u == null:
				continue
			u.position = field.open_spot(u, u.position)
			u.set_meta("objective", true)
			u.set_meta("pinned", true)
			u.set_meta("free_speed", u.speed)
			u.set_meta("free_damage", u.attack_damage)
			u.set_meta("duty", "pinned")
			u.speed = 0.0
			u.attack_damage = 0.0
			_tag(u, "Pinned squad")
	elif kind == "jammer":
		var j: RTSUnit = _spawn_foe(at, _kind("guns", 0), "jammer", "Jammer", 160.0, 0.0, 0.0)
		if j != null:
			j.attack_damage = 0.0
	elif kind == "intercept" and not b.has("duty"):
		var start: Vector3 = _point(b.get("at", rally))
		for i: int in 2:
			var c: RTSUnit = _spawn_foe(start + Vector3(0.0, 0.0, -1.8 * float(i)), _kind("convoy", 0), "convoy", "Supply convoy", 140.0, 2.4, 0.0)
			if c != null:
				c.attack_damage = 0.0
	_emit("bonus_site", "", at, FOOTHOLD, {"bonus": kind})

func _roll_convoy() -> void:
	var b: Dictionary = plan.get("bonus", {}) as Dictionary
	if b.has("duty"):
		return
	var to: Vector3 = _point(b.get("to", rally))
	for u: RTSUnit in _all("convoy"):
		u.set_path(route_for(u, u.global_position, to))
	convoy_rolling = true
	_mark("convoy")
	_emit("convoy", "A supply convoy is moving on the streets.", _point(b.get("at", rally)), ESCALATION)

func _bonus_tick() -> void:
	if bonus_state != "open":
		return
	var b: Dictionary = plan.get("bonus", {}) as Dictionary
	var kind: String = str(b.get("kind", ""))
	if kind == "capture":
		if _company_near(bonus_at()):
			_win_bonus()
	elif kind == "rescue":
		var pinned: Array[RTSUnit] = _all("pinned")
		if pinned.is_empty():
			fail_bonus()
		elif _company_near(pinned[0].global_position):
			for u: RTSUnit in pinned:
				u.set_meta("objective", false)
				u.set_meta("pinned", false)
				u.set_meta("duty", "")
				u.speed = float(u.get_meta("free_speed", 6.0))
				u.attack_damage = float(u.get_meta("free_damage", 10.0))
				_tag(u, "")
			_win_bonus()
	elif kind == "jammer":
		if not _any("jammer"):
			_win_bonus()
	elif kind == "intercept":
		var duty: String = bonus_duty()
		if _any(duty):
			_convoy_seen = true
			if duty == "convoy":
				var to: Vector3 = _point(b.get("to", rally))
				for u: RTSUnit in _all("convoy"):
					if _flat(u.global_position).distance_to(_flat(to)) <= ESCAPE:
						fail_bonus()
						return
		elif _convoy_seen:
			_win_bonus()

func _win_bonus() -> void:
	bonus_state = "done"
	var reward: String = str((plan.get("bonus", {}) as Dictionary).get("reward", "funds"))
	reward_paid = reward
	var line: String = ""
	if reward == "funds":
		if economy != null:
			economy.earn(SMPointer.PLAYER, FUNDS)
		line = "Bonus complete. Bonus funds: +600 credits."
	elif reward == "reinforce":
		var kinds: Array = (ALLIES[ally_faction] as Dictionary)["column"]
		for i: int in kinds.size():
			var u: RTSUnit = field.spawn(SMPointer.PLAYER, rally + Vector3(-3.0 + 1.6 * float(i), 0.0, 4.0), kinds[i] as StringName, false)
			if u != null:
				u.position = field.open_spot(u, u.position)
				u.set_meta("arrived_by", "reward")
				allies.append(u)
		line = "Bonus complete. Reinforcements are on the way."
	elif reward == "veteran":
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if not _living(u) or bool(u.get_meta("objective", false)):
				continue
			u.set_meta("veteran", int(u.get_meta("veteran", 0)) + 1)
			u.max_hp *= VET_HP
			u.hp = minf(u.max_hp, u.hp * VET_HP)
			u.attack_damage *= VET_DMG
		line = "Bonus complete. Your troops earn a veterancy crate."
	elif reward == "strike":
		if protocols != null:
			for id: StringName in protocols.cool_left.keys():
				protocols.cool_left[id] = 0.0
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			if _living(u) and u.has_meta("f_ready"):
				u.set_meta("f_ready", 0.0)
		line = "Bonus complete. Air-strike cooldowns are reset."
	_mark("bonus:done:%s" % reward)
	_emit("bonus", line, bonus_at(), stage, {"reward": reward})

## Corner points of a walk over the paved cells from near `from` toward `to`, ending at `to`. When the streets
## do not connect (a channel between two towns) the walk stops at the paved cell nearest `to`. With no dressing
## it is a straight line.
func street_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if dress == null or grid == null or dress.paved.is_empty():
		out.append(to)
		return out
	var start: Vector2i = _paved_near(grid.cell_at(from))
	var goal: Vector2i = _paved_near(grid.cell_at(to))
	if start.x < 0 or goal.x < 0:
		out.append(to)
		return out
	var came: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var closest: Vector2i = start
	var closest_d: int = (start - goal).length_squared()
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var d: int = (c - goal).length_squared()
		if d < closest_d:
			closest_d = d
			closest = c
		if c == goal:
			break
		for s: Vector2i in steps:
			var n: Vector2i = c + s
			if came.has(n) or not dress.paved.has(n):
				continue
			came[n] = c
			queue.append(n)
	if not came.has(goal):
		goal = closest
	var cells: Array[Vector2i] = []
	var walk: Vector2i = goal
	while walk != start:
		cells.push_front(walk)
		walk = came[walk] as Vector2i
	cells.push_front(start)
	for i: int in cells.size():
		var corner: bool = i == 0 or i == cells.size() - 1
		if not corner:
			corner = (cells[i] - cells[i - 1]) != (cells[i + 1] - cells[i])
		if corner:
			var p: Vector3 = grid.cell_center(cells[i])
			out.append(Vector3(p.x, 0.0, p.z))
	out.append(to)
	return out

## The street walk for one unit, finished off the streets by that unit's own nav grid (land, water or both).
func route_for(u: RTSUnit, from: Vector3, to: Vector3) -> PackedVector3Array:
	var route: PackedVector3Array = street_route(from, to)
	var nav: RTSGridNav = field.nav_for_unit(u) if field != null and u != null else null
	if nav == null or route.size() < 2:
		return route
	var tail: PackedVector3Array = nav.find_path(route[route.size() - 2], to)
	if tail.is_empty():
		return route
	route.resize(route.size() - 1)
	route.append_array(tail)
	return route

func _paved_near(c: Vector2i) -> Vector2i:
	if dress.paved.has(c):
		return c
	for r: int in range(1, 10):
		var best: Vector2i = Vector2i(-1, -1)
		var best_d: int = 1 << 20
		for dx: int in range(-r, r + 1):
			for dy: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				var d: int = dx * dx + dy * dy
				if dress.paved.has(n) and d < best_d:
					best_d = d
					best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

func _street_spots(near: Vector3, lo: float, hi: float, want: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if dress == null or grid == null:
		return out
	var picks: Array = []
	for key: Variant in dress.paved.keys():
		if not (key is Vector2i):
			continue
		var p: Vector3 = grid.cell_center(key as Vector2i)
		var d: float = _flat(p).distance_to(_flat(near))
		if d >= lo and d <= hi:
			picks.append([d, Vector3(p.x, 0.0, p.z)])
	picks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for row: Array in picks:
		var p: Vector3 = row[1]
		var spaced: bool = true
		for q: Vector3 in out:
			if _flat(q).distance_to(_flat(p)) < 4.0:
				spaced = false
		if spaced:
			out.append(p)
		if out.size() >= want:
			break
	return out

func _company_center() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and not bool(u.get_meta("objective", false)):
			sum += u.global_position
			n += 1
	return rally if n == 0 else Vector3(sum.x / float(n), 0.0, sum.z / float(n))

func _company_near(at: Vector3) -> bool:
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if _living(u) and not bool(u.get_meta("objective", false)) and _flat(u.global_position).distance_to(_flat(at)) <= REACH:
			return true
	return false

func _spawn_foe(at: Vector3, kind: StringName, duty: String, label: String, hp: float, speed: float, damage: float) -> RTSUnit:
	field.next_look = foe_faction
	var u: RTSUnit = field.spawn(SMPointer.ENEMY, at, kind, false)
	if u == null:
		return null
	u.position = field.open_spot(u, u.position)
	u.max_hp = hp * foe_hp
	u.hp = u.max_hp
	if speed > 0.0:
		u.speed = speed
	elif duty == "boss" or duty == "jammer":
		u.speed = 0.0
	u.attack_damage = damage * foe_dmg
	u.set_meta(&"foe_scaled", true)
	u.set_meta("duty", duty)
	u.set_meta("stage_unit", true)
	_tag(u, label)
	return u

func _tag(u: RTSUnit, label: String) -> void:
	var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
	if tag != null and label != "":
		tag.text = label

func _kind(role: String, i: int) -> StringName:
	var row: Dictionary = FOES[foe_faction] as Dictionary
	var v: Variant = row.get(role, row["boss"])
	if v is Array:
		var list: Array = v
		return list[i % list.size()] as StringName
	return v as StringName

func _point(v: Variant) -> Vector3:
	if v is Vector3:
		return v as Vector3
	if v is Vector2i and grid != null:
		var key: String = "phillips" if mission_id == "phillips" else mission_id
		var c: Vector3 = grid.cell_center(SMDomainGrid.at(key, v as Vector2i))
		return Vector3(c.x, 0.0, c.z)
	return Vector3.INF

func _first(duty: String) -> RTSUnit:
	for u: RTSUnit in field.units:
		if _living(u) and str(u.get_meta("duty", "")) == duty:
			return u
	return null

func _all(duty: String) -> Array[RTSUnit]:
	var out: Array[RTSUnit] = []
	for u: RTSUnit in field.units:
		if _living(u) and str(u.get_meta("duty", "")) == duty:
			out.append(u)
	return out

func _any(duty: String) -> bool:
	return _first(duty) != null

func _count(duty: String) -> int:
	return _all(duty).size()

func _living(u: RTSUnit) -> bool:
	return u != null and is_instance_valid(u) and u.is_alive()

func _mark(entry: String) -> void:
	history.append(entry)

func _emit(kind: String, text: String, at: Vector3, on_stage: int, extra: Dictionary = {}) -> void:
	var e: Dictionary = {"kind": kind, "text": text, "at": at, "stage": on_stage}
	e.merge(extra)
	events.append(e)
	if events.size() > EVENT_CAP:
		events.remove_at(0)

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
