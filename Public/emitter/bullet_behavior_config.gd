class_name BulletBehaviorConfig
extends Resource

## 子弹行为配置：scene + motion 策略。

@export var bullet_scene: PackedScene
@export var motion: BulletMotion
@export var damage: int = 1
@export var bullet_lifetime: float = 6.0
