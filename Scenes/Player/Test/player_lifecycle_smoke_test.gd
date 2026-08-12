extends Node

# 玩家生命周期冒烟测试：用真实 Player 场景实例验证死亡→重生→GameOver 状态机时序。
# 覆盖：残机扣减、died/respawned/game_over 信号、隐藏/碰撞禁用、重生位置/满血、
# 无敌期忽略伤害、GameOver 销毁。使用 print() 输出（debug_log 不打印到控制台）。

const PLAYER_SCENE: PackedScene = preload("res://Scenes/Player/player.tscn")

var _failures: Array[String] = []
var _check_count: int = 0
var _died_values: Array[int] = []
var _respawned_count: int = 0
var _game_over_count: int = 0
var _player: CharacterBody2D


func _ready() -> void:
	call_deferred("_run_tests")


# 实例化玩家、连接信号并逐步驱动死亡流程。
func _run_tests() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_player.died.connect(_on_died)
	_player.respawned.connect(_on_respawned)
	_player.game_over.connect(_on_game_over)

	_check(_player.lives == 3, "初始残机为 max_lives (3)，实际 %d" % _player.lives)
	_check(_player.hp == 1, "初始血量为 max_hp (1)，实际 %d" % _player.hp)
	_check(not _player.body_collision.disabled, "初始本体碰撞启用")

	# 第一次死亡：lives 3 -> 2
	_player.take_damage(1)
	_check(_died_values.size() == 1 and _died_values[0] == 2,
		"第一次死亡 died(2) 发出，实际 %s" % str(_died_values))
	_check(not _player.visible, "死亡后玩家隐藏")
	await get_tree().process_frame
	_check(_player.body_collision.disabled, "死亡后本体碰撞禁用")

	# 等待重生延迟（1.0s + 余量）
	await get_tree().create_timer(1.4).timeout
	_check(_respawned_count == 1, "重生信号 respawned 发出，实际 %d" % _respawned_count)
	_check(_player.position == Vector2(320, 600),
		"重生位置为固定安全位，实际 %s" % str(_player.position))
	_check(_player.hp == 1, "重生恢复满血，实际 %d" % _player.hp)
	_check(_player.visible, "重生后玩家可见")
	_check(not _player.body_collision.disabled, "重生后本体碰撞恢复")

	# 无敌期内受击应被忽略
	_player.take_damage(1)
	_check(_died_values.size() == 1, "重生无敌期内受击被忽略，died 未再发出")

	# 等待重生无敌（3s）结束，第二次死亡：lives 2 -> 1
	await get_tree().create_timer(3.2).timeout
	_player.take_damage(1)
	_check(_died_values.size() == 2 and _died_values[1] == 1,
		"第二次死亡 died(1) 发出，实际 %s" % str(_died_values))
	await get_tree().create_timer(1.4).timeout
	_check(_respawned_count == 2, "第二次重生 respawned 发出，实际 %d" % _respawned_count)

	# 等待重生无敌结束，第三次死亡：lives 1 -> 0 → GameOver
	await get_tree().create_timer(3.2).timeout
	_player.take_damage(1)
	_check(_died_values.size() == 3 and _died_values[2] == 0,
		"第三次死亡 died(0) 发出，实际 %s" % str(_died_values))
	_check(_game_over_count == 1, "GameOver 信号发出，实际 %d" % _game_over_count)
	await get_tree().process_frame
	_check(not is_instance_valid(_player), "GameOver 后玩家销毁")

	if _failures.is_empty():
		print("Player lifecycle smoke test passed: %d checks" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("Player lifecycle smoke test failed: %s" % failure)
	get_tree().quit(1)


func _on_died(lives_left: int) -> void:
	_died_values.append(lives_left)


func _on_respawned() -> void:
	_respawned_count += 1


func _on_game_over() -> void:
	_game_over_count += 1


func _check(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
