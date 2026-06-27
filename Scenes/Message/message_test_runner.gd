extends Node

@export var controller_path: NodePath = NodePath("../MessageLayer/MessageController")


# 启动后按固定节奏触发三条示例消息，方便快速验证消息框系统。
func _ready() -> void:
	call_deferred("_run_test_sequence")
 

# 依次触发登场、阶段变化和击败提示。
func _run_test_sequence() -> void:
	var controller: MessageController = get_node_or_null(controller_path) as MessageController
	if controller == null:
		push_warning("MessageController not found for message test")
		return

	controller.show_by_id("eye_intro_warning")
	await get_tree().create_timer(2.0).timeout
	controller.show_by_id("eye_phase_2")
	await get_tree().create_timer(2.0).timeout
	controller.show_by_id("eye_defeated")
