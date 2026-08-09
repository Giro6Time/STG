class_name BossSegment
extends LevelSegment

# Boss 登场段：声明本段要实例化哪个 Boss、何时入场、可召唤的敌人与转阶段消息。
# 本段"段自驱动"：play(context) 仅声明意图，把 Boss 装配（实例化/连接信号）委派给装配方
# 提供的 spawn_boss_segment 端口，装配方保留场景知识与信号接线（见 LevelManager 头部技术债说明）。

@export var boss_scene: PackedScene
## 入场前等待。本次控制"何时把 Boss 加入场景树"（真实入场动画留给演出 stage）。
@export var entrance_delay: float = 0.0
## Boss 出生位置（屏幕坐标）。
@export var spawn_position: Vector2 = Vector2.ZERO
## 召唤敌人声明。本次只承载数据并提供能力接口，真正波次时机留到以后。
@export var summoned_enemy_scenes: Array[PackedScene] = []
## 转阶段消息映射：phase_id -> 消息 id（写入 messages_zh.json）。装配方在转阶段时触发。
@export var phase_message_ids: Dictionary = {}


# 自驱动播放：声明本段要生成 Boss，由装配方注入的端口决定如何实例化与接线。
func play(context: LevelContext) -> void:
	if context.spawn_boss_segment.is_valid():
		await context.spawn_boss_segment.call(self)
