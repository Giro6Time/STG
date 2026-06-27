class_name FlowPattern
extends Node

signal pattern_completed(pattern: FlowPattern)

@export var enabled: bool = true
@export var pattern_name: String = ""
@export var required_for_phase_completion: bool = false

var _pattern_owner: Node
var _is_running: bool = false
var _is_completed: bool = false


# 启动 Pattern 并记录运行宿主；宿主可以是 Boss、子弹或后续新增的发射源。
func start_pattern(pattern_owner: Node) -> void:
	_pattern_owner = pattern_owner
	_is_running = enabled
	_is_completed = not enabled

	if not _is_running:
		return

	DebugState.debug_log("Flow pattern start: %s" % get_pattern_label(), "Flow")


# 提供 Pattern 每帧更新入口，子类按需要实现具体行为。
func update_pattern(_runtime_data: FlowPhaseRuntimeData) -> void:
	pass


# 停止 Pattern 并释放对运行宿主的引用。
func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Flow pattern stop: %s" % get_pattern_label(), "Flow")

	_is_running = false
	_pattern_owner = null


# 把 Pattern 标记为完成并通知阶段逻辑。
func mark_completed() -> void:
	if _is_completed:
		return

	_is_completed = true
	_is_running = false
	DebugState.debug_log("Flow pattern completed: %s" % get_pattern_label(), "Flow")
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


# 返回当前宿主是 Boss 时的强类型引用，避免通过反射调用宿主能力。
func get_owner_as_boss() -> Boss:
	return _pattern_owner as Boss


# 返回当前宿主是 Node2D 时的强类型引用，供移动和发射类 Pattern 使用坐标。
func get_owner_as_node2d() -> Node2D:
	return _pattern_owner as Node2D


# 返回当前宿主引用，供未来新增宿主类型在子类中做显式类型判断。
func get_pattern_owner() -> Node:
	return _pattern_owner
