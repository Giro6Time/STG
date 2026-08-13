# 关卡流程系统重做设计（Level Flow v2）

> 背景：现有 `LevelDefinition → LevelSegment → BossSegment` 数据模型过于简陋——
> `_consume_segments()` 是纯 await 顺序，无"开始时机/激活条件/完成语义"概念，
> 无法承载波次重叠、条件触发、事件驱动等关卡编排。本次重做数据结构 + LevelManager 推进模型。
>
> 前身 spec：`2026-08-10-level-flow-redesign.md`（只规划了"夜晚→Boss→胜利"一条演出线，
> 本次在保留其完成条件模型的基础上，扩展为通用关卡编排）。

## 目标

1. LevelManager 成为关卡内**所有事件的统筹者**：Boss、小怪波次、剧情、奖励等，
   全部由关卡数据结构声明，LevelManager 按数据驱动执行与推进。
2. 支持**条件触发的有序流**：主线仍是有序段列表（保证可预测性），但每段可带
   激活条件（不满足则跳过）、开始时机、完成语义。
3. 支持**波次重叠**：小怪波次之间不互相等待，按时间轴并行出怪（STG 手感核心）。
4. 段类型可扩展：新增段类型 = 继承 `LevelSegment` + LevelManager 一个分发分支。

## 已确认决策

1. **骨架 = 条件触发的有序流**：不做"玩家选择导致完全不同分支"的事件图。
   主线有序（保证"玩家一定能走到 Boss 面前"），节点可带条件触发/跳过。
2. **段三维度**（核心模型）：

   ```
   LevelSegment
   ├── 开始时机   start_delay: float          # 相对上一段触发后延迟 N 秒
   ├── 激活条件   await_signal: String        # 等某信号才触发（空 = 不等待）
   └── 完成语义   completion: SegmentCompletion # null = 非阻塞（触发即完成）
   ```

3. **开始时机 = 相对上一段触发**（非绝对时间轴）：改单段不影响整条轴，贴近调手感直觉。
4. **波次重叠**：小怪波次 `completion = null`（非阻塞）+ `start_delay` 编排，
   波次按时间轴并行，不等待上一波清空。
5. **激活条件细分**：通用激活条件只做 `start_delay` + `await_signal`。
   **血量/成就等不做通用字段**——它们将来统一抽象为 flag，由专门的监测系统 set flag，
   段通过 flag 检查触发（`required_flag` 留到 flag 系统实现后，放条件段子类，不进基类）。
6. **完成条件 = 优先级链（非 OR）**：`SegmentCompletion` 按固定顺序检查
   （`wait_time` → `await_signal` → `wait_group_empty` → `wait_messages_done`），
   命中首个非空条件即按该条件等待并完成；多字段同时设置只取第一个（不是 OR 组合）。
   字段集是"扩展点"，供不同关卡取用其中一种语义，而非在同一段内组合多种条件。
   不引入 AND（AND 组合可用"拆两段 + 中间演出段"实现）。
7. **完成条件字段**：`wait_time` / `await_signal` / `wait_group_empty` / `wait_messages_done`。
8. **本次实现段类型**：`BossSegment`（已有，适配新模型）+ `MinionWaveSegment`（新增，实现但暂不配入关卡）。
   其他段类型（剧情/奖励/隐藏 Boss）留接口，后做。
9. **flag 系统不实现**，只留扩展点。

## 段模型（数据结构）

```
LevelDefinition (Resource)
└── @export var segments: Array[LevelSegment]      # 关卡全流程，有序

LevelSegment (Resource, 基类)
├── @export var type: String                       # 段类型标识（Inspector 直观区分）
├── @export var start_delay: float = 0.0           # 相对上一段"触发"后延迟 N 秒
├── @export var await_signal: String = ""          # 等某信号才触发本段（空 = 不等待）
└── @export var completion: SegmentCompletion      # null = 非阻塞（触发即完成）

SegmentCompletion (Resource)                       # 完成条件，优先级链：首个非空字段生效
├── @export var wait_time: float = 0.0             # 等 N 秒（0 = 不用）
├── @export var await_signal: String = ""          # 等某信号（如 "boss_died"）
├── @export var wait_group_empty: String = ""      # 等某 group 节点清空（如 "enemies"）
└── @export var wait_messages_done: bool = false   # 等 MessageController 消息流播完

BossSegment (extends LevelSegment)
├── @export var boss_scene: PackedScene
├── @export var spawn_position: Vector2
├── @export var phase_message_ids: Dictionary      # 转阶段消息映射（保留）
├── @export var summoned_enemy_scenes: Array[PackedScene]
└── completion                                    # 例：{await_signal: "boss_died"}

MinionWaveSegment (extends LevelSegment)           # 本次新增，实现但暂不配入关卡
├── @export var enemy_scene: PackedScene           # 波次刷的敌人
├── @export var count: int = 0                     # 本波数量
├── @export var spawn_interval: float = 0.5        # 相邻敌人生成间隔
├── @export var spawn_positions: Array[Vector2]    # 生成位置（多组）
├── @export var lanes: int = 1                     # 同时生成的行数/列数
└── completion = null                              # 非阻塞，触发即完成
```

**信号命名约定**：`await_signal` / `completion.await_signal` 用字符串（如 `"boss_died"`），
LevelManager 维护"信号名 → 实际信号"映射表。Resource 不持有场景信号对象。

## LevelManager 推进模型

```
扫描段（有序）：
  for each segment:
    - start_delay 计时（相对上一段触发）
    - 检查 await_signal（激活条件，空 = 跳过检查）
    - 触发段动作（_run_xxx 按类型分发）
    - completion == null ? 立即看下一段 : 挂起等 completion 满足再继续

信号响应（并行，不阻塞主推进）：
  - 段动作会注册信号监听（如 boss.died → 完成 Boss 段）
   - completion 的首个非空条件满足 → 段完成 → 推进
```

**防死锁保障**：任何 completion 都有兜底（`wait_time` 超时或视为完成）；
`wait_group_empty` 轮询带上限。关卡不会卡死。

## 明确不做（防范围蔓延）

- 不做 flag / 成就系统（`required_flag` 留扩展点）。
- 不做剧情/奖励/隐藏 Boss 段类型（基类支持，具体类后做）。
- 不做绝对时间轴（只有相对 start_delay）。
- 不做 AND 完成条件。
- 不做分支图（玩家选择 → 完全不同的后续）。
- MinionWaveSegment 实现但暂不配入 `level_001.tres`。

## 开放点（待用户否决）

1. **`MinionWaveSegment` 字段**：上表是最小猜测集（敌人/数量/间隔/位置/行数）。
   具体出怪形态（直线队列/环形/追踪）等美术/玩法需求明确后再扩展。
2. **BossSegment.entrance_delay 与新模型关系**：`entrance_delay` 是"spawn 前等待"，
   与 `start_delay`（相对上一段触发）语义重叠。倾向：保留 `entrance_delay`
   作为 Boss 段特有字段（入场演出等待），`start_delay` 管段间编排。
