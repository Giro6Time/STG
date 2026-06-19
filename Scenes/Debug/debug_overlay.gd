extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var fps_label: Label = $Panel/Margin/VBox/FpsLabel
@onready var bullets_label: Label = $Panel/Margin/VBox/BulletsLabel
@onready var enemies_label: Label = $Panel/Margin/VBox/EnemiesLabel
@onready var enemy_hp_label: Label = $Panel/Margin/VBox/EnemyHpLabel
@onready var log_label: Label = $Panel/Margin/VBox/LogLabel

var _f3_pressed_last_frame := false
var _f4_pressed_last_frame := false
var _f5_pressed_last_frame := false


func _ready() -> void:
	panel.visible = DebugState.debug_enabled
	DebugState.debug_enabled_changed.connect(_on_debug_enabled_changed)
	DebugState.options_changed.connect(_refresh_static_text)
	DebugState.log_added.connect(_on_log_added)
	_refresh_static_text()


func _process(_delta: float) -> void:
	_handle_debug_input()

	if not DebugState.debug_enabled:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	bullets_label.text = "Bullets: %s" % _get_bullet_stats()
	enemies_label.text = "Enemies: %d" % enemies.size()
	enemy_hp_label.text = _get_enemy_hp_text(enemies)
	_refresh_logs()


func _handle_debug_input() -> void:
	if not DebugState.can_use_debug():
		return

	var f3_pressed := Input.is_key_pressed(KEY_F3)
	var f4_pressed := Input.is_key_pressed(KEY_F4)
	var f5_pressed := Input.is_key_pressed(KEY_F5)
	var f3_just_pressed := f3_pressed and not _f3_pressed_last_frame
	var f4_just_pressed := f4_pressed and not _f4_pressed_last_frame
	var f5_just_pressed := f5_pressed and not _f5_pressed_last_frame

	_f3_pressed_last_frame = f3_pressed
	_f4_pressed_last_frame = f4_pressed
	_f5_pressed_last_frame = f5_pressed

	if Input.is_action_just_pressed("toggle_debug") or f3_just_pressed:
		DebugState.toggle_debug()
	elif Input.is_action_just_pressed("toggle_debug_collision") or f4_just_pressed:
		DebugState.toggle_collision_shapes()
	elif Input.is_action_just_pressed("toggle_debug_log") or f5_just_pressed:
		DebugState.toggle_logs()


func _on_debug_enabled_changed(enabled: bool) -> void:
	panel.visible = enabled
	_refresh_static_text()


func _on_log_added(_message: String) -> void:
	_refresh_logs()


func _refresh_static_text() -> void:
	title_label.text = "DEBUG MODE"
	_refresh_logs()


func _refresh_logs() -> void:
	if not DebugState.debug_enabled or not DebugState.show_logs:
		log_label.text = "Logs: hidden"
		return

	if DebugState.logs.is_empty():
		log_label.text = "Logs: none"
	else:
		log_label.text = "Logs:\n" + "\n".join(DebugState.logs)


func _get_bullet_stats() -> String:
	if not DebugState.show_bullet_count:
		return "hidden"

	var current_scene := get_tree().current_scene
	if current_scene == null:
		return "n/a"

	var bullet_layer := current_scene.get_node_or_null("BulletLayer")
	if bullet_layer == null:
		return "n/a"

	if not bullet_layer.has_method("get_active_bullet_count"):
		return "n/a"

	return "active %d / pooled %d / total %d" % [
		bullet_layer.get_active_bullet_count(),
		bullet_layer.get_inactive_bullet_count(),
		bullet_layer.get_total_bullet_count()
	]


func _get_enemy_hp_text(enemies: Array) -> String:
	if not DebugState.show_enemy_hp:
		return "Enemy HP: hidden"

	if enemies.is_empty():
		return "Enemy HP: none"

	var lines: Array[String] = ["Enemy HP:"]
	for index in range(enemies.size()):
		var enemy = enemies[index]
		var hp_text := "?"
		var max_hp_text := "?"
		if enemy.has_method("get_hp"):
			hp_text = str(enemy.get_hp())
		elif enemy.get("hp") != null:
			hp_text = str(enemy.get("hp"))
		if enemy.has_method("get_max_hp"):
			max_hp_text = str(enemy.get_max_hp())
		elif enemy.get("max_hp") != null:
			max_hp_text = str(enemy.get("max_hp"))
		lines.append("  #%d %s/%s" % [index + 1, hp_text, max_hp_text])

	return "\n".join(lines)