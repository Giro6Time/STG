class_name BossWaitPattern
extends BossPattern

@export var duration: float = 1.0

var _elapsed: float = 0.0


func _init() -> void:
	required_for_phase_completion = true


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)
	_elapsed = 0.0

	if _is_running and duration <= 0.0:
		mark_completed()


func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	_elapsed += delta
	if _elapsed >= duration:
		mark_completed()
