class_name BossAimedShotPattern
extends BossAttackPattern

@export var fire_interval: float = 1.0
@export var bullet_speed: float = 220.0
@export var damage: int = 1

var _fire_timer: float = 0.0


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)
	_fire_timer = 0.0


func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	_fire_timer -= delta
	if _fire_timer > 0.0:
		return

	_fire_timer = fire_interval

	# 当前先做“朝玩家方向发射一发子弹”，后续可扩展成多发、扇形或预判射击。
	var direction: Vector2 = _get_direction_to_player()
	spawn_enemy_bullet(_boss.global_position, direction, bullet_speed, damage)
	DebugState.debug_log("Boss attack fire: %s" % get_pattern_label())


func _get_direction_to_player() -> Vector2:
	if _boss == null:
		return Vector2.DOWN

	var player: Node2D = _boss.get_player()
	if player == null:
		return Vector2.DOWN

	var direction: Vector2 = player.global_position - _boss.global_position
	if direction.length() <= 0.001:
		return Vector2.DOWN

	return direction.normalized()
