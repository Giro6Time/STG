extends Node

# 关卡推进模型冒烟测试：验证 LevelManager 的三段式推进。
# 覆盖：波次生成、wait_group_empty 阻塞/完成、信号映射、真实 _consume_segments 骨架（Boss 段阻塞至 boss_died）。
# 防挂死设计：_process 帧计数硬超时（不依赖协程，唯一兜底——GDScript 无 try/catch）。
# 任何异常（协程静默死亡）或卡住都会在 HARD_TIMEOUT_FRAMES 帧内强制退出。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const SEGMENT_SCRIPT: GDScript = preload("res://Public/level/level_segment.gd")
const COMPLETION_SCRIPT: GDScript = preload("res://Public/level/segment_completion.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const BOSS_SEGMENT_SCRIPT: GDScript = preload("res://Public/level/boss_segment.gd")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/Enemy/enemy_base.tscn")
const BOSS_SCENE: PackedScene = preload("res://Scenes/Boss/boss_base.tscn")

# 硬超时：无论发生什么，超过该帧数即强制退出（60fps 下 40 秒）。绝不无限等待。
# 测试 4 加入了真实 Boss 场景 spawn（0.3s + 0.5s 等待），2400 帧留足余量。
const HARD_TIMEOUT_FRAMES: int = 2400

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D
var _finished: bool = false
var _frame_count: int = 0
var _completion_done: bool = false
var _consume_done: bool = false


func _ready() -> void:
	call_deferred("_run_tests")


# 每帧检查硬超时：不依赖协程，绝对可靠。测试正常 1-2 秒内自行 quit。
func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count > HARD_TIMEOUT_FRAMES and not _finished:
		push_error("Level flow smoke test hard timeout after %d frames" % HARD_TIMEOUT_FRAMES)
		_finished = true
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
	await wave.execute(_manager)
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

	# 测试 4：_consume_segments 真实骨架 —— Boss 段阻塞至 boss_died。
	# 用真实 BossSegment + boss_base.tscn 走通 LevelManager 完整推进链路。
	# 注：真实 Boss 场景较"重"（阶段机/血条/弹幕 Pattern），但 headless 可正常实例化；
	# 本测试在 Intro 阶段自动转场（0.8s）之前就杀死 Boss，不会进入需要玩家瞄准的弹幕阶段。
	_manager.boss = null
	var boss_seg: BossSegment = BOSS_SEGMENT_SCRIPT.new()
	boss_seg.boss_scene = BOSS_SCENE
	boss_seg.entrance_delay = 0.05
	boss_seg.spawn_position = Vector2(320, 200)
	var comp4: SegmentCompletion = COMPLETION_SCRIPT.new()
	comp4.await_signal = "boss_died"
	boss_seg.completion = comp4

	var def4: LevelDefinition = LevelDefinition.new()
	def4.segments = [boss_seg]
	_manager.level_definition = def4

	# 用独立协程启动消费（detached，不阻塞本测试）。
	# 同测试 2：lambda 按值捕获局部变量，故用成员变量 _consume_done 传递完成标志。
	_consume_done = false
	var consume_waiter := func() -> void:
		await _manager._consume_segments()
		_consume_done = true
	get_tree().create_timer(0.01).timeout.connect(consume_waiter)

	# 等 Boss spawn（entrance_delay 0.05 + 余量）
	await get_tree().create_timer(0.3).timeout
	_check(_manager.boss != null, "Boss 已 spawn（_consume_segments 推进到 Boss 段）")
	_check(not _consume_done, "Boss 存活时 _consume_segments 应阻塞在完成条件上")

	# 杀死 Boss → 完成（die() 内部 emit died 后 queue_free）
	if _manager.boss != null:
		_manager.boss.die()
	await get_tree().create_timer(0.5).timeout
	_check(_consume_done, "boss_died 后 _consume_segments 完成")

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
