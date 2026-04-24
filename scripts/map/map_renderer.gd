extends Node2D

var _md: Node
var _highlight_stations: Array = []
var _highlight_color: Color = Color.GREEN
var _pulse_time: float = 0.0
var _token_nodes: Dictionary = {}
var _token_stations: Dictionary = {}
var _station_font: Font
var _connections: Array = []
var _stations: Dictionary = {}
var _show_station_numbers: bool = false

func _ready() -> void:
	_md = get_node("/root/MapData")
	_connections = _md._connections_raw
	_stations = _md.stations
	_station_font = ThemeDB.fallback_font
	refresh()

func refresh() -> void:
	var parent = get_parent()
	var vp_size: Vector2
	if parent is Control and parent.size.x > 10 and parent.size.y > 10:
		vp_size = parent.size
	else:
		vp_size = get_viewport_rect().size
	if vp_size.x > 10 and vp_size.y > 10:
		_md.calculate_viewport_transform(vp_size)
	_update_token_positions()
	queue_redraw()

func _update_token_positions() -> void:
	for idx in _token_nodes:
		if _token_stations.has(idx):
			var station_id: int = _token_stations[idx]
			var pos: Vector2 = _md.get_station_position(station_id)
			_token_nodes[idx].position = pos

func _process(delta: float) -> void:
	if _highlight_stations.size() > 0:
		_pulse_time += delta * 3.0
		queue_redraw()

func _draw() -> void:
	_draw_connections()
	_draw_stations(true)
	_draw_highlights()

func _draw_connections() -> void:
	for conn in _connections:
		var from_pos: Vector2 = _md.get_station_position(conn["from"])
		var to_pos: Vector2 = _md.get_station_position(conn["to"])
		var color: Color = GameConstants.CONNECTION_COLORS[conn["type"]]
		var width: float = GameConstants.CONNECTION_WIDTHS[conn["type"]]
		if conn["type"] == GameConstants.TransportType.UNDERGROUND:
			_draw_dashed_line(from_pos, to_pos, color, width, 6.0)
		elif conn["type"] == GameConstants.TransportType.FERRY:
			_draw_dashed_line(from_pos, to_pos, color, width, 10.0)
		else:
			draw_line(from_pos, to_pos, color, width)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float) -> void:
	var direction: Vector2 = (to - from)
	var length: float = direction.length()
	if length < 1.0:
		return
	var normal: Vector2 = direction.normalized()
	var drawn: float = 0.0
	var is_dash: bool = true
	while drawn < length:
		var seg_end: float = minf(drawn + dash_length, length)
		if is_dash:
			draw_line(from + normal * drawn, from + normal * seg_end, color, width)
		drawn = seg_end
		is_dash = not is_dash

func _draw_stations(show_numbers: bool = false) -> void:
	for sid_str in _stations:
		var sid: int = int(sid_str)
		var pos: Vector2 = _md.get_station_position(sid)
		draw_circle(pos, 3.5, Color("#BBBBBB"))
		if show_numbers:
			var label: String = str(sid)
			var font_size: int = 8
			var text_size: Vector2 = _station_font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos: Vector2 = Vector2(pos.x - text_size.x / 2.0, pos.y - 12.0)
			draw_string(_station_font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color("#666666"))

func _draw_highlights() -> void:
	if _highlight_stations.is_empty():
		return
	var pulse: float = (sin(_pulse_time) + 1.0) / 2.0
	var radius: float = lerp(9.0, 13.0, pulse)
	var alpha: float = lerp(0.35, 0.85, pulse)
	var fill_col: Color = Color(0.2, 0.9, 0.3, alpha * 0.3)
	var border_col: Color = Color(0.2, 0.9, 0.3, alpha)
	for sid in _highlight_stations:
		var pos: Vector2 = _md.get_station_position(sid)
		draw_circle(pos, radius, fill_col)
		draw_circle(pos, radius, border_col, false, 3.0)

func highlight_stations(station_ids: Array, color: Color = Color.GREEN) -> void:
	_highlight_stations = station_ids
	_highlight_color = color
	_pulse_time = 0.0

func clear_highlights() -> void:
	_highlight_stations = []
	queue_redraw()

func get_station_pos(station_id: int) -> Vector2:
	return _md.get_station_position(station_id)

func create_token(player_index: int, station_id: int, color: Color, label: String) -> void:
	var token := Node2D.new()
	token.name = "Token%d" % player_index
	var pos: Vector2 = _md.get_station_position(station_id)
	token.position = pos
	var dyn_script = GDScript.new()
	dyn_script.source_code = 'extends Node2D\nvar _color: Color\nvar _label: String\nvar _font: Font\nfunc setup(c: Color, l: String):\n\t_color = c\n\t_label = l\nfunc _ready():\n\t_font = ThemeDB.fallback_font\nfunc _draw():\n\tdraw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.4))\n\tdraw_circle(Vector2.ZERO, 14, _color)\n\tdraw_circle(Vector2.ZERO, 14, Color.WHITE, false, 2.0)\n\tvar ts: Vector2 = _font.get_string_size(_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)\n\tdraw_string(_font, Vector2(-ts.x/2.0, -ts.y/2.0 - 3.0), _label, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color.WHITE)'
	dyn_script.reload()
	token.set_script(dyn_script)
	token.call("setup", color, label)
	add_child(token)
	_token_nodes[player_index] = token
	_token_stations[player_index] = station_id

func move_token(player_index: int, station_id: int) -> void:
	if not _token_nodes.has(player_index):
		return
	_token_stations[player_index] = station_id
	var token: Node2D = _token_nodes[player_index]
	var target_pos: Vector2 = _md.get_station_position(station_id)
	var tween = create_tween()
	tween.tween_property(token, "position", target_pos, 0.3)

func remove_token(player_index: int) -> void:
	if _token_nodes.has(player_index):
		_token_nodes[player_index].queue_free()
		_token_nodes.erase(player_index)

func show_token(player_index: int) -> void:
	if _token_nodes.has(player_index):
		_token_nodes[player_index].visible = true

func hide_token(player_index: int) -> void:
	if _token_nodes.has(player_index):
		_token_nodes[player_index].visible = false
