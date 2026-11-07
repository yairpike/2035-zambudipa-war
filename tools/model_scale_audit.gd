extends SceneTree
## Prints authored and in-game sizes of every unit, building and scenery model as TSV.
## godot --headless --path . -s res://tools/model_scale_audit.gd

const Forms = preload("res://game/unit_meshes.gd")
const Models = preload("res://game/model_registry.gd")
const Env = preload("res://game/env_dress.gd")

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child.call_deferred(root)
	await process_frame
	print("kind\tid\tsource\tauthored_w\tauthored_h\tauthored_d\tgame_w\tgame_h\tgame_d")
	for faction: String in ["gtfc", "mvd", "nmrf", "black_market"]:
		SMFront.faction_id = faction
		var data: Dictionary = SMCatalog.faction(faction)
		for unit: Dictionary in SMCatalog.units_of(data):
			var id: String = str(unit.get("id", ""))
			var body: MeshInstance3D = Forms.dress_unit(id, str(unit.get("role", "")), str(unit.get("locomotion", "ground")), Color.GRAY)
			root.add_child(body)
			_row("unit", id, body, Models.source_of(id))
			body.free()
		var raw: Variant = data.get("buildings", [])
		if raw is Array:
			for item: Variant in raw:
				var row: Dictionary = item as Dictionary
				var bid: String = str(row.get("id", ""))
				var mi := MeshInstance3D.new()
				mi.name = "Built_%s" % bid
				if not Forms.dress_structure(mi, SMPointer.BUILDING_SIZE, Color.GRAY):
					mi.free()
					continue
				root.add_child(mi)
				_row("building:%s" % faction, bid, mi, Models.source_of(Models.structure_id(mi.name)))
				mi.free()
	var dir := DirAccess.open("res://game/models/env")
	if dir != null:
		for file: String in dir.get_files():
			if not file.ends_with(".glb"):
				continue
			var id: String = file.get_basename()
			var scene: Node3D = Env._load(id)
			if scene == null:
				continue
			root.add_child(scene)
			var box: AABB = Models._merged_aabb(scene)
			var fit: float = Env.fit_of(id, box)
			print("env\t%s\tenv\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f" % [id, box.size.x, box.size.y, box.size.z, box.size.x * fit, box.size.y * fit, box.size.z * fit])
			scene.free()
	quit(0)

func _row(kind: String, id: String, body: MeshInstance3D, source: String) -> void:
	var model: Node3D = body.get_node_or_null("Model") as Node3D
	if model == null:
		print("%s\t%s\tprocedural\t-\t-\t-\t-\t-\t-" % [kind, id])
		return
	var authored: AABB = Models._merged_aabb(model)
	var placed: AABB = model.transform * authored
	print("%s\t%s\t%s\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f" % [kind, id, source.get_file(), authored.size.x, authored.size.y, authored.size.z, placed.size.x, placed.size.y, placed.size.z])
