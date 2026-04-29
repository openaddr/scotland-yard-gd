class_name WinChecker
extends RefCounted

static func check_after_move(mover_index: int, players: Array[PlayerData]) -> Dictionary:
	var mover := players[mover_index]
	if mover.role == GameConstants.PlayerRole.DETECTIVE:
		if mover.station_id == players[0].station_id:
			return {"game_over": true, "winner": GameConstants.PlayerRole.DETECTIVE,
					"reason": "%s 在站点 %d 抓住了 Mr. X!" % [mover.player_name, mover.station_id]}
	else:
		for i in range(1, players.size()):
			var det := players[i]
			if mover.station_id == det.station_id:
				return {"game_over": true, "winner": GameConstants.PlayerRole.DETECTIVE,
						"reason": "Mr. X 在站点 %d 撞上了 %s!" % [mover.station_id, det.player_name]}
	return {"game_over": false}

static func check_all_detectives_stuck(players: Array[PlayerData]) -> bool:
	for i in range(1, players.size()):
		if not players[i].is_stuck:
			return false
	return true

static func check_move_limit(move_count: int) -> Dictionary:
	if move_count >= GameConstants.MAX_ROUNDS:
		return {"game_over": true, "winner": GameConstants.PlayerRole.MRX,
				"reason": "Mr. X 成功逃脱!"}
	return {"game_over": false}
