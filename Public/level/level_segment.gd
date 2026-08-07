class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 按 type 分发消费；新段类型继承本类并自定义字段。
@export var type: String = ""
