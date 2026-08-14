extends CanvasLayer

# 分数 HUD：顶部居中显示当前总分，监听 ScoreManager.score_changed 刷新。
# 纯显示组件（单一职责）：不持有计分逻辑，ScoreManager 缺失时打日志跳过不崩。

@onready var score_label: Label = $Margin/VBox/ScoreLabel


func _ready() -> void:
	if ScoreManager == null:
		DebugState.debug_log("ScoreHUD: ScoreManager 未注册，跳过分数显示", "Score")
		return

	# 连接前先刷新一次初始值，避免开局显示残留文本。
	_on_score_changed(ScoreManager.get_score())
	ScoreManager.score_changed.connect(_on_score_changed)


func _on_score_changed(score: int) -> void:
	if score_label == null:
		return
	score_label.text = "SCORE %07d" % score
