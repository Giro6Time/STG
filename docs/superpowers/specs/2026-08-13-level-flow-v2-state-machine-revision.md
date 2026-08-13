---

# Level Flow v2 状态机驱动修订（State Machine Revision）

> 背景：现有 LevelManager 用 await 协程推进段（`_wait_for_activate` → `_run_segment` → `_wait_for_completion`）。
> 问题：① await 隐式挂起导致控制流不可中断、不可暂停、难调试；② 项目并存两套推进范式
> （Boss 用 FlowPhaseMachine 每帧 update 驱动，关卡段用 await 协程）。
> 本次修订：统一为 StateMachine 每帧驱动——LevelManager 用底层 `StateMachine` 驱动段，
> 段实现状态机钩子，完成条件改为段自报（`segment_finished` flag）。

## 目标

1. LevelManager 去 await，改为 `_process` 每帧 step 当前段（显式控制流、可中断、可调试）。
2. 复用底层 `StateMachine`（方案 A：泛化接受 RefCounted 状态），Boss 体系与关卡段体系共用同一状态机核心。
3. 完成条件语义归位：段自己声明结束（`segment_finished` flag），LevelManager 只做编排。
4. 保留段数据驱动（Resource）与段自执行（execute → enter_state）的方向。

## 已确认决策

1. **StateMachine 泛化**（方案 A）：
   - `setup(states)` 去掉 `as Node` cast（状态可为 Resource）
   - `_current_state` 类型 Node → Object
   - `state_changed` 信号参数 Node → Object
   - FlowPhaseMachine（Boss）零影响（FlowPhase 是 Node 满足 Object；回调参数类型顺手对齐）
2. **段状态钩子**：`enter_state(owner: Node)` / `update_state(delta: float)` / `exit_state()`
   - `enter_state` 等价于原 `execute(context)`：spawn 动作 + 连接自己的完成信号
   - `update_state` 每帧被 StateMachine.update 调用（段内计时/生成逻辑）
   - `exit_state` 段结束或中断时调用
3. **`SegmentCompletion` 只保留 `wait_time`**：
   - `> 0`：超时兜底（N 秒后强制完成）
   - `-1`：显式无限等待（只等段完成信号，无超时）
   - `0`：未配置（依赖段完成信号）
   - 删除 `await_signal` / `wait_group_empty` / `wait_messages_done`；删除 `is_empty()` / `is_non_blocking()`（所有段完成都靠 mark，completion 只是超时选项）
4. **`segment_finished` flag**：
   - LevelManager 持有 `_segment_finished`，每段进入时重置 false
   - 段通过 `context.mark_segment_finished()` 置 true
   - 完成判定 = `_segment_finished` 或 wait_time 超时（`> 0` 时）
   - 只重置 segment_finished；其他 flag（跨关保持的）不自动重置
5. **完成条件段内自决**（不再靠 completion 通用字段）：
   - BossSegment：enter_state 里连接 `boss.died` → `mark_segment_finished()`
   - MinionWaveSegment：跟踪本波敌人 `died` 信号，全部死亡 → `mark_segment_finished()`
   - 未来对话段：自己等 MessageController 播完 → mark
6. **波次重叠语义**（靠超时兜底，不改语义）：
   - `wait_time > 0`：怪没死完但超时 → 强制完成 → 下一波进场 → 重叠
   - `wait_time = -1`：无限等怪死完 → 不重叠（清场间隙）
7. **激活条件保留**：`start_delay`（相对上一段完成后计时）+ `await_signal`（等信号才开始，走 `_get_signal_holder` 映射）
8. **跳过条件不实现**（留扩展：未来激活条件加 `required_flag`）；信号配置化（Listener Resource）搁置——段内代码写死连接自己的完成信号
9. **BossSegment.entrance_delay 保留**：`update_state` 计时（`_elapsed >= entrance_delay` 后 spawn），替代 await 计时
10. **LevelManager 去 await**：`_process` 每帧 step；删 `_wait_for_activate` / `_wait_for_completion` / `_await_signal_once` / `_completion_signal_waiter` 等协程编排方法（改为每帧检查）

## 架构

```
StateMachine（泛化，RefCounted）
├── setup(owner, states)      # states 可为 Resource
├── start / update / transition_to / transition_to_next
├── enter_state(owner) / exit_state()  # 状态钩子
└── _current_state: Object

LevelSegment (Resource) —— 实现状态机钩子
├── enter_state(owner): spawn + 连接完成信号
├── update_state(delta): 每帧逻辑（计时/生成）
└── exit_state(): 清理

LevelManager (Node2D) —— 编排器
├── _segment_machine: StateMachine
├── _process(delta):
│   ├── 激活阶段: start_delay 计时 + await_signal 检查
│   └── 运行阶段: _segment_machine.update(delta)
│       ├── _segment_finished or wait_time 超时 → transition_to_next()
├── mark_segment_finished(): 段完成 flag 置位
├── register_boss(node, phase_message_ids): 环境接口
└── 保留: 玩家生命周期响应 / 信号映射 / 转阶段消息转发
```

## 组件职责

| 组件 | 职责 |
|---|---|
| StateMachine | 通用状态机核心（进入/退出/每帧 update/顺序切换） |
| LevelSegment | 段基类：三维度字段 + 状态机钩子基实现 |
| SegmentCompletion | 只剩 wait_time（超时选项） |
| BossSegment | spawn boss + 连接 boss.died → mark |
| MinionWaveSegment | 按间隔生成 + 跟踪敌人 died，全死完 → mark |
| LevelManager | 编排：激活/完成判定/推进/事件协调/环境接口 |

## 明确不做

- 不做跳过条件（required_flag）——留扩展点
- 不做信号配置化 Listener（A 点搁置）——段内代码写死连接
- 不做独立 LevelContext / spawn 管理类——LevelManager 环境接口足够
- 不自动重置除 segment_finished 外的 flag
- 不引入并行段（仍线性顺序推进）

## 测试策略

1. 冒烟测试重写：从 await 时序断言改为每帧状态断言（_process 自动驱动）
2. 覆盖：Boss 段阻塞至 died、MinionWave 怪死完完成、wait_time 超时推进、-1 无限等待、start_delay 延迟
3. 帧计数硬超时保留（防挂死）；运行命令 --quit-after 引擎上限
4. 回归：player_lifecycle / gameover_reload 冒烟测试不受影响

---
