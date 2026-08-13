class_name SegmentCompletion
extends Resource

# 关卡段的完成条件：字段按优先级链检查，首个非空条件生效（不是真 OR 竞态）。
# 全部为空时视为立即完成（等价于 completion 为 null 的非阻塞行为）。

## 等 N 秒后完成（0 = 不用时间条件）。
@export var wait_time: float = 0.0
## 等某信号后完成（如 "boss_died"）；空字符串 = 不用。
@export var await_signal: String = ""
## 等某 group 节点清空后完成（如 "enemies"）；空字符串 = 不用。
@export var wait_group_empty: String = ""
## 等 MessageController 消息流播完后完成。
@export var wait_messages_done: bool = false


# 判断是否存在任何有效完成条件。
func is_empty() -> bool:
	return wait_time <= 0.0 \
		and await_signal.is_empty() \
		and wait_group_empty.is_empty() \
		and not wait_messages_done
