class_name BossSegment
extends LevelSegment

# Boss 登场段：声明本段要实例化哪个 Boss、何时入场、可召唤的敌人与转阶段消息。
@export var boss_scene: PackedScene
## 入场前等待。本次控制"何时把 Boss 加入场景树"（真实入场动画留给演出 stage）。
@export var entrance_delay: float = 0.0
## Boss 出生位置（屏幕坐标）。
@export var spawn_position: Vector2 = Vector2.ZERO
## 召唤敌人声明。本次只承载数据并提供能力接口，真正波次时机留到以后。
@export var summoned_enemy_scenes: Array[PackedScene] = []
## 转阶段消息映射：phase_id -> 消息 id（写入 messages_zh.json）。LevelManager 在转阶段时触发。
@export var phase_message_ids: Dictionary = {}


# 执行 Boss 段：等待入场延迟后实例化 Boss 并注册到关卡环境。
func execute(context: LevelManager) -> void:
	if boss_scene == null:
		DebugState.debug_log("BossSegment: boss_scene 为空，跳过", "Level")
		return

	await context.get_tree().create_timer(entrance_delay).timeout

	var boss_node: Node = boss_scene.instantiate()
	boss_node.position = spawn_position
	context.add_child(boss_node)

	if boss_node is Boss:
		var boss: Boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(summoned_enemy_scenes)
		context.register_boss(boss, phase_message_ids)

	DebugState.debug_log("BossSegment: 已实例化 Boss", "Level")
