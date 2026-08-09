extends Node2D
class_name LevelManager

# 关卡装配器：读取 LevelDefinition，构造执行上下文，顺序消费流程段并实例化内容。
# LevelManager 只是"装配/编排器"：把增删场景/生命周期的动作交给段与 Boss，自己不认识段的具体字段。
# 段通过 LevelContext 自驱动（见 LevelSegment.play / level_context.gd），达成开闭原则：
# 新增段类型不需要改本文件的分发逻辑。Boss 装配仍保留在 Manager（场景知识 + 信号接线）。

# 背景/场景切换意图接口出口：本 stage 不建视觉层，仅日志占位，待美术确认交互方式后接入。
signal scene_change_requested(scene_key: String, params: Dictionary)

@export var level_definition: LevelDefinition

## 当前 BossSegment 的转阶段消息映射（phase_id -> message_id），由当前段配置而来。
var _phase_message_ids: Dictionary = {}

var boss: Boss

# 演出用音频轨道（现有完整版 BGM + 测试 SFX；后期替换为正式资源后仅改此处）。
const BGM_TRACKS: Array[AudioBgmTrack] = [
	preload("res://data/audio/test/test_boss_intro.tres"),
	preload("res://data/audio/test/test_boss.tres"),
]
const SFX_EVENTS: Array[AudioSfxEvent] = [
	preload("res://data/audio/test/test_hit.tres"),
]


# 按组装 context 后顺序消费流程段；null 则警告并返回。
func _ready() -> void:
	_ensure_audio_config()

	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	var context := _build_context()
	for segment in level_definition.segments:
		await segment.play(context)


# 构造本关卡的执行上下文：注入消息控制器、时钟与行为端口。
func _build_context() -> LevelContext:
	var context := LevelContext.new()
	context.clock = get_tree()
	context.message_controller = get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	context.request_scene_change = _request_scene_change
	context.spawn_boss_segment = _spawn_boss_segment
	return context


# Autoload 的 audio_manager.tscn 未预置轨道，运行时注入测试资源（与测试场景同模式）。
func _ensure_audio_config() -> void:
	if AudioManager.bgm_tracks.is_empty():
		AudioManager.bgm_tracks = BGM_TRACKS
	if AudioManager.sfx_events.is_empty():
		AudioManager.sfx_events = SFX_EVENTS
	AudioManager.rebuild_config_index()


# Boss 登场装配端口（供 BossSegment.play 委派）：等待 → 实例化 Boss → 注入 → 锁输入 → 连信号。
func _spawn_boss_segment(segment: BossSegment) -> void:
	if segment.boss_scene == null:
		DebugState.debug_log("LevelManager: boss_scene 为空，跳过本段", "Level")
		return

	await get_tree().create_timer(segment.entrance_delay).timeout

	_set_player_input_enabled(false)

	var boss_node: Node = segment.boss_scene.instantiate()
	boss_node.position = segment.spawn_position
	add_child(boss_node)

	if boss_node is Boss:
		boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(segment.summoned_enemy_scenes)
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.external_event_requested.connect(_on_boss_external_event)
		boss.died.connect(_on_boss_died)
		AudioManager.play_bgm("test_boss", 1.0, 0.5)

	# 记录本段的转阶段消息映射，供 phase_changed 时查询。
	_phase_message_ids = segment.phase_message_ids

	DebugState.debug_log("LevelManager: 已实例化 Boss，输入已锁定", "Level")


# Boss 转阶段：Phase1（Intro 结束进入正式战斗）解锁玩家输入；
# 若该阶段在 BossSegment 配置了消息，则通过 发到消息器发送。
func _on_boss_phase_changed(phase_id: int) -> void:
	if phase_id == 1:
		_set_player_input_enabled(true)
		DebugState.debug_log("LevelManager: Boss 入场完成，输入解锁", "Level")

	var msg_id: String = str(_phase_message_ids.get(phase_id, ""))
	if msg_id.is_empty():
		return

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	if controller == null:
		DebugState.debug_log("LevelManager: 找不到 message_controllers，跳过消息 %s" % msg_id, "Level")
		return

	controller.show_by_id(msg_id)


# Boss 转段/演出外部事件分发：数据在 Boss 场景的 Pattern 配置，LevelManager 按事件名响应。
func _on_boss_external_event(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"phase_transition_performance":
			_play_phase_transition(payload)
		_:
			DebugState.debug_log("LevelManager: 未识别外部事件 %s" % event_name, "Level")


# 转段演出（storyboard Node05）：对话 + 音乐下一层 + 背景意图（日志占位）。
func _play_phase_transition(_payload: Dictionary) -> void:
	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	for msg_id in ["transition_01", "transition_02", "transition_03"]:
		if controller != null:
			controller.show_by_id(msg_id)

	AudioManager.set_bgm_layer_enabled(true, 0.8)
	_request_scene_change("phase_transition", {"source": "boss_external_event"})
	DebugState.debug_log("LevelManager: 转段演出已触发", "Level")


# 胜利演出（storyboard Node06）：清屏 → 暂停输入 → stinger → 场景通知 → 胜利对话 → flag 日志。
# 掉落物已由 Boss.die 消散动画后自行生成（_spawn_drops），本层只消费死亡事件，不再负责造掉落。
func _on_boss_died(death_info: BossDiedInfo) -> void:
	DebugState.debug_log("LevelManager: Boss 死亡，进入胜利流程", "Level")

	# 先清屏再锁输入：Boss 死亡瞬间的残留敌弹若不清理，会在玩家失去操控后被补刀击杀。
	_clear_enemy_bullets()
	_set_player_input_enabled(false)
	AudioManager.play_sfx_id(2)  # test_hit 占位 Victory stinger
	_request_scene_change("victory_clear", {"source": "boss_died"})

	# 根据死亡信息做演出分支：若 Boss 掉落了物品，可播掉落演出/音效（本 stage 仅日志占位）。
	if death_info != null and death_info.has_drops:
		DebugState.debug_log(
			"LevelManager: Boss 掉落物已生成于 %s（演出占位）" % death_info.drop_position,
			"Level"
		)

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	for msg_id in level_definition.victory_message_ids:
		if controller != null:
			controller.show_by_id(msg_id)

	# boss_flag 更新占位：无持久化系统，仅日志。
	DebugState.debug_log("LevelManager: boss_flag 更新占位（后续接入存档）", "Level")


# 清屏：仅回收敌方子弹（保留玩家弹）。Boss 死亡瞬间调用，防止残留敌弹补刀玩家。
# 敌人/召唤物实体（非子弹）的清屏留后续：Enemy 有独立生命周期与场景容器，不归宿 BulletLayer。
func _clear_enemy_bullets() -> void:
	var layer := get_tree().get_first_node_in_group(BulletLayer.GROUP_NAME) as BulletLayer
	if layer == null:
		DebugState.debug_log("LevelManager: 找不到 bullet_layers，敌弹清屏跳过", "Level")
		return
	layer.clear_enemy_bullets()


# 统一玩家输入开关；找不到 Player 时仅日志（不崩溃）。
func _set_player_input_enabled(enabled: bool) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node
	if player == null:
		DebugState.debug_log("LevelManager: 找不到 Player，输入锁定跳过", "Level")
		return
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(enabled)


# 背景/场景切换意图接口出口：本 stage 仅日志，视觉待美术确认后接入。
func _request_scene_change(scene_key: String, params: Dictionary) -> void:
	scene_change_requested.emit(scene_key, params)
	DebugState.debug_log("LevelManager: 背景意图 %s（视觉待接入）" % scene_key, "Level")