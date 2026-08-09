class_name LevelDefinition
extends Resource

# 关卡全流程声明：一个有序的流程段列表。Boss/敌人/演出都作为"段"出现，可插花、可重复。
@export var segments: Array[LevelSegment] = []

## 胜利对话序列（storyboard Node06）。Boss died 后由 LevelManager 依序播放；可为空（跳过对话）。
@export var victory_message_ids: Array[String] = []
