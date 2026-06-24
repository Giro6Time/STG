class_name BossPattern
extends Node

signal pattern_completed(pattern: BossPattern)

@export var enabled: bool = true
@export var pattern_name: String = ""
@export var required_for_phase_completion: bool = false

var _boss: Boss
var _is_running: bool = false
var _is_completed: bool = false


# 启动 Pattern 并记录运行状态，禁用时直接标记完成。
func start_pattern(boss: Boss) -> void:
	_boss = boss
	_is_running = enabled
	_is_completed = not enabled

	if not _is_running:
		return

	DebugState.debug_log("Boss pattern start: %s" % get_pattern_label())


# 提供 Pattern 每帧更新入口，子类按需要实现。
func update_pattern(_delta: float) -> void:
	pass


# 停止 Pattern 并释放对 Boss 的引用。
func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss pattern stop: %s" % get_pattern_label())

	_is_running = false
	_boss = null


# 把 Pattern 标记为完成并通知阶段逻辑。
func mark_completed() -> void:
	if _is_completed:
		return

	_is_completed = true
	_is_running = false
	DebugState.debug_log("Boss pattern completed: %s" % get_pattern_label())
	pattern_completed.emit(self)


# 返回 Pattern 是否已经完成。
func is_completed() -> bool:
	return _is_completed


# 返回该 Pattern 是否参与阶段完成判定。
func is_required_for_phase_completion() -> bool:
	return required_for_phase_completion


# 返回调试日志中使用的 Pattern 名称。
func get_pattern_label() -> String:
	if pattern_name != "":
		return pattern_name

	return name
