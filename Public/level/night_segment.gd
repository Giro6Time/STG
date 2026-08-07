class_name NightSegment
extends LevelSegment

# 夜晚降临段：声明开场等待、对话序列、夜晚 BGM 与背景意图 key。
# 背景视觉本 stage 不实现，scene_ambience_key 仅作为接口参数发出（见 LevelManager）。
@export var wait_before_start: float = 0.0
@export var message_ids: Array[String] = []
@export var bgm_track: String = ""
@export var bgm_fade_in: float = 1.0
@export var bgm_fade_out: float = 1.0
@export var scene_ambience_key: String = "night_fall"