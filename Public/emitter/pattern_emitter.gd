class_name PatternEmitter
extends Resource

@export var curve: ParametricCurve
@export var sampler: ParameterSampler
@export var spawn_rule: BulletSpawnRule


func emit_once(bullet_layer: BulletLayer, bullet_scene: PackedScene, init_data: Dictionary, origin: Vector2) -> void:
	if bullet_layer == null:
		return

	var active_curve: ParametricCurve = curve
	if active_curve == null:
		active_curve = CircleParametricCurve.new()

	var active_sampler: ParameterSampler = sampler
	if active_sampler == null:
		var default_sampler: UniformParameterSampler = UniformParameterSampler.new()
		default_sampler.sample_count = 16
		active_sampler = default_sampler

	var active_spawn_rule: BulletSpawnRule = spawn_rule
	if active_spawn_rule == null:
		active_spawn_rule = BulletSpawnRule.new()

	var values: Array[float] = active_sampler.sample_values()
	for index in range(values.size()):
		var t: float = values[index]
		var local_point: Vector2 = active_curve.sample(t)
		var tangent: Vector2 = active_curve.tangent(t)
		active_spawn_rule.spawn_from_curve(bullet_layer, bullet_scene, origin, local_point, tangent, init_data)
