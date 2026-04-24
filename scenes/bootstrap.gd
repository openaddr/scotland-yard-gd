extends Node

func _ready() -> void:
	await get_tree().process_frame
	var md := Node.new()
	md.name = "MapData"
	md.set_script(load("res://autoload/map_data.gd"))
	get_tree().root.add_child(md)
	await get_tree().process_frame

	var gs := Node.new()
	gs.name = "GameState"
	gs.set_script(load("res://autoload/game_state.gd"))
	get_tree().root.add_child(gs)
	await get_tree().process_frame

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
