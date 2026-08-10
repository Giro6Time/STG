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

## 套娃绑定：母弹（BulletBase）→ 内层子 pattern（BossBulletPattern）。
## 每颗母弹生成时按 sub_shape 构造一个内层 pattern，origin 每帧跟随母弹位置。
var _sub_bindings: Array[Dictionary] = []

## 子 pattern 驱动用的运行时数据（复用，避免每帧分配）。
var _sub_runtime_data: FlowPhaseRuntimeData = null


func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	if timeline != null:
		timeline.begin()


func stop_pattern() -> void:
	super.stop_pattern()
	# 清理所有套娃子 pattern
	for binding in _sub_bindings:
		_release_sub_binding(binding)
	_sub_bindings.clear()
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
		# get_round() 返回的是已递增后的轮次，本轮实际编号 = 值 - 1（0 起）
		var round_index: int = timeline.get_round() - 1
		_apply_evolution(round_index)
		_emit_round(round_index, _get_timeline_vars())
		if emitter.emission_mode == PatternEmitter.EmissionMode.STREAM:
			emitter.emit_begin(_get_bullet_layer(), _get_bullet_scene(), _get_bullet_init_data(), origin)
			_streaming = true
			emitter.emit_next_step()
		else:
			var spawned: Array[BulletBase] = emitter.emit_once(_get_bullet_layer(), _get_bullet_scene(), _get_bullet_init_data(), origin)
			_bind_sub_shapes(spawned)

	# 套娃子 pattern 由 _process 独立驱动（跟随母弹位置），这里不再重复 tick
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


# --- 套娃（sub_shape）递归发射 ---

## 子 pattern 独立于外层 pattern 的生命周期驱动（母弹回收前持续喷圈）。
func _process(delta: float) -> void:
	if _sub_bindings.is_empty():
		return
	if _sub_runtime_data == null:
		_sub_runtime_data = FlowPhaseRuntimeData.new()
	_sub_runtime_data.setup(self, delta, 0.0)
	_update_sub_patterns(_sub_runtime_data)


## 给本轮 spawn 的每颗母弹绑定一个内层子 pattern（sub_shape 配置）。
func _bind_sub_shapes(spawned: Array[BulletBase]) -> void:
	if sub_shape == null or spawned.is_empty():
		return
	for bullet in spawned:
		if bullet == null or not is_instance_valid(bullet):
			continue
		var inner: BossBulletPattern = sub_shape.build(bullet)
		inner.name = "SubShape_%d" % bullet.get_instance_id()
		add_child(inner)
		inner.start_pattern(bullet)
		# 绑定字典必须为同一实例（signal 回调按引用传递，has() 才生效）
		var binding: Dictionary = {"bullet": bullet, "pattern": inner}
		var callback := _on_sub_bullet_recycled.bind(binding)
		binding["callback"] = callback
		_sub_bindings.append(binding)
		bullet.recycled.connect(callback)


## 每帧驱动所有套娃子 pattern：origin 跟随母弹位置，再推进内层发射。
func _update_sub_patterns(runtime_data: FlowPhaseRuntimeData) -> void:
	if _sub_bindings.is_empty():
		return
	for i in range(_sub_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _sub_bindings[i]
		var bullet: BulletBase = binding["bullet"]
		var inner: BossBulletPattern = binding["pattern"]
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			_release_sub_binding(binding)
			_sub_bindings.remove_at(i)
			continue
		inner.origin = bullet.global_position
		inner.update_pattern(runtime_data)


## 母弹被回收（进对象池）时释放对应子 pattern。
func _on_sub_bullet_recycled(binding: Dictionary) -> void:
	if not _sub_bindings.has(binding):
		return
	_release_sub_binding(binding)
	_sub_bindings.erase(binding)


## 停止并释放单个套娃子 pattern，断开母弹信号。
func _release_sub_binding(binding: Dictionary) -> void:
	var bullet: BulletBase = binding.get("bullet")
	var inner: BossBulletPattern = binding.get("pattern")
	var callback: Callable = binding.get("callback", Callable())
	if bullet != null and is_instance_valid(bullet):
		if callback.is_valid() and bullet.recycled.is_connected(callback):
			bullet.recycled.disconnect(callback)
	if inner != null and is_instance_valid(inner):
		inner.stop_pattern()
		inner.queue_free()


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
