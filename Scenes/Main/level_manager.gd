extends Node2D
class_name LevelManager

# 关卡纯编排器：读取 LevelDefinition，用 StateMachine 按顺序驱动流程段（进入 → 运行 → 完成推进）。
# 内容生成在段自身的状态机钩子（enter_state/update_state/exit_state）里；LevelManager 只负责
# 时序编排与环境接口（register_boss / mark_segment_finished）。
# LevelManager 只在"何时驱动段 / 何时发消息"，Boss 只提供动作与信号，双方不互相持有 UI/背景/玩家引用。

@export var level_definition: LevelDefinition

## 当前 BossSegment 的转阶段消息映射（phase_id -> message_id），由当前段配置而来。
var _phase_message_ids: Dictionary = {}

var boss: Boss

# 关卡段状态机：驱动段 enter/update/exit 生命周期。
var _segment_machine: StateMachine = StateMachine.new()
var _current_segment: LevelSegment
# 段完成标志：每段进入时重置，段通过 mark_segment_finished() 置位。
var _segment_finished: bool = false


# 按关卡配置装配：null 则警告并返回。构建段状态机后直接 start 第一个段。
func _ready() -> void:
	_connect_player_signals()

	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_build_segment_machine()
	var first_segment: LevelSegment = level_definition.segments[0] if level_definition.segments.size() > 0 else null
	if first_segment != null:
		_current_segment = first_segment
		_segment_machine.start(first_segment)


# 构建段状态机：按顺序登记 transition（线性推进）。
func _build_segment_machine() -> void:
	var segments: Array[LevelSegment] = level_definition.segments
	_segment_machine.setup(self, segments)
	for index in range(segments.size() - 1):
		if segments[index] != null and segments[index + 1] != null:
			_segment_machine.add_transition(segments[index], segments[index + 1])


# 每帧驱动关卡：step 当前段 → 完成判定推进（段自报完成或 wait_time 超时）。
func _process(delta: float) -> void:
	if _current_segment == null:
		return

	_segment_machine.update(delta)

	if _segment_finished or _completion_timeout():
		_advance_to_next()


# 完成超时判定：completion 非 null 且 wait_time > 0 且超时。
# 段内计时用 _current_segment._elapsed（update_state 每帧累积，与状态机当前态同对象）。
# 注：_elapsed 从 enter_state 起计，包含 start_delay 等待时间；completion.wait_time 与之比较，
#     即超时窗口包含进入后延迟。当前无段同时配置两者，此语义可接受。
func _completion_timeout() -> bool:
	if _current_segment == null or _current_segment.completion == null:
		return false
	return _current_segment.completion.wait_time > 0.0 \
		and _current_segment._elapsed >= _current_segment.completion.wait_time


# 推进到下一个段：重置完成 flag → transition（exit 旧段 / enter 新段）。
# 重置必须在 transition 之前：新段 enter_state 内若 mark_segment_finished，先重置才不会把旧段完成态带入新段。
func _advance_to_next() -> void:
	var finished_segment: LevelSegment = _current_segment
	_segment_finished = false
	_segment_machine.transition_to_next()
	var next_state: Object = _segment_machine.get_current_state()

	if next_state == null or next_state == finished_segment:
		DebugState.debug_log("LevelManager: 关卡流程结束", "Level")
		_current_segment = null
		return

	_current_segment = next_state as LevelSegment
	DebugState.debug_log("LevelManager: 段完成 %s，推进到 %s" % [finished_segment.type, _current_segment.type], "Level")


# 环境接口：段自报完成时调用（段内连接自己的完成信号后触发）。
func mark_segment_finished() -> void:
	_segment_finished = true


# 连接玩家生命周期信号：死亡清屏由本管理器响应，Game Over 重载场景。
# 注：player.gd 未声明 class_name，故用无类型引用做鸭子类型访问（与 boss_base.get_player 风格一致）。
func _connect_player_signals() -> void:
	var player = get_node_or_null("Player")
	if player == null:
		DebugState.debug_log("LevelManager: 找不到 Player，跳过玩家生命周期接入", "Level")
		return

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if not player.game_over.is_connected(_on_player_game_over):
		player.game_over.connect(_on_player_game_over)


# 玩家死亡：清掉屏幕上的敌方子弹（保留玩家弹），重生安全交由 Player 状态机。
func _on_player_died(_lives_left: int) -> void:
	var layer := get_tree().get_first_node_in_group(BulletLayer.GROUP_NAME) as BulletLayer
	if layer == null:
		DebugState.debug_log("LevelManager: 找不到 bullet_layers，跳过死亡清屏", "Level")
		return

	layer.clear_enemy_bullets()
	DebugState.debug_log("LevelManager: 死亡清屏完成", "Level")


# 玩家残机耗尽：锁输入 + 重载当前场景（未来结算界面接入后改为切场景）。
func _on_player_game_over() -> void:
	DebugState.debug_log("LevelManager: Game Over，重载场景", "Level")

	var player = get_node_or_null("Player")
	if player != null:
		player.set_input_enabled(false)

	# game_over 信号在物理回调中发出（子弹命中玩家触发），场景切换必须推迟到物理步进结束后，
	# 否则 Godot 报 "Removing a CollisionObject node during a physics callback"。
	get_tree().call_deferred("reload_current_scene")


# 环境接口：段执行时注册 Boss，供转阶段消息转发使用。
func register_boss(boss_node: Boss, phase_message_ids: Dictionary) -> void:
	boss = boss_node
	_phase_message_ids = phase_message_ids
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.died.connect(_on_boss_died)
	# entrance_finished: 本次保留出口信号，接入真实解锁/演出留给演出 stage。


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
