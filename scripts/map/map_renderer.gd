extends Node2D

var _md: Node
var _token_nodes: Dictionary = {}
var _token_stations: Dictionary = {}
var _station_font: Font
var _connections: Array = []
var _stations: Dictionary = {}
var _bg_sprite: Sprite2D
var _highlight_layer: Node2D
var _label_layer: Node2D
var _sp: float = 1.0
var _current_player_idx: int = -1

func _ready() -> void:
	_md = get_node("/root/MapData")
	_connections = _md._connections_raw
	_stations = _md.stations
	_station_font = ThemeDB.fallback_font

	# SVG background: z_index=-1 so it draws below everything
	_bg_sprite = Sprite2D.new()
	_bg_sprite.name = "BoardBackground"
	_bg_sprite.z_index = -1
	var svg_tex: Texture2D = load("res://assets/Scotland_Yard_schematic.svg")
	if svg_tex:
		_bg_sprite.texture = svg_tex
	add_child(_bg_sprite)

	# Station label layer: z_index=3 draws above highlights and tokens
	_label_layer = Node2D.new()
	_label_layer.name = "StationLabelLayer"
	_label_layer.z_index = 3
	var label_script = load("res://scripts/map/label_layer.gd")
	_label_layer.set_script(label_script)
	_label_layer.call("setup", _stations, _md)
	add_child(_label_layer)

	# Highlight layer: z_index=0, above SVG but below labels
	_highlight_layer = Node2D.new()
	_highlight_layer.name = "HighlightLayer"
	_highlight_layer.z_index = 0
	var hl_script = load("res://scripts/map/highlight_layer.gd")
	_highlight_layer.set_script(hl_script)
	_highlight_layer.call("setup", _md)
	add_child(_highlight_layer)

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
	_update_bg_sprite()
	_update_token_positions()
	_sp = _md.get_viewport_scale()
	queue_redraw()
	if _label_layer:
		_label_layer.queue_redraw()

func _update_bg_sprite() -> void:
	if not _bg_sprite or not _bg_sprite.texture:
		return
	_sp = _md.get_viewport_scale()
	var off: Vector2 = _md.get_viewport_offset()
	var tex: Texture2D = _bg_sprite.texture
	var s: float = _sp * 600.0 / tex.get_width()
	_bg_sprite.scale = Vector2(s, s)
	_bg_sprite.position = Vector2(
		off.x + 300.0 * _sp,
		off.y + 225.0 * _sp
	)

func _update_token_positions() -> void:
	for idx in _token_nodes:
		if _token_stations.has(idx):
			var station_id: int = _token_stations[idx]
			var pos: Vector2 = _md.get_station_position(station_id)
			_token_nodes[idx].position = pos
			var token: Node2D = _token_nodes[idx]
			if "sp" in token:
				token.sp = _sp

func highlight_stations(station_ids: Array, _color: Color = Color.GREEN) -> void:
	if _highlight_layer:
		_highlight_layer._stations = station_ids.duplicate()
		_highlight_layer._pulse_time = 0.0
		_highlight_layer.queue_redraw()

func clear_highlights() -> void:
	if _highlight_layer:
		_highlight_layer._stations = []

func set_active_player(player_index: int) -> void:
	_current_player_idx = player_index
	for idx in _token_nodes:
			var token: Node2D = _token_nodes[idx]
			token.set("is_active", idx == player_index)

func get_station_pos(station_id: int) -> Vector2:
	return _md.get_station_position(station_id)

func create_token(player_index: int, station_id: int, color: Color) -> void:
	var token := Node2D.new()
	token.name = "Token%d" % player_index
	var pos: Vector2 = _md.get_station_position(station_id)
	token.position = pos
	token.z_index = 4
	var dyn_script = load("res://scripts/map/token_renderer.gd")
	token.set_script(dyn_script)
	token.call("setup", color)
	add_child(token)
	_token_nodes[player_index] = token
	_token_stations[player_index] = station_id
	if "sp" in token:
		token.sp = _sp

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
