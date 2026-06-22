class_name BossExternalEventPattern
extends BossPattern

signal external_event_requested(event_name: String, payload: Dictionary, pattern: BossPattern)

@export var event_name: String = ""
@export var payload: Dictionary = {}
@export var complete_on_request: bool = false
@export var timeout: float = -1.0

var _elapsed: float = 0.0
var _request_sent: bool = false


func _init() -> void:
	required_for_phase_completion = true


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)
	_elapsed = 0.0
	_request_sent = false

	if not _is_running:
		return

	_send_request()

	if complete_on_request:
		mark_completed()


func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	if not _request_sent:
		_send_request()

	if timeout < 0.0:
		return

	_elapsed += delta
	if _elapsed >= timeout:
		DebugState.debug_log("Boss external event timeout: %s" % get_pattern_label())
		mark_completed()


func complete_from_external() -> void:
	mark_completed()


func _send_request() -> void:
	_request_sent = true
	DebugState.debug_log("Boss external event requested: %s" % get_pattern_label())
	external_event_requested.emit(event_name, payload, self)
