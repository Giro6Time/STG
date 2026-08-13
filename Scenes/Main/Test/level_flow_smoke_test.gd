extends Node

# 关卡推进状态机冒烟测试：验证 LevelManager 的 StateMachine 驱动。
# 覆盖：MinionWave 生成与全灭完成、Boss 段阻塞至 died、_get_signal_holder 信号映射。
# 防挂死：_process 帧计数硬超时 + try 无（GDScript 无）→ 帧计数兜底。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const BOSS_SEGMENT_SCRIPT: GDScript = preload("res://Public/level/boss_segment.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/Enemy/enemy_base.tscn")
const BOSS_SCENE: PackedScene = preload("res://Scenes/Boss/boss_base.tscn")

const HARD_TIMEOUT_FRAMES: int = 2400

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D
var _finished: bool = false
var _frame_count: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count > HARD_TIMEOUT_FRAMES and not _finished:
		push_error("Level flow smoke test hard timeout after %d frames" % HARD_TIMEOUT_FRAMES)
		get_tree().quit(1)


func _run_tests() -> void:
	_manager = Node2D.new()
	_manager.set_script(LEVEL_MANAGER_SCRIPT)
	add_child(_manager)

	# 测试 1：MinionWave 生成敌人并跟踪存活（直接调段钩子验证生成逻辑）
	var wave: MinionWaveSegment = MINION_WAVE_SCRIPT.new()
	wave.enemy_scene = ENEMY_SCENE
	wave.count = 3
	wave.spawn_interval = 0.05
	wave.spawn_positions = [Vector2(100, 100), Vector2(200, 100), Vector2(300, 100)]
	wave.enter_state(_manager)
	# 模拟若干帧 update（推进生成）
	for i in range(10):
		wave.update_state(0.1)
		await get_tree().process_frame
	_check(wave._spawned_count == 3, "波次生成 3 个敌人，实际 %d" % wave._spawned_count)
	_check(get_tree().get_nodes_in_group("enemies").size() == 3,
		"enemies group 有 3 个敌人，实际 %d" % get_tree().get_nodes_in_group("enemies").size())

	# 清理：杀掉敌人触发 died → 段完成
	for enemy in get_tree().get_nodes_in_group("enemies"):
		(enemy as Enemy).die()
	await get_tree().create_timer(0.3).timeout
	_check(_manager._segment_finished, "MinionWave 怪死完后段完成 flag 置位")

	# 测试 2：Boss 段阻塞至 died（用真实段 + 手动驱动钩子）
	await _reset_manager_state()
	var boss_seg: BossSegment = BOSS_SEGMENT_SCRIPT.new()
	boss_seg.boss_scene = BOSS_SCENE
	boss_seg.entrance_delay = 0.05
	boss_seg.spawn_position = Vector2(320, 200)
	boss_seg.enter_state(_manager)
	for i in range(5):
		boss_seg.update_state(0.1)
		await get_tree().process_frame
	_check(_manager.boss != null, "Boss 已 spawn（enter/update 驱动）")
	_check(not _manager._segment_finished, "Boss 存活时段完成 flag 未置位")
	_manager.boss.die()
	await get_tree().create_timer(0.3).timeout
	_check(_manager._segment_finished, "boss.died 后段完成 flag 置位")

	# 测试 3：_get_signal_holder 映射
	_check(_manager._get_signal_holder("boss_died") == _manager.boss, "boss_died 映射到 boss 节点")
	_check(_manager._get_signal_holder("unknown") == null, "未注册信号返回 null")

	_finish()


# 重置管理器内部状态（模拟推进到下一段前的清理）。
func _reset_manager_state() -> void:
	_manager._segment_finished = false
	# 清掉测试 1 残留的敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("Level flow smoke test passed: %d checks" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("Level flow smoke test failed: %s" % failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
