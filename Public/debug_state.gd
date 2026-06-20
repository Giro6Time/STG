extends Node

signal debug_enabled_changed(enabled: bool)
signal options_changed
signal log_added(message: String)

const MAX_LOG_LINES := 12

var debug_enabled := false
var show_logs := true
var show_enemy_hp := true
var show_bullet_count := true
var show_collision_shapes := false

var logs: Array[String] = []


func can_use_debug() -> bool:
	# Keep editor play mode usable first. Export presets can later disable this
	# by omitting the debug_tools feature and adding a project setting gate.
	return true


func toggle_debug() -> void:
	set_debug_enabled(not debug_enabled)


func set_debug_enabled(enabled: bool) -> void:
	if not can_use_debug():
		enabled = false

	if debug_enabled == enabled:
		return

	debug_enabled = enabled
	debug_enabled_changed.emit(debug_enabled)
	DebugHelper.queue_debug_collision_redraw(get_tree())


func toggle_logs() -> void:
	show_logs = not show_logs
	options_changed.emit()


func toggle_enemy_hp() -> void:
	show_enemy_hp = not show_enemy_hp
	options_changed.emit()


func toggle_bullet_count() -> void:
	show_bullet_count = not show_bullet_count
	options_changed.emit()


func toggle_collision_shapes() -> void:
	show_collision_shapes = not show_collision_shapes
	options_changed.emit()
	DebugHelper.queue_debug_collision_redraw(get_tree())


func debug_log(message: String) -> void:
	if not can_use_debug() or not debug_enabled or not show_logs:
		return

	logs.append(message)
	while logs.size() > MAX_LOG_LINES:
		logs.pop_front()

	log_added.emit(message)