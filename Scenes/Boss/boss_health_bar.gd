class_name BossHealthBar
extends CanvasLayer

# Boss 血条独立成 CanvasLayer，避免跟随 Boss 位置移动。
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var phase_label: Label = $MarginContainer/VBoxContainer/PhaseLabel


func setup(max_hp: int) -> void:
	# 初始化血条范围，Boss 生成时默认显示满血。
	progress_bar.min_value = 0.0
	progress_bar.max_value = float(max_hp)
	progress_bar.value = float(max_hp)


func set_hp(current_hp: int, max_hp: int) -> void:
	progress_bar.max_value = float(max_hp)
	progress_bar.value = float(current_hp)


func set_phase(current_phase: int) -> void:
	# 保留数字阶段接口，方便非 BossPhase 调用者继续使用。
	if current_phase <= 0:
		set_phase_label("Intro")
		return

	set_phase_label("Phase %d" % current_phase)


func set_phase_label(current_phase_label: String) -> void:
	if current_phase_label == "":
		return

	phase_label.text = current_phase_label
