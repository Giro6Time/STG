class_name BossHorizontalSweepMovement
extends BossMovementPattern

@export var amplitude: float = 80.0
@export var sweep_speed: float = 1.5

var _origin_position: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)

	if _is_running and _boss != null:
		_origin_position = _boss.global_position
		_elapsed = 0.0


func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	if _boss == null:
		return

	# 基础横向巡航，用于验证移动 Pattern；后续冲撞类移动可以做成独立 Pattern。
	_elapsed += delta
	var next_position: Vector2 = _boss.global_position
	next_position.x = _origin_position.x + sin(_elapsed * sweep_speed) * amplitude
	_boss.global_position = next_position
