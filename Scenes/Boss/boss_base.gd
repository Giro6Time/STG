class_name Boss
extends Area2D

# Boss 对外广播血量、阶段和死亡事件，后续关卡流程或弹幕控制器可以监听这些信号。
signal hp_changed(current_hp: int, max_hp: int)
signal phase_changed(current_phase: int)
signal phase_transition_started(current_phase: int)
signal phase_transition_finished(current_phase: int)
signal died

@export var max_hp: int = 100
@export var contact_damage: int = 1
@export var bullet_scene: PackedScene

@onready var health_bar: BossHealthBar = $BossHealthBar
@onready var phase_state_machine: PhaseStateMachine = $PhaseStateMachine
@onready var bullet_layer: BulletLayer = get_tree().current_scene.get_node_or_null("BulletLayer") as BulletLayer

var hp: int = 0
var current_phase: int = 0
var active_phase: BossPhase


# 初始化 Boss 血量、调试绘制、碰撞事件和阶段状态机。
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

	_connect_phase_state_machine()
	hp_changed.emit(hp, max_hp)
	phase_state_machine.setup(self)


# 处理 Boss 受到伤害后的血量变化、UI 更新和死亡判定。
func take_damage(damage: int) -> void:
	if damage <= 0:
		return

	# 统一伤害入口，玩家子弹只需要调用 take_damage() 就能命中 Boss。
	hp = max(hp - damage, 0)
	DebugState.debug_log("Boss hit: %d/%d (-%d)" % [hp, max_hp, damage])

	if health_bar != null:
		health_bar.set_hp(hp, max_hp)

	hp_changed.emit(hp, max_hp)

	if hp <= 0:
		die()


# 关闭阶段逻辑并广播 Boss 死亡事件。
func die() -> void:
	DebugState.debug_log("Boss destroyed")
	if phase_state_machine != null:
		phase_state_machine.shutdown()

	died.emit()
	queue_free()


# 提供当前场景中的子弹层，供弹幕发射上下文使用。
func get_bullet_layer() -> BulletLayer:
	return bullet_layer


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


# 连接阶段状态机信号到 Boss 对外广播接口。
func _connect_phase_state_machine() -> void:
	var phase_changed_callback: Callable = Callable(self, "_on_phase_state_machine_phase_changed")
	var transition_started_callback: Callable = Callable(self, "_on_phase_transition_started")
	var transition_finished_callback: Callable = Callable(self, "_on_phase_transition_finished")

	if not phase_state_machine.phase_changed.is_connected(phase_changed_callback):
		phase_state_machine.phase_changed.connect(phase_changed_callback)
	if not phase_state_machine.phase_transition_started.is_connected(transition_started_callback):
		phase_state_machine.phase_transition_started.connect(transition_started_callback)
	if not phase_state_machine.phase_transition_finished.is_connected(transition_finished_callback):
		phase_state_machine.phase_transition_finished.connect(transition_finished_callback)


# 同步当前阶段数据并更新血条阶段文字。
func _on_phase_state_machine_phase_changed(phase: BossPhase) -> void:
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
