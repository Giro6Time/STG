extends Node

# 分数系统冒烟测试：验证 ScoreManager（Autoload）作为唯一分数来源。
# 覆盖：add_score 累加 / 负数忽略 / score_changed 广播 / reset 清零 /
#      擦弹汇入（grazed 信号）/ Boss 击破分（LevelManager 钩子）。
# 防挂死：_process 帧计数硬超时 + get_tree().quit(0/1)（沿用项目 smoke test 约定）。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const BOSS_SEGMENT_SCRIPT: GDScript = preload("res://Public/level/boss_segment.gd")
const BOSS_SCENE: PackedScene = preload("res://Scenes/Boss/boss_base.tscn")

const HARD_TIMEOUT_FRAMES: int = 2400

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D
var _finished: bool = false
var _frame_count: int = 0
var _last_score_changed: int = -1
var _score_changed_count: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count > HARD_TIMEOUT_FRAMES and not _finished:
		push_error("Score system smoke test hard timeout after %d frames" % HARD_TIMEOUT_FRAMES)
		get_tree().quit(1)


func _run_tests() -> void:
	ScoreManager.reset()
	GrazeContext.reset()
	ScoreManager.score_changed.connect(_on_score_changed)

	# 测试 1：add_score 累加
	ScoreManager.add_score(100)
	_check(ScoreManager.get_score() == 100, "add_score(100) 后分数 100，实际 %d" % ScoreManager.get_score())
	ScoreManager.add_score(50)
	_check(ScoreManager.get_score() == 150, "再 add_score(50) 后分数 150，实际 %d" % ScoreManager.get_score())

	# 测试 2：负数忽略
	ScoreManager.add_score(-10)
	_check(ScoreManager.get_score() == 150, "add_score(-10) 被忽略，分数仍 150，实际 %d" % ScoreManager.get_score())

	# 测试 3：score_changed 广播
	_check(_score_changed_count >= 2, "score_changed 至少广播 2 次，实际 %d" % _score_changed_count)
	_check(_last_score_changed == 150, "最后一次 score_changed 值为 150，实际 %d" % _last_score_changed)

	# 测试 4：reset 清零
	ScoreManager.reset()
	_check(ScoreManager.get_score() == 0, "reset 后分数 0，实际 %d" % ScoreManager.get_score())
	_check(_last_score_changed == 0, "reset 广播 score_changed(0)，实际 %d" % _last_score_changed)

	# 测试 5：擦弹汇入（真实链路：request_graze → GrazeContext 统计 → grazed 信号 → ScoreManager 加分）
	GrazeContext.reset()
	ScoreManager.reset()
	var fake_bullet: Node = Node.new()
	add_child(fake_bullet)
	GrazeContext.request_graze(fake_bullet, Vector2(100, 100))
	GrazeContext.request_graze(fake_bullet, Vector2(200, 100))
	await get_tree().create_timer(0.2).timeout
	var expected_graze_score: int = 2 * ScoreManager.SCORE_PER_GRAZE
	_check(ScoreManager.get_score() == expected_graze_score,
		"擦弹 2 次后分数 %d（每次 %d），实际 %d" % [expected_graze_score, ScoreManager.SCORE_PER_GRAZE, ScoreManager.get_score()])

	# 测试 6：Boss 击破分（LevelManager 钩子 → add_score）
	await _setup_boss_scenario()
	ScoreManager.reset()
	_manager.boss.die()
	await get_tree().create_timer(0.3).timeout
	_check(ScoreManager.get_score() == ScoreManager.BOSS_DEFEAT_SCORE,
		"Boss 击破后分数 %d，实际 %d" % [ScoreManager.BOSS_DEFEAT_SCORE, ScoreManager.get_score()])

	_finish()


# 搭一个真实 BossSegment + LevelManager 场景：register_boss 走正式链路。
func _setup_boss_scenario() -> void:
	_manager = Node2D.new()
	_manager.set_script(LEVEL_MANAGER_SCRIPT)
	add_child(_manager)

	var boss_seg: BossSegment = BOSS_SEGMENT_SCRIPT.new()
	boss_seg.boss_scene = BOSS_SCENE
	boss_seg.start_delay = 0.05
	boss_seg.spawn_position = Vector2(320, 200)
	boss_seg.enter_state(_manager)
	for i in range(5):
		boss_seg.update_state(0.1)
		await get_tree().process_frame
	_check(_manager.boss != null, "Boss 已 spawn（register_boss 链路）")


func _on_score_changed(score: int) -> void:
	_score_changed_count += 1
	_last_score_changed = score


func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("Score system smoke test passed: %d checks" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("Score system smoke test failed: %s" % failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
