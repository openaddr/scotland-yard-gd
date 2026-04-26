class_name MoveValidator
extends RefCounted

static func get_valid_moves(player: PlayerData, all_players: Array[PlayerData], map_data: Node = null) -> Array:
	if map_data == null:
		return []
	var result: Array = []
	var connections = map_data.get_all_connections_from(player.station_id)
	if connections.is_empty():
		return result
	for conn in connections:
		var to_id: int = conn["to"]
		var ttype: int = conn["type"]
		if player.role == GameConstants.PlayerRole.DETECTIVE and ttype == GameConstants.TransportType.FERRY:
			continue
		if _is_station_occupied(to_id, player, all_players):
			continue
		var ticket_options: Array = _get_ticket_options(ttype, player)
		for t in ticket_options:
			result.append({"station_id": to_id, "ticket_type": t, "transport_type": ttype})
	return result

static func _get_ticket_options(transport_type: int, player: PlayerData) -> Array:
	var options: Array = []
	var ticket_map := {
		GameConstants.TransportType.TAXI: GameConstants.TicketType.TAXI,
		GameConstants.TransportType.BUS: GameConstants.TicketType.BUS,
		GameConstants.TransportType.UNDERGROUND: GameConstants.TicketType.UNDERGROUND,
		GameConstants.TransportType.FERRY: GameConstants.TicketType.BLACK,
	}
	var normal_ticket: int = ticket_map.get(transport_type, -1)
	if normal_ticket >= 0 and player.tickets.can_use(normal_ticket):
		options.append(normal_ticket)
	if player.role == GameConstants.PlayerRole.MRX and player.tickets.can_use(GameConstants.TicketType.BLACK):
		if not options.has(GameConstants.TicketType.BLACK):
			options.append(GameConstants.TicketType.BLACK)
	return options

static func _is_station_occupied(station_id: int, player: PlayerData, all_players: Array[PlayerData]) -> bool:
	if player.role == GameConstants.PlayerRole.MRX:
		return false
	for p in all_players:
		if p.player_index != player.player_index and p.station_id == station_id:
			if p.role == GameConstants.PlayerRole.DETECTIVE:
				return true
	return false

static func can_player_move(player: PlayerData, all_players: Array[PlayerData], map_data: Node = null) -> bool:
	if map_data == null:
		return false
	return get_valid_moves(player, all_players, map_data).size() > 0

static func get_unique_destinations(valid_moves: Array) -> Array:
	var dests: Array = []
	for m in valid_moves:
		if not dests.has(m["station_id"]):
			dests.append(m["station_id"])
	return dests

static func get_ticket_options_for_destination(station_id: int, valid_moves: Array) -> Array:
	var options: Array = []
	for m in valid_moves:
		if m["station_id"] == station_id and not options.has(m["ticket_type"]):
			options.append(m["ticket_type"])
	return options
