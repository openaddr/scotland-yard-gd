extends Control

var _selected_count: int = 3
var _count_buttons: Dictionary = {}

func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.15, 1)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -200
	vbox.offset_top = -200
	vbox.offset_right = 200
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

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

	var start_btn := Button.new()
	start_btn.custom_minimum_size = Vector2(200, 60)
	start_btn.text = "开始游戏"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.pressed.connect(_start_game)
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

func _start_game() -> void:
	get_node("/root/GameState").start_game(_selected_count)
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
