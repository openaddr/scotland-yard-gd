extends Node

signal room_found(room_name: String, host_ip: String, players: int, max_players: int)
signal room_lost(host_ip: String)
signal hosted(room_name: String)
signal joined(room_name: String, player_index: int, role: int)
signal join_failed(reason: String)
signal player_joined(player_index: int, player_name: String)
signal player_left(player_index: int)
signal connection_lost()
signal message_received(msg: Dictionary)
signal game_started

const DISCOVERY_PORT := 45678
const GAME_PORT := 9080
const BROADCAST_INTERVAL := 2.0
const ROOM_TIMEOUT := 5.0

enum { OFFLINE, HOST, CLIENT }

var _mode: int = OFFLINE
var _my_player_index: int = -1
var _my_name: String = ""
var _host_lan_ip: String = ""
var _room_name: String = ""
var _max_players: int = 5

# Host state
var _tcp_server: TCPServer
var _ws_peers: Dictionary = {}
var _next_peer_id: int = 1
var _color_indices: Array = []
var _lobby_players: Array = []

# Client state
var _client: WebSocketPeer
var _client_joined_sent: bool = false

# Discovery
var _udp_broadcast: PacketPeerUDP
var _udp_listen: PacketPeerUDP
var _broadcast_timer: float = 0.0
var _discovered_rooms: Dictionary = {}


func _process(delta: float) -> void:
	_process_discovery(delta)
	if _mode == HOST:
		_poll_server()
	elif _mode == CLIENT:
		_poll_client()


# ==================== Discovery ====================

func _get_lan_ip() -> String:
	var addresses: PackedStringArray = IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return ""


func start_discovery() -> void:
	stop_discovery()
	_udp_listen = PacketPeerUDP.new()
	_udp_listen.bind(DISCOVERY_PORT, "0.0.0.0")
	_discovered_rooms.clear()


func stop_discovery() -> void:
	if _udp_listen:
		_udp_listen.close()
		_udp_listen = null
	for ip in _discovered_rooms:
		room_lost.emit(ip)
	_discovered_rooms.clear()


func _process_discovery(delta: float) -> void:
	if _mode == HOST and _udp_broadcast:
		_broadcast_timer -= delta
		if _broadcast_timer <= 0.0:
			_broadcast_timer = BROADCAST_INTERVAL
			_send_broadcast()
	if _udp_listen and _mode != HOST:
		_receive_discovery()


func _send_broadcast() -> void:
	if not _udp_broadcast:
		return
	if _host_lan_ip.is_empty():
		_host_lan_ip = _get_lan_ip()
		print("[Net] LAN IP: %s" % _host_lan_ip)
	var msg := JSON.stringify({
		"type": "scotland_yard_room",
		"name": _room_name,
		"port": GAME_PORT,
		"players": 1 + _ws_peers.size(),
		"max": _max_players,
		"host_ip": _host_lan_ip,
	})
	_udp_broadcast.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_udp_broadcast.put_packet(msg.to_utf8_buffer())


func _receive_discovery() -> void:
	while _udp_listen.get_available_packet_count() > 0:
		_udp_listen.get_packet()
		var raw := _udp_listen.get_packet()
		var msg_str := raw.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(msg_str) != OK or not json.data is Dictionary:
			continue
		var data: Dictionary = json.data
		if data.get("type", "") != "scotland_yard_room":
			continue
		var ip: String = data.get("host_ip", "")
		if ip.is_empty():
			ip = _udp_listen.get_packet_ip()
		var rname: String = data.get("name", "?")
		var n_players: int = int(data.get("players", 0))
		var n_max: int = int(data.get("max", 5))
		if not _discovered_rooms.has(ip):
			_discovered_rooms[ip] = {"name": rname, "players": n_players, "max": n_max, "last_seen": Time.get_ticks_msec() / 1000.0}
			room_found.emit(rname, ip, n_players, n_max)
		else:
			_discovered_rooms[ip]["last_seen"] = Time.get_ticks_msec() / 1000.0
			_discovered_rooms[ip]["players"] = n_players
	var now := Time.get_ticks_msec() / 1000.0
	var expired: Array = []
	for ip in _discovered_rooms:
		if now - _discovered_rooms[ip]["last_seen"] > ROOM_TIMEOUT:
			expired.append(ip)
	for ip in expired:
		_discovered_rooms.erase(ip)
		room_lost.emit(ip)


# ==================== Host ====================

func create_room(room_name: String, max_players: int, host_name: String, host_color_index: int) -> bool:
	if _mode != OFFLINE:
		return false
	_room_name = room_name
	_max_players = max_players
	_my_name = host_name
	_my_player_index = 0
	_next_peer_id = 1
	_ws_peers.clear()
	_color_indices.clear()
	_lobby_players.clear()

	if host_color_index >= 0:
		_color_indices.append(host_color_index)
	_lobby_players.append({
		"name": host_name,
		"color_index": host_color_index,
		"role": GameConstants.PlayerRole.MRX,
		"ready": true,
	})

	_tcp_server = TCPServer.new()
	var err: int = _tcp_server.listen(GAME_PORT)
	if err != OK:
		push_error("TCP listen failed on port %d: %s" % [GAME_PORT, err])
		_tcp_server = null
		return false

	_mode = HOST
	_host_lan_ip = _get_lan_ip()
	print("[Net] 房间创建成功, LAN IP: %s" % _host_lan_ip)

	_udp_broadcast = PacketPeerUDP.new()
	_udp_broadcast.set_broadcast_enabled(true)
	var bind_err: int = _udp_broadcast.bind(DISCOVERY_PORT + 1)
	if bind_err != OK:
		push_warning("UDP broadcast bind failed: %s" % bind_err)
		_udp_broadcast = null
	_broadcast_timer = 0.0

	_connect_host_signals()
	hosted.emit(room_name)
	return true


func _poll_server() -> void:
	if not _tcp_server:
		return
	while _tcp_server.is_connection_available():
		var tcp_stream: StreamPeerTCP = _tcp_server.take_connection()
		if not tcp_stream:
			continue
		var ws: WebSocketPeer = WebSocketPeer.new()
		ws.accept_stream(tcp_stream)
		var pid: int = _next_peer_id
		_next_peer_id += 1
		_ws_peers[pid] = {"tcp": tcp_stream, "ws": ws, "name": "", "color_index": -1, "ready": false, "player_index": -1}
		print("[Net] 新TCP连接: peer_id=%d, ws_state=%d" % [pid, ws.get_ready_state()])

	var to_remove: Array = []
	for pid in _ws_peers:
		var ws: WebSocketPeer = _ws_peers[pid]["ws"]
		ws.poll()
		var state: int = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			print("[Net] peer %d 握手成功" % pid)
			while ws.get_available_packet_count() > 0:
				var raw: String = ws.get_packet().get_string_from_utf8()
				if not raw.is_empty():
					_on_peer_packet(pid, raw)
		elif state == WebSocketPeer.STATE_CLOSED:
			print("[Net] peer关闭: pid=%d" % pid)
			to_remove.append(pid)

	for pid in to_remove:
		_on_peer_closed(pid)


func _on_peer_packet(pid: int, raw: String) -> void:
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return
	var msg: Dictionary = json.data
	match msg.get("type", ""):
		"join":
			_on_client_join(pid, msg)
		"ready":
			if _ws_peers.has(pid):
				_ws_peers[pid]["ready"] = true
				_refresh_lobby()
		"move":
			_on_client_move(pid, msg)
		"use_double":
			if _ws_peers.get(pid, {}).get("player_index", -1) == 0:
				get_node("/root/GameState").use_double_move()
		"skip_double":
			if _ws_peers.get(pid, {}).get("player_index", -1) == 0:
				get_node("/root/GameState").skip_double_move()


func _on_client_join(pid: int, msg: Dictionary) -> void:
	var pname: String = msg.get("name", "Player")
	var ci: int = int(msg.get("color_index", -1))

	# If peer already joined, this is a color update
	var existing_pi: int = _ws_peers.get(pid, {}).get("player_index", -1)
	if existing_pi >= 0:
		# Remove old color if any
		var old_ci: int = int(_ws_peers[pid].get("color_index", -1))
		if old_ci >= 0 and old_ci != ci:
			var idx := _color_indices.find(old_ci)
			if idx >= 0:
				_color_indices.remove_at(idx)
		if ci >= 0 and not _color_indices.has(ci):
			_color_indices.append(ci)
		_ws_peers[pid]["color_index"] = ci
		_refresh_lobby()
		return

	print("[Net] 收到join: pid=%d, name=%s, color=%d" % [pid, pname, ci])
	if _ws_peers.size() + 1 >= _max_players:
		print("[Net] 房间已满: peers=%d, max=%d" % [_ws_peers.size(), _max_players])
		for p in _ws_peers:
			print("[Net]   peer %d: name=%s, pi=%d" % [p, _ws_peers[p].get("name","?"), _ws_peers[p].get("player_index",-1)])
		_send_peer(pid, {"type": "join_rejected", "reason": "房间已满"})
		return
	if ci >= 0 and _color_indices.has(ci):
		_send_peer(pid, {"type": "join_rejected", "reason": "颜色已被选择"})
		return
	var pi: int = _ws_peers.size() + 1
	if ci >= 0:
		_color_indices.append(ci)
	_ws_peers[pid]["name"] = pname
	_ws_peers[pid]["color_index"] = ci
	_ws_peers[pid]["player_index"] = pi
	_ws_peers[pid]["ready"] = false
	player_joined.emit(pi, pname)
	_refresh_lobby()
	_send_peer(pid, {
		"type": "welcome",
		"player_index": pi,
		"role": GameConstants.PlayerRole.DETECTIVE,
		"room_name": _room_name,
	})


func _on_client_move(pid: int, msg: Dictionary) -> void:
	var pi: int = _ws_peers.get(pid, {}).get("player_index", -1)
	if pi < 0:
		return
	var gs = get_node("/root/GameState")
	if gs.current_player_index != pi:
		return
	gs.execute_move(int(msg.get("target_station", -1)), int(msg.get("ticket_type", -1)))


func _on_peer_closed(pid: int) -> void:
	if not _ws_peers.has(pid):
		return
	var pi: int = _ws_peers[pid].get("player_index", -1)
	_ws_peers.erase(pid)
	if pi >= 0:
		player_left.emit(pi)
	_refresh_lobby()


func _refresh_lobby() -> void:
	_lobby_players.clear()
	_lobby_players.append({
		"name": _my_name,
		"color_index": _color_indices[0] if _color_indices.size() > 0 else -1,
		"role": GameConstants.PlayerRole.MRX,
		"ready": true,
	})
	for pid in _ws_peers:
		var c = _ws_peers[pid]
		_lobby_players.append({
			"name": c["name"],
			"color_index": c["color_index"],
			"role": GameConstants.PlayerRole.DETECTIVE,
			"ready": c["ready"],
		})
	_broadcast_all({"type": "lobby_state", "players": _lobby_players.duplicate(true)})


func _send_peer(pid: int, msg: Dictionary) -> void:
	if _mode != HOST or not _ws_peers.has(pid):
		return
	var ws: WebSocketPeer = _ws_peers[pid]["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var text: String = JSON.stringify(msg)
		ws.send_text(text)
		print("[Net] 发送给 peer %d: %s" % [pid, text])
	else:
		print("[Net] 发送给 peer %d 失败, ws_state=%d" % [pid, ws.get_ready_state()])


func _broadcast_all(msg: Dictionary) -> void:
	if _mode != HOST:
		return
	var text := JSON.stringify(msg)
	for pid in _ws_peers:
		var ws: WebSocketPeer = _ws_peers[pid]["ws"]
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(text)


# ==================== Client ====================

func join_room(host_ip: String, player_name: String) -> void:
	if _mode != OFFLINE:
		print("[Net] join_room: 已经不是 OFFLINE 状态, mode=%d" % _mode)
		return
	_my_name = player_name
	_mode = CLIENT
	_client = WebSocketPeer.new()
	var url: String = "ws://%s:%d" % [host_ip, GAME_PORT]
	print("[Net] join_room: 连接 %s" % url)
	_client.connect_to_url(url)


func _poll_client() -> void:
	if not _client:
		return
	_client.poll()
	var state: int = _client.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _client_joined_sent:
			_client_joined_sent = true
			print("[Net] 客户端连接成功, 发送 join")
			_client.send_text(JSON.stringify({"type": "join", "name": _my_name, "color_index": -1}))
		while _client and _client.get_available_packet_count() > 0:
			var raw: String = _client.get_packet().get_string_from_utf8()
			if not raw.is_empty():
				_parse_client_packet(raw)
				if not _client:
					break
	elif state == WebSocketPeer.STATE_CLOSED:
		print("[Net] 客户端连接已关闭")
		if _mode == CLIENT:
			connection_lost.emit()
			_cleanup()


func _parse_client_packet(raw: String) -> void:
	print("[Net] 客户端收到消息: %s" % raw)
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return
	var msg: Dictionary = json.data
	var t: String = msg.get("type", "")
	match t:
		"welcome":
			_my_player_index = int(msg["player_index"])
			print("[Net] 收到 welcome: room=%s, pi=%d, role=%d" % [msg.get("room_name", ""), _my_player_index, int(msg["role"])])
			joined.emit(msg.get("room_name", ""), _my_player_index, int(msg["role"]))
		"join_rejected":
			join_failed.emit(msg.get("reason", ""))
			_cleanup()
			return
		"lobby_state":
			_lobby_players = msg.get("players", [])
		"game_start":
			get_node("/root/GameState").load_full_state(msg)
			get_node("/root/GameState").phase = GameConstants.GamePhase.PLAYING
			game_started.emit()
		"turn_started":
			_apply_turn_started(msg)
		"move_made":
			_apply_move_made(msg)
		"valid_moves":
			get_node("/root/GameState").valid_moves_updated.emit(msg.get("moves", []))
		"mrx_logged":
			_apply_mrx_logged(msg)
		"double_move_available":
			get_node("/root/GameState").double_move_available.emit()
		"double_move_second":
			get_node("/root/GameState").double_move_second_step.emit()
		"game_over":
			get_node("/root/GameState").phase = GameConstants.GamePhase.GAME_OVER
			get_node("/root/GameState").game_over.emit(int(msg["winner"]), msg["reason"])
		"state_sync":
			get_node("/root/GameState").load_full_state(msg)
	message_received.emit(msg)


func _apply_turn_started(msg: Dictionary) -> void:
	var gs = get_node("/root/GameState")
	gs.current_player_index = int(msg["player_index"])
	gs.current_round = int(msg["round_number"])
	gs.turn_started.emit(gs.current_player_index, gs.current_round)


func _apply_move_made(msg: Dictionary) -> void:
	var gs = get_node("/root/GameState")
	var pi: int = int(msg["player_index"])
	var from: int = int(msg["from_station"])
	var to: int = int(msg["to_station"])
	var tt: int = int(msg["ticket_type"])
	if pi < gs.players.size():
		gs.players[pi].station_id = to
		if gs.players[pi].role == GameConstants.PlayerRole.DETECTIVE:
			gs.players[pi].tickets.use_ticket(tt)
			gs.ticket_pool[tt] = gs.ticket_pool.get(tt, 0) + 1
		else:
			gs.players[pi].tickets.use_ticket(tt)
	gs.move_made.emit(pi, from, to, tt)


func _apply_mrx_logged(msg: Dictionary) -> void:
	var gs = get_node("/root/GameState")
	var mn: int = int(msg["move_number"])
	var tt: int = int(msg["ticket_type"])
	var sid: int = int(msg["station_id"])
	var shown: bool = msg.get("station_shown", false)
	gs.mrx_move_count = mn
	gs.mrx_log.append(MoveRecord.new(mn, tt, sid, shown))
	gs.mrx_move_logged.emit(mn, tt, sid, shown)
	if shown:
		gs.players[0].station_id = sid
		gs.mrx_surfaced.emit(sid, mn)


# ==================== Host Signal Routing ====================

func _connect_host_signals() -> void:
	var gs = get_node("/root/GameState")
	if not gs.is_connected("turn_started", _host_turn_started):
		gs.turn_started.connect(_host_turn_started)
	if not gs.is_connected("move_made", _host_move_made):
		gs.move_made.connect(_host_move_made)
	if not gs.is_connected("mrx_move_logged", _host_mrx_logged):
		gs.mrx_move_logged.connect(_host_mrx_logged)
	if not gs.is_connected("game_over", _host_game_over):
		gs.game_over.connect(_host_game_over)
	if not gs.is_connected("valid_moves_updated", _host_valid_moves):
		gs.valid_moves_updated.connect(_host_valid_moves)


func _disconnect_host_signals() -> void:
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		return
	if gs.is_connected("turn_started", _host_turn_started):
		gs.turn_started.disconnect(_host_turn_started)
	if gs.is_connected("move_made", _host_move_made):
		gs.move_made.disconnect(_host_move_made)
	if gs.is_connected("mrx_move_logged", _host_mrx_logged):
		gs.mrx_move_logged.disconnect(_host_mrx_logged)
	if gs.is_connected("game_over", _host_game_over):
		gs.game_over.disconnect(_host_game_over)
	if gs.is_connected("valid_moves_updated", _host_valid_moves):
		gs.valid_moves_updated.disconnect(_host_valid_moves)


func _host_turn_started(pi: int, rn: int) -> void:
	_broadcast_all({"type": "turn_started", "player_index": pi, "round_number": rn})


func _host_move_made(pi: int, from_s: int, to_s: int, tt: int) -> void:
	_broadcast_all({"type": "move_made", "player_index": pi, "from_station": from_s, "to_station": to_s, "ticket_type": tt})


func _host_mrx_logged(mn: int, tt: int, sid: int, shown: bool) -> void:
	_broadcast_all({"type": "mrx_logged", "move_number": mn, "ticket_type": tt, "station_id": sid, "station_shown": shown})


func _host_game_over(winner: int, reason: String) -> void:
	_broadcast_all({"type": "game_over", "winner": winner, "reason": reason})


func _host_valid_moves(moves: Array) -> void:
	var gs = get_node("/root/GameState")
	var cpi = gs.current_player_index
	if cpi == 0:
		return
	for pid in _ws_peers:
		if _ws_peers[pid].get("player_index", -1) == cpi:
			_send_peer(pid, {"type": "valid_moves", "moves": moves})
			return


# ==================== Start Game ====================

func start_game() -> bool:
	if _mode != HOST:
		return false
	for pid in _ws_peers:
		if not _ws_peers[pid].get("ready", false):
			return false
	var ci: Array = []
	if _color_indices.size() > 0:
		ci.append(_color_indices[0])
	for pid in _ws_peers:
		var c = _ws_peers[pid].get("color_index", -1)
		if c >= 0:
			ci.append(c)
	var gs = get_node("/root/GameState")
	gs.start_game(1 + _ws_peers.size(), ci)
	_broadcast_all(gs.get_full_state())
	game_started.emit()
	return true


# ==================== Public API ====================

func send_message(msg: Dictionary) -> void:
	if _mode == CLIENT and _client and _client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_client.send_text(JSON.stringify(msg))


func is_host() -> bool:
	return _mode == HOST


func is_connected_to_room() -> bool:
	if _mode == HOST:
		return true
	if _mode == CLIENT and _client:
		return _client.get_ready_state() == WebSocketPeer.STATE_OPEN
	return false


func get_my_player_index() -> int:
	return _my_player_index


func get_my_role() -> int:
	return GameConstants.PlayerRole.MRX if _mode == HOST else GameConstants.PlayerRole.DETECTIVE


func get_lobby_players() -> Array:
	return _lobby_players.duplicate(true)


func leave_room() -> void:
	_cleanup()


func _cleanup() -> void:
	_disconnect_host_signals()
	_mode = OFFLINE
	_my_player_index = -1
	_lobby_players.clear()
	_ws_peers.clear()
	_color_indices.clear()
	if _tcp_server:
		_tcp_server.stop()
		_tcp_server = null
	if _client:
		_client.close()
		_client = null
		_client_joined_sent = false
	if _udp_broadcast:
		_udp_broadcast.close()
		_udp_broadcast = null
	stop_discovery()
