extends RefCounted
## Victory and defeat plate. The match status line stays where the tests read it.

const Backdrop = preload("res://game/menu_backdrop.gd")

static func show(layer: Node, won: bool) -> void:
	if layer == null or layer.get_node_or_null("OutroPlate") != null:
		return
	var boot_chip: CanvasItem = layer.find_child("MissionBoot", true, false) as CanvasItem
	if boot_chip != null:
		boot_chip.visible = false
	var plate := Control.new()
	plate.name = "OutroPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.z_index = 30
	var art: Control = Backdrop.new() as Control
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.call("set_screen", "faction")
	art.call("set_faction", SMFront.current())
	plate.add_child(art)
	var rail: Panel = Panel.new()
	rail.name = "OutroGlass"
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.position = Vector2(24, 32)
	rail.size = Vector2(400, 192)
	preload("res://game/glass.gd").dress(rail, 14, Color(0.03, 0.035, 0.05, 0.5), 0)
	plate.add_child(rail)
	var title := Label.new()
	title.name = "OutroTitle"
	title.text = "Victory" if won else "Defeat"
	title.theme_type_variation = "Header"
	title.position = Vector2(64, 56)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	plate.add_child(title)
	var back: Button = (load("res://game/menu_plate.gd") as GDScript).new() as Button
	back.text = "Boot menu"
	back.position = Vector2(48, 140)
	back.custom_minimum_size = Vector2(280, 52)
	back.size = Vector2(280, 52)
	back.pressed.connect(func() -> void:
		preload("res://game/lan_link.gd").close()
		var tree: SceneTree = layer.get_tree()
		if tree != null:
			tree.change_scene_to_file("res://game/boot.tscn")
	)
	plate.add_child(back)
	layer.add_child(plate)
