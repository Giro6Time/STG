extends Node2D
class_name LevelManager

# 关卡装配器：读取 LevelDefinition，顺序消费流程段并实例化内容。
# LevelManager 只在"何时叫 Boss / 何时发消息"，Boss 只提供动作与信号，双方不互相持有 UI/背景/玩家引用。

@export var level_definition: LevelDefinition

## 当前 BossSegment 的转阶段消息映射（phase_id -> message_id），由当前段配置而来。
var _phase_message_ids: Dictionary = {}

var boss: Boss


# 按关卡配置异步装配：null 则警告并返回。
func _ready() -> void:
	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_consume_segments()


# 按顺序处理每个流程段；本次只有 boss 段，未知类型警告并跳过。
func _consume_segments() -> void:
	for segment in level_definition.segments:
		if segment is BossSegment:
			await _spawn_boss(segment as BossSegment)
		else:
			DebugState.debug_log(
				"LevelManager: 未知关卡段类型 '%s'，跳过" % (segment.type if segment else "null"),
				"Level"
			)


# 等待入场延迟后实例化 Boss、注入召唤列表并连接所需信号。
func _spawn_boss(segment: BossSegment) -> void:
	if segment.boss_scene == null:
		DebugState.debug_log("LevelManager: boss_scene 为空，跳过本段", "Level")
		return

	await get_tree().create_timer(segment.entrance_delay).timeout

	var boss_node: Node = segment.boss_scene.instantiate()
	boss_node.position = segment.spawn_position
	add_child(boss_node)

	if boss_node is Boss:
		boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(segment.summoned_enemy_scenes)
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.died.connect(_on_boss_died)
		# entrance_finished: 本次保留出口信号，接入真实解锁/演出留给演出 stage。

	# 记录本段的转阶段消息映射，供 phase_changed 时查询。
	_phase_message_ids = segment.phase_message_ids

	DebugState.debug_log("LevelManager: 已实例化 Boss", "Level")


# Boss 转阶段：若该阶段在 BossSegment 配置了消息，则通过 MessageController 发送。
# 数据在关卡配置里，LevelManager 只是"转发"。
func _on_boss_phase_changed(phase_id: int) -> void:
	var msg_id: String = str(_phase_message_ids.get(phase_id, ""))
	if msg_id.is_empty():
		return

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	if controller == null:
		DebugState.debug_log("LevelManager: 找不到 message_controllers，跳过消息 %s" % msg_id, "Level")
		return

	controller.show_by_id(msg_id)


# Boss 死亡：结算入口占位（掉物/恢复/flag 留演出 stage）。
func _on_boss_died() -> void:
	DebugState.debug_log("LevelManager: Boss 死亡，结算入口待接入", "Level")