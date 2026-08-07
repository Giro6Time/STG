class_name NightSegment
extends LevelSegment

# 夜晚降临段：声明开场等待、对话序列、夜晚 BGM 与背景意图 key。
# 背景视觉本 stage 不实现，scene_ambience_key 仅作为接口参数发出。
# 本段"段自驱动"：play(context) 自带时序，LevelManager 只负责消费段（见 LevelManager 头部技术债说明）。

@export var wait_before_start: float = 0.0
@export var message_ids: Array[String] = []
@export var bgm_track: String = ""
@export var bgm_fade_in: float = 1.0
@export var bgm_fade_out: float = 1.0
@export var scene_ambience_key: String = "night_fall"


# 自驱动播放：等待 → 依序播放开场对话 → 切 BGM → 发背景意图 → 等对话队列播完。
func play(context: LevelContext) -> void:
	if wait_before_start > 0.0:
		await context.clock.create_timer(wait_before_start).timeout

	context.show_messages(message_ids)

	if not bgm_track.is_empty():
		AudioManager.play_bgm(bgm_track, bgm_fade_in, bgm_fade_out)

	if context.request_scene_change.is_valid():
		context.request_scene_change.call(scene_ambience_key, {"source": "night_segment"})

	await context.wait_for_messages_done()
	DebugState.debug_log("LevelManager: 夜晚段完成", "Level")