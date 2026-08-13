class_name MinionWaveSegment
extends LevelSegment

# 小怪波次段：声明本波刷什么敌人、刷多少、何时刷。非阻塞（completion 默认 null），
# 触发即完成，配合 start_delay 形成并行波次（不等待上一波清空）。

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


# 执行小怪波次：按间隔依次生成敌人。非阻塞（completion 默认 null），触发即完成。
func execute(context: LevelManager) -> void:
	var scene: PackedScene = get_enemy_scene()
	if scene == null:
		DebugState.debug_log("MinionWaveSegment: enemy_scene 为空，跳过", "Level")
		return

	var positions: Array[Vector2] = get_spawn_positions()
	var count: int = get_spawn_count()

	for index in range(count):
		if index > 0 and get_spawn_interval() > 0.0:
			await context.get_tree().create_timer(get_spawn_interval()).timeout

		var enemy_node: Node2D = scene.instantiate()
		if positions.size() > 0:
			enemy_node.position = positions[index % positions.size()]
		else:
			enemy_node.position = Vector2(
				randf_range(32.0, 608.0),
				-32.0
			)
		context.add_child(enemy_node)
		DebugState.debug_log("MinionWaveSegment: 生成敌人 %d/%d" % [index + 1, count], "Level")
