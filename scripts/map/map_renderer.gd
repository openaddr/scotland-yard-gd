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
	var svg_tex := _load_svg_texture("res://assets/Scotland_Yard_schematic.svg")
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

func _load_svg_texture(path: String) -> ImageTexture:
	var svg_file := FileAccess.open(path, FileAccess.READ)
	if not svg_file:
		push_warning("Could not open SVG: " + path)
		return null
	var svg_data := svg_file.get_buffer(svg_file.get_length())
	svg_file.close()
	var img := Image.new()
	var sh = get_node_or_null("/root/ScreenHelper")
	var svg_scale: float = 3.0 if (sh and sh.is_mobile) else 2.0
	var err := img.load_svg_from_buffer(svg_data, svg_scale)
	if err != OK or img.is_empty():
		push_warning("Failed to create image from SVG: %s (error: %d)" % [path, err])
		return null
	return ImageTexture.create_from_image(img)

func _update_bg_sprite() -> void:
	if not _bg_sprite or not _bg_sprite.texture:
		return
	_sp = _md.get_viewport_scale()
	var off: Vector2 = _md.get_viewport_offset()
	var s: float = _sp / 2.0
	_bg_sprite.scale = Vector2(s, s)
	_bg_sprite.position = Vector2(
		off.x + 600.0 * s,
		off.y + 450.0 * s
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

func highlight_stations(station_ids: Array, color: Color = Color.GREEN) -> void:
	_highlight_stations = station_ids
	_highlight_color = color
	_pulse_time = 0.0
	if _highlight_layer:
		_highlight_layer._stations = station_ids.duplicate()
		_highlight_layer._pulse_time = 0.0
		_highlight_layer.queue_redraw()

func clear_highlights() -> void:
	_highlight_stations = []
	if _highlight_layer:
		_highlight_layer._stations = []

func set_active_player(player_index: int) -> void:
	_current_player_idx = player_index
	for idx in _token_nodes:
			var token: Node2D = _token_nodes[idx]
			token.set("is_active", idx == player_index)

func get_station_pos(station_id: int) -> Vector2:
	return _md.get_station_position(station_id)

func create_token(player_index: int, station_id: int, color: Color, label: String) -> void:
	var token := Node2D.new()
	token.name = "Token%d" % player_index
	var pos: Vector2 = _md.get_station_position(station_id)
	token.position = pos
	token.z_index = 4
	var dyn_script = load("res://scripts/map/token_renderer.gd")
	token.set_script(dyn_script)
	token.call("setup", color, label)
	add_child(token)
	_token_nodes[player_index] = token
	_token_stations[player_index] = station_id
	var tok_script = token as Node2D
	if "sp" in tok_script:
		tok_script.sp = _sp

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
