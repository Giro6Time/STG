class_name MinionWaveSegment
extends LevelSegment

# 小怪波次段：声明本波刷什么敌人、刷多少、何时刷。
# 段自报完成：本波敌人全部生成且全部死亡后 mark_segment_finished（配合超时兜底）。
# 波次重叠由 LevelManager 的 wait_time 超时驱动（怪没死完超时→下一波进场）。

## 本波次生成的敌人场景。
@export var enemy_scene: PackedScene
## 本波次敌人总数。
@export var count: int = 0
## 相邻敌人生成间隔（秒）。
@export var spawn_interval: float = 0.5
## 生成位置列表（世界坐标）；为空时默认在屏幕顶部随机。
@export var spawn_positions: Array[Vector2] = []


func get_enemy_scene() -> PackedScene:
	return enemy_scene


func get_spawn_count() -> int:
	return count


func get_spawn_interval() -> float:
	return spawn_interval


func get_spawn_positions() -> Array[Vector2]:
	return spawn_positions

# 段运行时状态：生成进度与存活敌人计数。
var _spawned_count: int = 0
var _alive_count: int = 0


# StateMachine 钩子：进入段时重置生成状态。
func enter_state(owner: Node) -> void:
	super.enter_state(owner)
	_spawned_count = 0
	_alive_count = 0


# StateMachine 钩子：每帧按间隔生成敌人；全部生成且全部死亡 → 段完成。
func update_state(delta: float) -> void:
	super.update_state(delta)
	_spawn_pending_enemies()


# 按生成间隔批量生成剩余敌人（一次 update 内尽量多生成，受间隔约束）。
func _spawn_pending_enemies() -> void:
	while _spawned_count < get_spawn_count():
		if _spawned_count > 0 and _elapsed < _spawned_count * get_spawn_interval():
			return
		var enemy_scene: PackedScene = get_enemy_scene()
		if enemy_scene == null:
			DebugState.debug_log("MinionWaveSegment: enemy_scene 为空，跳过", "Level")
			_owner.mark_segment_finished()
			_spawned_count = get_spawn_count()
			return
		var enemy_node: Node2D = enemy_scene.instantiate()
		var positions: Array[Vector2] = get_spawn_positions()
		if positions.size() > 0:
			enemy_node.position = positions[_spawned_count % positions.size()]
		else:
			enemy_node.position = Vector2(randf_range(32.0, 608.0), -32.0)
		_owner.add_child(enemy_node)
		_alive_count += 1
		_spawned_count += 1
		enemy_node.died.connect(_on_wave_enemy_died)


# 敌人死亡回调：存活计数减一；全部生成且全部死亡 → 段完成。
func _on_wave_enemy_died() -> void:
	_alive_count -= 1
	if _spawned_count >= get_spawn_count() and _alive_count <= 0:
		_owner.mark_segment_finished()
