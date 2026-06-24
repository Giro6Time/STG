class_name BossRadialWavePattern
extends BossAttackPattern

@export var fire_interval: float = 1.4
@export var bullet_count: int = 24
@export var spawn_radius: float = 16.0
@export var angle_offset_degrees: float = 90.0
@export var bullet_speed: float = 90.0
@export var bullet_acceleration: float = 35.0
@export var bullet_scene: PackedScene
@export var damage: int = 1
@export var fire_immediately: bool = true

var _fire_timer: float = 0.0
var _emitter: PatternEmitter = PatternEmitter.new()
var _curve: CircleParametricCurve = CircleParametricCurve.new()
var _sampler: UniformParameterSampler = UniformParameterSampler.new()


func start_pattern(boss: Boss) -> void:
	super.start_pattern(boss)
	_configure_emitter()
	if fire_immediately:
		_fire_timer = 0.0
	else:
		_fire_timer = fire_interval


func update_pattern(delta: float) -> void:
	if not _is_running:
		return

	_fire_timer -= delta
	if _fire_timer > 0.0:
		return

	_fire_timer = fire_interval
	fire_wave()


func fire_wave() -> bool:
	if not _is_running:
		return false
	if _boss == null || bullet_scene == null:
		return false

	_configure_emitter()
	_emitter.emit_once(
		_boss.get_bullet_layer(),
		bullet_scene,
		_boss.get_enemy_bullet_init_data(),
		_boss.global_position
	)
	DebugState.debug_log("Boss radial wave fire: %s" % get_pattern_label())
	return true

func _configure_emitter() -> void:
	_curve.radius = spawn_radius
	_curve.angle_offset_degrees = angle_offset_degrees

	_sampler.start_t = 0.0
	_sampler.end_t = 1.0
	_sampler.sample_count = bullet_count
	_sampler.include_end = false

	_spawn_rule.bullet_speed = bullet_speed
	_spawn_rule.acceleration = bullet_acceleration
	_spawn_rule.damage = damage
	_spawn_rule.use_curve_point_as_direction = true
	_spawn_rule.use_tangent_as_direction = false
	_spawn_rule.fallback_direction = Vector2.DOWN

	_emitter.curve = _curve
	_emitter.sampler = _sampler
	_emitter.spawn_rule = _spawn_rule
