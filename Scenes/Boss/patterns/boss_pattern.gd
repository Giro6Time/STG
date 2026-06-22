class_name BossPattern
extends Node

signal pattern_completed(pattern: BossPattern)

@export var enabled: bool = true
@export var pattern_name: String = ""
@export var required_for_phase_completion: bool = false

var _boss: Boss
var _is_running: bool = false
var _is_completed: bool = false


func start_pattern(boss: Boss) -> void:
	_boss = boss
	_is_running = enabled
	_is_completed = not enabled

	if not _is_running:
		return

	DebugState.debug_log("Boss pattern start: %s" % get_pattern_label())


func update_pattern(_delta: float) -> void:
	pass


func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss pattern stop: %s" % get_pattern_label())

	_is_running = false
	_boss = null


func mark_completed() -> void:
	if _is_completed:
		return

	_is_completed = true
	_is_running = false
	DebugState.debug_log("Boss pattern completed: %s" % get_pattern_label())
	pattern_completed.emit(self)


func is_completed() -> bool:
	return _is_completed


func is_required_for_phase_completion() -> bool:
	return required_for_phase_completion


func get_pattern_label() -> String:
	if pattern_name != "":
		return pattern_name

	return name
