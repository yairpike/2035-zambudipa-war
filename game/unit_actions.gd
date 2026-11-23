extends RefCounted
## Actions a unit can actually perform. Idle, move, attack and ability come from the
## faction row. Deploy is the packer's brace clip. Secondary is the second weapon profile.
## Crawl and hide are not actions this project plays, so they are not listed.

const ORDER: PackedStringArray = ["idle", "move", "attack", "ability", "deploy", "secondary"]

static func list_for(row: Dictionary) -> PackedStringArray:
	var have: Dictionary = {}
	have["idle"] = true
	if float(row.get("speed", 0.0)) > 0.0:
		have["move"] = true
	var armed: bool = not SMArms.profiles(row).is_empty()
	if armed or float(row.get("weapon_damage", 0.0)) > 0.0:
		have["attack"] = true
	if str(row.get("ability", "")) != "":
		have["ability"] = true
	if str(row.get("id", "")) == "packer":
		have["deploy"] = true
	if armed:
		have["secondary"] = true
	var out: PackedStringArray = PackedStringArray()
	for key: String in ORDER:
		if bool(have.get(key, false)):
			out.append(key)
	return out

static func has(row: Dictionary, action: String) -> bool:
	return list_for(row).has(action)
