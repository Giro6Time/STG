class_name MessageBox
extends Control

signal message_finished

const STATE_IDLE: int = 0
const STATE_TYPING: int = 1
const STATE_PAUSE: int = 2
const STATE_HOLD: int = 3

const NAMED_COLORS: Dictionary = {
	"red": "#ff5555",
	"green": "#55ff88",
	"blue": "#66aaff",
	"yellow": "#ffe066",
	"cyan": "#66ffff",
	"magenta": "#ff66ff",
	"orange": "#ffaa44",
	"purple": "#bb88ff",
	"white": "#ffffff",
	"black": "#000000"
}

@export var panel: PanelContainer
@export var speaker_label: Label
@export var content_label: RichTextLabel

var _state: int = STATE_IDLE
var _segments: Array[Dictionary] = []
var _visible_runs: Array[Dictionary] = []
var _segment_index: int = 0
var _segment_char_index: int = 0
var _char_progress: float = 0.0
var _pause_timer: float = 0.0
var _hold_timer: float = 0.0
var _duration: float = 3.0
var _busy: bool = false


# 初始化时隐藏消息框，等待 MessageController 主动显示。
func _ready() -> void:
	if panel == null:
		push_warning("Panel not assigned in MessageBox")
	if speaker_label == null:
		push_warning("Speaker label not assigned in MessageBox")
	if content_label == null:
		push_warning("Content label not assigned in MessageBox")
	hide_message()


# 根据当前状态推进打字机、暂停和停留计时。
func _process(delta: float) -> void:
	if not _busy:
		return

	if _state == STATE_TYPING:
		_process_typing(delta)
	elif _state == STATE_PAUSE:
		_process_pause(delta)
	elif _state == STATE_HOLD:
		_process_hold(delta)


# 显示一条消息，按配置决定是否启用打字机。
func show_message(message_data: Dictionary) -> void:
	_prepare_message(message_data)


# 立即打断当前消息并显示新消息。
func interrupt_and_show(message_data: Dictionary) -> void:
	hide_message()
	_prepare_message(message_data)


# 立即完成当前文本显示，但仍保留 duration 的自动隐藏逻辑。
func finish_current_text_immediately() -> void:
	if not _busy:
		return

	_visible_runs = _collect_text_runs(_segments)
	_refresh_content_label()
	_start_hold()


# 隐藏消息框并重置当前播放状态。
func hide_message() -> void:
	visible = false
	_busy = false
	_state = STATE_IDLE
	_segments.clear()
	_visible_runs.clear()
	_segment_index = 0
	_segment_char_index = 0
	_char_progress = 0.0
	_pause_timer = 0.0
	_hold_timer = 0.0
	if is_node_ready():
		if speaker_label != null:
			speaker_label.text = ""
		if content_label != null:
			content_label.clear()


# 返回当前消息框是否正在显示或等待隐藏。
func is_busy() -> bool:
	return _busy


# 读取消息字典并初始化显示控件。
func _prepare_message(message_data: Dictionary) -> void:
	if speaker_label == null or content_label == null:
		push_warning("MessageBox labels are not assigned")
		return

	var speaker: String = str(message_data.get("speaker", ""))
	var text: String = str(message_data.get("text", ""))
	_duration = float(message_data.get("duration", 3.0))
	var base_speed: float = float(message_data.get("chars_per_second", 24))
	var use_typewriter: bool = bool(message_data.get("typewriter", true))

	visible = true
	_busy = true
	_state = STATE_TYPING
	_segments = _parse_text_segments(text, base_speed)
	_visible_runs.clear()
	_segment_index = 0
	_segment_char_index = 0
	_char_progress = 0.0
	_pause_timer = 0.0
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	content_label.clear()

	if not use_typewriter:
		finish_current_text_immediately()


# 推进普通文本 segment 的逐字显示，遇到 pause segment 时切换状态。
func _process_typing(delta: float) -> void:
	if _segment_index >= _segments.size():
		_start_hold()
		return

	var segment: Dictionary = _segments[_segment_index]
	var segment_type: String = str(segment.get("type", "text"))
	if segment_type == "pause":
		_pause_timer = max(float(segment.get("duration", 0.0)), 0.0)
		_segment_index += 1
		_state = STATE_PAUSE
		return

	var segment_text: String = str(segment.get("text", ""))
	var speed: float = max(float(segment.get("speed", 24.0)), 1.0)
	var color_text: String = str(segment.get("color", ""))
	_char_progress += delta * speed
	var chars_to_add: int = int(_char_progress)
	if chars_to_add <= 0:
		return

	_char_progress -= float(chars_to_add)
	while chars_to_add > 0 and _segment_char_index < segment_text.length():
		_append_visible_character(segment_text.substr(_segment_char_index, 1), color_text)
		_segment_char_index += 1
		chars_to_add -= 1

	_refresh_content_label()
	if _segment_char_index >= segment_text.length():
		_segment_index += 1
		_segment_char_index = 0
		_char_progress = 0.0


# 推进文本中的 pause 控制标记。
func _process_pause(delta: float) -> void:
	_pause_timer -= delta
	if _pause_timer <= 0.0:
		_state = STATE_TYPING


# 推进完整显示后的停留时间，结束后自动隐藏并广播完成信号。
func _process_hold(delta: float) -> void:
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		hide_message()
		message_finished.emit()


# 进入完整显示后的停留阶段。
func _start_hold() -> void:
	_state = STATE_HOLD
	_hold_timer = max(_duration, 0.0)
	if _hold_timer <= 0.0:
		hide_message()
		message_finished.emit()


# 将带控制标记的文本解析为文本、暂停、速度和颜色 segment。
func _parse_text_segments(raw_text: String, chars_per_second: float) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var normal_speed: float = max(chars_per_second, 1.0)
	var speed_stack: Array[float] = [normal_speed]
	var color_stack: Array[String] = [""]
	var current_speed: float = normal_speed
	var current_color: String = ""
	var buffer: String = ""
	var index: int = 0

	while index < raw_text.length():
		var current_char: String = raw_text.substr(index, 1)
		if current_char == "[":
			var close_index: int = raw_text.find("]", index)
			if close_index >= 0:
				var tag: String = raw_text.substr(index + 1, close_index - index - 1).strip_edges().to_lower()
				var handled: bool = false
				if _is_supported_control_tag(tag):
					if buffer != "":
						_append_text_segment(segments, buffer, current_speed, current_color)
						buffer = ""
					handled = _apply_control_tag(segments, speed_stack, color_stack, tag, normal_speed)
					current_speed = speed_stack[speed_stack.size() - 1]
					current_color = color_stack[color_stack.size() - 1]
				if handled:
					index = close_index + 1
					continue

		buffer += current_char
		index += 1

	if buffer != "":
		_append_text_segment(segments, buffer, current_speed, current_color)

	return segments


# 判断标签是否属于消息框支持的控制语法。
func _is_supported_control_tag(tag: String) -> bool:
	return tag == "slow" \
		or tag == "fast" \
		or tag == "/slow" \
		or tag == "/fast" \
		or tag == "/color" \
		or tag.begins_with("pause=") \
		or tag.begins_with("color=")


# 根据解析到的控制标记更新速度栈、颜色栈或插入暂停片段。
func _apply_control_tag(
	segments: Array[Dictionary],
	speed_stack: Array[float],
	color_stack: Array[String],
	tag: String,
	normal_speed: float
) -> bool:
	if tag == "slow":
		speed_stack.append(normal_speed * 0.5)
		return true
	if tag == "fast":
		speed_stack.append(normal_speed * 2.0)
		return true
	if tag == "/slow" or tag == "/fast":
		if speed_stack.size() > 1:
			speed_stack.pop_back()
		return true
	if tag == "/color":
		if color_stack.size() > 1:
			color_stack.pop_back()
		return true
	if tag.begins_with("pause="):
		var value_text: String = tag.substr("pause=".length())
		if not value_text.is_valid_float():
			return false
		segments.append({
			"type": "pause",
			"duration": max(value_text.to_float(), 0.0)
		})
		return true
	if tag.begins_with("color="):
		var color_text: String = _normalize_color_text(tag.substr("color=".length()))
		if color_text == "":
			return false
		color_stack.append(color_text)
		return true

	return false


# 将颜色标签参数规整为 RichTextLabel 可用的 HTML 颜色。
func _normalize_color_text(raw_color: String) -> String:
	var color_text: String = raw_color.strip_edges().to_lower()
	if NAMED_COLORS.has(color_text):
		return str(NAMED_COLORS[color_text])
	if _is_valid_hex_color(color_text):
		return color_text
	return ""


# 检查 #rgb、#rrggbb 或 #rrggbbaa 形式的颜色值。
func _is_valid_hex_color(color_text: String) -> bool:
	if not color_text.begins_with("#"):
		return false
	var length: int = color_text.length()
	if length != 4 and length != 7 and length != 9:
		return false
	for index in range(1, length):
		var code: int = color_text.unicode_at(index)
		var is_digit: bool = code >= 48 and code <= 57
		var is_lower_hex: bool = code >= 97 and code <= 102
		if not is_digit and not is_lower_hex:
			return false
	return true


# 添加普通文本片段，空文本会被忽略。
func _append_text_segment(segments: Array[Dictionary], text: String, speed: float, color_text: String) -> void:
	if text == "":
		return

	segments.append({
		"type": "text",
		"text": text,
		"speed": speed,
		"color": color_text
	})


# 记录一个已经显示出来的字符，并与相同颜色的前一段合并。
func _append_visible_character(character: String, color_text: String) -> void:
	if _visible_runs.is_empty():
		_visible_runs.append({
			"text": character,
			"color": color_text
		})
		return

	var last_run: Dictionary = _visible_runs[_visible_runs.size() - 1]
	if str(last_run.get("color", "")) == color_text:
		last_run["text"] = str(last_run.get("text", "")) + character
	else:
		_visible_runs.append({
			"text": character,
			"color": color_text
		})


# 按颜色 run 重绘 RichTextLabel，避免控制标记显示到 UI。
func _refresh_content_label() -> void:
	if content_label == null:
		return

	content_label.clear()
	for index in range(_visible_runs.size()):
		var run: Dictionary = _visible_runs[index]
		var color_text: String = str(run.get("color", ""))
		if color_text != "":
			content_label.push_color(Color.html(color_text))
		content_label.add_text(str(run.get("text", "")))
		if color_text != "":
			content_label.pop()


# 收集所有文本 segment 的颜色 run，用于跳过打字机时显示完整文本。
func _collect_text_runs(segments: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		if str(segment.get("type", "text")) == "text":
			var text: String = str(segment.get("text", ""))
			var color_text: String = str(segment.get("color", ""))
			if text != "":
				result.append({
					"text": text,
					"color": color_text
				})
	return result


# 收集所有文本 segment 的纯文本，供测试或未来非富文本场景使用。
func _collect_plain_text(segments: Array[Dictionary]) -> String:
	var result: String = ""
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		if str(segment.get("type", "text")) == "text":
			result += str(segment.get("text", ""))
	return result
