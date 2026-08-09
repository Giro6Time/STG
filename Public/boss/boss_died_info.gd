class_name BossDiedInfo
extends RefCounted

# 结构化死亡事件负载：Boss 死亡时随 died 信号传给关卡演出层（LevelManager）。
# Boss 只填结构体字段，LevelManager 只消费结构体，双方通过数据解耦，
# 从而不同 Boss 可产出不同的掉落/演出数据而不改演出消费方。

## 掉落生成世界坐标（取自 Boss 消散前位置）。
var drop_position: Vector2 = Vector2.ZERO
## 本次死亡是否生成了掉落物（供演出层决定是否播掉落相关演出/音效）。
var has_drops: bool = false