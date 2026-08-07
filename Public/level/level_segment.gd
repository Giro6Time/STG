class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 按 type 分发消费；新段类型继承本类并自定义字段。
# 本类实现"段自驱动"契约：每个段类型实现 play(context)，由 LevelManager 统一消费，
# 装配器不再认识段的具体字段（见 LevelManager 头部技术债说明 / level_context.gd）。

@export var type: String = ""


## 段自驱动入口：LevelManager 顺序调用。context 由装配方注入行为端口。
## 基类空实现：继承段按需 override 并 await 自身播放完成。
func play(_context: LevelContext) -> void:
	pass
