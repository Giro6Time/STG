class_name MessageController
extends Node

@export var messages_json_path: String = "res://data/messages/messages_zh.json"
@export var message_box_path: NodePath = NodePath("../MessageBox")

var database: MessageDatabase = MessageDatabase.new()
var _message_box: MessageBox
var _queue: Array[Dictionary] = []


# 初始化消息数据库和消息框引用，MessageLayer 放入场景后会自动加载默认 JSON。
func _ready() -> void:
	_message_box = get_node_or_null(message_box_path) as MessageBox
	if _message_box == null:
		push_warning("MessageBox not found: %s" % str(message_box_path))
	else:
		var callback: Callable = Callable(self, "_on_message_box_finished")
		if not _message_box.message_finished.is_connected(callback):
			_message_box.message_finished.connect(callback)

	database.load_from_json(messages_json_path)


# 按消息 id 显示消息，找不到时只输出 warning。
func show_by_id(message_id: String) -> void:
	if not database.has_message(message_id):
		push_warning("Message id not found: %s" % message_id)
		return

	show_message_data(database.get_message(message_id))


# 直接显示一条消息数据，并按 interrupt_policy 管理队列和打断。
func show_message_data(message_data: Dictionary) -> void:
	if _message_box == null:
		push_warning("MessageBox is missing, cannot show message")
		return

	var interrupt_policy: String = str(message_data.get("interrupt_policy", "queue")).to_lower()
	if not _message_box.is_busy():
		_message_box.show_message(message_data)
		return

	if interrupt_policy == "queue":
		_queue.append(message_data.duplicate(true))
	elif interrupt_policy == "interrupt":
		_message_box.interrupt_and_show(message_data)
	elif interrupt_policy == "ignore":
		return
	else:
		push_warning("Unknown interrupt_policy, fallback to queue: %s" % interrupt_policy)
		_queue.append(message_data.duplicate(true))


# 清空等待显示的消息队列，不影响当前正在显示的消息。
func clear_queue() -> void:
	_queue.clear()


# 隐藏当前消息并尝试显示队列中的下一条。
func hide_current() -> void:
	if _message_box != null:
		_message_box.hide_message()
	_show_next_queued_message()


# 当前消息自然完成后继续显示队列中的下一条消息。
func _on_message_box_finished() -> void:
	_show_next_queued_message()


# 如果队列中还有消息，则按先进先出的顺序显示下一条。
func _show_next_queued_message() -> void:
	if _message_box == null or _message_box.is_busy():
		return
	if _queue.is_empty():
		return

	var next_message: Dictionary = _queue.pop_front()
	_message_box.show_message(next_message)
