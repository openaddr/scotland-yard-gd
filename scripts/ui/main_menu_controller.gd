extends Control

var _selected_count: int = 3
var _count_buttons: Dictionary = {}
var _color_selections: Array = []
var _color_btns: Array[Button] = []
var _color_prompt_label: Label
var _color_grid: GridContainer
var _main_content: Control
var _color_content: Control
var _settings_content: Control
var _hl_color_btns: Array[Button] = []

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.15, 1)
	add_child(bg)

	_main_content = Control.new()
	_main_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_content)

	_color_content = Control.new()
	_color_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_content.visible = false
	add_child(_color_content)

	_settings_content = Control.new()
	_settings_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_content.visible = false
	add_child(_settings_content)


	_build_main_ui()
	_build_color_ui()
	_build_settings_ui()

func _build_main_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200
	vbox.offset_top = -200
	vbox.offset_right = 200
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)
	_main_content.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Scotland Yard"
	var ls_title := LabelSettings.new()
	ls_title.font_size = 48
	ls_title.font_color = Color("#E8C840")
	title.label_settings = ls_title
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.text = "苏 格 兰 场"
	var ls_sub := LabelSettings.new()
	ls_sub.font_size = 32
	ls_sub.font_color = Color("#CCCCCC")
	subtitle.label_settings = ls_sub
	vbox.add_child(subtitle)

	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.text = "选择玩家人数"
	var ls_normal := LabelSettings.new()
	ls_normal.font_size = 20
	ls_normal.font_color = Color.WHITE
	count_label.label_settings = ls_normal
	vbox.add_child(count_label)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_box)

	for count in [3, 4, 5]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 50)
		btn.text = "%d人" % count
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func(): _select_count(count))
		btn_box.add_child(btn)
		_count_buttons[count] = btn

	_select_count(3)

	var settings_btn := Button.new()
	settings_btn.custom_minimum_size = Vector2(200, 45)
	settings_btn.text = "设置"
	settings_btn.add_theme_font_size_override("font_size", 18)
	settings_btn.pressed.connect(_enter_settings)
	vbox.add_child(settings_btn)

	var start_btn := Button.new()
	start_btn.custom_minimum_size = Vector2(200, 60)
	start_btn.text = "开始游戏"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.pressed.connect(_enter_color_selection)
	vbox.add_child(start_btn)

	var rules_btn := Button.new()
	rules_btn.custom_minimum_size = Vector2(200, 45)
	rules_btn.text = "游戏规则"
	rules_btn.add_theme_font_size_override("font_size", 18)
	rules_btn.pressed.connect(_show_rules)
	vbox.add_child(rules_btn)

	_build_rules_popup()

	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = "本地多人热座模式"
	var ls_small := LabelSettings.new()
	ls_small.font_size = 14
	ls_small.font_color = Color("#888888")
	info.label_settings = ls_small
	vbox.add_child(info)

	var rules := Label.new()
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.text = "侦探协作追踪 Mr. X，Mr. X 在伦敦地铁中逃脱"
	var ls_rules := LabelSettings.new()
	ls_rules.font_size = 12
	ls_rules.font_color = Color("#666666")
	rules.label_settings = ls_rules
	vbox.add_child(rules)

func _build_color_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -250
	vbox.offset_top = -200
	vbox.offset_right = 250
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)
	_color_content.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "选择颜色"
	var ls_title := LabelSettings.new()
	ls_title.font_size = 36
	ls_title.font_color = Color("#E8C840")
	title.label_settings = ls_title
	vbox.add_child(title)

	_color_prompt_label = Label.new()
	_color_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_color_prompt_label.text = ""
	var ls_prompt := LabelSettings.new()
	ls_prompt.font_size = 22
	ls_prompt.font_color = Color.WHITE
	_color_prompt_label.label_settings = ls_prompt
	vbox.add_child(_color_prompt_label)

	var summary_label := Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.name = "SummaryLabel"
	summary_label.text = ""
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ls_summary := LabelSettings.new()
	ls_summary.font_size = 14
	ls_summary.font_color = Color("#999999")
	summary_label.label_settings = ls_summary
	vbox.add_child(summary_label)

	_color_grid = GridContainer.new()
	_color_grid.columns = 5
	_color_grid.add_theme_constant_override("h_separation", 10)
	_color_grid.add_theme_constant_override("v_separation", 10)
	_color_grid.add_theme_constant_override("h_size_flags", 4)
	vbox.add_child(_color_grid)

	for i in range(GameConstants.COLOR_PALETTE.size()):
		var entry = GameConstants.COLOR_PALETTE[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 70)
		var c: Color = entry["color"]
		btn.add_theme_color_override("font_color", (Color("#DDDDDD") if c.get_luminance() < 0.4 else Color("#333333")))
		var style := StyleBoxFlat.new()
		style.bg_color = c
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color.TRANSPARENT
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, style.duplicate())
		var label_text = entry["name"]
		btn.text = label_text
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_color_selected.bind(i))
		_color_grid.add_child(btn)
		_color_btns.append(btn)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_box)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(120, 45)
	back_btn.text = "返回"
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_exit_color_selection)
	btn_box.add_child(back_btn)

	var reset_btn := Button.new()
	reset_btn.custom_minimum_size = Vector2(120, 45)
	reset_btn.text = "重新选择"
	reset_btn.add_theme_font_size_override("font_size", 18)
	reset_btn.pressed.connect(_reset_color_selection)
	reset_btn.name = "ResetBtn"
	btn_box.add_child(reset_btn)

func _select_count(count: int) -> void:
	_selected_count = count
	for c in _count_buttons:
		var btn: Button = _count_buttons[c]
		if c == count:
			btn.add_theme_color_override("font_color", Color("#E8C840"))
			for state in ["normal", "hover", "pressed", "focus"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("#3A3A4A")
				style.border_color = Color("#E8C840")
				style.set_border_width_all(2)
				style.set_corner_radius_all(6)
				if state == "pressed":
					style.bg_color = Color("#4A4A5A")
				btn.add_theme_stylebox_override(state, style)
		else:
			btn.add_theme_color_override("font_color", Color.WHITE)
			for state in ["normal", "hover", "pressed", "focus"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("#2A2A3A")
				style.set_corner_radius_all(6)
				if state == "hover":
					style.bg_color = Color("#3A3A4A")
				elif state == "pressed":
					style.bg_color = Color("#4A4A5A")
				btn.add_theme_stylebox_override(state, style)

func _enter_color_selection() -> void:
	_color_selections.clear()
	_main_content.visible = false
	_color_content.visible = true
	_update_color_ui()

func _exit_color_selection() -> void:
	_color_content.visible = false
	_main_content.visible = true

func _reset_color_selection() -> void:
	_color_selections.clear()
	_update_color_ui()

func _update_color_ui() -> void:
	var current_player: int = _color_selections.size()
	if current_player >= _selected_count:
		_start_game_with_colors()
		return
	var player_label: String
	if current_player == 0:
		player_label = "Mr. X"
	else:
		player_label = "侦探 %d" % current_player
	_color_prompt_label.text = "请 %s 选择颜色" % player_label
	for i in range(_color_btns.size()):
		var btn: Button = _color_btns[i]
		var is_taken: bool = _color_selections.has(i)
		btn.disabled = is_taken
		if is_taken:
			for state in ["normal", "hover", "pressed", "focus"]:
				var s: StyleBoxFlat = btn.get_theme_stylebox(state).duplicate()
				s.bg_color = Color(0.3, 0.3, 0.3, 0.5)
				s.border_color = Color.TRANSPARENT
				btn.add_theme_stylebox_override(state, s)
			btn.add_theme_color_override("font_color", Color("#666666"))
		else:
			var entry = GameConstants.COLOR_PALETTE[i]
			var c: Color = entry["color"]
			for state in ["normal", "hover", "pressed", "focus"]:
				var s := StyleBoxFlat.new()
				s.bg_color = c
				s.set_corner_radius_all(8)
				s.set_border_width_all(2)
				s.border_color = Color.TRANSPARENT
				if state == "hover":
					s.border_color = Color.WHITE
				elif state == "pressed":
					s.bg_color = c.darkened(0.2)
				btn.add_theme_stylebox_override(state, s)
			btn.add_theme_color_override("font_color", (Color("#DDDDDD") if c.get_luminance() < 0.4 else Color("#333333")))
	var summary_label = _color_content.find_child("SummaryLabel", true, false)
	if summary_label:
		var parts: PackedStringArray = []
		for idx in _color_selections:
			parts.append(GameConstants.COLOR_PALETTE[idx]["name"])
		summary_label.text = "已选: " + " ".join(parts) if parts.size() > 0 else ""
	var reset_btn = _color_content.find_child("ResetBtn", true, false)
	if reset_btn:
		reset_btn.visible = _color_selections.size() > 0

func _on_color_selected(index: int) -> void:
	if _color_selections.has(index):
		return
	_color_selections.append(index)
	_update_color_ui()

func _start_game_with_colors() -> void:
	get_node("/root/GameState").start_game(_selected_count, _color_selections)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _build_rules_popup() -> void:
	var popup := AcceptDialog.new()
	popup.title = "游戏规则"
	popup.size = Vector2i(520, 480)
	popup.unresizable = true
	popup.get_ok_button().text = "知道了"
	var rules_text := "Scotland Yard（苏格兰场）游戏规则：

【目标】
  侦探方：协作追踪并抓住 Mr. X
  Mr. X：利用交通工具在伦敦逃脱，坚持24回合

【交通方式】
  出租车（黄色票）：可前往相邻站点
  公交车（绿色票）：可前往较远站点
  地铁（红色票）：可前往跨区站点
  渡船（黑票）：仅限 Mr. X 使用

【操作方式】
  1. 每回合玩家轮流操作
  2. 绿色高亮站点为可移动目标，点击选择
  3. 到达目标需消耗对应车票
  4. 多种交通可选时弹窗选择车票类型
  5. 侦探用过的车票会进入公共票池

【特殊规则】
  - 第 3/8/13/18/24 回合 Mr. X 位置公开
  - Mr. X 拥有黑票（可替代任何票）和双倍移动票
  - 侦探无法移动时自动跳过
  - 侦探到达 Mr. X 所在站点即获胜"

	var label := Label.new()
	label.text = rules_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	popup.add_child(label)
	add_child(popup)

func _show_rules() -> void:
	var popup = get_child(get_child_count() - 1)
	if popup is AcceptDialog:
		popup.popup_centered()

func _build_settings_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200
	vbox.offset_top = -150
	vbox.offset_right = 200
	vbox.offset_bottom = 150
	vbox.add_theme_constant_override("separation", 20)
	_settings_content.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "设置"
	var ls_title := LabelSettings.new()
	ls_title.font_size = 36
	ls_title.font_color = Color("#E8C840")
	title.label_settings = ls_title
	vbox.add_child(title)

	var hl_label := Label.new()
	hl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl_label.text = "站点高亮颜色"
	var ls_hl := LabelSettings.new()
	ls_hl.font_size = 20
	ls_hl.font_color = Color.WHITE
	hl_label.label_settings = ls_hl
	vbox.add_child(hl_label)

	var hl_grid := GridContainer.new()
	hl_grid.columns = 5
	hl_grid.add_theme_constant_override("h_separation", 10)
	hl_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(hl_grid)

	var preset_colors := [
		{"name": "绿色", "color": Color(0.2, 0.95, 0.3)},
		{"name": "蓝色", "color": Color(0.3, 0.6, 1.0)},
		{"name": "红色", "color": Color(1.0, 0.3, 0.2)},
		{"name": "橙色", "color": Color(1.0, 0.6, 0.0)},
		{"name": "紫色", "color": Color(0.6, 0.15, 0.95)},
		{"name": "青色", "color": Color(0.0, 0.75, 0.85)},
		{"name": "粉色", "color": Color(0.95, 0.2, 0.4)},
		{"name": "金色", "color": Color(1.0, 0.85, 0.0)},
		{"name": "白色", "color": Color(0.9, 0.9, 0.9)},
		{"name": "黄色", "color": Color(0.9, 0.8, 0.15)},
	]

	var gs = get_node_or_null("/root/GameSettings")
	var current_color: Color = gs.highlight_color if gs else Color(0.2, 0.95, 0.3)

	for i in range(preset_colors.size()):
		var entry = preset_colors[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 60)
		var c: Color = entry["color"]
		btn.text = entry["name"]
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", (Color("#DDDDDD") if c.get_luminance() < 0.4 else Color("#333333")))
		var style := StyleBoxFlat.new()
		style.bg_color = c
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color.TRANSPARENT
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, style.duplicate())
		if current_color.is_equal_approx(c):
			for state in ["normal", "hover", "pressed", "focus"]:
				var s: StyleBoxFlat = btn.get_theme_stylebox(state)
				s.border_color = Color.WHITE
				btn.add_theme_stylebox_override(state, s)
		btn.pressed.connect(_on_hl_color_selected.bind(i))
		hl_grid.add_child(btn)
		_hl_color_btns.append(btn)

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.text = "保存并返回"
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_exit_settings)
	vbox.add_child(back_btn)

func _enter_settings() -> void:
	_main_content.visible = false
	_settings_content.visible = true

func _exit_settings() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.save_settings()
	_settings_content.visible = false
	_main_content.visible = true

func _on_hl_color_selected(index: int) -> void:
	var preset_colors := [
		Color(0.2, 0.95, 0.3),
		Color(0.3, 0.6, 1.0),
		Color(1.0, 0.3, 0.2),
		Color(1.0, 0.6, 0.0),
		Color(0.6, 0.15, 0.95),
		Color(0.0, 0.75, 0.85),
		Color(0.95, 0.2, 0.4),
		Color(1.0, 0.85, 0.0),
		Color(0.9, 0.9, 0.9),
		Color(0.9, 0.8, 0.15),
	]
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.highlight_color = preset_colors[index]
	# Update button borders to show selection
	for i in range(_hl_color_btns.size()):
		var btn: Button = _hl_color_btns[i]
		for state in ["normal", "hover", "pressed", "focus"]:
			var s: StyleBoxFlat = btn.get_theme_stylebox(state).duplicate()
			s.border_color = Color.TRANSPARENT
			btn.add_theme_stylebox_override(state, s)
		var selected_btn: Button = _hl_color_btns[index]
		for state in ["normal", "hover", "pressed", "focus"]:
			var s: StyleBoxFlat = selected_btn.get_theme_stylebox(state).duplicate()
			s.border_color = Color.WHITE
			selected_btn.add_theme_stylebox_override(state, s)
