extends Control

var _map_renderer: Node2D
var _map_container: Control
var _valid_moves: Array = []
var _selected_station: int = -1
var _waiting_for_ready: bool = false
var _current_player_for_display: int = -1
var _ticket_rows: Dictionary = {}
var _pool_rows: Dictionary = {}
var _round_label: Label
var _player_label: Label
var _log_list: VBoxContainer
var _turn_overlay: Control
var _overlay_msg: Label
var _overlay_name: Label
var _overlay_hint: Label
var _ready_btn: Button
var _game_over: Control
var _go_title: Label
var _go_reason: Label
var _ticket_popup: Control
var _popup_panel: PanelContainer
var _popup_content: VBoxContainer
var _confirm_popup: Control
var _confirm_station: int = -1
var _confirm_ticket: int = -1
var _ticket_panel: VBoxContainer
var _pool_panel: VBoxContainer
var _hint_label: Label

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_build_ticket_panels()
	_build_pool_panels()
	get_viewport().size_changed.connect(_on_viewport_resized)
	call_deferred("_deferred_setup")

func _deferred_setup() -> void:
	await get_tree().process_frame
	_setup_map()
	# 手动同步有效移动（信号可能在场景加载前就发了）
	var gs = get_node("/root/GameState")
	var player = gs.get_current_player()
	if player and not player.is_stuck:
		_valid_moves = MoveValidator.get_valid_moves(player, gs.players, get_node("/root/MapData"))
	_show_turn_overlay(0)

func _build_ui() -> void:
	# Side panel (right side, fixed 280px)
	var side := PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_FULL_RECT)
	side.anchor_left = 1.0
	side.offset_left = -280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	side.add_theme_stylebox_override("panel", style)
	add_child(side)
	_map_container = Control.new()
	_map_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_container.anchor_right = 1.0
	_map_container.offset_right = -280
	_map_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_container.z_index = 1
	add_child(_map_container)

	_map_renderer = Node2D.new()
	_map_renderer.name = "MapRenderer"
	_map_renderer.set_script(load("res://scripts/map/map_renderer.gd"))
	_map_container.add_child(_map_renderer)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 8)
	side.add_child(side_vbox)

	_round_label = Label.new()
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.text = "回合: 1 / %d" % GameConstants.MAX_ROUNDS
	_round_label.add_theme_font_size_override("font_size", 16)
	_round_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	side_vbox.add_child(_round_label)

	_player_label = Label.new()
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_label.text = "当前: Mr. X"
	_player_label.add_theme_font_size_override("font_size", 20)
	_player_label.add_theme_color_override("font_color", Color.WHITE)
	side_vbox.add_child(_player_label)

	side_vbox.add_child(HSeparator.new())

	var t_title := Label.new()
	t_title.text = "  当前玩家车票"
	t_title.add_theme_font_size_override("font_size", 14)
	t_title.add_theme_color_override("font_color", Color("#CCCCCC"))
	side_vbox.add_child(t_title)

	_ticket_panel = VBoxContainer.new()
	_ticket_panel.add_theme_constant_override("separation", 4)
	side_vbox.add_child(_ticket_panel)

	side_vbox.add_child(HSeparator.new())

	var p_title := Label.new()
	p_title.text = "  公共票池"
	p_title.add_theme_font_size_override("font_size", 14)
	p_title.add_theme_color_override("font_color", Color("#CCCCCC"))
	side_vbox.add_child(p_title)

	_pool_panel = VBoxContainer.new()
	_pool_panel.add_theme_constant_override("separation", 4)
	side_vbox.add_child(_pool_panel)

	side_vbox.add_child(HSeparator.new())

	var l_title := Label.new()
	l_title.text = "  Mr. X 移动记录"
	l_title.add_theme_font_size_override("font_size", 14)
	l_title.add_theme_color_override("font_color", Color("#CCCCCC"))
	side_vbox.add_child(l_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_vbox.add_child(scroll)

	_log_list = VBoxContainer.new()
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_log_list)

	# 操作提示栏
	side_vbox.add_child(HSeparator.new())
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.text = "点击绿色高亮的站点移动"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color("#77AA77"))
	side_vbox.add_child(_hint_label)

	# Turn overlay
	_turn_overlay = Control.new()
	_turn_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn_overlay.z_index = 100
	add_child(_turn_overlay)

	var overlay_bg := ColorRect.new()
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_bg.color = Color.BLACK
	overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_turn_overlay.add_child(overlay_bg)

	var ov_box := VBoxContainer.new()
	ov_box.set_anchors_preset(Control.PRESET_CENTER)
	ov_box.offset_left = -200
	ov_box.offset_top = -120
	ov_box.offset_right = 200
	ov_box.offset_bottom = 120
	ov_box.add_theme_constant_override("separation", 30)
	_turn_overlay.add_child(ov_box)

	_overlay_msg = Label.new()
	_overlay_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_msg.text = "请将设备交给"
	_overlay_msg.add_theme_font_size_override("font_size", 22)
	_overlay_msg.add_theme_color_override("font_color", Color("#CCCCCC"))
	ov_box.add_child(_overlay_msg)

	_overlay_name = Label.new()
	_overlay_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_name.text = "Mr. X"
	_overlay_name.add_theme_font_size_override("font_size", 32)
	_overlay_name.add_theme_color_override("font_color", Color("#E8C840"))
	ov_box.add_child(_overlay_name)

	_overlay_hint = Label.new()
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_hint.text = ""
	_overlay_hint.add_theme_font_size_override("font_size", 14)
	_overlay_hint.add_theme_color_override("font_color", Color("#888888"))
	ov_box.add_child(_overlay_hint)

	_ready_btn = Button.new()
	_ready_btn.custom_minimum_size = Vector2(180, 55)
	_ready_btn.text = "准备好了，开始操作"
	_ready_btn.add_theme_font_size_override("font_size", 20)
	ov_box.add_child(_ready_btn)

	# Game over screen
	_game_over = Control.new()
	_game_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.z_index = 200
	_game_over.visible = false
	add_child(_game_over)

	var go_bg := ColorRect.new()
	go_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	go_bg.color = Color(0, 0, 0, 0.85)
	go_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over.add_child(go_bg)

	var go_box := VBoxContainer.new()
	go_box.set_anchors_preset(Control.PRESET_CENTER)
	go_box.offset_left = -220
	go_box.offset_top = -130
	go_box.offset_right = 220
	go_box.offset_bottom = 130
	go_box.add_theme_constant_override("separation", 25)
	_game_over.add_child(go_box)

	_go_title = Label.new()
	_go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_title.text = "游戏结束"
	_go_title.add_theme_font_size_override("font_size", 36)
	go_box.add_child(_go_title)

	_go_reason = Label.new()
	_go_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_reason.text = ""
	_go_reason.add_theme_font_size_override("font_size", 20)
	_go_reason.add_theme_color_override("font_color", Color.WHITE)
	go_box.add_child(_go_reason)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(180, 50)
	back_btn.text = "返回主菜单"
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	go_box.add_child(back_btn)

	# Ticket select popup — uses PanelContainer + VBox for clean layout
	_ticket_popup = Control.new()
	_ticket_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ticket_popup.z_index = 50
	_ticket_popup.visible = false
	_map_container.add_child(_ticket_popup)

	_popup_panel = PanelContainer.new()
	_popup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var pop_style := StyleBoxFlat.new()
	pop_style.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	pop_style.border_color = Color(0.4, 0.4, 0.5)
	pop_style.set_border_width_all(2)
	pop_style.set_corner_radius_all(8)
	pop_style.set_content_margin_all(16)
	_popup_panel.add_theme_stylebox_override("panel", pop_style)
	_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ticket_popup.add_child(_popup_panel)

	_popup_content = VBoxContainer.new()
	_popup_content.add_theme_constant_override("separation", 12)
	_popup_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_panel.add_child(_popup_content)

	# Move confirmation popup
	_confirm_popup = Control.new()
	_confirm_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_popup.z_index = 60
	_confirm_popup.visible = false
	_map_container.add_child(_confirm_popup)

	var confirm_panel := PanelContainer.new()
	confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	confirm_style.border_color = Color(0.4, 0.4, 0.5)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(8)
	confirm_style.set_content_margin_all(20)
	confirm_panel.add_theme_stylebox_override("panel", confirm_style)
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_panel.name = "ConfirmVBox"
	_confirm_popup.add_child(confirm_panel)

	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.add_theme_constant_override("separation", 12)
	confirm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_panel.add_child(confirm_vbox)

	var confirm_title := Label.new()
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.text = "确认移动？"
	confirm_title.add_theme_font_size_override("font_size", 18)
	confirm_title.add_theme_color_override("font_color", Color.WHITE)
	confirm_vbox.add_child(confirm_title)

	var confirm_info := Label.new()
	confirm_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_info.name = "ConfirmInfo"
	confirm_info.text = ""
	confirm_info.add_theme_font_size_override("font_size", 14)
	confirm_info.add_theme_color_override("font_color", Color("#CCCCCC"))
	confirm_vbox.add_child(confirm_info)

	var confirm_btn_box := HBoxContainer.new()
	confirm_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_btn_box.add_theme_constant_override("separation", 20)
	confirm_vbox.add_child(confirm_btn_box)

	var confirm_yes := Button.new()
	confirm_yes.custom_minimum_size = Vector2(100, 40)
	confirm_yes.text = "确认"
	confirm_yes.add_theme_font_size_override("font_size", 16)
	confirm_yes.pressed.connect(_on_move_confirmed)
	confirm_btn_box.add_child(confirm_yes)

	var confirm_no := Button.new()
	confirm_no.custom_minimum_size = Vector2(100, 40)
	confirm_no.text = "取消"
	confirm_no.add_theme_font_size_override("font_size", 16)
	confirm_no.pressed.connect(_on_move_cancelled)
	confirm_btn_box.add_child(confirm_no)

func _setup_map() -> void:
	var gs = get_node("/root/GameState")
	var md = get_node("/root/MapData")
	print("[GameBoard] map_container size=", _map_container.size, " viewport=", get_viewport_rect().size)
	if _map_container.size.x < 10 or _map_container.size.y < 10:
		print("[GameBoard] container too small, using viewport fallback")
		md.calculate_viewport_transform(get_viewport_rect().size * 0.78)
	else:
		md.calculate_viewport_transform(_map_container.size)
	_map_renderer.refresh()
	for i in range(gs.players.size()):
		var p = gs.players[i]
		var label := "X" if p.role == GameConstants.PlayerRole.MRX else "D%d" % i
		_map_renderer.create_token(i, p.station_id, p.color, label)
	_update_token_visibility()

func _connect_signals() -> void:
	var gs = get_node("/root/GameState")
	gs.turn_started.connect(_on_turn_started)
	gs.move_made.connect(_on_move_made)
	gs.mrx_surfaced.connect(_on_mrx_surfaced)
	gs.mrx_move_logged.connect(_on_mrx_move_logged)
	gs.game_over.connect(_on_game_over)
	gs.valid_moves_updated.connect(_on_valid_moves_updated)
	gs.double_move_available.connect(_on_double_move_available)
	gs.double_move_second_step.connect(_on_double_move_second_step)
	_ready_btn.pressed.connect(_on_ready_pressed)

func _build_ticket_panels() -> void:
	var gs = get_node("/root/GameState")
	for child in _ticket_panel.get_children():
		child.queue_free()
	_ticket_rows.clear()
	var ticket_types: Array = [GameConstants.TicketType.TAXI, GameConstants.TicketType.BUS, GameConstants.TicketType.UNDERGROUND]
	if gs.players.size() > 0:
		ticket_types.append_array([GameConstants.TicketType.BLACK, GameConstants.TicketType.DOUBLE])
	for tt in ticket_types:
		var row := HBoxContainer.new()
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(16, 16)
		cr.color = GameConstants.TICKET_COLORS[tt]
		var nl := Label.new()
		nl.text = GameConstants.TICKET_NAMES[tt]
		nl.add_theme_font_size_override("font_size", 14)
		var cl := Label.new()
		cl.text = "x0"
		cl.add_theme_font_size_override("font_size", 14)
		row.add_child(cr)
		row.add_child(nl)
		row.add_child(cl)
		_ticket_panel.add_child(row)
		_ticket_rows[tt] = cl

func _build_pool_panels() -> void:
	for child in _pool_panel.get_children():
		child.queue_free()
	_pool_rows.clear()
	for tt in [GameConstants.TicketType.TAXI, GameConstants.TicketType.BUS, GameConstants.TicketType.UNDERGROUND]:
		var row := HBoxContainer.new()
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(12, 12)
		cr.color = GameConstants.TICKET_COLORS[tt]
		var nl := Label.new()
		nl.text = GameConstants.TICKET_NAMES[tt]
		nl.add_theme_font_size_override("font_size", 12)
		var cl := Label.new()
		cl.text = "x0"
		cl.add_theme_font_size_override("font_size", 12)
		row.add_child(cr)
		row.add_child(nl)
		row.add_child(cl)
		_pool_panel.add_child(row)
		_pool_rows[tt] = cl

func _update_ticket_panel() -> void:
	var gs = get_node("/root/GameState")
	var player = gs.get_current_player()
	if player == null:
		return
	for tt in _ticket_rows:
		if _ticket_rows[tt]:
			_ticket_rows[tt].text = "x%d" % player.tickets.counts.get(tt, 0)

func _update_pool_panel() -> void:
	var gs = get_node("/root/GameState")
	for tt in _pool_rows:
		if _pool_rows[tt]:
			_pool_rows[tt].text = "x%d" % gs.ticket_pool.get(tt, 0)

func _update_token_visibility() -> void:
	var gs = get_node("/root/GameState")
	for i in range(gs.players.size()):
		var p = gs.players[i]
		if p.role == GameConstants.PlayerRole.MRX:
			if _current_player_for_display == 0:
				_map_renderer.show_token(i)
			elif gs.is_surface_round(gs.mrx_move_count):
				_map_renderer.show_token(i)
			else:
				_map_renderer.hide_token(i)
		else:
			_map_renderer.show_token(i)

func _show_turn_overlay(player_index: int, hint: String = "") -> void:
	_waiting_for_ready = true
	var gs = get_node("/root/GameState")
	var player = gs.players[player_index]
	_turn_overlay.visible = true
	_overlay_msg.text = "请将设备交给"
	_overlay_name.text = player.name
	_overlay_name.add_theme_color_override("font_color", player.color)
	_overlay_hint.text = hint
	_map_renderer.clear_highlights()
	_update_token_visibility()

func _on_ready_pressed() -> void:
	if not _waiting_for_ready:
		return
	_waiting_for_ready = false
	_turn_overlay.visible = false
	var gs = get_node("/root/GameState")
	_current_player_for_display = gs.current_player_index
	_update_token_visibility()
	_map_renderer.set_active_player(gs.current_player_index)
	_update_ticket_panel()
	_update_pool_panel()
	var player = gs.get_current_player()
	if player and not player.is_stuck:
		_valid_moves = MoveValidator.get_valid_moves(player, gs.players, get_node("/root/MapData"))
		var dests: Array = MoveValidator.get_unique_destinations(_valid_moves)
		print("[highlight] dests=", dests.size())
		_map_renderer.highlight_stations(dests, Color.GREEN)
		_hint_label.text = "点击绿色高亮站点进行移动" + "\n" + "多交通类型可选时会弹窗选择车票"
	elif player and player.is_stuck:
		_hint_label.text = "当前玩家被困住了，自动跳过"

func _on_turn_started(player_index: int, round_number: int) -> void:
	var gs = get_node("/root/GameState")
	_round_label.text = "回合: %d / %d" % [round_number, GameConstants.MAX_ROUNDS]
	var player = gs.players[player_index]
	_player_label.text = "当前: %s" % player.name
	_player_label.add_theme_color_override("font_color", player.color)
	var hint: String = ""
	if player_index == 0 and gs.is_double_move:
		hint = "双倍移动 - 第二步"
	_show_turn_overlay(player_index, hint)

func _on_move_made(player_index: int, _from: int, to: int, _ticket: int) -> void:
	_map_renderer.move_token(player_index, to)

func _on_mrx_surfaced(_station_id: int, _round: int) -> void:
	pass

func _on_mrx_move_logged(move_number: int, ticket_type: int, station_id: int, station_shown: bool) -> void:
	var row := HBoxContainer.new()
	var rl := Label.new()
	rl.text = "#%d:" % move_number
	rl.custom_minimum_size.x = 40.0
	rl.add_theme_font_size_override("font_size", 12)
	var cr := ColorRect.new()
	cr.custom_minimum_size = Vector2(12, 12)
	cr.color = GameConstants.TICKET_COLORS.get(ticket_type, Color.GRAY)
	var tl := Label.new()
	tl.text = GameConstants.TICKET_NAMES.get(ticket_type, "?")
	tl.add_theme_font_size_override("font_size", 12)
	var sl := Label.new()
	if station_shown:
		sl.text = "  -> 站点 %d" % station_id
		sl.add_theme_color_override("font_color", Color("#E8C840"))
	else:
		sl.text = "  -> ???"
		sl.add_theme_color_override("font_color", Color("#666666"))
	sl.add_theme_font_size_override("font_size", 12)
	row.add_child(rl)
	row.add_child(cr)
	row.add_child(tl)
	row.add_child(sl)
	_log_list.add_child(row)

func _on_game_over(winner: int, reason: String) -> void:
	_game_over.visible = true
	if winner == GameConstants.PlayerRole.DETECTIVE:
		_go_title.text = "侦探胜利!"
		_go_title.add_theme_color_override("font_color", Color("#4CAF50"))
	else:
		_go_title.text = "Mr. X 胜利!"
		_go_title.add_theme_color_override("font_color", Color("#E8C840"))
	_go_reason.text = reason

func _on_valid_moves_updated(_moves: Array) -> void:
	pass

func _on_double_move_available() -> void:
	var gs = get_node("/root/GameState")
	if not gs.players[0].tickets.can_use(GameConstants.TicketType.DOUBLE):
		gs.skip_double_move()
		return
	_turn_overlay.visible = true
	_overlay_msg.text = "Mr. X 是否使用"
	_overlay_name.text = "双倍移动票?"
	_overlay_name.add_theme_color_override("font_color", Color("#9C27B0"))
	_overlay_hint.text = ""
	# Replace ready button with two option buttons
	_ready_btn.visible = false
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	btn_box.name = "DoubleBtnBox"
	var ov_box = _turn_overlay.get_child(1)
	ov_box.add_child(btn_box)
	var use_btn := Button.new()
	use_btn.custom_minimum_size = Vector2(140, 50)
	use_btn.text = "使用"
	use_btn.add_theme_color_override("font_color", Color("#9C27B0"))
	use_btn.add_theme_font_size_override("font_size", 20)
	use_btn.pressed.connect(func():
		_turn_overlay.visible = false
		btn_box.queue_free()
		_ready_btn.visible = true
		_update_ticket_panel()
		gs.use_double_move()
	)
	btn_box.add_child(use_btn)
	var skip_btn := Button.new()
	skip_btn.custom_minimum_size = Vector2(140, 50)
	skip_btn.text = "不使用"
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.pressed.connect(func():
		_turn_overlay.visible = false
		btn_box.queue_free()
		_ready_btn.visible = true
		gs.skip_double_move()
	)
	btn_box.add_child(skip_btn)

func _on_double_move_second_step() -> void:
	_turn_overlay.visible = true
	_overlay_msg.text = "Mr. X 双倍移动"
	_overlay_name.text = "第二步"
	_overlay_name.add_theme_color_override("font_color", Color("#9C27B0"))
	_overlay_hint.text = "请选择第二个目标站点"
	_ready_btn.visible = true
	_ready_btn.text = "准备好了"
	_waiting_for_ready = true
	_map_renderer.clear_highlights()

func _gui_input(event: InputEvent) -> void:
	if _waiting_for_ready:
		return
	var gs = get_node("/root/GameState")
	if gs == null or gs.phase != GameConstants.GamePhase.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_map_click(get_global_mouse_position())

func _handle_map_click(screen_pos: Vector2) -> void:
	var gs = get_node("/root/GameState")
	var player = gs.get_current_player()
	if player == null or player.is_stuck:
		return
	var map_rect: Rect2 = _map_container.get_global_rect()
	if not map_rect.has_point(screen_pos):
		return
	var local_pos: Vector2 = screen_pos - map_rect.position
	var md = get_node("/root/MapData")
	var candidates: Array = md.get_station_ids_at_position(local_pos)
	if candidates.is_empty():
		return
	var dests: Array = MoveValidator.get_unique_destinations(_valid_moves)
	var station_id: int = -1
	for entry in candidates:
		if dests.has(entry["id"]):
			station_id = entry["id"]
			break
	if station_id < 0:
		return
	var ticket_options: Array = MoveValidator.get_ticket_options_for_destination(station_id, _valid_moves)
	if ticket_options.size() == 1:
		_show_move_confirm(station_id, player.station_id, ticket_options[0])
	elif ticket_options.size() > 1:
		_show_ticket_select(station_id, ticket_options)

func _show_ticket_select(station_id: int, options: Array) -> void:
	_selected_station = station_id
	for child in _popup_content.get_children():
		child.queue_free()

	var pop_title := Label.new()
	pop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop_title.text = "选择车票类型"
	pop_title.add_theme_font_size_override("font_size", 20)
	pop_title.add_theme_color_override("font_color", Color.WHITE)
	_popup_content.add_child(pop_title)

	for tt in options:
		var btn := Button.new()
		var tname: String = GameConstants.TICKET_NAMES.get(tt, "?")
		var color: Color = GameConstants.TICKET_COLORS.get(tt, Color.GRAY)
		btn.text = "  " + tname
		btn.custom_minimum_size = Vector2(160, 44)
		btn.add_theme_font_size_override("font_size", 18)
		if color.v < 0.3:
			btn.add_theme_color_override("font_color", Color("#BBBBBB"))
		else:
			btn.add_theme_color_override("font_color", color)
		btn.pressed.connect(_on_ticket_selected.bind(tt))
		_popup_content.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.add_theme_color_override("font_color", Color("#888888"))
	cancel_btn.pressed.connect(func():
		_ticket_popup.visible = false
		_selected_station = -1
	)
	_popup_content.add_child(cancel_btn)

	_ticket_popup.visible = true

func _on_ticket_selected(ticket_type: int) -> void:
	_ticket_popup.visible = false
	if _selected_station >= 0:
		var gs = get_node("/root/GameState")
		var player = gs.get_current_player()
		_show_move_confirm(_selected_station, player.station_id, ticket_type)
		_selected_station = -1

func _show_move_confirm(target: int, from: int, ticket_type: int) -> void:
	_confirm_station = target
	_confirm_ticket = ticket_type
	var info = _confirm_popup.find_child("ConfirmInfo", true, false)
	if info:
		var ticket_name: String = GameConstants.TICKET_NAMES.get(ticket_type, "?")
		var ticket_color: Color = GameConstants.TICKET_COLORS.get(ticket_type, Color.GRAY)
		info.text = "站点 %d → 站点 %d\n将消耗: %s" % [from, target, ticket_name]
		if ticket_color.v < 0.3:
			info.add_theme_color_override("font_color", Color("#BBBBBB"))
		else:
			info.add_theme_color_override("font_color", ticket_color)
	_confirm_popup.visible = true

func _on_move_confirmed() -> void:
	_confirm_popup.visible = false
	if _confirm_station >= 0:
		get_node("/root/GameState").execute_move(_confirm_station, _confirm_ticket)
		_confirm_station = -1
		_confirm_ticket = -1

func _on_move_cancelled() -> void:
	_confirm_popup.visible = false
	_confirm_station = -1
	_confirm_ticket = -1
var _resize_timer: SceneTreeTimer = null

func _on_viewport_resized() -> void:
	_map_renderer.refresh()
	if _resize_timer:
		_resize_timer.timeout.disconnect(_deferred_highlight)
	_resize_timer = get_tree().create_timer(0.2)
	_resize_timer.timeout.connect(_deferred_highlight)

func _deferred_highlight() -> void:
	_resize_timer = null
	if _waiting_for_ready:
		return
	var gs = get_node("/root/GameState")
	if gs == null or gs.phase != GameConstants.GamePhase.PLAYING:
		return
	var player = gs.get_current_player()
	if player and not player.is_stuck:
		var moves: Array = MoveValidator.get_valid_moves(player, gs.players, get_node("/root/MapData"))
		var dests: Array = MoveValidator.get_unique_destinations(moves)
		_map_renderer.highlight_stations(dests, Color.GREEN)
