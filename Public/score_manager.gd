extends Node

# 全局分数账本（Autoload）：项目唯一分数来源。
# 职责：累加分数、清零、广播变化。评分规则（擦弹分/击破分常量）集中在本类，
# 计分来源只通过 add_score() 汇入，不直接持有任何场景节点引用（依赖倒置）。
# 数据流：GrazeContext.grazed → add_score → score_changed → ScoreHUD 刷新。

signal score_changed(score: int)

## 每次擦弹得分。
const SCORE_PER_GRAZE: int = 10
## Boss 击破固定得分。
const BOSS_DEFEAT_SCORE: int = 1000

var _score: int = 0


# Autoload 全部就绪后连接擦弹事件：GrazeContext 只做统计，加分规则由本类执行。
func _ready() -> void:
	if GrazeContext == null:
		return
	GrazeContext.grazed.connect(_on_graze)


# 计分统一入口：负分忽略（防御非法调用），加分后广播变化。
func add_score(amount: int) -> void:
	if amount <= 0:
		return
	_score += amount
	score_changed.emit(_score)


# 返回当前总分。
func get_score() -> int:
	return _score


# 清零总分并广播，供 Game Over 重开新一局或测试显式重置。
func reset() -> void:
	_score = 0
	score_changed.emit(_score)


# 擦弹事件汇入：按本帧擦弹次数计算得分。
func _on_graze(_total_graze: int, frame_graze_count: int) -> void:
	add_score(frame_graze_count * SCORE_PER_GRAZE)
