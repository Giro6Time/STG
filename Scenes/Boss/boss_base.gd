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


func die() -> void:
	DebugState.debug_log("Boss destroyed")
	if phase_state_machine != null:
		phase_state_machine.shutdown()

	died.emit()
	queue_free()


func spawn_enemy_bullet(spawn_position: Vector2, direction: Vector2, speed: float, damage: int) -> void:
	if bullet_layer == null:
		DebugState.debug_log("Boss bullet layer missing")
		return

	if bullet_scene == null:
		DebugState.debug_log("Boss bullet scene missing")
		return

	bullet_layer.spawn_bullet(
		bullet_scene,
		spawn_position,
		{
			"velocity": direction,
			"speed": speed,
			"damage": damage,
			"collision_layer": CollisionLayers.ENEMY_BULLET,
			"collision_mask": CollisionLayers.PLAYER
		}
	)


func get_player() -> Node2D:
	var player: Node = get_tree().current_scene.get_node_or_null("Player")
	return player as Node2D


func get_hp() -> int:
	return hp


func get_max_hp() -> int:
	return max_hp


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


func _on_phase_state_machine_phase_changed(phase: BossPhase) -> void:
	active_phase = phase
	current_phase = phase.phase_id

	if health_bar != null:
		health_bar.set_phase_label(phase.get_phase_label())

	phase_changed.emit(current_phase)


func _on_phase_transition_started(phase_id: int) -> void:
	phase_transition_started.emit(phase_id)


func _on_phase_transition_finished(phase_id: int) -> void:
	phase_transition_finished.emit(phase_id)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)


func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)
