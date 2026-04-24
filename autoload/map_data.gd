extends Node

var stations: Dictionary = {}
var adjacency: Dictionary = {}
var _connections_raw: Array = []
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _min_pos: Vector2 = Vector2.ZERO
var _max_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_load_stations()
	_load_connections()

func _load_stations() -> void:
	var file := FileAccess.open("res://data/stations.json", FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse stations.json: %s" % err)
		return
	stations = json.data
	for sid in stations:
		var s = stations[sid]
		var x: float = s["x"]
		var y: float = s["y"]
		if x < _min_pos.x or stations.keys().find(sid) == 0:
			_min_pos.x = x
		if y < _min_pos.y or stations.keys().find(sid) == 0:
			_min_pos.y = y
		if x > _max_pos.x:
			_max_pos.x = x
		if y > _max_pos.y:
			_max_pos.y = y
		stations[sid]["id"] = int(sid)
	_min_pos.x -= 20
	_min_pos.y -= 20
	_max_pos.x += 20
	_max_pos.y += 20
	print("Loaded %d stations" % stations.size())

func _load_connections() -> void:
	var file := FileAccess.open("res://data/connections.json", FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse connections.json: %s" % err)
		return
	var raw = json.data
	var type_map := {
		"taxi": GameConstants.TransportType.TAXI,
		"bus": GameConstants.TransportType.BUS,
		"underground": GameConstants.TransportType.UNDERGROUND,
		"ferry": GameConstants.TransportType.FERRY,
	}
	for conn in raw:
		var from_id: int = conn["from"]
		var to_id: int = conn["to"]
		var ttype = type_map.get(conn["type"], GameConstants.TransportType.TAXI)
		_connections_raw.append({"from": from_id, "to": to_id, "type": ttype})
		if not adjacency.has(from_id):
			adjacency[from_id] = []
		if not adjacency.has(to_id):
			adjacency[to_id] = []
		adjacency[from_id].append({"to": to_id, "type": ttype})
		adjacency[to_id].append({"to": from_id, "type": ttype})
	print("Loaded %d connections (%d adjacency entries)" % [_connections_raw.size(), adjacency.size()])

func calculate_viewport_transform(viewport_size: Vector2, margin: float = 60.0) -> void:
	var data_w := _max_pos.x - _min_pos.x
	var data_h := _max_pos.y - _min_pos.y
	var avail_w := viewport_size.x - 2.0 * margin
	var avail_h := viewport_size.y - 2.0 * margin
	var sx := avail_w / data_w
	var sy := avail_h / data_h
	_scale = min(sx, sy)
	var used_w := data_w * _scale
	var used_h := data_h * _scale
	_offset.x = margin + (avail_w - used_w) / 2.0 - _min_pos.x * _scale
	_offset.y = margin + (avail_h - used_h) / 2.0 - _min_pos.y * _scale

func get_station_position(station_id: int) -> Vector2:
	if not stations.has(str(station_id)):
		return Vector2.ZERO
	var s = stations[str(station_id)]
	return Vector2(s["x"] * _scale + _offset.x, s["y"] * _scale + _offset.y)

func get_all_connections_from(station_id: int) -> Array:
	if adjacency.has(station_id):
		return adjacency[station_id]
	return []

func get_station_ids_at_position(screen_pos: Vector2, tolerance: float = 18.0) -> Array:
	var best_id: int = -1
	var best_dist: float = tolerance
	for sid_str in stations:
		var pos := get_station_position(int(sid_str))
		var dist := screen_pos.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			best_id = int(sid_str)
	if best_id >= 0:
		return [best_id]
	return []
