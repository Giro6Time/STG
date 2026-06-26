class_name BossExternalEventPattern
extends BossPattern

signal external_event_requested(event_name: String, payload: Dictionary, pattern: BossPattern)

@export var event_name: String = ""
@export var payload: Dictionary = {}
@export var complete_on_request: bool = false
@export var timeout: float = -1.0

var _elapsed: float = 0.0
var _request_sent: bool = false


# 把外部事件 Pattern 默认设为阶段完成所需条件。
func _init() -> void:
	required_for_phase_completion = true


# 启动等待外部事件的 Pattern 并按配置发出请求。
func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)
	_elapsed = 0.0
	_request_sent = false

	if not _is_running:
		return

	_send_request()

	if complete_on_request:
		mark_completed()


# 在超时策略启用时累计等待时间并自动完成。
func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	if not _request_sent:
		_send_request()

	if timeout < 0.0:
		return

	_elapsed += delta
	if _elapsed >= timeout:
		DebugState.debug_log("Boss external event timeout: %s" % get_pattern_label(), "Boss")
		mark_completed()


# 供外部系统回调，手动完成当前 Pattern。
func complete_from_external() -> void:
	mark_completed()


# 广播或记录外部事件请求，提示关卡流程接管。
func _send_request() -> void:
	_request_sent = true
	DebugState.debug_log("Boss external event requested: %s" % get_pattern_label(), "Boss")
	external_event_requested.emit(event_name, payload, self)
