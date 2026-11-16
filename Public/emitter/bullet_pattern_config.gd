class_name BulletPatternConfig
extends Resource

## 弹幕完整配置：数据只存参数，build() 构造运行时 Pattern。

enum OriginMode { BOSS_LOCAL, WORLD_ABSOLUTE, PLAYER_POSITION }

@export var display_name: String = ""
@export var duration: float = 4.0
@export var origin_mode: OriginMode = OriginMode.BOSS_LOCAL
@export var origin_offset: Vector2 = Vector2.ZERO
@export var curve: ParametricCurve = CircleParametricCurve.new()
@export var sampler: ParameterSampler = UniformParameterSampler.new()
@export var timeline: TimelineDriver
@export var direction_mode: BulletSpawnRule.DirectionMode = BulletSpawnRule.DirectionMode.CURVE_TANGENT
@export var bullet: BulletBehaviorConfig
@export var sub_shape: BulletPatternConfig = null

## 每轮演化（可选，通用变换层，不依赖底层曲线类型）：
## 操作 TransformCurve 的 rotation_degrees / scale，包任意曲线都适用。
@export var angle_increment_per_round: float = 0.0
@export var radius_increment_per_round: float = 0.0


func build(owner_node: Node2D) -> BossBulletPattern:
	var pattern := BossBulletPattern.new()
	pattern.pattern_name = display_name
	pattern.origin = _resolve_origin(owner_node)

	# 构造发射规则与执行器
	var spawn_rule := BulletSpawnRule.new()
	spawn_rule.direction_mode = direction_mode
	spawn_rule.bullet_speed = _get_bullet_speed()
	spawn_rule.damage = _get_damage()
	spawn_rule.bullet_lifetime = _get_lifetime()
	if bullet != null:
		spawn_rule.motion = bullet.motion

	# 需要每轮演化时，把曲线包一层 TransformCurve（操作通用变换字段）
	var emit_curve: ParametricCurve = curve
	if angle_increment_per_round != 0.0 or radius_increment_per_round != 0.0:
		var transform := TransformCurve.new()
		transform.base = curve
		transform.rotation_degrees = 0.0
		transform.scale = Vector2.ONE
		emit_curve = transform
		pattern.set_meta("evolve_transform", transform)
		pattern.set_meta("angle_increment", angle_increment_per_round)
		pattern.set_meta("radius_increment", radius_increment_per_round)

	pattern.emitter = PatternEmitter.new()
	pattern.emitter.curve = emit_curve
	pattern.emitter.sampler = sampler
	pattern.emitter.spawn_rule = spawn_rule
	# 注入 bullet_scene（唯一持有者 BulletBehaviorConfig）
	if bullet != null:
		pattern.emitter.set_meta("bullet_scene", bullet.bullet_scene)

	pattern.timeline = timeline
	pattern.sub_shape = sub_shape
	return pattern


func _resolve_origin(owner_node: Node2D) -> Vector2:
	match origin_mode:
		OriginMode.WORLD_ABSOLUTE:
			return origin_offset
		OriginMode.PLAYER_POSITION:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				var player := tree.get_first_node_in_group("players") as Node2D
				if player != null:
					return player.global_position + origin_offset
			return origin_offset
		_:
			if owner_node != null:
				return owner_node.global_position + origin_offset
			return origin_offset


func _get_bullet_speed() -> float:
	if bullet != null and bullet.motion is LinearMotion:
		return (bullet.motion as LinearMotion).speed
	return 90.0


func _get_damage() -> int:
	return bullet.damage if bullet != null else 1


func _get_lifetime() -> float:
	return bullet.bullet_lifetime if bullet != null else 6.0
