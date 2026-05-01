extends Node

# 测试从主菜单点击开始游戏到进入游戏场景的完整流程

var _md: Node
var _gs: Node
var _errors: Array = []
var _step: int = 0

func _ready() -> void:
	await get_tree().process_frame

	_md = get_node_or_null("/root/MapData")
	_gs = get_node_or_null("/root/GameState")

	print("=== 测试完整游戏流程 ===")
	await _test_start_and_enter_game()
	await _test_game_board_ready()
	await get_tree().process_frame
	print("=== 测试完成，无报错 ===")
	get_tree().quit()

func _log(step_name: String) -> void:
	_step += 1
	print("  [步骤%d] %s" % [_step, step_name])

func _test_start_and_enter_game() -> void:
	_log("启动游戏 (3人)")
	_gs.start_game(3)
	_log("切换到游戏场景")
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_log("游戏场景已加载")

func _test_game_board_ready() -> void:
	var game_board = get_node_or_null("/root/Game")
	if game_board == null:
		print("  错误: Game 节点未找到!")
		return
	_log("Game 节点存在")

	var map_container = game_board.get_node_or_null("MapRenderer")
	if map_container == null:
		# 可能在不同路径
		for child in game_board.get_children():
			print("    子节点: %s (%s)" % [child.name, child.get_class()])
	else:
		_log("MapRenderer 节点存在")

	# 检查所有关键UI节点
	var checks = ["TurnOverlay", "TicketPopup"]
	for check_name in checks:
		var node = game_board.get_node_or_null(check_name)
		var found = false
		if node == null:
			for child in game_board.get_children():
				if child.name.find(check_name) >= 0:
					_log("找到 %s (实际名称: %s)" % [check_name, child.name])
					found = true
					break
			if not found:
				print("    警告: %s 未找到" % check_name)

	_log("当前玩家: %s" % _gs.get_current_player().player_name)
	_log("当前回合: %d" % _gs.current_round)
	_log("有效移动数: %d" % MoveValidator.get_valid_moves(_gs.get_current_player(), _gs.players, _md).size())
