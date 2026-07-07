class_name AudioBgmTrack
extends Resource

@export var track_name: String = ""
@export var track_id: int = -1
@export var primary_stream: AudioStream
@export var layer_stream: AudioStream
@export var volume_db: float = 0.0
@export var layer_volume_db: float = 0.0
@export var bus: StringName = &"Master"
@export var loop: bool = true
@export var start_with_layer: bool = false


# BGM 至少需要主通道资源，第二通道可以按曲目需求留空。
func is_valid_track() -> bool:
	return track_name != "" and primary_stream != null


# 返回主通道音乐长度，供外部做时间轴或 UI 估算。
func get_length() -> float:
	if primary_stream == null:
		return 0.0

	return primary_stream.get_length()
