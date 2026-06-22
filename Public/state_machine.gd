class_name StateMachine
extends RefCounted

signal state_changed(previous_state: Node, current_state: Node)

var _owner: Node
var _states: Array = []
var _transitions: Dictionary = {}
var _current_state: Node


func setup(owner: Node, states: Array) -> void:
	_owner = owner
	_states.clear()
	_transitions.clear()
	_current_state = null

	for index in range(states.size()):
		var state: Node = states[index] as Node
		if state != null:
			_states.append(state)


func add_transition(from_state: Node, to_state: Node) -> void:
	if from_state == null or to_state == null:
		return

	_transitions[from_state] = to_state


func start(initial_state: Node) -> void:
	if initial_state == null:
		return

	_transition_to_internal(initial_state)


func update(delta: float) -> void:
	if _current_state == null:
		return

	if _current_state.has_method("update_state"):
		_current_state.update_state(delta)


func transition_to(next_state: Node) -> bool:
	if next_state == null:
		return false

	if next_state == _current_state:
		return false

	return _transition_to_internal(next_state)


func transition_to_next() -> bool:
	if _current_state == null:
		return false

	var next_state: Node = _transitions.get(_current_state) as Node
	if next_state == null:
		return false

	return transition_to(next_state)


func get_current_state() -> Node:
	return _current_state


func get_states() -> Array:
	return _states.duplicate()


func _transition_to_internal(next_state: Node) -> bool:
	var previous_state: Node = _current_state

	if previous_state != null and previous_state.has_method("exit_state"):
		previous_state.exit_state()

	_current_state = next_state

	if _current_state.has_method("enter_state"):
		_current_state.enter_state(_owner)

	state_changed.emit(previous_state, _current_state)
	return true