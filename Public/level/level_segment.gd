class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 按序消费，段通过 execute(context) 多态自执行。
# 段三维度：开始时机(start_delay) / 激活条件(await_signal) / 完成语义(completion)。
# 新增段类型 = 继承本类 + 实现 execute(context)，编排层零改动。

## 段类型标识（Inspector 直观区分，也用于日志与分发）。
@export var type: String = ""

## 相对"上一段触发"后延迟 N 秒才开始本段（0 = 立即）。
@export var start_delay: float = 0.0

## 激活条件：等某信号才触发本段（空字符串 = 不等待）。
## 与 completion.await_signal 的区别：这是"开始"条件，completion 里是"完成"条件。
@export var await_signal: String = ""

## 完成语义：null 或空 = 非阻塞（触发即完成，不等待）。
## 非空 = 阻塞，按优先级链首个非空条件生效（非真 OR 竞态）。
@export var completion: SegmentCompletion


# 判断本段是否为非阻塞（无有效完成条件即触发即完成）。
func is_non_blocking() -> bool:
	return completion == null or completion.is_empty()


# 执行本段的动作。子类必须实现；未实现 = 该段类型不可执行（警告跳过）。
# context 提供场景访问能力（Resource 不在场景树中，需要注入执行环境）。
func execute(context: LevelManager) -> void:
	DebugState.debug_log("LevelSegment: 类型 '%s' 未实现 execute()，跳过" % type, "Level")
