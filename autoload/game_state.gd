extends Node

signal game_phase_changed(new_phase: int)
signal turn_started(player_index: int, round_number: int)
signal move_made(player_index: int, from_station: int, to_station: int, ticket_used: int)
signal mrx_surfaced(station_id: int, round_number: int)
signal mrx_move_logged(round_number: int, ticket_type: int, station_id: int, station_shown: bool)
signal game_over(winner: int, reason: String)
signal valid_moves_updated(moves: Array)
signal double_move_available()
signal double_move_second_step()

var phase: int = GameConstants.GamePhase.MENU
var current_round: int = 0
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

func start_game(player_count: int) -> void:
	players.clear()
	mrx_log.clear()
	current_round = 0
	current_player_index = 0
	is_double_move = false
	ticket_pool[GameConstants.TicketType.TAXI] = 0
	ticket_pool[GameConstants.TicketType.BUS] = 0
	ticket_pool[GameConstants.TicketType.UNDERGROUND] = 0
	var mrx := PlayerData.new(0, GameConstants.PlayerRole.MRX,
		GameConstants.PLAYER_NAMES[0], GameConstants.PLAYER_COLORS[0],
		GameConstants.MRX_STARTING_TICKETS)
	players.append(mrx)
	var start_data := _load_start_positions()
	var mrx_starts: Array = start_data["mrx"]
	var det_starts: Array = start_data["detectives"]
	mrx_starts.shuffle()
	mrx.station_id = mrx_starts[0]
	det_starts.shuffle()
	for i in range(1, player_count):
		var det := PlayerData.new(i, GameConstants.PlayerRole.DETECTIVE,
			GameConstants.PLAYER_NAMES[i], GameConstants.PLAYER_COLORS[i],
			GameConstants.DETECTIVE_STARTING_TICKETS)
		det.station_id = det_starts[i - 1]
		players.append(det)
	phase = GameConstants.GamePhase.PLAYING
	game_phase_changed.emit(phase)
	_start_round()

func _load_start_positions() -> Dictionary:
	var file := FileAccess.open("res://data/starting_positions.json", FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	return json.data

func _start_round() -> void:
	current_round += 1
	current_player_index = 0
	is_double_move = false
	turn_started.emit(0, current_round)
	_update_valid_moves()

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
	var is_surface := GameConstants.SURFACE_ROUNDS.has(current_round)
	var player := players[0]
	if is_double_move:
		is_double_move = false
		mrx_log.append(MoveRecord.new(current_round, ticket_type, target_station, is_surface))
		if is_surface:
			mrx_surfaced.emit(target_station, current_round)
		mrx_move_logged.emit(current_round, ticket_type, target_station, is_surface)
		var result := WinChecker.check_after_move(player.player_index, players)
		if result["game_over"]:
			_end_game(result["winner"], result["reason"])
			return
		_advance_turn()
	else:
		mrx_log.append(MoveRecord.new(current_round, ticket_type, target_station, is_surface))
		if is_surface:
			mrx_surfaced.emit(target_station, current_round)
		mrx_move_logged.emit(current_round, ticket_type, target_station, is_surface)
		var result := WinChecker.check_after_move(player.player_index, players)
		if result["game_over"]:
			_end_game(result["winner"], result["reason"])
			return
		if player.tickets.can_use(GameConstants.TicketType.DOUBLE) and MoveValidator.can_player_move(player, players, _map_data):
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
	if current_player_index >= players.size():
		var round_result := WinChecker.check_round_limit(current_round)
		if round_result["game_over"]:
			_end_game(round_result["winner"], round_result["reason"])
			return
		if WinChecker.check_all_detectives_stuck(players):
			_end_game(GameConstants.PlayerRole.MRX, "所有侦探都被困住了，Mr. X 胜利!")
			return
		_start_round()
	else:
		var next_player := get_current_player()
		if next_player.is_stuck:
			_advance_turn()
			return
		turn_started.emit(current_player_index, current_round)
		_update_valid_moves()

func _end_game(winner: int, reason: String) -> void:
	phase = GameConstants.GamePhase.GAME_OVER
	game_over.emit(winner, reason)

func is_surface_round(round_num: int) -> bool:
	return GameConstants.SURFACE_ROUNDS.has(round_num)

func get_last_mrx_surface_station() -> int:
	for i in range(mrx_log.size() - 1, -1, -1):
		if mrx_log[i].is_surface:
			return mrx_log[i].station_id
	return players[0].station_id if players.size() > 0 else -1
