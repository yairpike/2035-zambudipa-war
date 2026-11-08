class_name SMArms
extends RefCounted
## Red Alert 3 style dual weapons. Every combat unit row in the faction JSON carries `weapons.primary` and
## `weapons.secondary`. The live slot sets the unit's damage, range, cadence, the target kinds it can hit and
## its muzzle tint. F and the HUD weapon slots swap it; `auto_pick` swaps when only the other slot can hit.

const PRIMARY: String = "primary"
const SECONDARY: String = "secondary"

static func profiles(row: Dictionary) -> Dictionary:
	var raw: Variant = row.get("weapons", null)
	if not (raw is Dictionary):
		return {}
	var both: Dictionary = raw
	if not (both.get(PRIMARY, null) is Dictionary) or not (both.get(SECONDARY, null) is Dictionary):
		return {}
	return both

## Stores the catalog profiles on `u` and marks the primary live.
static func arm(u: RTSUnit, row: Dictionary) -> bool:
	var both: Dictionary = profiles(row)
	if both.is_empty() or not is_instance_valid(u):
		return false
	u.set_meta("arms", both)
	return equip(u, PRIMARY)

static func armed(u: RTSUnit) -> bool:
	return is_instance_valid(u) and u.has_meta("arms")

static func slot_of(u: RTSUnit) -> String:
	if not armed(u):
		return ""
	return str(u.get_meta("weapon_slot", PRIMARY))

static func other(slot: String) -> String:
	return SECONDARY if slot == PRIMARY else PRIMARY

static func profile(u: RTSUnit, slot: String) -> Dictionary:
	if not armed(u):
		return {}
	var both: Dictionary = u.get_meta("arms") as Dictionary
	var raw: Variant = both.get(slot, {})
	return raw as Dictionary if raw is Dictionary else {}

static func targets(p: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = p.get("targets", [])
	if raw is Array:
		for item: Variant in raw:
			out.append(str(item))
	return out

## Makes `slot` the live weapon. The primary is the unit's live stats (missions and upgrades may have changed
## them since spawn); the secondary scales those by its profile against the primary profile, and switching
## back restores them. A drone that spent its missiles keeps firing nothing until it rearms.
static func equip(u: RTSUnit, slot: String) -> bool:
	var p: Dictionary = profile(u, slot)
	if p.is_empty():
		return false
	var live: String = str(u.get_meta("weapon_slot", ""))
	var spent: bool = u.has_meta("attack_bank") and u.attack_damage <= 0.0
	if slot == SECONDARY and live != SECONDARY:
		u.set_meta("arms_base", {
			"damage": float(u.get_meta("attack_bank", 0.0)) if spent else u.attack_damage,
			"range": u.attack_range,
			"interval": u.attack_interval,
		})
	var dmg: float = u.attack_damage
	if slot == SECONDARY:
		var pri: Dictionary = profile(u, PRIMARY)
		var base: Dictionary = u.get_meta("arms_base") as Dictionary
		dmg = float(base["damage"]) * _ratio(p, pri, "damage")
		u.attack_range = float(base["range"]) * _ratio(p, pri, "range")
		u.attack_interval = float(base["interval"]) * _ratio(p, pri, "interval")
		_set_damage(u, dmg, spent)
	elif live == SECONDARY and u.has_meta("arms_base"):
		var back: Dictionary = u.get_meta("arms_base") as Dictionary
		u.attack_range = float(back["range"])
		u.attack_interval = float(back["interval"])
		_set_damage(u, float(back["damage"]), spent)
	u.set_meta("weapon_slot", slot)
	u.set_meta("weapon_name", str(p.get("name", "")))
	u.set_meta("weapon_kind", str(p.get("kind", "")))
	u.set_meta("weapon_mode", str(p.get("mode", "")))
	u.set_meta("weapon_targets", targets(p))
	u.set_meta("muzzle_tint", str(p.get("tint", "#FFD15A")))
	return true

static func _ratio(p: Dictionary, pri: Dictionary, key: String) -> float:
	var under: float = float(pri.get(key, 0.0))
	if under <= 0.0:
		return 1.0
	return float(p.get(key, under)) / under

static func _set_damage(u: RTSUnit, dmg: float, spent: bool) -> void:
	if spent:
		u.set_meta("attack_bank", dmg)
	else:
		u.attack_damage = dmg

## Swaps to the other slot. Returns the slot now live, or "" when `u` has no weapons.
static func toggle(u: RTSUnit) -> String:
	if not armed(u):
		return ""
	var next: String = other(slot_of(u))
	return next if equip(u, next) else ""

## Target class a weapon must list: ground (infantry and vehicles), air, or naval.
static func target_class(category: String) -> String:
	if category == "aircraft":
		return "air"
	if category == "boat":
		return "naval"
	return "ground"

static func can_hit(p: Dictionary, category: String) -> bool:
	return targets(p).has(target_class(category))

## Swaps slots when the live weapon cannot hit `category` and the other can. True when it swapped.
static func auto_pick(u: RTSUnit, category: String) -> bool:
	if not armed(u):
		return false
	var live: String = slot_of(u)
	if can_hit(profile(u, live), category):
		return false
	var spare: String = other(live)
	if not can_hit(profile(u, spare), category):
		return false
	return equip(u, spare)

## One line for a slot: "Coaxial MG  dmg 10  rng 8  ground".
static func describe(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	var line: String = "%s  dmg %d  rng %d  %s" % [str(p.get("name", "")), int(round(float(p.get("damage", 0.0)))), int(round(float(p.get("range", 0.0)))), ", ".join(targets(p))]
	var mode: String = str(p.get("mode", ""))
	return line if mode == "" else "%s (%s)" % [line, mode]
