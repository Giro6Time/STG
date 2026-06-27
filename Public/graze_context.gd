extends Node

signal grazed(total_graze: int, frame_graze_count: int, added_score: int)

@export var score_per_graze: int = 10

var total_graze: int = 0
var graze_score: int = 0

var _pending_grazes: Array[Dictionary] = []


# 接收擦弹请求并暂存到本帧队列，实际计分统一在 _process 中结算。
func request_graze(bullet: Node, position: Vector2) -> void:
	if bullet == null:
		return

	_pending_grazes.append({
		"bullet": bullet,
		"position": position
	})


# 每帧集中结算擦弹，避免同一帧大量子弹分别刷新 UI 或重复广播。
func _process(_delta: float) -> void:
	_settle_pending_grazes()


# 清空累计数据，后续重开关卡或测试时可以显式调用。
func reset() -> void:
	total_graze = 0
	graze_score = 0
	_pending_grazes.clear()


# 结算本帧全部擦弹并发出一次汇总信号。
func _settle_pending_grazes() -> void:
	var frame_graze_count: int = _pending_grazes.size()
	if frame_graze_count <= 0:
		return

	var feedback_position: Vector2 = _get_feedback_position()
	_pending_grazes.clear()

	var added_score: int = frame_graze_count * score_per_graze
	total_graze += frame_graze_count
	graze_score += added_score

	play_graze_feedback(feedback_position)
	DebugState.debug_log("Graze +%d total %d score %d" % [frame_graze_count, total_graze, graze_score], "Graze")
	grazed.emit(total_graze, frame_graze_count, added_score)


# 计算本帧擦弹反馈位置，当前只取平均点以保留后续特效入口。
func _get_feedback_position() -> Vector2:
	var total_position: Vector2 = Vector2.ZERO
	for index in range(_pending_grazes.size()):
		total_position += _pending_grazes[index].get("position", Vector2.ZERO)

	if _pending_grazes.is_empty():
		return Vector2.ZERO

	return total_position / float(_pending_grazes.size())


# 预留轻量反馈钩子，后续可以接音效、粒子或资源奖励。
func play_graze_feedback(_position: Vector2) -> void:
	pass
