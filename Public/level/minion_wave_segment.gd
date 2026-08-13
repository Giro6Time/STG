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
# 段完成锁：段已自报完成或已退出后，迟到的小怪死亡信号不再推进（防跨段污染）。
var _finished: bool = false
# 本段生成过的小怪列表：exit_state 时逐个断开 died 连接，避免超时退出后残留敌人影响下一段。
var _tracked_enemies: Array[Node] = []


# StateMachine 钩子：进入段时重置生成状态。
func enter_state(owner: Node) -> void:
	super.enter_state(owner)
	_spawned_count = 0
	_alive_count = 0
	_finished = false
	# 空波次防护：count<=0 永不会生成敌人也不会触发完成信号，直接完成防死锁。
	if get_spawn_count() <= 0:
		_finished = true
		_owner.mark_segment_finished()


# StateMachine 钩子：段退出时锁定完成回调并断开残留敌人的 died 连接。
func exit_state() -> void:
	_finished = true
	for enemy in _tracked_enemies:
		if is_instance_valid(enemy) and enemy.died.is_connected(_on_wave_enemy_died):
			enemy.died.disconnect(_on_wave_enemy_died)
	_tracked_enemies.clear()


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
		_tracked_enemies.append(enemy_node)
		enemy_node.died.connect(_on_wave_enemy_died)


# 敌人死亡回调：存活计数减一；全部生成且全部死亡 → 段完成。
# 段已完成后（完成锁）迟到的死亡信号直接忽略，防止推进下一段。
func _on_wave_enemy_died() -> void:
	if _finished:
		return
	_alive_count -= 1
	if _spawned_count >= get_spawn_count() and _alive_count <= 0:
		_finished = true
		_owner.mark_segment_finished()
