class_name LevelDefinition
extends Resource

# 关卡全流程声明：一个有序的流程段列表。Boss/敌人/演出都作为"段"出现，可插花、可重复。
@export var segments: Array[LevelSegment] = []
