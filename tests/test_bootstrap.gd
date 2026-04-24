extends Node

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var md = get_node_or_null("/root/MapData")
	var gs = get_node_or_null("/root/GameState")

	print("=== Bootstrap Test ===")
	print("MapData: %s" % str(md != null))
	print("GameState: %s" % str(gs != null))

	if md != null:
		print("Stations: %d" % md.stations.size())
		print("Connections: %d" % md._connections_raw.size())

	if gs != null:
		print("Phase: %d" % gs.phase)

	print("=== Done ===")
	get_tree().quit()
