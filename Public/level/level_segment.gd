class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 用 StateMachine 驱动。
# 段三维度：开始时机(start_delay) / 激活条件(await_signal) / 完成超时(completion.wait_time)。
# 段实现状态机钩子：enter_state(spawn+连完成信号) / update_state(每帧) / exit_state(清理)。
# 新增段类型 = 继承本类 + 实现三个钩子 + 声明自己的完成信号。

## 段类型标识（Inspector 直观区分，也用于日志与分发）。
@export var type: String = ""

## 相对"上一段完成后"延迟 N 秒才开始本段（0 = 立即）。
@export var start_delay: float = 0.0

## 激活条件：等某信号才触发本段（空字符串 = 不等待）。走 LevelManager._get_signal_holder 映射。
@export var await_signal: String = ""

## 完成超时选项：null = 无超时（依赖段完成信号）；非 null 时 wait_time 控制超时/-1 无限。
@export var completion: SegmentCompletion

# 段运行时状态（StateMachine 注入）
var _owner: Node
var _elapsed: float = 0.0


# StateMachine 钩子：进入段时调用（spawn 动作 + 连接完成信号）。
func enter_state(owner: Node) -> void:
	_owner = owner
	_elapsed = 0.0


# StateMachine 钩子：每帧调用（段内计时/生成逻辑）。
func update_state(delta: float) -> void:
	_elapsed += delta


# StateMachine 钩子：段结束或中断时调用（清理）。
func exit_state() -> void:
	pass
