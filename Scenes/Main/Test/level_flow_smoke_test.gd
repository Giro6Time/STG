extends Node

# 关卡推进状态机冒烟测试：验证 LevelManager 的 StateMachine 驱动。
# 覆盖：MinionWave 生成与全灭完成、Boss 段阻塞至 died、_get_signal_holder 信号映射、
# _process 全链路驱动（wait_time 超时推进 + 末段完成后关卡结束）。
# 防挂死：_process 帧计数硬超时 + try 无（GDScript 无）→ 帧计数兜底。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const BOSS_SEGMENT_SCRIPT: GDScript = preload("res://Public/level/boss_segment.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const COMPLETION_SCRIPT: GDScript = preload("res://Public/level/segment_completion.gd")
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

	# 测试 4：_process 全链路驱动（真实 LevelDefinition，由 LevelManager._process 编排）
	# 段 1：MinionWave（wait_time=0.2 超时兜底，怪没死完也推进）→ 段 2：BossSegment
	await _reset_manager_state()
	var wave2: MinionWaveSegment = MINION_WAVE_SCRIPT.new()
	wave2.enemy_scene = ENEMY_SCENE
	wave2.count = 1
	wave2.spawn_interval = 0.05
	wave2.spawn_positions = [Vector2(100, 100)]
	var comp_t: SegmentCompletion = COMPLETION_SCRIPT.new()
	comp_t.wait_time = 0.2
	wave2.completion = comp_t

	var boss_seg2: BossSegment = BOSS_SEGMENT_SCRIPT.new()
	boss_seg2.boss_scene = BOSS_SCENE
	boss_seg2.entrance_delay = 0.05
	boss_seg2.spawn_position = Vector2(320, 200)

	var def2: LevelDefinition = LevelDefinition.new()
	def2.segments = [wave2, boss_seg2]
	_manager.level_definition = def2
	_manager._build_segment_machine()
	# 从第一个段重新激活（重置管理器到干净状态）
	_manager._segment_finished = false
	_manager._current_segment = def2.segments[0]
	_manager._begin_activation()

	# 等待驱动：段1 超时(0.2s)强制推进 → 段2 进入 → Boss spawn
	await get_tree().create_timer(0.5).timeout
	_check(_manager._current_segment == boss_seg2, "wait_time 超时后推进到段2（波次重叠语义）")
	_check(_manager.boss != null, "段2 Boss 已 spawn")

	# 段2 完成：杀 Boss（died 同步置位）→ 下一帧推进 → 关卡结束
	_manager.boss.die()
	_check(_manager._segment_finished, "Boss 死后段2完成 flag 置位")
	await get_tree().create_timer(0.3).timeout
	_check(_manager._current_segment == null, "末段完成后关卡结束（current_segment 置 null）")

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
