class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 用 StateMachine 驱动。
# 段维度：开始时机(start_delay) / 完成超时(completion.wait_time)。
# start_delay 语义：段被确认进入（start）后延迟 N 秒才开始真正执行（演出/就位等待）。
# 段实现状态机钩子：enter_state(spawn+连完成信号) / update_state(每帧) / exit_state(清理)。
# 新增段类型 = 继承本类 + 实现三个钩子 + 声明自己的完成信号。

## 段类型标识（Inspector 直观区分，也用于日志与分发）。
@export var type: String = ""

## 进入后延迟：段被 start 后等 N 秒才开始实际执行（0 = 立即执行）。
@export var start_delay: float = 0.0

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


# 进入后延迟是否已过（start_delay 语义：确认进入后等 N 秒才开始执行）。
# 子类 update_state 里先 super.update_state(delta) 再判断此方法，延迟未过则直接 return。
func is_delay_elapsed() -> bool:
	return _elapsed >= start_delay


# 抢占判断（占位）：是否应打断当前运行段立刻进入本段。默认 false = 不抢占。
# 将来某段覆写它（如血量阈值/成就达成时立刻插入），LevelManager 每帧询问所有段。
func should_preempt() -> bool:
	return false
