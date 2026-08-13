extends Node

# 关卡推进模型冒烟测试：验证 LevelManager 的三段式推进。
# 覆盖：波次生成、wait_group_empty 阻塞/完成、信号映射。
# 防挂死设计：_process 帧计数硬超时（不依赖协程，唯一兜底——GDScript 无 try/catch）。
# 任何异常（协程静默死亡）或卡住都会在 HARD_TIMEOUT_FRAMES 帧内强制退出。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const SEGMENT_SCRIPT: GDScript = preload("res://Public/level/level_segment.gd")
const COMPLETION_SCRIPT: GDScript = preload("res://Public/level/segment_completion.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/Enemy/enemy_base.tscn")

# 硬超时：无论发生什么，超过该帧数即强制退出（60fps 下 10 秒）。绝不无限等待。
const HARD_TIMEOUT_FRAMES: int = 600

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D
var _finished: bool = false
var _frame_count: int = 0
var _completion_done: bool = false


func _ready() -> void:
	call_deferred("_run_tests")


# 每帧检查硬超时：不依赖协程，绝对可靠。测试正常 1-2 秒内自行 quit。
func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count > HARD_TIMEOUT_FRAMES and not _finished:
		push_error("Level flow smoke test hard timeout after %d frames" % HARD_TIMEOUT_FRAMES)
		get_tree().quit(1)


# 测试主体。注意：GDScript 无 try/catch，协程中途报错会静默死亡；
# 此时测试停在半路、_finished 保持 false，_process 硬超时会在
# HARD_TIMEOUT_FRAMES 帧内强制 quit(1)——挂死被绝对排除。
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

	# 测试 2：wait_group_empty 阻塞/完成
	var seg: LevelSegment = SEGMENT_SCRIPT.new()
	var comp: SegmentCompletion = COMPLETION_SCRIPT.new()
	comp.wait_group_empty = "enemies"
	seg.completion = comp

	# 放入 blocker 让 _await_group_empty 进入轮询
	var blocker: Node = Node.new()
	blocker.add_to_group("enemies")
	add_child(blocker)

	# 用独立协程启动完成等待（detached，不阻塞本测试）。
	# 注意：GDScript lambda 按值捕获局部变量，写入不会传播到外层，
	# 故必须用成员变量 _completion_done 传递完成标志。
	_completion_done = false
	var waiter := func() -> void:
		await _manager._wait_for_completion(seg)
		_completion_done = true
	get_tree().create_timer(0.01).timeout.connect(waiter)

	# 竞速断言 1：blocker 未清空时应仍阻塞（0.3s 内不完成）
	await get_tree().create_timer(0.3).timeout
	_check(not _completion_done, "group 非空时 wait_group_empty 应阻塞")

	# 清空 blocker → 应很快完成
	blocker.queue_free()
	await get_tree().create_timer(0.5).timeout
	_check(_completion_done, "group 清空后 wait_group_empty 完成")

	# 测试 3：_get_signal_holder 映射
	var fake_holder: Boss = Boss.new()
	_manager.boss = fake_holder
	_check(_manager._get_signal_holder("boss_died") == fake_holder, "boss_died 映射到 boss 节点")
	_check(_manager._get_signal_holder("unknown") == null, "未注册信号返回 null")
	fake_holder.free()

	_finish()


# 统一收尾：打印结果并退出。
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
