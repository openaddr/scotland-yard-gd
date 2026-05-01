extends Node

# Automated integration test for the full game flow
# Creates singletons manually, then runs tests

var _md: Node
var _gs: Node
var _passed: int = 0
var _failed: int = 0
var _errors: Array = []

func _ready() -> void:
	# Bootstrap: create singletons - must wait for scene tree to be fully ready
	await get_tree().process_frame
	await get_tree().process_frame

	var md := Node.new()
	md.name = "MapData"
	md.ccd  --resume "token-color-selection" set_script(load("res://autoload/map_data.gd"))
	get_tree().root.add_child(md)
	await get_tree().process_frame

	var gs := Node.new()
	gs.name = "GameState"
	gs.set_script(load("res://autoload/game_state.gd"))
	get_tree().root.add_child(gs)
	await get_tree().process_frame

	_md = md
	_gs = gs

	print("========================================")
	print("  Scotland Yard - Integration Test Suite")
	print("========================================")

	_test_singletons()
	_test_map_data()
	_test_start_game()
	_test_mrx_moves()
	_test_detective_moves()
	_test_win_conditions()
	_test_viewport_transform()

	print("")
	print("========================================")
	print("  Results: %d passed, %d failed" % [_passed, _failed])
	if _errors.size() > 0:
		print("  FAILURES:")
		for e in _errors:
			print("    - %s" % e)
	else:
		print("  ALL TESTS PASSED!")
	print("========================================")

	get_tree().quit()

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % test_name)
	else:
		_failed += 1
		_errors.append(test_name)
		print("  FAIL: %s" % test_name)

func _test_singletons() -> void:
	print("\n[Group] Singletons")
	_assert(_md != null, "MapData singleton exists")
	_assert(_gs != null, "GameState singleton exists")

func _test_map_data() -> void:
	print("\n[Group] MapData")
	_assert(_md.stations.size() == 199, "199 stations loaded (got %d)" % _md.stations.size())
	_assert(_md._connections_raw.size() > 400, "Connections loaded (got %d)" % _md._connections_raw.size())
	_assert(_md.adjacency.size() > 150, "Adjacency list built (got %d entries)" % _md.adjacency.size())

	var pos = _md.get_station_position(1)
	_assert(pos != Vector2.ZERO, "Station 1 has valid position")

	_md.calculate_viewport_transform(Vector2(1000, 800))
	var pos1 = _md.get_station_position(1)
	var found = _md.get_station_ids_at_position(pos1, 20.0)
	_assert(found.size() > 0 and found[0] == 1, "Click on station 1 finds station 1")

	var conns = _md.get_all_connections_from(1)
	_assert(conns.size() > 0, "Station 1 has connections (got %d)" % conns.size())

func _test_start_game() -> void:
	print("\n[Group] Start Game")
	_gs.start_game(3)
	_assert(_gs.players.size() == 3, "3 players created")
	_assert(_gs.players[0].role == GameConstants.PlayerRole.MRX, "Player 0 is Mr. X")
	_assert(_gs.players[1].role == GameConstants.PlayerRole.DETECTIVE, "Player 1 is Detective")
	_assert(_gs.players[2].role == GameConstants.PlayerRole.DETECTIVE, "Player 2 is Detective")
	_assert(_gs.phase == GameConstants.GamePhase.PLAYING, "Game phase is PLAYING")
	_assert(_gs.current_round == 1, "Round is 1")
	_assert(_gs.current_player_index == 0, "Current player is Mr. X (index 0)")

	var mrx = _gs.players[0]
	_assert(mrx.tickets.counts.get(GameConstants.TicketType.TAXI, 0) == 4, "Mr. X has 4 taxi tickets")
	_assert(mrx.tickets.counts.get(GameConstants.TicketType.BLACK, 0) == 2, "Mr. X has 2 black tickets (3 players - 1)")

	var det = _gs.players[1]
	_assert(det.tickets.counts.get(GameConstants.TicketType.TAXI, 0) == 10, "Detective 1 has 10 taxi tickets")

func _test_mrx_moves() -> void:
	print("\n[Group] Mr. X Moves")
	var mrx = _gs.players[0]
	var moves = MoveValidator.get_valid_moves(mrx, _gs.players, _md)
	_assert(moves.size() > 0, "Mr. X has valid moves (got %d)" % moves.size())

	if moves.size() > 0:
		var first_move = moves[0]
		var target = first_move["station_id"]
		var ticket = first_move["ticket_type"]
		var from = mrx.station_id

		var ok = _gs.execute_move(target, ticket)
		_assert(ok, "Mr. X move %d->%d succeeded" % [from, target])
		_assert(mrx.station_id == target, "Mr. X is now at station %d" % target)
		_assert(_gs.mrx_move_count == 1, "Mr. X move count is 1 after first move")

		# After Mr. X move, either: double_move_available fires (stays at index 0)
		# or turn advances to detective (index 1)
		var advanced: bool = _gs.current_player_index == 1
		var waiting_double: bool = _gs.current_player_index == 0
		_assert(advanced or waiting_double,
			"Turn state is valid after Mr. X move (advanced=%s, waiting_double=%s)" % [str(advanced), str(waiting_double)])

		# If double move is pending, skip it to advance
		if waiting_double:
			_gs.skip_double_move()
			_assert(_gs.current_player_index == 1, "After skip double, current player is Detective 1")

func _test_detective_moves() -> void:
	print("\n[Group] Detective Moves")
	if _gs.current_player_index < 1 or _gs.current_player_index >= _gs.players.size():
		_assert(false, "Cannot test detective moves - wrong player index")
		return

	var det = _gs.players[_gs.current_player_index]
	_assert(det.role == GameConstants.PlayerRole.DETECTIVE, "Current player is a detective")

	var moves = MoveValidator.get_valid_moves(det, _gs.players, _md)
	if moves.size() > 0:
		var first_move = moves[0]
		var target = first_move["station_id"]
		var ticket = first_move["ticket_type"]
		var from = det.station_id

		var ok = _gs.execute_move(target, ticket)
		_assert(ok, "Detective move %d->%d succeeded" % [from, target])
		_assert(det.station_id == target, "Detective is now at station %d" % target)
		_assert(_gs.ticket_pool.get(ticket, 0) > 0, "Ticket added to pool")
	else:
		print("  SKIP: Detective has no valid moves")

func _test_win_conditions() -> void:
	print("\n[Group] Win Conditions")
	var result = WinChecker.check_move_limit(24)
	_assert(result["game_over"] == true, "Move limit triggers game over at move 24")
	_assert(result["winner"] == GameConstants.PlayerRole.MRX, "Move limit winner is Mr. X")

	result = WinChecker.check_move_limit(20)
	_assert(result["game_over"] == false, "No game over at move 20")

	var all_stuck = WinChecker.check_all_detectives_stuck(_gs.players)
	_assert(typeof(all_stuck) == TYPE_BOOL, "check_all_detectives_stuck returns bool")

func _test_viewport_transform() -> void:
	print("\n[Group] Viewport Transform")
	_md.calculate_viewport_transform(Vector2(1200, 900))

	var pos1 = _md.get_station_position(1)
	var pos199 = _md.get_station_position(199)

	_assert(pos1.x > 0 and pos1.y > 0, "Station 1 position is positive")
	_assert(pos199.x > 0 and pos199.y > 0, "Station 199 position is positive")
	_assert(pos1.x < 1200 and pos1.y < 900, "Station 1 is within viewport")
	_assert(pos199.x < 1200 and pos199.y < 900, "Station 199 is within viewport")

	var dist = pos1.distance_to(pos199)
	_assert(dist > 100, "Stations have reasonable spread (distance=%d)" % int(dist))
