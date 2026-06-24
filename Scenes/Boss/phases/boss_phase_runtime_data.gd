class_name BossPhaseRuntimeData
extends RefCounted

var boss: Boss
var delta: float = 0.0
var hp: int = 0
var max_hp: int = 0
var hp_ratio: float = 0.0
var phase_elapsed: float = 0.0
var player: Node2D


# 封装阶段本帧需要读取的 Boss、时间和血量比例数据。
func setup(source_boss: Boss, frame_delta: float, elapsed: float) -> void:
	boss = source_boss
	delta = frame_delta
	phase_elapsed = elapsed

	if boss == null:
		return

	hp = boss.get_hp()
	max_hp = boss.get_max_hp()
	if max_hp > 0:
		hp_ratio = float(hp) / float(max_hp)
	else:
		hp_ratio = 0.0

	player = boss.get_player()
