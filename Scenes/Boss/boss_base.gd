class_name Boss
extends Area2D

# Boss 对外广播血量、阶段和死亡事件，后续关卡流程或弹幕控制器可以监听这些信号。
signal hp_changed(current_hp: int, max_hp: int)
signal phase_changed(current_phase: int)
signal phase_transition_started(current_phase: int)
signal phase_transition_finished(current_phase: int)
signal died
signal entrance_finished
signal external_event_requested(event_name: String, payload: Dictionary)

@export var max_hp: int = 100
@export var contact_damage: int = 1
@export var bullet_scene: PackedScene

## 本场战斗可召唤的敌人场景；由 LevelManager 依据 BossSegment 注入，本次只提供能力借口，不设时机。
@export var summonable_enemy_scenes: Array[PackedScene] = []

@onready var health_bar: BossHealthBar = $BossHealthBar
@onready var phase_machine: FlowPhaseMachine = $FlowPhaseMachine

var hp: int = 0
var current_phase: int = 0
var active_phase: FlowPhase

# 死亡流程守卫：防止消散期间残留子弹再次 take_damage 触发重复 die()/died.emit，
# 避免 LevelManager 胜利演出与胜利对话被反复入队。
var _dying: bool = false


# 初始化 Boss 血量、调试绘制、碰撞事件和阶段流程。
func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	add_to_group("bosses")
	add_to_group("enemies")
	hp = max_hp
	body_entered.connect(_on_body_entered)

	# 血条是 Boss 自带显示组件；缺失时不影响 Boss 本体逻辑。
	if health_bar != null:
		health_bar.setup(max_hp)
		health_bar.set_hp(hp, max_hp)

	_connect_phase_machine()
	hp_changed.emit(hp, max_hp)
	phase_machine.setup(self)
	_forward_external_events()


# 处理 Boss 受到伤害后的血量变化、UI 更新和死亡判定。
func take_damage(damage: int) -> void:
	if damage <= 0:
		return

	# 统一伤害入口，玩家子弹只需要调用 take_damage() 就能命中 Boss。
	hp = max(hp - damage, 0)
	DebugState.debug_log("Boss hit: %d/%d (-%d)" % [hp, max_hp, damage], "Boss")

	if health_bar != null:
		health_bar.set_hp(hp, max_hp)

	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		die()


# 关闭阶段流程并广播 Boss 死亡事件，然后播消散占位动画后释放。
func die() -> void:
	if _dying:
		return
	_dying = true

	DebugState.debug_log("Boss destroyed", "Boss")
	if phase_machine != null:
		phase_machine.shutdown()

	died.emit()
	await _play_dissolve()


# 提供 Boss 默认使用的子弹场景资源。
func get_bullet_scene() -> PackedScene:
	return bullet_scene


# 返回敌方子弹的碰撞层和碰撞掩码初始化数据。
func get_enemy_bullet_init_data() -> Dictionary:
	return {
		"collision_layer": CollisionLayers.ENEMY_BULLET,
		"collision_mask": CollisionLayers.PLAYER
	}


# 从当前场景中查找玩家节点供攻击模式瞄准。
func get_player() -> Node2D:
	var player: Node = get_tree().current_scene.get_node_or_null("Player")
	return player as Node2D


# 返回 Boss 当前血量。
func get_hp() -> int:
	return hp


# 返回 Boss 最大血量。
func get_max_hp() -> int:
	return max_hp


# 连接阶段流程信号到 Boss 对外广播接口。
func _connect_phase_machine() -> void:
	var phase_changed_callback: Callable = Callable(self, "_on_phase_machine_phase_changed")
	var transition_started_callback: Callable = Callable(self, "_on_phase_transition_started")
	var transition_finished_callback: Callable = Callable(self, "_on_phase_transition_finished")

	if not phase_machine.phase_changed.is_connected(phase_changed_callback):
		phase_machine.phase_changed.connect(phase_changed_callback)
	if not phase_machine.phase_transition_started.is_connected(transition_started_callback):
		phase_machine.phase_transition_started.connect(transition_started_callback)
	if not phase_machine.phase_transition_finished.is_connected(transition_finished_callback):
		phase_machine.phase_transition_finished.connect(transition_finished_callback)


# 同步当前阶段数据并更新血条阶段文字。
func _on_phase_machine_phase_changed(phase: FlowPhase) -> void:
	active_phase = phase
	current_phase = phase.phase_id

	if health_bar != null:
		health_bar.set_phase_label(phase.get_phase_label())

	phase_changed.emit(current_phase)


# 向外转发阶段切换开始事件。
func _on_phase_transition_started(phase_id: int) -> void:
	phase_transition_started.emit(phase_id)


# 向外转发阶段切换完成事件。
func _on_phase_transition_finished(phase_id: int) -> void:
	phase_transition_finished.emit(phase_id)


# Boss 接触可受伤对象时造成碰撞伤害。
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)


# 在调试模式下绘制 Boss 的碰撞形状。
func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)


# 由外部（LevelManager）注入本次可召唤的敌人场景列表。
func set_summonable_enemy_scenes(scenes: Array[PackedScene]) -> void:
	summonable_enemy_scenes = scenes


# 召唤一个敌人：从召唤列表取指定场景实例化为 owner 挂入父节点（即关卡），避免跟随 Boss 移动。
func summon_enemy(scene_index: int = 0) -> Enemy:
	if scene_index < 0 or scene_index >= summonable_enemy_scenes.size():
		return null
	var scene: PackedScene = summonable_enemy_scenes[scene_index]
	if scene == null:
		return null
	var enemy: Enemy = scene.instantiate() as Enemy
	if enemy == null:
		return null
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(enemy)
	return enemy


# 转发场景内所有 BossExternalEventPattern 的事件到 Boss 对外信号，
# 保持"Boss 只发信号，LevelManager 决定响应"的边界，不感知演出细节。
func _forward_external_events() -> void:
	var patterns := find_children("*", "BossExternalEventPattern", true, true)
	for pattern in patterns:
		var callback := Callable(self, "_on_pattern_external_event")
		if not pattern.external_event_requested.is_connected(callback):
			pattern.external_event_requested.connect(callback)


func _on_pattern_external_event(event_name: String, payload: Dictionary, _pattern: FlowPattern) -> void:
	external_event_requested.emit(event_name, payload)


# 死亡：关闭阶段流程、广播死亡事件，然后播消散占位动画（缩至 0 + 淡出）后释放。
# 消散期间 Boss 仍保留在场景树，LevelManager 的胜利演出（掉落/对话）可并行进行。
func _play_dissolve() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
