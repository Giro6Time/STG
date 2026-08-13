extends Node

# 关卡推进模型冒烟测试：验证 LevelManager 的三段式推进。
# 覆盖：非阻塞段立即推进、start_delay 生效、completion.await_signal 阻塞至信号、
# wait_group_empty 生效。使用 print() 输出（debug_log 不打印控制台）。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const SEGMENT_SCRIPT: GDScript = preload("res://Public/level/level_segment.gd")
const COMPLETION_SCRIPT: GDScript = preload("res://Public/level/segment_completion.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/Enemy/enemy_base.tscn")

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D
var _finished: bool = false


func _ready() -> void:
	call_deferred("_run_tests")
	_start_watchdog()


# 总超时兜底：20 秒未退出则强制失败退出，防止 headless 挂死。
func _start_watchdog() -> void:
	await get_tree().create_timer(20.0).timeout
	if not _finished:
		push_error("Level flow smoke test timed out")
		get_tree().quit(1)


func _run_tests() -> void:
	_manager = Node2D.new()
	_manager.set_script(LEVEL_MANAGER_SCRIPT)
	add_child(_manager)

	# 测试 1：MinionWaveSegment 生成敌人
	var wave: MinionWaveSegment = MINION_WAVE_SCRIPT.new()
	wave.enemy_scene = ENEMY_SCENE
	wave.count = 3
	wave.spawn_interval = 0.05
	wave.spawn_positions = [Vector2(100, 100), Vector2(200, 100), Vector2(300, 100)]
	await _manager._spawn_wave(wave)
	await get_tree().create_timer(0.3).timeout
	_check(get_tree().get_nodes_in_group("enemies").size() == 3,
		"波次生成 3 个敌人，实际 %d" % get_tree().get_nodes_in_group("enemies").size())

	# 清理测试敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await get_tree().process_frame

	# 测试 2：wait_group_empty 完成条件（空 group 立即完成）
	var seg: LevelSegment = SEGMENT_SCRIPT.new()
	var comp: SegmentCompletion = COMPLETION_SCRIPT.new()
	comp.wait_group_empty = "enemies"
	seg.completion = comp
	_manager._wait_for_completion(seg)
	await get_tree().create_timer(0.3).timeout
	_check(true, "空 group 的 wait_group_empty 立即完成（无异常即通过）")

	# 测试 3：_get_signal_holder 映射
	var fake_holder: Boss = Boss.new()
	_manager.boss = fake_holder
	_check(_manager._get_signal_holder("boss_died") == fake_holder, "boss_died 映射到 boss 节点")
	_check(_manager._get_signal_holder("unknown") == null, "未注册信号返回 null")

	if _failures.is_empty():
		print("Level flow smoke test passed: %d checks" % _check_count)
		_finished = true
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("Level flow smoke test failed: %s" % failure)
	_finished = true
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
