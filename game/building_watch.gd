extends Node
## Polls a build yard's structure health a few times a second and passes it to each structure's BuildingFx.
## Read-only on the yard.

const BuildingFx = preload("res://game/building_fx.gd")
const Power = preload("res://addons/rts_advanced/sm_power.gd")
const PERIOD: float = 0.25

var yard: SMBuildYard
var stage: Node3D
var wait: float = 0.0

static func watch(p_stage: Node3D, p_yard: SMBuildYard) -> void:
	if p_stage == null or p_yard == null:
		return
	var node_name: String = "BuildingWatch_%d" % p_yard.get_instance_id()
	if p_stage.get_node_or_null(node_name) != null:
		return
	var w: Node = (load("res://game/building_watch.gd") as GDScript).new() as Node
	w.name = node_name
	w.set("yard", p_yard)
	w.set("stage", p_stage)
	p_stage.add_child(w)

func _process(delta: float) -> void:
	wait -= delta
	if wait > 0.0 or yard == null or stage == null:
		return
	wait = PERIOD
	var powered: bool = Power.online(yard)
	for id: StringName in yard.structure_hp.keys():
		var top: float = float(yard.structure_max.get(id, 0.0))
		if top <= 0.0:
			continue
		var node: Node3D = stage.get_node_or_null("Built_%s" % str(id)) as Node3D
		if node != null:
			BuildingFx.set_health(node, float(yard.structure_hp[id]) / top)
			BuildingFx.set_state(node, powered, bool(yard.repairing.get(id, false)))
