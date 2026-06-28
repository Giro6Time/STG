class_name BossAttackPattern
extends FlowPattern

var _spawn_rule: BulletSpawnRule = BulletSpawnRule.new()


# 启动攻击 Pattern，并输出攻击开始日志。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)

	if _is_running:
		DebugState.debug_log("Boss attack start: %s" % get_pattern_label(), "Boss")


# 停止攻击 Pattern，并输出攻击停止日志。
func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss attack stop: %s" % get_pattern_label(), "Boss")

	super.stop_pattern()


# 用通用发射规则创建一枚敌方阵营子弹。
func fire_bullet(spawn_position: Vector2, direction: Vector2, speed: float, damage: int, acceleration: float = 0.0) -> void:
	if not _is_running:
		return

	var boss: Boss = get_owner_as_boss()
	if boss == null:
		return

	_spawn_rule.bullet_speed = speed
	_spawn_rule.damage = damage
	_spawn_rule.acceleration = acceleration
	_spawn_rule.fallback_direction = Vector2.DOWN
	_spawn_rule.spawn_bullet(
		_get_bullet_layer(),
		boss.get_bullet_scene(),
		spawn_position,
		direction,
		boss.get_enemy_bullet_init_data()
	)


# 通过 Godot group 查找当前场景的主 BulletLayer。
func _get_bullet_layer() -> BulletLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	return tree.get_first_node_in_group("bullet_layers") as BulletLayer
