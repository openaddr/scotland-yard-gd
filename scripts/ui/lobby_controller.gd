extends Control

var _nm: Node
var _bg: ColorRect
var _content: Control

# Input fields
var _name_input: LineEdit
var _room_name_input: LineEdit
var _count_select: int = 3
var _count_btns: Dictionary = {}

# Join UI
var _room_list: ItemList
var _discovered_ips: Dictionary = {}  # display_text -> host_ip
var _join_btn: Button
var _search_btn: Button
var _searching: bool = false

# Room UI (shown after create/join)
var _room_panel: Control
var _room_title: Label
var _player_list_vbox: VBoxContainer
var _color_btns: Array[Button] = []
var _my_color_index: int = -1
var _ready_btn: Button
var _start_btn: Button
var _back_lobby_btn: Button

# State
var _phase: int = 0  # 0=menu, 1=in_room
var _lobby_players: Array = []


func _ready() -> void:
	_nm = get_node_or_null("/root/NetworkManager")
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.1, 0.1, 0.15, 1)
	add_child(_bg)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content)

	_build_menu_ui()
	_build_room_ui()


func _build_menu_ui() -> void:
	_content.name = "MenuPanel"

	# Title
	var title := Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.offset_left = -200
	title.offset_top = -270
	title.offset_right = 200
	title.offset_bottom = -230
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "苏格兰场 — 联机"
	var ls := LabelSettings.new()
	ls.font_size = 38
	ls.font_color = Color("#E8C840")
	title.label_settings = ls
	_content.add_child(title)

	# Name input
	var name_box := HBoxContainer.new()
	name_box.set_anchors_preset(Control.PRESET_CENTER)
	name_box.offset_left = -260
	name_box.offset_top = -220
	name_box.offset_right = 260
	name_box.offset_bottom = -175
	name_box.add_theme_constant_override("separation", 10)
	_content.add_child(name_box)
	var name_label := Label.new()
	name_label.text = "昵称:"
	name_label.custom_minimum_size.x = 55.0
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_box.add_child(name_label)
	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.placeholder_text = "输入你的昵称"
	_name_input.add_theme_font_size_override("font_size", 18)
	name_box.add_child(_name_input)

	# Two-column layout
	var cols := HBoxContainer.new()
	cols.set_anchors_preset(Control.PRESET_CENTER)
	cols.offset_left = -310
	cols.offset_top = -160
	cols.offset_right = 310
	cols.offset_bottom = 180
	cols.add_theme_constant_override("separation", 30)
	_content.add_child(cols)

	# Left: Create room
	var create_col := VBoxContainer.new()
	create_col.add_theme_constant_override("separation", 12)
	create_col.custom_minimum_size.x = 280.0
	cols.add_child(create_col)

	var create_title := Label.new()
	create_title.text = "创建房间"
	create_title.add_theme_font_size_override("font_size", 22)
	create_title.add_theme_color_override("font_color", Color("#E8C840"))
	create_col.add_child(create_title)

	var room_box := HBoxContainer.new()
	room_box.add_theme_constant_override("separation", 8)
	create_col.add_child(room_box)
	var room_label := Label.new()
	room_label.text = "房间名:"
	room_label.custom_minimum_size.x = 55.0
	room_label.add_theme_font_size_override("font_size", 18)
	room_label.add_theme_color_override("font_color", Color.WHITE)
	room_box.add_child(room_label)
	_room_name_input = LineEdit.new()
	_room_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name_input.placeholder_text = "房间名"
	_room_name_input.add_theme_font_size_override("font_size", 18)
	room_box.add_child(_room_name_input)

	var count_label := Label.new()
	count_label.text = "玩家人数"
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	create_col.add_child(count_label)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 15)
	create_col.add_child(btn_box)
	for c in [3, 4, 5]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 45)
		btn.text = "%d人" % c
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func(): _select_count(c))
		btn_box.add_child(btn)
		_count_btns[c] = btn
	_select_count(3)

	var create_btn := Button.new()
	create_btn.custom_minimum_size = Vector2(260, 52)
	create_btn.text = "创建房间"
	create_btn.add_theme_font_size_override("font_size", 20)
	create_btn.pressed.connect(_on_create_room)
	create_col.add_child(create_btn)

	# Vertical separator
	var sep := VSeparator.new()
	sep.custom_minimum_size.x = 1
	cols.add_child(sep)

	# Right: Join room
	var join_col := VBoxContainer.new()
	join_col.add_theme_constant_override("separation", 12)
	join_col.custom_minimum_size.x = 280.0
	cols.add_child(join_col)

	var join_title := Label.new()
	join_title.text = "加入房间"
	join_title.add_theme_font_size_override("font_size", 22)
	join_title.add_theme_color_override("font_color", Color("#E8C840"))
	join_col.add_child(join_title)

	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 10)
	join_col.add_child(search_row)
	_search_btn = Button.new()
	_search_btn.custom_minimum_size = Vector2(120, 45)
	_search_btn.text = "搜索房间"
	_search_btn.add_theme_font_size_override("font_size", 18)
	_search_btn.pressed.connect(_on_toggle_search)
	search_row.add_child(_search_btn)
	_join_btn = Button.new()
	_join_btn.custom_minimum_size = Vector2(120, 45)
	_join_btn.text = "加入"
	_join_btn.disabled = true
	_join_btn.add_theme_font_size_override("font_size", 18)
	_join_btn.pressed.connect(_on_join_room)
	search_row.add_child(_join_btn)

	_room_list = ItemList.new()
	_room_list.custom_minimum_size = Vector2(280, 150)
	_room_list.add_theme_font_size_override("font_size", 15)
	_room_list.item_selected.connect(func(_idx):
		_join_btn.disabled = false
	)
	join_col.add_child(_room_list)

	# Back button
	var back_btn := Button.new()
	back_btn.set_anchors_preset(Control.PRESET_CENTER)
	back_btn.offset_top = 200
	back_btn.offset_bottom = 250
	back_btn.custom_minimum_size = Vector2(200, 45)
	back_btn.text = "返回主菜单"
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back)
	_content.add_child(back_btn)


func _build_room_ui() -> void:
	_room_panel = Control.new()
	_room_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room_panel.visible = false
	add_child(_room_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -250
	vbox.offset_top = -260
	vbox.offset_right = 250
	vbox.offset_bottom = 260
	vbox.add_theme_constant_override("separation", 14)
	_room_panel.add_child(vbox)

	_room_title = Label.new()
	_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_title.text = ""
	var ls := LabelSettings.new()
	ls.font_size = 30
	ls.font_color = Color("#E8C840")
	_room_title.label_settings = ls
	vbox.add_child(_room_title)

	var color_title := Label.new()
	color_title.text = "选择你的颜色"
	color_title.add_theme_font_size_override("font_size", 18)
	color_title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(color_title)

	var color_grid := GridContainer.new()
	color_grid.columns = 5
	color_grid.add_theme_constant_override("h_separation", 8)
	color_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(color_grid)

	for i in range(GameConstants.COLOR_PALETTE.size()):
		var entry = GameConstants.COLOR_PALETTE[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 55)
		var c: Color = entry["color"]
		btn.text = entry["name"]
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color("#DDD") if c.get_luminance() < 0.4 else Color("#333"))
		var style := StyleBoxFlat.new()
		style.bg_color = c
		style.set_corner_radius_all(6)
		style.set_border_width_all(2)
		style.border_color = Color.TRANSPARENT
		for s in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(s, style.duplicate())
		btn.pressed.connect(_on_color_selected.bind(i))
		color_grid.add_child(btn)
		_color_btns.append(btn)

	var pl_title := Label.new()
	pl_title.text = "房间玩家"
	pl_title.add_theme_font_size_override("font_size", 18)
	pl_title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(pl_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	vbox.add_child(scroll)
	_player_list_vbox = VBoxContainer.new()
	_player_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_player_list_vbox)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_box)

	_ready_btn = Button.new()
	_ready_btn.custom_minimum_size = Vector2(140, 50)
	_ready_btn.text = "准备"
	_ready_btn.add_theme_font_size_override("font_size", 20)
	_ready_btn.pressed.connect(_on_ready)
	btn_box.add_child(_ready_btn)

	_start_btn = Button.new()
	_start_btn.custom_minimum_size = Vector2(140, 50)
	_start_btn.text = "开始游戏"
	_start_btn.disabled = true
	_start_btn.add_theme_font_size_override("font_size", 20)
	_start_btn.pressed.connect(_on_start_game)
	_start_btn.visible = false
	btn_box.add_child(_start_btn)

	_back_lobby_btn = Button.new()
	_back_lobby_btn.custom_minimum_size = Vector2(140, 45)
	_back_lobby_btn.text = "离开房间"
	_back_lobby_btn.add_theme_font_size_override("font_size", 16)
	_back_lobby_btn.pressed.connect(_on_leave_room)
	vbox.add_child(_back_lobby_btn)


func _connect_signals() -> void:
	if not _nm:
		return
	_nm.room_found.connect(_on_room_found)
	_nm.room_lost.connect(_on_room_lost)
	_nm.hosted.connect(_on_hosted)
	_nm.joined.connect(_on_joined)
	_nm.join_failed.connect(_on_join_failed)
	_nm.player_joined.connect(_on_player_joined)
	_nm.player_left.connect(_on_player_left)
	_nm.connection_lost.connect(_on_connection_lost)
	_nm.game_started.connect(_on_game_started)
	_nm.message_received.connect(_on_message_received)


func _select_count(c: int) -> void:
	_count_select = c
	for k in _count_btns:
		var btn: Button = _count_btns[k]
		if k == c:
			btn.add_theme_color_override("font_color", Color("#E8C840"))
			for s in ["normal", "hover", "pressed", "focus"]:
				var st := StyleBoxFlat.new()
				st.bg_color = Color("#3A3A4A")
				st.border_color = Color("#E8C840")
				st.set_border_width_all(2)
				st.set_corner_radius_all(6)
				btn.add_theme_stylebox_override(s, st)
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
			for s in ["normal", "hover", "pressed", "focus"]:
				var st := StyleBoxFlat.new()
				st.bg_color = Color("#2A2A3A")
				st.set_corner_radius_all(6)
				if s == "hover":
					st.bg_color = Color("#3A3A4A")
				btn.add_theme_stylebox_override(s, st)


func _on_create_room() -> void:
	var name_str := _name_input.text.strip_edges()
	if name_str.is_empty():
		_show_error("请输入昵称")
		return
	var room_name := _room_name_input.text.strip_edges()
	if room_name.is_empty():
		room_name = "%s的房间" % name_str
	if not _nm.create_room(room_name, _count_select, name_str, -1):
		_show_error("创建房间失败，端口可能被占用")
		return
	_enter_room()


func _on_toggle_search() -> void:
	if _searching:
		_nm.stop_discovery()
		_searching = false
		_search_btn.text = "搜索房间"
	else:
		_nm.start_discovery()
		_searching = true
		_search_btn.text = "停止搜索"


func _on_room_found(room_name: String, host_ip: String, players: int, max_players: int) -> void:
	var key := "%s (%s) %d/%d人" % [room_name, host_ip, players, max_players]
	_discovered_ips[key] = host_ip
	_room_list.add_item(key)


func _on_room_lost(host_ip: String) -> void:
	for i in range(_room_list.item_count - 1, -1, -1):
		var txt := _room_list.get_item_text(i)
		var stored_ip: String = _discovered_ips.get(txt, "")
		if stored_ip == host_ip:
			_discovered_ips.erase(txt)
			_room_list.remove_item(i)


func _on_join_room() -> void:
	var selected := _room_list.get_selected_items()
	if selected.is_empty():
		print("[Lobby] 加入: 未选中房间")
		return
	var idx := selected[0]
	var key := _room_list.get_item_text(idx)
	var ip: String = _discovered_ips.get(key, "")
	print("[Lobby] 加入: key='%s', ip='%s'" % [key, ip])
	if ip.is_empty():
		print("[Lobby] 加入: IP 为空, 退出")
		return
	var name_str := _name_input.text.strip_edges()
	if name_str.is_empty():
		_show_error("请输入昵称")
		return
	_nm.stop_discovery()
	_searching = false
	print("[Lobby] 加入: 调用 join_room('%s', '%s')" % [ip, name_str])
	_nm.join_room(ip, name_str)


func _on_hosted(_room_name: String) -> void:
	_enter_room()


func _on_joined(_room_name: String, _pi: int, _role: int) -> void:
	print("[Lobby] 已加入房间: room='%s', pi=%d, role=%d" % [_room_name, _pi, _role])
	_enter_room()


func _on_join_failed(reason: String) -> void:
	print("[Lobby] 加入失败: %s" % reason)
	_show_error("加入失败: %s" % reason)


func _on_player_joined(_pi: int, _player_name: String) -> void:
	_refresh_player_list()


func _on_player_left(_pi: int) -> void:
	_refresh_player_list()


func _on_connection_lost() -> void:
	print("[Lobby] 连接断开")
	_show_error("连接断开")
	_exit_room()


func _on_game_started() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_message_received(msg: Dictionary) -> void:
	if msg.get("type") == "lobby_state":
		_lobby_players = msg.get("players", [])
		_refresh_player_list()
		_update_color_availability()


func _enter_room() -> void:
	_phase = 1
	_my_color_index = -1
	_content.visible = false
	_room_panel.visible = true
	if _nm.is_host():
		_room_title.text = "房间: %s (你是房主)" % _nm._room_name
		_start_btn.visible = true
	else:
		_room_title.text = "房间: 连接中..."
		_ready_btn.visible = true
	_refresh_player_list()
	_update_color_availability()


func _exit_room() -> void:
	_phase = 0
	_nm.leave_room()
	_my_color_index = -1
	_content.visible = true
	_room_panel.visible = false
	_room_list.clear()
	_discovered_ips.clear()


func _refresh_player_list() -> void:
	for child in _player_list_vbox.get_children():
		child.queue_free()
	var players: Array = _nm.get_lobby_players()
	for p in players:
		var row := HBoxContainer.new()
		var role_text: String = "Mr. X" if int(p["role"]) == GameConstants.PlayerRole.MRX else "侦探"
		var ready_text: String = " ✓" if p.get("ready", false) else ""
		var ci := int(p.get("color_index", -1))
		var color_name: String = GameConstants.COLOR_PALETTE[ci]["name"] if ci >= 0 and ci < GameConstants.COLOR_PALETTE.size() else ""
		var text: String = "%s (%s%s) [%s]" % [p["name"], role_text, ready_text, color_name]
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(label)
		_player_list_vbox.add_child(row)
	if _nm.is_host():
		var all_ready := true
		for p in players:
			if int(p["role"]) == GameConstants.PlayerRole.DETECTIVE and not p.get("ready", false):
				all_ready = false
				break
		_start_btn.disabled = not all_ready or players.size() < _count_select


var _error_popup: AcceptDialog

func _show_error(text: String) -> void:
	if not _error_popup:
		_error_popup = AcceptDialog.new()
		_error_popup.title = "提示"
		_error_popup.get_ok_button().text = "确定"
		add_child(_error_popup)
	_error_popup.dialog_text = text
	_error_popup.popup_centered()


func _update_color_availability() -> void:
	var players: Array = _nm.get_lobby_players()
	var taken: Array = []
	for p in players:
		var ci := int(p.get("color_index", -1))
		if ci >= 0:
			taken.append(ci)
	for i in range(_color_btns.size()):
		var btn: Button = _color_btns[i]
		var is_taken := taken.has(i) and i != _my_color_index
		btn.disabled = is_taken
		if is_taken:
			for s in ["normal", "hover", "pressed", "focus"]:
				var st := StyleBoxFlat.new()
				st.bg_color = Color(0.3, 0.3, 0.3, 0.5)
				st.set_corner_radius_all(6)
				btn.add_theme_stylebox_override(s, st)
			btn.add_theme_color_override("font_color", Color("#666"))
		else:
			var entry = GameConstants.COLOR_PALETTE[i]
			var c: Color = entry["color"]
			for s in ["normal", "hover", "pressed", "focus"]:
				var st := StyleBoxFlat.new()
				st.bg_color = c
				st.set_corner_radius_all(6)
				st.set_border_width_all(2)
				st.border_color = Color.TRANSPARENT
				if s == "hover":
					st.border_color = Color.WHITE
				btn.add_theme_stylebox_override(s, st)
			btn.add_theme_color_override("font_color", Color("#DDD") if c.get_luminance() < 0.4 else Color("#333"))
			if i == _my_color_index:
				for s in ["normal", "hover", "pressed", "focus"]:
					var st := StyleBoxFlat.new()
					st.bg_color = c
					st.set_corner_radius_all(6)
					st.set_border_width_all(3)
					st.border_color = Color("#E8C840")
					btn.add_theme_stylebox_override(s, st)


func _on_color_selected(index: int) -> void:
	_my_color_index = index
	if _nm.is_host():
		_nm._color_indices.clear()
		_nm._color_indices.append(index)
		_nm._lobby_players[0]["color_index"] = index
		_nm._refresh_lobby()
	else:
		_nm.send_message({"type": "join", "name": _nm._my_name, "color_index": index})
	_update_color_availability()


func _on_ready() -> void:
	if _my_color_index < 0:
		_show_error("请先选择颜色")
		return
	_nm.send_message({"type": "ready"})
	_ready_btn.disabled = true
	_ready_btn.text = "已准备"


func _on_start_game() -> void:
	if _nm.is_host():
		_nm.start_game()


func _on_leave_room() -> void:
	_exit_room()


func _on_back() -> void:
	_nm.stop_discovery()
	_nm.leave_room()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
