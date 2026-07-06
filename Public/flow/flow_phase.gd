class_name FlowPhase
extends Node

const NO_TRANSITION_KEY: String = ""

@export var phase_id: int = 1
@export var phase_name: String = ""
@export var pattern_paths: Array[NodePath] = []

@export var auto_transition_after: float = -1.0
@export var auto_transition_key: String = "next"
@export var auto_transition_when_patterns_completed: bool = false
@export var patterns_completed_transition_key: String = "next"
@export var hp_ratio_below: float = -1.0
@export var hp_transition_key: String = "hp_threshold"
@export var transition_keys: Array[String] = []
@export var transition_target_phase_ids: Array[int] = []

var _pattern_owner: Node
var _patterns: Array[FlowPattern] = []
var _is_active: bool = false


# 进入阶段时解析并启动本阶段配置的所有 Pattern。
func enter_state(owner: Node) -> void:
	if owner == null:
		return

	_pattern_owner = owner
	_patterns = _resolve_patterns()
	_is_active = true

	# Phase 只负责编排 Pattern，具体运动、发射或演出由 Pattern 自身处理。
	DebugState.debug_log("Flow phase enter: %s" % get_phase_label(), "Flow")

	for index in range(_patterns.size()):
		var pattern: FlowPattern = _patterns[index]
		pattern.start_pattern(_pattern_owner)


# 逐帧更新尚未完成的阶段 Pattern。
func update_phase(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_active:
		return

	for index in range(_patterns.size()):
		var pattern: FlowPattern = _patterns[index]
		if not pattern.is_completed():
			pattern.update_pattern(runtime_data)


# 根据时间、血量和 Pattern 完成状态决定是否转场。
func evaluate_transition(runtime_data: FlowPhaseRuntimeData) -> String:
	if not _is_active:
		return NO_TRANSITION_KEY

	if auto_transition_after >= 0.0 and runtime_data.phase_elapsed >= auto_transition_after:
		return auto_transition_key

	if hp_ratio_below >= 0.0 and runtime_data.hp_ratio <= hp_ratio_below:
		return hp_transition_key

	if auto_transition_when_patterns_completed and _required_patterns_completed():
		return patterns_completed_transition_key

	return NO_TRANSITION_KEY


# 把转场 key 映射为目标阶段 id。
func get_transition_target_phase_id(transition_key: String) -> int:
	for index in range(transition_keys.size()):
		var configured_key: String = transition_keys[index]
		if configured_key == transition_key:
			if index < transition_target_phase_ids.size():
				return transition_target_phase_ids[index]
			return -1

	return -1


# 离开阶段时停止所有正在运行的 Pattern。
func exit_state() -> void:
	if not _is_active:
		return

	DebugState.debug_log("Flow phase exit: %s" % get_phase_label(), "Flow")

	for index in range(_patterns.size()):
		var pattern: FlowPattern = _patterns[index]
		pattern.stop_pattern()

	_patterns.clear()
	_is_active = false
	_pattern_owner = null


# 返回阶段显示名称，未配置时使用默认编号。
func get_phase_label() -> String:
	if phase_name != "":
		return phase_name

	return "Phase %d" % phase_id


# 检查所有必需 Pattern 是否已经完成。
func _required_patterns_completed() -> bool:
	var has_required_pattern: bool = false

	for index in range(_patterns.size()):
		var pattern: FlowPattern = _patterns[index]
		if pattern.is_required_for_phase_completion():
			has_required_pattern = true
			if not pattern.is_completed():
				return false

	return has_required_pattern


# 根据配置的 NodePath 找到本阶段实际运行的 Pattern。
func _resolve_patterns() -> Array[FlowPattern]:
	var result: Array[FlowPattern] = []

	for index in range(pattern_paths.size()):
		var pattern_path: NodePath = pattern_paths[index]
		var pattern: FlowPattern = get_node_or_null(pattern_path) as FlowPattern
		if pattern != null:
			result.append(pattern)
		else:
			DebugState.debug_log("Flow phase pattern missing: %s" % str(pattern_path), "Flow")

	return result
