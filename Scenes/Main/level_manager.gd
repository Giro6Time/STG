extends Node2D
class_name LevelManager

# 关卡装配器：读取 LevelDefinition，顺序消费流程段并实例化内容。
# LevelManager 只在"何时叫 Boss / 何时发消息"，Boss 只提供动作与信号，双方不互相持有 UI/背景/玩家引用。

@export var level_definition: LevelDefinition

## 当前 BossSegment 的转阶段消息映射（phase_id -> message_id），由当前段配置而来。
var _phase_message_ids: Dictionary = {}

var boss: Boss

# 完成信号接收标志：供 _completion_signal_waiter 轮询。
var _completion_signal_received: bool = false


# 按关卡配置异步装配：null 则警告并返回。
func _ready() -> void:
	_connect_player_signals()

	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_consume_segments()


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


# 按顺序消费每个流程段：等待激活 → 执行段动作 → 等待完成（非阻塞段立即推进）。
func _consume_segments() -> void:
	for segment in level_definition.segments:
		if segment == null:
			continue
		await _wait_for_activate(segment)
		await _run_segment(segment)
		await _wait_for_completion(segment)


# 按段类型分发执行动作；未知类型警告并跳过。
func _run_segment(segment: LevelSegment) -> void:
	if segment is BossSegment:
		await _spawn_boss(segment as BossSegment)
	elif segment is MinionWaveSegment:
		_spawn_wave(segment as MinionWaveSegment)
	else:
		DebugState.debug_log("LevelManager: 未知关卡段类型 '%s'，跳过" % segment.type, "Level")


# 等待段激活条件：start_delay 计时（相对上一段触发）后，等待 await_signal 信号。
# await_signal 为空则只等 start_delay。
func _wait_for_activate(segment: LevelSegment) -> void:
	if segment.start_delay > 0.0:
		await get_tree().create_timer(segment.start_delay).timeout

	if not segment.await_signal.is_empty():
		await _await_signal_once(segment.await_signal)


# 信号名 → 持有者节点映射。Resource 不持有场景对象，LevelManager 维护映射。
# 新增信号名 = 这里加一行。
func _get_signal_holder(signal_name: String) -> Node:
	match signal_name:
		"boss_died":
			return boss
		"boss_phase_changed":
			return boss
		_:
			return null


# 等待段完成：非阻塞（无有效 completion）立即返回；阻塞则按优先级链检查完成条件——
# 首个非空条件生效（wait_time → await_signal → wait_group_empty → wait_messages_done），
# 多条件同时设置时只取第一个，字段集是扩展点而非 OR 组合。
# 防死锁：wait_time 超时兜底，wait_group_empty / wait_messages_done 轮询带上限。
func _wait_for_completion(segment: LevelSegment) -> void:
	if segment.is_non_blocking():
		return

	var completion: SegmentCompletion = segment.completion

	if completion.wait_time > 0.0:
		await get_tree().create_timer(completion.wait_time).timeout
		return

	if not completion.await_signal.is_empty():
		await _await_signal_once(completion.await_signal)
		return

	if not completion.wait_group_empty.is_empty():
		await _await_group_empty(completion.wait_group_empty)
		return

	if completion.wait_messages_done:
		await _await_messages_done()
		return

	# completion 存在但全空：视为立即完成（防御）。
	DebugState.debug_log("LevelManager: 完成条件为空，立即推进", "Level")


# 等待某信号触发一次。信号名 → 实际信号通过 _get_signal_holder + match 解析。
func _await_signal_once(signal_name: String) -> void:
	var signal_holder: Node = _get_signal_holder(signal_name)
	if signal_holder == null:
		DebugState.debug_log(
			"LevelManager: 信号 '%s' 未注册，视为立即完成" % signal_name,
			"Level"
		)
		return

	_completion_signal_received = false
	match signal_name:
		"boss_died":
			if not signal_holder.died.is_connected(_on_completion_signal):
				signal_holder.died.connect(_on_completion_signal)
			await _completion_signal_waiter()
		"boss_phase_changed":
			if not signal_holder.phase_changed.is_connected(_on_completion_signal):
				signal_holder.phase_changed.connect(_on_completion_signal)
			await _completion_signal_waiter()
		_:
			DebugState.debug_log("LevelManager: 信号 '%s' 未处理" % signal_name, "Level")


# 轮询等待完成信号接收标志（信号回调置位）。
func _completion_signal_waiter() -> void:
	while not _completion_signal_received:
		await get_tree().process_frame


# 完成信号回调：设置接收标志。
func _on_completion_signal(_arg = null) -> void:
	_completion_signal_received = true


# 轮询等待某 group 清空；带上限（默认 60 秒）防死锁。
func _await_group_empty(group_name: String) -> void:
	var elapsed: float = 0.0
	while get_tree().get_nodes_in_group(group_name).size() > 0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if elapsed > 60.0:
			DebugState.debug_log(
				"LevelManager: 等待 group '%s' 清空超时，强制推进" % group_name,
				"Level"
			)
			return


# 轮询等待消息流播完（MessageController.is_busy）。
func _await_messages_done() -> void:
	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	if controller == null:
		DebugState.debug_log("LevelManager: 找不到 message_controllers，跳过消息等待", "Level")
		return

	var elapsed: float = 0.0
	while controller.is_busy():
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if elapsed > 60.0:
			DebugState.debug_log("LevelManager: 等待消息播完超时，强制推进", "Level")
			return


# 执行小怪波次：按间隔依次生成敌人。非阻塞（completion=null），触发即完成。
func _spawn_wave(segment: MinionWaveSegment) -> void:
	var scene: PackedScene = segment.get_enemy_scene()
	if scene == null:
		DebugState.debug_log("LevelManager: 波次 enemy_scene 为空，跳过", "Level")
		return

	var positions: Array[Vector2] = segment.get_spawn_positions()
	var count: int = segment.get_spawn_count()

	for index in range(count):
		if index > 0 and segment.get_spawn_interval() > 0.0:
			await get_tree().create_timer(segment.get_spawn_interval()).timeout

		var enemy_node: Node2D = scene.instantiate()
		if positions.size() > 0:
			enemy_node.position = positions[index % positions.size()]
		else:
			enemy_node.position = Vector2(
				randf_range(32.0, 608.0),
				-32.0
			)
		add_child(enemy_node)
		DebugState.debug_log("LevelManager: 波次生成敌人 %d/%d" % [index + 1, count], "Level")


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