class_name BossRadialWavePattern
extends BossAttackPattern

@export var fire_interval: float = 1.4
@export var curve: ParametricCurve = CircleParametricCurve.new()
@export var sampler: ParameterSampler = UniformParameterSampler.new()
@export var bullet_speed: float = 90.0
@export var bullet_acceleration: float = 35.0
@export var bullet_scene: PackedScene
@export var damage: int = 1
@export var fire_immediately: bool = true

var _fire_timer: float = 0.0
var _emitter: PatternEmitter = PatternEmitter.new()


# 启动圆形波次弹幕，注册曲线调试数据并设置首次发射计时。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	DebugHelper.register_curve_drawable(self)
	_configure_emitter()
	if fire_immediately:
		_fire_timer = 0.0
	else:
		_fire_timer = fire_interval


# 停止圆形波次弹幕时注销曲线调试数据，避免阶段结束后残留显示。
func stop_pattern() -> void:
	DebugHelper.unregister_curve_drawable(self)
	super.stop_pattern()


# 按发射间隔触发一圈径向弹幕。
func update_pattern(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_running:
		return

	_fire_timer -= runtime_data.delta
	if _fire_timer > 0.0:
		return

	_fire_timer = fire_interval
	fire_wave()


# 用通用 Emitter 从宿主位置发射一组曲线弹幕。
func fire_wave() -> bool:
	if not _is_running:
		return false

	var boss: Boss = get_owner_as_boss()
	var owner_node: Node2D = get_owner_as_node2d()
	if boss == null or owner_node == null or bullet_scene == null:
		return false

	_configure_emitter()
	_emitter.emit_once(
		_get_bullet_layer(),
		bullet_scene,
		boss.get_enemy_bullet_init_data(),
		owner_node.global_position
	)
	DebugState.debug_log("Boss curve wave fire: %s" % get_pattern_label(), "Curve")
	return true


# 提供当前曲线的调试绘制数据，Debug 层只负责调用 Curve 自己的可视化方法。
func get_debug_curve_draw_data() -> Array[Dictionary]:
	var owner_node: Node2D = get_owner_as_node2d()
	if owner_node == null:
		return []

	_configure_emitter()
	return [
		{
			"curve": curve,
			"sampler": sampler,
			"origin": owner_node.global_position,
			"color": Color(0.85, 0.3, 1.0, 0.95),
			"tangent_length": 14.0
		}
	]


# 把导出的曲线、采样器和发射参数同步到 Emitter。
func _configure_emitter() -> void:
	if curve == null:
		curve = CircleParametricCurve.new()
	if sampler == null:
		sampler = UniformParameterSampler.new()

	_spawn_rule.bullet_speed = bullet_speed
	_spawn_rule.acceleration = bullet_acceleration
	_spawn_rule.damage = damage
	_spawn_rule.use_curve_point_as_direction = true
	_spawn_rule.use_tangent_as_direction = false
	_spawn_rule.fallback_direction = Vector2.DOWN

	_emitter.curve = curve
	_emitter.sampler = sampler
	_emitter.spawn_rule = _spawn_rule
