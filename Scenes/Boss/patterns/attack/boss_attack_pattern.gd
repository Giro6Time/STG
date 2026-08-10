class_name BossAttackPattern
extends FlowPattern

## 泛"Boss 攻击行为"抽象：Boss 在当前阶段可能的一种行为。
## 弹幕是攻击的一种（BossBulletPattern 继承本类），冲撞/召唤等也是。
## 本类只放通用骨架与宿主访问，不放任何弹幕专用字段。

## 启动攻击 Pattern。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	if _is_running:
		DebugState.debug_log("Boss attack start: %s" % get_pattern_label(), "Boss")


## 停止攻击 Pattern。
func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss attack stop: %s" % get_pattern_label(), "Boss")
	super.stop_pattern()
