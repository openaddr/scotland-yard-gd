extends Node

signal game_phase_changed(new_phase: int)
signal turn_started(player_index: int, round_number: int)
signal move_made(player_index: int, from_station: int, to_station: int, ticket_used: int)
signal mrx_surfaced(station_id: int, move_number: int)
signal mrx_move_logged(move_number: int, ticket_type: int, station_id: int, station_shown: bool)
signal game_over(winner: int, reason: String)
signal valid_moves_updated(moves: Array)
signal double_move_available()
signal double_move_second_step()

var phase: int = GameConstants.GamePhase.MENU
var current_round: int = 0
var mrx_move_count: int = 0
var current_player_index: int = 0
var players: Array[PlayerData] = []
var mrx_log: Array[MoveRecord] = []
var ticket_pool: Dictionary = {
	GameConstants.TicketType.TAXI: 0,
	GameConstants.TicketType.BUS: 0,
	GameConstants.TicketType.UNDERGROUND: 0,
}
var is_double_move: bool = false
var _map_data: Node

func _ready() -> void:
	_map_data = get_node_or_null("/root/MapData")

func start_game(player_count: int, color_indices: Array = []) -> void:
	players.clear()
	mrx_log.clear()
	current_round = 0
	mrx_move_count = 0
	current_player_index = 0
	is_double_move = false
	ticket_pool[GameConstants.TicketType.TAXI] = 0
	ticket_pool[GameConstants.TicketType.BUS] = 0
	ticket_pool[GameConstants.TicketType.UNDERGROUND] = 0
	var mrx_tickets := GameConstants.MRX_STARTING_TICKETS.duplicate()
	mrx_tickets[GameConstants.TicketType.BLACK] = player_count - 1
	var mrx_color: Color
	if color_indices.size() > 0:
		mrx_color = GameConstants.COLOR_PALETTE[color_indices[0]]["color"]
	else:
		mrx_color = GameConstants.PLAYER_COLORS[0]
	var mrx := PlayerData.new(0, GameConstants.PlayerRole.MRX,
		"Mr. X", mrx_color, mrx_tickets)
	players.append(mrx)
	var start_data := _load_start_positions()
	var mrx_starts: Array = start_data["mrx"]
	var det_starts: Array = start_data["detectives"]
	mrx_starts.shuffle()
	mrx.station_id = mrx_starts[0]
	det_starts.shuffle()
	for i in range(1, player_count):
		var det_color: Color
		var det_name: String
		if color_indices.size() > i:
			var entry = GameConstants.COLOR_PALETTE[color_indices[i]]
			det_color = entry["color"]
			det_name = entry["name"]
		else:
			det_color = GameConstants.PLAYER_COLORS[i] if i < GameConstants.PLAYER_COLORS.size() else Color.WHITE
			det_name = GameConstants.PLAYER_NAMES[i] if i < GameConstants.PLAYER_NAMES.size() else "侦探%d" % i
		var det := PlayerData.new(i, GameConstants.PlayerRole.DETECTIVE,
			det_name, det_color,
			GameConstants.DETECTIVE_STARTING_TICKETS)
		det.station_id = det_starts[i - 1]
		players.append(det)
	phase = GameConstants.GamePhase.PLAYING
	game_phase_changed.emit(phase)
	_start_round()

func _load_start_positions() -> Dictionary:
	var file := FileAccess.open("res://data/starting_positions.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load starting_positions.json")
		return {"mrx": [], "detectives": []}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse starting_positions.json: %s" % err)
		return {"mrx": [], "detectives": []}
	return json.data

func _start_round() -> void:
	current_round += 1
	current_player_index = 0
	is_double_move = false
	_distribute_ticket_pool()
	turn_started.emit(0, current_round)
	_update_valid_moves()

func _distribute_ticket_pool() -> void:
	var mrx := players[0]
	for ticket_type in ticket_pool:
		var count: int = ticket_pool[ticket_type]
		if count > 0:
			mrx.tickets.add_ticket(ticket_type, count)
			ticket_pool[ticket_type] = 0

func get_current_player() -> PlayerData:
	if current_player_index < players.size():
		return players[current_player_index]
	return null

func _update_valid_moves() -> void:
	var player := get_current_player()
	if player == null:
		return
	if player.is_stuck:
		valid_moves_updated.emit([])
		return
	var moves := MoveValidator.get_valid_moves(player, players, _map_data)
	valid_moves_updated.emit(moves)

func execute_move(target_station: int, ticket_type: int) -> bool:
	var player := get_current_player()
	if player == null or player.is_stuck:
		return false
	var moves := MoveValidator.get_valid_moves(player, players, _map_data)
	var found := false
	for m in moves:
		if m["station_id"] == target_station and m["ticket_type"] == ticket_type:
			found = true
			break
	if not found:
		return false
	var from_station := player.station_id
	player.station_id = target_station
	player.tickets.use_ticket(ticket_type)
	if player.role == GameConstants.PlayerRole.DETECTIVE:
		ticket_pool[ticket_type] = ticket_pool.get(ticket_type, 0) + 1
	move_made.emit(player.player_index, from_station, target_station, ticket_type)
	if player.role == GameConstants.PlayerRole.MRX:
		_process_mrx_move(ticket_type, target_station)
	else:
		if not MoveValidator.can_player_move(player, players, _map_data):
			player.is_stuck = true
		var result := WinChecker.check_after_move(player.player_index, players)
		if result["game_over"]:
			_end_game(result["winner"], result["reason"])
			return true
		_advance_turn()
	return true

func _process_mrx_move(ticket_type: int, target_station: int) -> void:
	mrx_move_count += 1
	var is_surface := GameConstants.SURFACE_ROUNDS.has(mrx_move_count)
	var player := players[0]
	mrx_log.append(MoveRecord.new(mrx_move_count, ticket_type, target_station, is_surface))
	mrx_move_logged.emit(mrx_move_count, ticket_type, target_station, is_surface)
	if is_surface:
		mrx_surfaced.emit(target_station, mrx_move_count)
	var result := WinChecker.check_after_move(player.player_index, players)
	if result["game_over"]:
		_end_game(result["winner"], result["reason"])
		return
	if is_double_move:
		is_double_move = false
		_advance_turn()
	elif player.tickets.can_use(GameConstants.TicketType.DOUBLE) and MoveValidator.can_player_move(player, players, _map_data):
		double_move_available.emit()
	else:
		_advance_turn()

func use_double_move() -> void:
	if not players[0].tickets.can_use(GameConstants.TicketType.DOUBLE):
		_advance_turn()
		return
	players[0].tickets.use_ticket(GameConstants.TicketType.DOUBLE)
	is_double_move = true
	double_move_second_step.emit()
	_update_valid_moves()

func skip_double_move() -> void:
	_advance_turn()

func _advance_turn() -> void:
	if is_double_move:
		return
	current_player_index += 1
	if _try_check_end_conditions():
		return
	while current_player_index < players.size():
		var next_player := get_current_player()
		if next_player != null and not next_player.is_stuck:
			break
		current_player_index += 1
	if _try_check_end_conditions():
		return
	turn_started.emit(current_player_index, current_round)
	_update_valid_moves()

func _try_check_end_conditions() -> bool:
	if current_player_index < players.size():
		return false
	var move_result := WinChecker.check_move_limit(mrx_move_count)
	if move_result["game_over"]:
		_end_game(move_result["winner"], move_result["reason"])
		return true
	if WinChecker.check_all_detectives_stuck(players):
		_end_game(GameConstants.PlayerRole.MRX, "所有侦探都被困住了，Mr. X 胜利!")
		return true
	_start_round()
	return true
func _end_game(winner: int, reason: String) -> void:
	phase = GameConstants.GamePhase.GAME_OVER
	game_over.emit(winner, reason)

func is_surface_round(move_num: int) -> bool:
	return GameConstants.SURFACE_ROUNDS.has(move_num)

func get_last_mrx_surface_station() -> int:
	for i in range(mrx_log.size() - 1, -1, -1):
		if mrx_log[i].is_surface:
			return mrx_log[i].station_id
	return players[0].station_id if players.size() > 0 else -1
