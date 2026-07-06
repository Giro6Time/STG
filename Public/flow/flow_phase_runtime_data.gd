class_name FlowPhaseRuntimeData
extends RefCounted

var pattern_owner: Node
var delta: float = 0.0
var hp: int = 0
var max_hp: int = 0
var hp_ratio: float = 0.0
var phase_elapsed: float = 0.0
var player: Node2D


# 封装阶段本帧需要读取的宿主、时间和可选战斗数据。
func setup(source_owner: Node, frame_delta: float, elapsed: float) -> void:
	pattern_owner = source_owner
	delta = frame_delta
	phase_elapsed = elapsed
	_update_boss_runtime_data(source_owner as Boss)


# 当宿主是 Boss 时补充血量和玩家引用；其他宿主保持默认值。
func _update_boss_runtime_data(boss: Boss) -> void:
	if boss == null:
		return

	hp = boss.get_hp()
	max_hp = boss.get_max_hp()
	if max_hp > 0:
		hp_ratio = float(hp) / float(max_hp)
	else:
		hp_ratio = 0.0

	player = boss.get_player()
