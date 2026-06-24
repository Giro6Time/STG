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


# 判断当前运行环境是否允许启用调试功能。
func can_use_debug() -> bool:
	# Keep editor play mode usable first. Export presets can later disable this
	# by omitting the debug_tools feature and adding a project setting gate.
	return true


# 切换全局调试开关并广播状态变化。
func toggle_debug() -> void:
	set_debug_enabled(not debug_enabled)


# 设置调试启用状态，避免重复广播相同值。
func set_debug_enabled(enabled: bool) -> void:
	if not can_use_debug():
		enabled = false

	if debug_enabled == enabled:
		return

	debug_enabled = enabled
	debug_enabled_changed.emit(debug_enabled)
	DebugHelper.queue_debug_collision_redraw(get_tree())


# 切换调试日志面板的可见状态。
func toggle_logs() -> void:
	show_logs = not show_logs
	options_changed.emit()


# 切换敌人血量调试信息的显示状态。
func toggle_enemy_hp() -> void:
	show_enemy_hp = not show_enemy_hp
	options_changed.emit()


# 切换子弹计数调试信息的显示状态。
func toggle_bullet_count() -> void:
	show_bullet_count = not show_bullet_count
	options_changed.emit()


# 切换碰撞形状调试绘制并请求场景重绘。
func toggle_collision_shapes() -> void:
	show_collision_shapes = not show_collision_shapes
	options_changed.emit()
	DebugHelper.queue_debug_collision_redraw(get_tree())


# 记录调试日志，并在调试可用时通知界面刷新。
func debug_log(message: String) -> void:
	if not can_use_debug() or not show_logs:
		return

	logs.append(message)
	while logs.size() > MAX_LOG_LINES:
		logs.pop_front()

	if debug_enabled:
		log_added.emit(message)
