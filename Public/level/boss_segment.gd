class_name BossSegment
extends LevelSegment

# Boss 登场段：声明本段要实例化哪个 Boss、何时入场、可召唤的敌人与转阶段消息。
# 入场等待用基类 start_delay（进入后延迟 N 秒才开始执行），本次控制"何时把 Boss 加入场景树"
#（真实入场动画留给演出 stage）。
@export var boss_scene: PackedScene
## Boss 出生位置（屏幕坐标）。
@export var spawn_position: Vector2 = Vector2.ZERO
## 召唤敌人声明。本次只承载数据并提供能力接口，真正波次时机留到以后。
@export var summoned_enemy_scenes: Array[PackedScene] = []
## 转阶段消息映射：phase_id -> 消息 id（写入 messages_zh.json）。LevelManager 在转阶段时触发。
@export var phase_message_ids: Dictionary = {}

# 段运行时状态：Boss 是否已生成。
var _spawned: bool = false
# 段完成锁：段已自报完成或已退出后，迟到的 Boss 死亡信号不再推进（防跨段污染）。
var _finished: bool = false
# 本段生成的 Boss 引用：exit_state 时断开 died 连接。
var _boss: Boss = null


# StateMachine 钩子：进入段时记录状态；实际 spawn 推迟到 start_delay（基类计时）后。
func enter_state(owner: Node) -> void:
	super.enter_state(owner)
	_spawned = false
	_finished = false


# StateMachine 钩子：段退出时锁定完成回调并断开 Boss 死亡连接。
func exit_state() -> void:
	_finished = true
	if _boss != null and is_instance_valid(_boss) and _boss.died.is_connected(_on_boss_finished):
		_boss.died.disconnect(_on_boss_finished)
	_boss = null


# StateMachine 钩子：每帧计时，start_delay 到后 spawn boss 并连接完成信号。
func update_state(delta: float) -> void:
	super.update_state(delta)
	if _spawned:
		return
	if not is_delay_elapsed():
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
		_boss = boss
		boss.set_summonable_enemy_scenes(summoned_enemy_scenes)
		_owner.register_boss(boss, phase_message_ids)
		# 段自己声明完成：Boss 死亡即本段结束。
		boss.died.connect(_on_boss_finished)

	DebugState.debug_log("BossSegment: 已实例化 Boss", "Level")
	_spawned = true


# Boss 死亡回调：段自报完成。完成锁保证迟到信号不推进下一段。
func _on_boss_finished() -> void:
	if _finished:
		return
	_finished = true
	_owner.mark_segment_finished()
