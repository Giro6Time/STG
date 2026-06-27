extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var fps_label: Label = $Panel/Margin/VBox/FpsLabel
@onready var bullets_label: Label = $Panel/Margin/VBox/BulletsLabel
@onready var graze_label: Label = $Panel/Margin/VBox/GrazeLabel
@onready var enemies_label: Label = $Panel/Margin/VBox/EnemiesLabel
@onready var enemy_hp_label: Label = $Panel/Margin/VBox/EnemyHpLabel
@onready var options_label: Label = $Panel/Margin/VBox/OptionsLabel
@onready var log_label: Label = $Panel/Margin/VBox/LogLabel

var _key_3_pressed_last_frame: bool = false
var _key_4_pressed_last_frame: bool = false
var _key_5_pressed_last_frame: bool = false
var _key_6_pressed_last_frame: bool = false
var _key_7_pressed_last_frame: bool = false
var _log_filter_pressed_last_frame: bool = false


# 初始化调试面板信号连接和紧凑显示状态。
func _ready() -> void:
	panel.visible = DebugState.debug_enabled
	DebugState.debug_enabled_changed.connect(_on_debug_enabled_changed)
	DebugState.options_changed.connect(_refresh_static_text)
	DebugState.log_added.connect(_on_log_added)
	_refresh_static_text()


# 调试开启时刷新输入、统计数据和日志显示。
func _process(_delta: float) -> void:
	_handle_debug_input()

	if not DebugState.debug_enabled:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	bullets_label.text = "Blt %s" % _get_bullet_stats()
	graze_label.text = "Grz %d / %d" % [GrazeContext.total_graze, GrazeContext.graze_score]
	enemies_label.text = "Enemy %d" % enemies.size()
	enemy_hp_label.text = _get_enemy_hp_text(enemies)
	_refresh_static_text()
	_refresh_logs()


# 处理调试快捷键并切换各类调试显示。
func _handle_debug_input() -> void:
	if not DebugState.can_use_debug():
		return

	var key_3_pressed: bool = Input.is_key_pressed(KEY_3)
	var key_4_pressed: bool = Input.is_key_pressed(KEY_4)
	var key_5_pressed: bool = Input.is_key_pressed(KEY_5)
	var key_6_pressed: bool = Input.is_key_pressed(KEY_6)
	var key_7_pressed: bool = Input.is_key_pressed(KEY_7)
	var log_filter_pressed: bool = Input.is_key_pressed(KEY_8)
	var key_3_just_pressed: bool = key_3_pressed and not _key_3_pressed_last_frame
	var key_4_just_pressed: bool = key_4_pressed and not _key_4_pressed_last_frame
	var key_5_just_pressed: bool = key_5_pressed and not _key_5_pressed_last_frame
	var key_6_just_pressed: bool = key_6_pressed and not _key_6_pressed_last_frame
	var key_7_just_pressed: bool = key_7_pressed and not _key_7_pressed_last_frame
	var log_filter_just_pressed: bool = log_filter_pressed and not _log_filter_pressed_last_frame

	_key_3_pressed_last_frame = key_3_pressed
	_key_4_pressed_last_frame = key_4_pressed
	_key_5_pressed_last_frame = key_5_pressed
	_key_6_pressed_last_frame = key_6_pressed
	_key_7_pressed_last_frame = key_7_pressed
	_log_filter_pressed_last_frame = log_filter_pressed

	if key_3_just_pressed:
		DebugState.toggle_debug()
	elif key_4_just_pressed:
		DebugState.toggle_collision_shapes()
	elif key_5_just_pressed:
		DebugState.toggle_logs()
	elif key_6_just_pressed:
		DebugState.toggle_invincible()
	elif key_7_just_pressed:
		DebugState.toggle_curve_visuals()
	elif log_filter_just_pressed:
		DebugState.cycle_log_filter()


# 响应调试开关变化并刷新面板可见性。
func _on_debug_enabled_changed(enabled: bool) -> void:
	panel.visible = enabled
	_refresh_static_text()


# 收到新日志时刷新日志文本。
func _on_log_added(_entry: Dictionary) -> void:
	_refresh_logs()


# 刷新调试面板顶部的快捷键和开关状态说明。
func _refresh_static_text() -> void:
	title_label.text = "DBG 3 | 4 Col:%s 5 Log:%s 6 Inv:%s 7 Curve:%s 8 %s" % [
		_on_off(DebugState.show_collision_shapes),
		_on_off(DebugState.show_logs),
		_on_off(DebugState.invincible_enabled),
		_on_off(DebugState.show_curve_visuals),
		DebugState.active_log_key
	]
	options_label.text = "Filter: %s" % DebugState.active_log_key


# 把过滤后的最近调试日志写入界面文本。
func _refresh_logs() -> void:
	if not DebugState.debug_enabled or not DebugState.show_logs:
		log_label.text = "Log hidden"
		return

	var visible_logs: Array[Dictionary] = DebugState.get_visible_logs()
	if visible_logs.is_empty():
		log_label.text = "Log none"
		return

	var lines: Array[String] = []
	for index in range(visible_logs.size()):
		var entry: Dictionary = visible_logs[index]
		lines.append("[%s] %s" % [entry.get("key", "General"), entry.get("message", "")])

	log_label.text = "\n".join(lines)


# 统计子弹层中的活跃、缓存和总子弹数。
func _get_bullet_stats() -> String:
	if not DebugState.show_bullet_count:
		return "hidden"

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return "n/a"

	var bullet_layer: Node = current_scene.get_node_or_null("BulletLayer")
	if bullet_layer == null:
		return "n/a"

	if not bullet_layer.has_method("get_active_bullet_count"):
		return "n/a"

	return "%d/%d/%d" % [
		bullet_layer.get_active_bullet_count(),
		bullet_layer.get_inactive_bullet_count(),
		bullet_layer.get_total_bullet_count()
	]


# 收集敌人和 Boss 的血量信息用于调试显示。
func _get_enemy_hp_text(enemies: Array[Node]) -> String:
	if not DebugState.show_enemy_hp:
		return "HP hidden"

	if enemies.is_empty():
		return "HP none"

	var lines: Array[String] = ["HP"]
	for index in range(enemies.size()):
		var enemy: Node = enemies[index]
		var hp_text: String = "?"
		var max_hp_text: String = "?"
		if enemy.has_method("get_hp"):
			hp_text = str(enemy.get_hp())
		elif enemy.get("hp") != null:
			hp_text = str(enemy.get("hp"))
		if enemy.has_method("get_max_hp"):
			max_hp_text = str(enemy.get_max_hp())
		elif enemy.get("max_hp") != null:
			max_hp_text = str(enemy.get("max_hp"))
		lines.append("#%d %s/%s" % [index + 1, hp_text, max_hp_text])

	return " ".join(lines)


# 把布尔开关压缩成短文本，减少调试面板占屏面积。
func _on_off(value: bool) -> String:
	if value:
		return "ON"
	return "OFF"
