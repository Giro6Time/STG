class_name BossAimedShotPattern
extends BossAttackPattern

@export var fire_interval: float = 1.0
@export var bullet_speed: float = 220.0
@export var damage: int = 1

var _fire_timer: float = 0.0


# 启动瞄准射击并重置开火计时。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	_fire_timer = 0.0


# 按间隔朝玩家方向发射一枚子弹。
func update_pattern(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_running:
		return

	_fire_timer -= runtime_data.delta
	if _fire_timer > 0.0:
		return

	_fire_timer = fire_interval

	# 当前先做“朝玩家方向发射一发子弹”，后续可扩展成多发、扇形或预判射击。
	var direction: Vector2 = _get_direction_to_player(runtime_data)
	var owner_node: Node2D = get_owner_as_node2d()
	if owner_node == null:
		return

	fire_bullet(owner_node.global_position, direction, bullet_speed, damage)
	DebugState.debug_log("Boss attack fire: %s" % get_pattern_label(), "Boss")


# 计算从宿主指向玩家的单位方向，缺失玩家时向下发射。
func _get_direction_to_player(runtime_data: FlowPhaseRuntimeData) -> Vector2:
	var owner_node: Node2D = get_owner_as_node2d()
	if owner_node == null:
		return Vector2.DOWN

	var player: Node2D = runtime_data.player
	if player == null:
		return Vector2.DOWN

	var direction: Vector2 = player.global_position - owner_node.global_position
	if direction.length() <= 0.001:
		return Vector2.DOWN

	return direction.normalized()
