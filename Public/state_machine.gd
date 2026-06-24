class_name StateMachine
extends RefCounted

signal state_changed(previous_state: Node, current_state: Node)

var _owner: Node
var _states: Array = []
var _transitions: Dictionary = {}
var _current_state: Node


# 初始化状态机的宿主和可用状态列表。
func setup(owner: Node, states: Array) -> void:
	_owner = owner
	_states.clear()
	_transitions.clear()
	_current_state = null

	for index in range(states.size()):
		var state: Node = states[index] as Node
		if state != null:
			_states.append(state)


# 登记一个允许从指定状态跳转到目标状态的关系。
func add_transition(from_state: Node, to_state: Node) -> void:
	if from_state == null or to_state == null:
		return

	_transitions[from_state] = to_state


# 从指定初始状态启动状态机生命周期。
func start(initial_state: Node) -> void:
	if initial_state == null:
		return

	_transition_to_internal(initial_state)


# 把每帧更新转发给当前激活状态。
func update(delta: float) -> void:
	if _current_state == null:
		return

	if _current_state.has_method("update_state"):
		_current_state.update_state(delta)


# 校验目标状态是否可达，并执行状态切换。
func transition_to(next_state: Node) -> bool:
	if next_state == null:
		return false

	if next_state == _current_state:
		return false

	return _transition_to_internal(next_state)


# 按状态列表顺序切换到下一个状态。
func transition_to_next() -> bool:
	if _current_state == null:
		return false

	var next_state: Node = _transitions.get(_current_state) as Node
	if next_state == null:
		return false

	return transition_to(next_state)


# 返回当前正在运行的状态节点。
func get_current_state() -> Node:
	return _current_state


# 返回状态机持有的全部状态列表。
func get_states() -> Array:
	return _states.duplicate()


# 执行退出旧状态、进入新状态和广播切换事件的核心流程。
func _transition_to_internal(next_state: Node) -> bool:
	var previous_state: Node = _current_state

	if previous_state != null and previous_state.has_method("exit_state"):
		previous_state.exit_state()

	_current_state = next_state

	if _current_state.has_method("enter_state"):
		_current_state.enter_state(_owner)

	state_changed.emit(previous_state, _current_state)
	return true
