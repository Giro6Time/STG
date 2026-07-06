class_name FlowPhaseMachine
extends Node

signal phase_changed(active_phase: FlowPhase)
signal phase_transition_started(phase_id: int)
signal phase_transition_finished(phase_id: int)

@export var phase_paths: Array[NodePath] = []
@export var phase_container_path: NodePath = NodePath("../Phases")

var active_phase: FlowPhase

var _pattern_owner: Node
var _state_machine: StateMachine = StateMachine.new()
var _phases: Array[FlowPhase] = []
var _phase_elapsed: float = 0.0


# 收集阶段节点并启动宿主的第一个流程阶段。
func setup(pattern_owner: Node) -> void:
	_pattern_owner = pattern_owner
	_phases = _get_configured_phases()
	_state_machine.setup(_pattern_owner, _phases)
	_connect_state_machine()

	if _phases.is_empty():
		DebugState.debug_log("Flow phase machine has no states", "Flow")
		return

	_state_machine.start(_phases[0])


# 按阶段 id 查找目标阶段并请求状态机切换。
func transition_to_phase_id(phase_id: int) -> bool:
	for index in range(_phases.size()):
		var phase: FlowPhase = _phases[index]
		if phase.phase_id == phase_id:
			return _state_machine.transition_to(phase)

	DebugState.debug_log("Flow phase id missing: %d" % phase_id, "Flow")
	return false


# 返回当前激活阶段的 id，缺失时返回 0。
func get_active_phase_id() -> int:
	if active_phase == null:
		return 0

	return active_phase.phase_id


# 让当前阶段执行退出逻辑，用于宿主死亡或清理。
func shutdown() -> void:
	var current_state: Node = _state_machine.get_current_state()
	if current_state != null and current_state is FlowPhase:
		var phase: FlowPhase = current_state as FlowPhase
		phase.exit_state()


# 每帧更新当前阶段并检查是否满足转场条件。
func _process(delta: float) -> void:
	if active_phase == null:
		return

	_phase_elapsed += delta

	var runtime_data: FlowPhaseRuntimeData = FlowPhaseRuntimeData.new()
	runtime_data.setup(_pattern_owner, delta, _phase_elapsed)

	active_phase.update_phase(runtime_data)
	_try_transition(active_phase, runtime_data)


# 连接底层状态机切换信号以同步当前阶段。
func _connect_state_machine() -> void:
	var callback: Callable = Callable(self, "_on_state_machine_state_changed")
	if not _state_machine.state_changed.is_connected(callback):
		_state_machine.state_changed.connect(callback)


# 按配置路径解析阶段节点，缺省时回退到阶段容器子节点。
func _get_configured_phases() -> Array[FlowPhase]:
	var result: Array[FlowPhase] = []

	for index in range(phase_paths.size()):
		var phase_path: NodePath = phase_paths[index]
		var phase: FlowPhase = get_node_or_null(phase_path) as FlowPhase
		if phase != null:
			result.append(phase)
		else:
			DebugState.debug_log("Flow phase path missing: %s" % str(phase_path), "Flow")

	if not result.is_empty():
		return result

	var phase_container: Node = get_node_or_null(phase_container_path)
	if phase_container == null:
		return result

	for index in range(phase_container.get_child_count()):
		var child_phase: FlowPhase = phase_container.get_child(index) as FlowPhase
		if child_phase != null:
			result.append(child_phase)

	return result


# 根据阶段运行数据计算并执行阶段转场。
func _try_transition(phase: FlowPhase, runtime_data: FlowPhaseRuntimeData) -> void:
	var transition_key: String = phase.evaluate_transition(runtime_data)
	if transition_key == FlowPhase.NO_TRANSITION_KEY:
		return

	var target_phase_id: int = phase.get_transition_target_phase_id(transition_key)
	if target_phase_id < 0:
		DebugState.debug_log("Flow phase transition missing: %s -> %s" % [phase.get_phase_label(), transition_key], "Flow")
		return

	DebugState.debug_log("Flow phase transition: %s -> %d by %s" % [phase.get_phase_label(), target_phase_id, transition_key], "Flow")
	transition_to_phase_id(target_phase_id)


# 记录新阶段、重置计时并广播阶段变化。
func _on_state_machine_state_changed(_previous_state: Node, current_state: Node) -> void:
	active_phase = current_state as FlowPhase
	_phase_elapsed = 0.0

	if active_phase == null:
		return

	DebugState.debug_log("Flow phase changed: %s" % active_phase.get_phase_label(), "Flow")
	phase_transition_started.emit(active_phase.phase_id)
	phase_changed.emit(active_phase)
	phase_transition_finished.emit(active_phase.phase_id)
