extends Node

signal debug_enabled_changed(enabled: bool)
signal options_changed
signal log_added(entry: Dictionary)

const MAX_LOG_LINES: int = 60
const MAX_VISIBLE_LOG_LINES: int = 7
const LOG_KEY_ALL: String = "ALL"

var debug_enabled: bool = false
var show_logs: bool = true
var show_enemy_hp: bool = true
var show_bullet_count: bool = true
var show_collision_shapes: bool = false
var show_curve_visuals: bool = false
var invincible_enabled: bool = false
var active_log_key: String = LOG_KEY_ALL

var logs: Array[Dictionary] = []
var log_keys: Array[String] = [LOG_KEY_ALL]


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
	DebugHelper.queue_debug_redraw(get_tree())


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


# 切换碰撞形状调试绘制并请求独立绘制层刷新。
func toggle_collision_shapes() -> void:
	show_collision_shapes = not show_collision_shapes
	options_changed.emit()
	DebugHelper.queue_debug_redraw(get_tree())


# 切换曲线采样可视化并请求独立绘制层刷新。
func toggle_curve_visuals() -> void:
	show_curve_visuals = not show_curve_visuals
	options_changed.emit()
	DebugHelper.queue_debug_redraw(get_tree())


# 切换玩家无敌状态，供调试弹幕时降低误操作成本。
func toggle_invincible() -> void:
	invincible_enabled = not invincible_enabled
	debug_log("Invincible: %s" % str(invincible_enabled), "Debug")
	options_changed.emit()


# 设置日志过滤 key，ALL 表示显示所有分类。
func set_log_filter(key: String) -> void:
	if key == "":
		key = LOG_KEY_ALL

	if active_log_key == key:
		return

	active_log_key = key
	options_changed.emit()


# 在已出现的日志分类之间循环，方便手柄或快捷键快速过滤。
func cycle_log_filter() -> void:
	if log_keys.is_empty():
		active_log_key = LOG_KEY_ALL
		options_changed.emit()
		return

	var current_index: int = log_keys.find(active_log_key)
	if current_index < 0:
		current_index = 0
	else:
		current_index = (current_index + 1) % log_keys.size()

	active_log_key = log_keys[current_index]
	options_changed.emit()


# 记录带分类的调试日志，并在调试开启时通知界面刷新。
func debug_log(message: String, key: String = "General") -> void:
	if not can_use_debug():
		return

	if key == "":
		key = "General"

	_register_log_key(key)

	var entry: Dictionary = {
		"key": key,
		"message": message,
		"frame": Engine.get_process_frames()
	}
	logs.append(entry)
	while logs.size() > MAX_LOG_LINES:
		logs.pop_front()

	if debug_enabled:
		log_added.emit(entry)


# 返回当前过滤条件下最近可显示的日志条目。
func get_visible_logs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(logs.size() - 1, -1, -1):
		var entry: Dictionary = logs[index]
		var key: String = entry.get("key", "General")
		if active_log_key == LOG_KEY_ALL or key == active_log_key:
			result.push_front(entry)
			if result.size() >= MAX_VISIBLE_LOG_LINES:
				break

	return result


# 记录新出现的日志分类，供过滤器循环使用。
func _register_log_key(key: String) -> void:
	if not log_keys.has(key):
		log_keys.append(key)
