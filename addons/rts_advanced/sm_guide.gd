class_name SMGuide
extends RefCounted
## First-run copy: controls, the how-to panel, and the Kokang lesson.

static func controls_hint() -> String:
	return "Left-click select. Shift-click adds. Double-click or E selects that type. Right-click ground to move, an enemy to attack. Shift-right-click adds a waypoint. Z lines the company up. Q attack-move. X halt. R moves the rally flag. Ctrl+1-9 stores a group, the number recalls it. A ring marks the order. Click the minimap to jump. F ability. H guide. P opens protocols."

static func howto_text() -> String:
	return "Left-click a unit, or drag a box around your company. An orange ring shows a selected unit's weapon range, and the same ring appears while the pointer rests on a unit.\nRight-click open ground to move. Right-click an enemy to attack. A ring marks that spot, then fades.\nPress Q to attack-move toward the cursor. Press X to halt. Ctrl and 1 through 9 stores a group. Press the number to recall it, and press it again to center the camera.\nShift-click adds a unit. Ctrl-click toggles it. Double-click, or E, selects every unit of that type. Z lines the company up for the next move. Shift-right-click on open ground adds another step. R plants the rally flag, and new units appear beside it. The top bar shows credits gained per second.\nA diamond sits on the lead unit's next step. A thin pulse marks the current objective, and the minimap frames that spot. Hits show a floating number.\nClick the minimap to jump the camera there.\nPress F, or Ability, to use the selected unit's power. Smart-cast fires only the closest ready unit.\nThe column on the right trains units and raises buildings. Walk onto a colored pad to claim it.\nBoats cross deep water. Tanks and infantry stay on land, and they use a shallow ford when one is open.\nMonsoon mud slows tanks and infantry. Strait Haze shortens sight unless a hydro radar is yours. On the Mekong, right-click a bridge to bring it down and open the canal. A captured arms bazaar sells CH-4, Su-30, Orlan-10, and the FLH7 Squad, and skims the enemy purse.\nLow power stops new production until a plant covers the draw, and it silences defenses. Cancel drops the building in progress. A hydro radar lights the river corridor. Right-click a Slag Pillbox or Multigunner with infantry to garrison them, then click that finished building to unload. A second click on a finished Defender-VX swaps its ground and air guns.\nP opens protocols. H opens this guide.\nThe status line reads Objective complete when you win, and Objective failed if your company dies."

static func tutorial_for(mission_id: String) -> String:
	if mission_id == "kokang":
		return "First mission. Select the company, right-click to move, and right-click the raiders to fight. Raise the yard, run the ruby night shift, and bring one rare-earth stock home. If the company dies, the raid fails."
	return ""

static func unit_tip(row: Dictionary) -> String:
	var name: String = str(row.get("display_name", row.get("id", "Unit")))
	var cost: int = int(row.get("cost", 0))
	var hp: int = int(row.get("hp", 0))
	var damage: int = int(row.get("weapon_damage", 0))
	var loco: String = str(row.get("locomotion", "ground"))
	var ability: String = str(row.get("ability", "ability"))
	return "%s. %d credits. HP %d. Damage %d. Moves on %s. F: %s." % [name, cost, hp, damage, loco, ability]

static func building_tip(row: Dictionary) -> String:
	var name: String = str(row.get("display_name", row.get("id", "Building")))
	var role: String = str(row.get("role", "structure"))
	var cost: int = int(row.get("cost", 0))
	var hp: int = int(row.get("hp", 0))
	return "%s. %s. %d credits. HP %d." % [name, role, cost, hp]

static func ability_tip() -> String:
	return "Ability (F). A toggle flips every selected toggle unit. Smart-cast fires only the closest ready unit. A finished beam freezes the nearest enemy."
