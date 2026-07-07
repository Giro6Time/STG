class_name AudioSfxEvent
extends Resource

enum SameEventPolicy {
	ALLOW_OVERLAP,
	INTERRUPT_PREVIOUS
}

@export var event_name: String = ""
@export var event_id: int = -1
@export var stream: AudioStream
@export var volume_db: float = 0.0
@export var pitch_scale: float = 1.0
@export var bus: StringName = &"Master"
@export var loop: bool = false
@export var use_2d_player: bool = true
@export var max_instances: int = 8
@export var same_event_policy: SameEventPolicy = SameEventPolicy.ALLOW_OVERLAP
@export var once_per_frame: bool = false


# 判断配置是否足够播放，避免运行时因为空资源中断玩法逻辑。
func is_valid_event() -> bool:
	return event_name != "" and stream != null
