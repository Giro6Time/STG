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

# 段运行时状态：Boss 是否已生成。
var _spawned: bool = false


# StateMachine 钩子：进入段时记录状态；实际 spawn 推迟到 entrance_delay 计时后。
func enter_state(owner: Node) -> void:
	super.enter_state(owner)
	_spawned = false


# StateMachine 钩子：每帧计时，entrance_delay 到后 spawn boss 并连接完成信号。
func update_state(delta: float) -> void:
	super.update_state(delta)
	if _spawned:
		return
	if _elapsed < entrance_delay:
		return

	if boss_scene == null:
		DebugState.debug_log("BossSegment: boss_scene 为空，跳过", "Level")
		_owner.mark_segment_finished()
		_spawned = true
		return

	var boss_node: Node = boss_scene.instantiate()
	boss_node.position = spawn_position
	_owner.add_child(boss_node)

	if boss_node is Boss:
		var boss: Boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(summoned_enemy_scenes)
		_owner.register_boss(boss, phase_message_ids)
		# 段自己声明完成：Boss 死亡即本段结束。
		boss.died.connect(func(): _owner.mark_segment_finished())

	DebugState.debug_log("BossSegment: 已实例化 Boss", "Level")
	_spawned = true
