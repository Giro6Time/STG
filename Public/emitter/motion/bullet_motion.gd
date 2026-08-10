class_name BulletMotion
extends Resource

## 子弹运动策略基类：定义"子弹发射后如何移动"。
## BulletBase 只持有 motion 引用并委托 process()，自身不保留运动学字段。
## 新增运动方式 = 新建子类。

func setup(_bullet: BulletBase, _init_data: Dictionary = {}) -> void:
	pass

func process(_bullet: BulletBase, _delta: float) -> void:
	pass
