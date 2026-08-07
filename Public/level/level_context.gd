class_name LevelContext
extends RefCounted

# 关卡执行上下文：LevelManager 在消费流程段前构造，把各段播放所需的"行为端口"注入给段。
# 段只依赖本上下文接口，不反向依赖 LevelManager 具体实现，从而"新增段类型不改装配器分发"。
# 遵循依赖倒置：Context 由装配方提供，段自驱动，装配方只 orchestrate。

## 消息控制器组首个实例（播放段内对话序列）。可为空，段需自行判空。
var message_controller: MessageController
## 无条件可用的播放/等待时钟（用于段内的延时编排）。
var clock: SceneTree
## 背景/场景切换意图出口。由 LevelManager 注入，段只声明意图，不关心视觉细节。
var request_scene_change: Callable
## 生成 Boss 责任端口：段内声明要生成的 Boss，由装配方决定如何实例化与连接。
var spawn_boss_segment: Callable


## 快捷：依序播放一段对话（controller 为空或 id 为空时安全跳过）。
func show_messages(msg_ids: Array[String]) -> void:
	for msg_id in msg_ids:
		if message_controller != null and not msg_id.is_empty():
			message_controller.show_by_id(msg_id)


## 等待消息流全部播完（用于段与段之间的自然节奏）。
func wait_for_messages_done() -> void:
	if message_controller == null:
		return
	while message_controller.is_busy():
		await clock.process_frame