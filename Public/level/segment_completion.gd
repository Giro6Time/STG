class_name SegmentCompletion
extends Resource

# 关卡段的完成超时选项（段完成信号由段自己声明，这里只控制超时兜底）。
# > 0：超时兜底，N 秒后强制完成（即使段未自报）。
# -1：显式无限等待，只等段完成信号。
# 0：未配置（依赖段完成信号，等效无限等但语义模糊，建议用 -1 显式声明）。

@export var wait_time: float = 0.0
