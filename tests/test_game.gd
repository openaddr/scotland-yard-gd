extends Node

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var md = get_node_or_null("/root/MapData")
	var gs = get_node_or_null("/root/GameState")

	if md == null or gs == null:
		push_error("Singletons not found! MapData=%s GameState=%s" % [str(md != null), str(gs != null)])
		# Print scene tree for debugging
		for c in get_tree().root.get_children():
			print("  root child: %s (%s)" % [c.name, c.get_class()])
		get_tree().quit()
		return

	print("=== Scotland Yard Tests ===")

	print("\n[1] MapData: stations=%d connections=%d" % [md.stations.size(), md._connections_raw.size()])

	gs.start_game(3)
	print("[2] Players: %d" % gs.players.size())
	for p in gs.players:
		print("    %s at station %d" % [p.player_name, p.station_id])

	var mrx = gs.players[0]
	var moves = MoveValidator.get_valid_moves(mrx, gs.players, md)
	print("[3] Mr. X valid moves: %d" % moves.size())
	for i in range(mini(3, moves.size())):
		print("    -> station %d (ticket=%d)" % [moves[i]["station_id"], moves[i]["ticket_type"]])

	if moves.size() > 0:
		var m = moves[0]
		var from = mrx.station_id
		var ok = gs.execute_move(m["station_id"], m["ticket_type"])
		print("[4] Move %d->%d ok=%s now=%s" % [from, mrx.station_id, str(ok), gs.get_current_player().player_name])
		if not ok:
			push_error("Execute move failed!")
	else:
		push_error("No valid moves!")

	md.calculate_viewport_transform(Vector2(1000, 800))
	var pos = md.get_station_position(1)
	var found = md.get_station_ids_at_position(pos, 20.0)
	print("[5] Station 1 pos=%s click=%s" % [str(pos), str(found)])

	print("\n=== Done ===")
	get_tree().quit()
