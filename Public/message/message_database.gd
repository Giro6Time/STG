class_name MessageDatabase
extends RefCounted

var _messages: Dictionary = {}


# 从 JSON 文件加载所有消息配置，失败时返回 false 并输出错误。
func load_from_json(json_path: String) -> bool:
	if not FileAccess.file_exists(json_path):
		push_error("Message JSON not found: %s" % json_path)
		return false

	var json_text: String = FileAccess.get_file_as_string(json_path)
	var parsed_data: Variant = JSON.parse_string(json_text)
	if not parsed_data is Dictionary:
		push_error("Message JSON root must be a dictionary: %s" % json_path)
		return false

	_messages.clear()
	var parsed_messages: Dictionary = parsed_data as Dictionary
	for message_id in parsed_messages.keys():
		var message_data: Variant = parsed_messages[message_id]
		if message_data is Dictionary:
			_messages[str(message_id)] = (message_data as Dictionary).duplicate(true)
		else:
			push_warning("Message data ignored because it is not a dictionary: %s" % str(message_id))

	return true


# 判断指定消息 id 是否已经加载，供业务逻辑提前检查。
func has_message(message_id: String) -> bool:
	return _messages.has(message_id)


# 按 id 返回消息数据副本，缺失时输出 warning 并返回空字典。
func get_message(message_id: String) -> Dictionary:
	if not has_message(message_id):
		push_warning("Message id not found: %s" % message_id)
		return {}

	return (_messages[message_id] as Dictionary).duplicate(true)
