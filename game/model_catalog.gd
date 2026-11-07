extends RefCounted
## Per-model data the registry applies on mount: forward-yaw corrections and building materials.
## Game forward is -Z. Every yaw here was checked on a facing sheet (tools/facing_sheet.gd).

## Rigged Tripo models come out of the retarget facing about +X. Bipeds: hip and shoulder line averaged over the walk clip.
## Dogs: head-to-tail line.
const RIGGED_YAW: Dictionary = {
	"amber_scout": 92.2,
	"charcoal_bike": 88.9,
	"clearance_engineer": 95.3,
	"clearance_trooper": 96.9,
	"crimson_sapper": 78.7,
	"cyan_sentry": 90.0,
	"emerald_cutter": 90.4,
	"kachin_dog": 48.4,
	"militia": 90.1,
	"olive_ranger": 104.3,
	"olive_sapper": 91.4,
	"packer": 90.0,
	"packer_escort": 84.8,
	"relay_van": 87.3,
	"river_rifle": 86.6,
	"ruby_lancer": 99.4,
	"ruby_mortar": 86.9,
	"wharf_gun": 91.5,
}

## Static Tripo game models (game/models/tripo/ or the store's models-tripo set). Unlisted ids face -Z already.
const TRIPO_YAW: Dictionary = {
	"cyan_gunship": 90.0,
	"plantation_bomber": 90.0,
}

## Older stand-in models in game/models/. All face -Z.
const STANDIN_YAW: Dictionary = {}

const BAMBOO: String = "bamboo_thatch"
const TIMBER: String = "timber"
const BRICK: String = "brick_plaster"
const CONCRETE: String = "concrete_rebar"
const STEEL: String = "steel_sheet"
const GLASS: String = "glass_led"
const STONE: String = "stone"
const KINDS: PackedStringArray = ["bamboo_thatch", "timber", "brick_plaster", "concrete_rebar", "steel_sheet", "glass_led", "stone"]

## One or two materials per building, main material first. Read off the concept sheets and texture colours.
const MATERIALS: Dictionary = {
	"bamboo_hide": [BAMBOO, TIMBER],
	"barracks": [BRICK, TIMBER],
	"flak_slag_mast": [STEEL, BRICK],
	"gtfc_airfield": [BRICK, STEEL],
	"gtfc_naval_yard": [STEEL, TIMBER],
	"gtfc_war_factory": [BRICK, STEEL],
	"salween_hydro": [CONCRETE, STEEL],
	"scaffold_yard": [BAMBOO, BRICK],
	"slag_pillbox": [CONCRETE, STEEL],
	"slag_refinery": [STEEL, CONCRETE],
	"tech_center": [BRICK, STEEL],
	"command_hub": [STEEL, GLASS],
	"defender_vx": [STEEL, GLASS],
	"drone_bay": [STEEL, GLASS],
	"hub_refinery": [STEEL, GLASS],
	"mvd_airfield": [CONCRETE, GLASS],
	"mvd_naval_yard": [STEEL, GLASS],
	"mvd_war_factory": [STEEL, GLASS],
	"siege_works": [STEEL, GLASS],
	"solar_biomass": [GLASS, STEEL],
	"spectrum_prism": [GLASS, STEEL],
	"swarm_hive": [STEEL, GLASS],
	"airfield": [STEEL, TIMBER],
	"naval_yard": [CONCRETE, STEEL],
	"war_factory": [CONCRETE, STEEL],
	"corsair_barracks": [TIMBER, BAMBOO],
	"gun_wharf": [TIMBER, STEEL],
	"multigunner": [STEEL, TIMBER],
	"nmrf_airfield": [TIMBER, STEEL],
	"nmrf_naval_yard": [TIMBER, STEEL],
	"nmrf_war_factory": [TIMBER, STEEL],
	"tidal_turbine": [STEEL, TIMBER],
	"tide_refinery": [STEEL, TIMBER],
	"wave_force": [STEEL, CONCRETE],
	"packer": [STEEL],
	"border_casino": [CONCRETE, GLASS],
	"border_guesthouse": [TIMBER, BRICK],
	"burmese_pagoda": [STONE, BRICK],
	"casino_tower": [GLASS, CONCRETE],
	"bamboo_footbridge": [BAMBOO],
}

## Fallback by structure form when an id has no entry yet.
const FORM_MATERIALS: Dictionary = {
	"power": [CONCRETE, STEEL],
	"refinery": [STEEL, CONCRETE],
	"barracks": [BRICK, TIMBER],
	"factory": [CONCRETE, STEEL],
	"naval": [CONCRETE, STEEL],
	"airfield": [STEEL, CONCRETE],
	"defense": [CONCRETE, STEEL],
	"tech": [BRICK, STEEL],
	"mast": [STEEL],
	"super": [STEEL, GLASS],
	"yard": [CONCRETE, STEEL],
}

static func forward_yaw_deg(id: String, path: String) -> float:
	if path.contains("/rigged/"):
		return float(RIGGED_YAW.get(id, 0.0))
	if path.contains("/tripo/") or path.contains("models-tripo"):
		return float(TRIPO_YAW.get(id, 0.0))
	return float(STANDIN_YAW.get(id, 0.0))

static func materials_of(id: String, form: String = "") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var listed: Variant = MATERIALS.get(id, FORM_MATERIALS.get(form, [CONCRETE]))
	for kind: Variant in listed:
		out.append(str(kind))
	return out
