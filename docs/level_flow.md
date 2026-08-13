# 关卡流程编排系统说明

本文说明关卡流程从"静态配置文件"到"StateMachine 分段驱动"的完整设计：段维度模型、段自报完成机制、波次重叠、段状态机钩子、段类型扩展与冒烟测试防挂死约定。核心目标是让"关卡内容 = 一段段带时机的编排描述"，LevelManager 只负责按序编排（进入 → 状态机驱动 → 段自报完成），内容生成由各段类型自己的状态机钩子（`enter_state` / `update_state` / `exit_state`）负责，流程控制与内容表现彻底解耦。

## 设计背景

在引入本系统之前，关卡是"单一 Boss 场景 + 散落的硬编码时序"：Boss 何时入场、小怪波次如何穿插、Boss 死亡后流程如何收尾，全部以命令式代码散落在各处。新增一种关卡内容就要动编排代码，关卡与流程纠缠在一起，无法用数据描述一关。

本系统的目标不是做一个功能完整的关卡编辑器，而是把"流程的骨架"从"内容的表现"中抽出来：关卡用一段 `LevelDefinition` 描述，每一段（Segment）只声明"什么时候开始执行、什么时候算完成、执行什么动作"，具体表现（Boss 动作、小怪波次、消息演出）由各段类型在状态机钩子里自己负责。LevelManager 是一个纯编排器，用 StateMachine 逐段驱动（进入 → 运行 → 段自报完成 → 推进），不持有任何表现层引用，只通过 `register_boss` 这类环境接口接收段执行时的注册信息。

## 段维度模型

每一段（`LevelSegment`）都由两个正交维度描述，各自只回答一个问题：

### start_delay —— 什么时候开始执行

段被确认进入（start）后延迟 N 秒才开始真正执行（演出/就位等待）。0 = 进入后立即执行。它只控制"开始执行的时机"，不涉及内容本身。

设计意图：把"时间上的先后/重叠"从"内容"里剥离出来。两个段之间的间隙、波次与 Boss 的并行，都只是 `start_delay` 的取值问题，改配置即可，不写代码。

### completion —— 完成超时兜底

`SegmentCompletion` 只有一个字段 `wait_time`，它不定义"何时算完成"（完成由段自报），只定义**超时兜底**：

- `> 0`：N 秒后强制推进（即使段尚未自报完成）
- `-1`：显式无限等待，只等段完成信号
- `0`：未配置（等效无限等，语义模糊，建议用 -1 显式声明）
- `null`：无超时（依赖段完成信号）

设计意图：把"完成的判定"从编排层彻底剥离——段最了解自己何时完成（Boss 段知道 Boss 何时死，波次段知道怪何时清空），因此由段自己上报；`wait_time` 只作为防死锁的兜底阀门。

### 为什么维度分开

"开始时机"与"完成兜底"一旦合并（比如用单个 `delay` 表达一切），新增时序语义就要动既有字段，牵一发动全身。拆开后，每新增一种内容类型都只需要在这两个维度上取值，编排层代码零改动。激活条件不再作为字段存在：激活即"进入"，段自身通过 `should_preempt()` 决定未来是否需要抢占插入（见下文抢占占位）。

## StateMachine 驱动与段自报完成机制

### 推进模型

`LevelManager` 持有 `_segment_machine: StateMachine`（泛化的 `Public/state_machine.gd`），按 `LevelDefinition.segments` 顺序登记线性 transition。每帧 `_process` 的职责只有两件事：

1. **运行**：`_segment_machine.update(delta)` 把每帧转发给当前段（`start_delay` 计时在段内做：段 `update_state` 里先 `super.update_state(delta)` 再用基类 `is_delay_elapsed()` 判断，延迟未过直接 return）；
2. **完成判定**：段自报完成（`_segment_finished` flag 置位）或 `wait_time` 超时 → `transition_to_next()` 推进。

没有任何 `await` 协程：时序推进完全由每帧轮询驱动，段的生命周期由底层 StateMachine 统一管理（enter → 每帧 update → exit）。

### 段状态机钩子

段是 StateMachine 的状态，实现三个钩子，被统一驱动：

- `enter_state(owner: Node)`：进入段时调用——重置自身运行时状态、执行 spawn 动作、连接自己的完成信号；
- `update_state(delta: float)`：每帧调用——段内计时 / 生成逻辑 / 每帧行为；
- `exit_state()`：段结束或中断时调用——清理（如断开已完成段的残留信号连接，防止迟到信号污染下一段）。

### 完成机制：段自报

段通过调用环境接口 `owner.mark_segment_finished()` 自报完成，LevelManager 置位 `_segment_finished` 后在当帧推进：

- **BossSegment**：enter 后经基类 `start_delay`（`is_delay_elapsed()` 计时）延迟，到时 spawn Boss 并连接 `boss.died`；Boss 死亡 → `mark_segment_finished()`。Boss 战阻塞至 Boss 死亡。
- **MinionWaveSegment**：update 每帧按 `spawn_interval` 生成敌人；全部生成且全部死亡 → `mark_segment_finished()`。

两段都带"完成锁"（`_finished` flag + `exit_state` 断开连接）：段完成后迟到的完成信号被忽略，防止跨段污染。

### 防死锁保障

- 段完成信号永不触发时，由 `completion.wait_time > 0` 超时兜底强制推进并打日志——宁可跳过完成语义，不可卡死关卡。
- `wait_time = -1` 或 `null` 是显式无限等待：等段完成信号。若信号真的不来会卡死，因此只有"完成条件绝对可靠"的段才建议无限等待。

## 波次重叠原理

波次重叠靠 `completion.wait_time` 超时驱动：小怪波次段正常"全部生成且全部死亡"时自报完成；若设置了 `wait_time > 0`，怪没死完但超时 → LevelManager 强制推进 → 下一段进场，两段内容在时间上重叠。

例如"先放一波小怪，1.5 秒后 Boss 入场"：小怪段配 `wait_time = 1.5`，1.5 秒后即使小怪还活着也强制推进 → 进入 Boss 段 → 经过其 `start_delay`/入场延迟后 Boss 入场。小怪在场上与 Boss 同时出现，玩家同时面对两路压力。

设计意图：**并行不需要"并行机制"**。只要完成条件允许"放完就走"（`wait_time` 超时提前放行），重叠就是自然的编排结果。若某天需要"打完这波才出 Boss"，把小怪段 `wait_time` 设为 `-1`（无限等）或去掉超时即可，编排层零改动。

## 抢占占位（should_preempt）

`LevelSegment.should_preempt()` 默认返回 false。未来某段（如血量阈值/成就达成时立刻插入的段）覆写它，LevelManager 每帧询问所有段判断是否打断当前运行段、立刻进入本段。当前为占位，本版不实现抢占。

## 段类型扩展方式

新增一种关卡内容段只需两步：

1. 继承 `LevelSegment`，实现 `enter_state` / `update_state` / `exit_state` 三个钩子（spawn 动作 + 每帧逻辑 + 清理），并在合适时机调用 `owner.mark_segment_finished()` 自报完成；
2. 什么都不用改：`_segment_machine` 统一调度三个钩子，多态分发自动生效。

`LevelManager._process` 的"状态机驱动 → 完成判定"骨架是所有段类型共享的，不需要动。段通过基类的维度字段自动获得全部时序能力。

设计意图：段类型是"内容插件"而非"流程特例"。流程骨架一旦稳定，新增内容就变成纯增量，不会反向修改编排层——段对 LevelManager 只依赖三个状态机钩子签名与 `register_boss` / `mark_segment_finished` 环境接口，耦合是单向的。

## flag 系统扩展点

Boss 结算、解锁等需要"条件门控"的功能在本版未实现，但数据层已预留扩展点：`required_flag` 这类字段将来放在"条件段"子类里（继承 `LevelSegment`，在激活条件中检查 flag），本版不实现。这是刻意的边界——本版的关卡只有 Boss 战一种终局内容，引入 flag 判定是过度设计；但段类型扩展方式已经保证了将来加条件段不需要动编排骨架。

## 冒烟测试防挂死约定（项目级强制）

所有 headless 冒烟测试必须遵守双层防挂死约定，这是本项目的强制经验：

1. **脚本内帧计数硬超时**：测试脚本在 `_process` 中累计帧数，超过上限（如 900 帧）仍未达到断言条件就打印失败并退出——保证测试自身不会因逻辑错误无限运行。
2. **引擎级 `--quit-after` 上限（CI 级 kill-switch）**：`--quit-after N` 是 CI 级 kill-switch，仅限制引擎运行时长；它本身不能区分"测试失败"和"测试挂起后被杀"（两者都退出码 0）。真正的成败判定依赖脚本内帧计数硬超时（挂起 → push_error + quit(1)）。两者必须成对使用。

判断标准以退出码为准：脚本内超时/失败退出码非 0，正常通过退出码为 0。任何一次回归都不允许出现"等不到退出"的情况。

## 关键设计决策小结

- **流程与内容分离**：LevelDefinition 描述"什么时候做什么"，LevelManager 只编排，内容表现由段类型自治。
- **StateMachine 统一驱动**：段生命周期（enter/update/exit）由泛化的 `Public/state_machine.gd` 管理，关卡段与 Boss 流程（`FlowPhaseMachine`）复用同一底层状态机；LevelManager 去 await，改为每帧驱动。
- **段自报完成**：段通过 `mark_segment_finished()` 上报完成，`completion.wait_time` 只作超时兜底（>0 超时 / -1 无限 / null 无超时）。
- **LevelManager = 纯编排器 + 环境接口**：只负责每帧驱动/完成推进/玩家生命周期/Boss 消息转发，内容生成零逻辑；段通过 `register_boss` 等接口回填编排所需信息。
- **维度正交**：开始时机 / 完成超时互不耦合，新内容在这两个维度上取值即可。
- **并行靠数据不靠机制**：波次重叠靠 `wait_time` 超时提前放行，`-1` 不重叠。

## 待办（TODO）

- **小怪波次结构扩展**：当前 `MinionWaveSegment` 字段（enemy_scene/count/spawn_interval/spawn_positions）是最小猜测集，结构偏单薄。等实际需求明确后扩展：
  - 出怪形态（直线队列 / 环形 / 追踪 / 编队）
  - 小怪对象池管理（与 BulletLayer 同思路；Boss 不池化，小怪适合）
  - 波次与玩家位置/状态的交互（如追踪玩家、按玩家方位分布）
  - 触发后细节（入场演出、掉落声明）
- **不引入专门 spawn 管理类**（当前切片段自管 spawn 足够，责任不溢出；等对象池等真实需求到来再评估）
