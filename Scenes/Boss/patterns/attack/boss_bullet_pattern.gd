class_name BossBulletPattern
extends BossAttackPattern

## 弹幕 Pattern：发射"一组子弹"（2 层递归：sub_shape 可为内层子形状）。
## 职责：持有空间（curve/sampler）+ 时间（timeline）+ 发射规则，驱动 timeline 每轮发射。

## 坐标原点（config 解析后注入，世界坐标基准）。
var origin: Vector2 = Vector2.ZERO

## 发射执行器（由 config.build 注入）。
var emitter: PatternEmitter = PatternEmitter.new()

## 时间采样器（由 config.build 注入）。
var timeline: TimelineDriver = null

## 内层子形状配置（2 层递归；null = 每轮直接发单颗）。
var sub_shape: BulletPatternConfig = null

## STREAM 模式逐颗推进状态。
var _streaming: bool = false


func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	if timeline != null:
		timeline.begin()


func stop_pattern() -> void:
	super.stop_pattern()
	if timeline != null:
		timeline = null


func update_pattern(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_running:
		return
	if timeline == null:
		return

	# STREAM 模式：本轮逐颗推进
	if emitter.emission_mode == PatternEmitter.EmissionMode.STREAM and _streaming:
		if not emitter.emit_stream_tick(runtime_data.delta):
			_streaming = false
			if timeline != null:
				timeline.tick(0.0)  # 空 tick 推进轮次/完成检查
		return

	var triggered: bool = timeline.tick(runtime_data.delta)
	if triggered:
		_apply_evolution(timeline.get_round())
		_emit_round(timeline.get_round(), _get_timeline_vars())
		if emitter.emission_mode == PatternEmitter.EmissionMode.STREAM:
			emitter.emit_begin(_get_bullet_layer(), _get_bullet_scene(), _get_bullet_init_data(), origin)
			_streaming = true
			emitter.emit_next_step()
		else:
			emitter.emit_once(_get_bullet_layer(), _get_bullet_scene(), _get_bullet_init_data(), origin)

	if timeline.is_completed():
		mark_completed()


## 每轮应用演化增量（config.build 注入 TransformCurve 元数据时生效）。
func _apply_evolution(round_index: int) -> void:
	if not has_meta("evolve_transform"):
		return
	var transform: TransformCurve = get_meta("evolve_transform") as TransformCurve
	var angle_inc: float = float(get_meta("angle_increment", 0.0))
	var radius_inc: float = float(get_meta("radius_increment", 0.0))
	if angle_inc != 0.0:
		transform.rotation_degrees = angle_inc * round_index
	if radius_inc != 0.0:
		transform.scale = Vector2.ONE * (1.0 + radius_inc * round_index)


## 本轮发射前的钩子（子类可重写做自定义动作）。
func _emit_round(_round_index: int, _vars: Dictionary) -> void:
	pass


func _get_timeline_vars() -> Dictionary:
	if timeline is RepeatTimelineDriver:
		return (timeline as RepeatTimelineDriver).get_vars()
	return {}


func _get_bullet_layer() -> BulletLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("bullet_layers") as BulletLayer


func _get_bullet_scene() -> PackedScene:
	# bullet_scene 的唯一持有者是 BulletBehaviorConfig（经 sub_shape 链传递）。
	# Pattern 通过 emitter 携带的引用获取；此处由 Task 12 config.build 注入 emitter 持有的 scene。
	if emitter != null and emitter.has_meta("bullet_scene"):
		return emitter.get_meta("bullet_scene") as PackedScene
	return null


func _get_bullet_init_data() -> Dictionary:
	return {
		"collision_layer": CollisionLayers.ENEMY_BULLET,
		"collision_mask": CollisionLayers.PLAYER,
	}
