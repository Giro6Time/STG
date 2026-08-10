# 2026-08-10 关卡流程串联重做设计（Level Flow Redesign）

> 背景：`feature/level-performance` 的演出串联实现代码质量不达标（用户看到 LevelManager 即放弃继续阅读）。
> 本次**完全重做**演出串联部分：保留 `develop`（`a03c34d`）基座的模块划分（LevelManager 装配器 + 段数据模型），
> 演出串联的设计从头讨论、实现走 superpowers 流程。
> 故事线来源：用户腾讯文档共享知识库（Node 03 夜晚降临 / Node 04 Boss 登场 / Node 05 转场 / Node 06 胜利）。
> 本文档只描述**技术实现设计**，不重写故事线。

## 背景与目标

`develop` @ `a03c34d`（= `feature/level-manager`）已完成：LevelManager 读取
`LevelDefinition.segments` 顺序实例化 Boss、转阶段消息链路（`phase_changed` →
`phase_message_ids` → `MessageController.show_by_id`）已真跑通。该基座 78 行、职责清晰，
**保留作为参考基线**。

`feature/level-performance`（8 个提交，自 `a03c34d` 分叉）的演出串联实现**全部作废，不参考**。
其核心问题（用户确认的痛点）：

1. **LevelManager 职责臃肿**：从 78 行膨胀到 147 行，音频/清屏/输入/消息/场景意图全知道。
2. **硬编码太多**：BGM 资源数组、SFX、`transition_01/02/03` 消息 id 写死在代码里。
3. **段自驱动设计有毛病**：`NightSegment.play()` 直接调 `AudioManager` 全局单例，自称"只发意图"却直接执行。
4. **LevelContext 万能上下文**：行为端口 Callable + 直接引用 + 全局单例混装，边界模糊。

**本 stage 目标**：克苏鲁之眼关卡演出整条跑通——夜晚降临 → Boss 登场 → 转场 → 胜利，
占位美术，先让流程能跑。**验收标准：结构清晰 + 流程跑通**（两者都是硬指标）。

## 已确认决策

1. **重做范围**：从 `develop` 基座重做演出串联。保留 LevelManager 装配器 + 段数据模型，重做串联编排。
2. **段模型**：段是**纯数据 Resource**（只声明动作参数 + 完成条件），不带执行逻辑，不碰全局单例。
3. **段接续**：段**自报完成条件，自动推进**。完成条件满足（多条件 OR）→ 自动进下一段。
   执行逻辑集中在 LevelManager，LevelManager 只做"条件监测 + 顺序推进 + 信号响应"。
4. **数据驱动程度**：演出编排（谁先谁后、每步做什么、何时推进）由关卡配置驱动；
   代码只提供"能力"（播对话/切音乐/锁输入/spawn）。**但不过度设计**——配简单逻辑不要搞一堆组件。
5. **波次**：本次不做 MinionWaveSegment，但**模型必须能承载**（`wait_group_empty` 完成条件即承载点）。
   克苏鲁之眼自身召唤小怪走 AttackPattern，不走关卡波次。
6. **背景/夜晚视觉**：本 stage 不实现，只留信号接口（`scene_change_requested`）+ debug 日志占位，
   等美术确认交互方式。
7. **音乐**：现有完整版 BGM + AudioManager 分层；`bgm_track` 用**名字字符串查表**，不硬编码资源。
8. **玩家输入**：`Player.set_input_enabled(bool)` 已有；登场 spawn 前锁 → `phase_changed(1)`
   （Intro→Phase1）解锁；胜利 `died` 后锁。
9. **解锁时机说明**：`entrance_finished` 信号当前从未 emit（仅声明），解锁依赖
   `phase_changed(1)`（IntroPhase `auto_transition_after=0.8` 结束转 Phase1）。

## 架构

```
main.tscn（根 = LevelManager，挂 LevelManager.gd 的 Node2D）
├── Player
├── BulletLayer
├── LevelManager (script, 根节点)
│   └── 顺序消费 LevelDefinition.segments → 执行段动作 → 监测完成条件 → 推进
├── MessageLayer（含 MessageBox + MessageController，group: message_controllers）
├── DebugDrawLayer / DebugOverlay
└── [背景/夜晚] 本 stage 不建视觉层，仅 scene_change_requested 信号出口（日志占位）
```

**驱动分工（反向代理，延续基座原则）：**

| 阶段 | 驱动者 | 说明 |
|---|---|---|
| 夜晚降临 (Node03) | LevelManager | 消费 `NightSegment`：对话 → BGM → 背景意图信号(日志占位) → 完成条件推进 |
| Boss 登场 (Node04) | LevelManager | `entrance_delay` 等待 → 锁输入 → spawn → 连信号 → 切 BGM |
| 转阶段 (Node05) | Boss 发信号 | `external_event_requested` → LevelManager 响应：对话 + 音乐分层 + 背景意图(日志占位) |
| 胜利 (Node06) | Boss 发信号 | `died` → LevelManager：清屏敌弹 → 锁输入 → Victory stinger → 胜利对话 → flag 日志 |

## 段模型

```
LevelDefinition (Resource)
└── @export var segments: Array[LevelSegment]      # 关卡全流程，有序

LevelSegment (Resource, 基类)
└── @export var completion: SegmentCompletion       # 可选；null = 立即完成

SegmentCompletion (Resource)                       # 完成条件，多字段任一满足(OR)
├── @export var wait_time: float = 0.0             # 等 N 秒（0 = 不用时间条件）
├── @export var await_signal: String = ""          # 等某信号（如 "boss_died"）
├── @export var wait_group_empty: String = ""      # 等某 group 节点清空（如 "enemies"）
└── @export var wait_messages_done: bool = false   # 等 MessageController 消息流播完（轮询 is_busy）

NightSegment (extends LevelSegment)
├── @export var message_ids: Array[String]         # 开场对话序列（Node03 共 4 条）
├── @export var bgm_track: String = ""             # 切 BGM 名（空 = 不切）
├── @export var bgm_fade_in: float = 1.0
├── @export var bgm_fade_out: float = 1.0
├── @export var scene_ambience_key: String = "night_fall"   # 背景意图（视觉待美术）
└── completion                                    # 例：{wait_messages_done: true} 对话播完即推进

BossSegment (extends LevelSegment)
├── @export var boss_scene: PackedScene
├── @export var spawn_position: Vector2
├── @export var entrance_delay: float = 0.0        # spawn 前等待
├── @export var phase_message_ids: Dictionary       # 转阶段消息映射（保留基座能力）
├── @export var summoned_enemy_scenes: Array[PackedScene]
├── @export var victory_message_ids: Array[String]  # 胜利对话序列（Node06，段内更内聚）
└── completion                                    # 例：{await_signal: "boss_died"}
```

**未来波次承载（本次不实现，验证模型可承载）：**

```
MinionWaveSegment (extends LevelSegment)
└── completion: {wait_group_empty: "enemies", wait_time: 30}
    # 小怪清空 或 30 秒到，任一满足 → 推进（OR 语义天然支持）
```

**关键设计点：**

1. **OR 语义**：`SegmentCompletion` 四字段任一满足即完成。
2. **信号字符串命名**：`await_signal` 用字符串（如 `"boss_died"`），执行器维护
   "信号名 → Boss 实际信号"映射表。Resource 不持有场景信号对象。
3. **completion 为 null**：段立即完成（动作做完马上推进）——覆盖顺序强依赖场景。

## 执行器（LevelManager 重构）

**核心原则：保留 develop 基座骨架（_consume_segments → 分发），职责通过方法拆分 + 硬编码清零。**

```
LevelManager（约 100-120 行，全是编排，零硬编码）
├── _ready()
│   └── _consume_segments()
│       └── for segment in segments:
│               await _run_segment(segment)      # 执行段动作
│               await _wait_for_completion(seg)  # 挂完成条件
│
├── _run_segment(segment)         # 按类型分发（每个段类型一个方法）
│   ├── _run_night(seg)           # 播对话 → 切 BGM → 发背景意图
│   └── _run_boss(seg)            # await entrance_delay → 锁输入 → spawn → 连信号 → 切 BGM
│
├── _wait_for_completion(seg)     # 读 SegmentCompletion，OR 并行等待
│   ├── wait_time          → 计时器
│   ├── await_signal       → 信号竞争（Boss 信号映射表）
│   ├── wait_group_empty   → group 清空监测
│   └── wait_messages_done → 轮询 MessageController.is_busy() 至空
│
├── _on_boss_phase_changed(phase_id)   # 转阶段：解锁输入(phase 1) + 转发 phase_message_ids
├── _on_boss_died()                    # 胜利：清屏 → 锁输入 → stinger → 胜利对话 → flag 日志
└── _on_boss_external_event(name, payload)  # 外部事件桥（转段演出）
```

**与 level-performance 的三个关键差异：**

1. **硬编码清零**：
   - BGM：段数据 `bgm_track` 是**名字字符串** → AudioManager 查表播放。不写资源数组。
   - 对话：全部 id 在段数据（`message_ids` / `phase_message_ids`），LevelManager 只转发。
   - 背景意图：`scene_ambience_key` 字符串 → `scene_change_requested` 信号发出，不写死 key。
2. **音频资源注入挪走**：不做 `_ensure_audio_config()` 硬塞测试资源。音频轨道配置放
   AudioManager 自己的场景/资源里，LevelManager 不碰资源装载。
3. **段动作 = 数据驱动分发**：`_run_segment` 按段类型分支，每分支读段字段执行。
   加新段类型 = 加 `_run_xxx` 方法 + 分发分支（develop 基座已验证的模式，不引入新抽象）。

**完成条件监测实现**（OR 并行等待）：GDScript 无内建 race，用信号/协程做"任一完成"竞争，
实现约 20 行，收敛在 `_wait_for_completion` 一个方法内。

### 信号 → 完成条件映射表

| await_signal 字符串 | 实际信号 |
|---|---|
| `"boss_died"` | `boss.died` |
| `"boss_phase_changed"` | `boss.phase_changed` |
| `"boss_entrance_finished"` | `boss.entrance_finished` |

新增信号名 = 映射表加一行，段数据不改结构。

## 新增能力（基座缺失，本次补齐）

以下能力在 `develop` 基座**不存在**（是 level-performance 分支加的，随其作废），本次需从零实现。
能力归各系统自己所有，LevelManager 只调用：

| 能力 | 归属 | 大小 | 用途 |
|---|---|---|---|
| `MessageController.is_busy() -> bool` | MessageController | ~5 行 | `wait_messages_done` 轮询判断消息流是否播完 |
| `BulletLayer.clear_enemy_bullets()` | BulletLayer | ~10 行 | 胜利清屏：仅回收敌方子弹，保留玩家弹 |
| 故事线对话录入 | `data/messages/messages_zh.json` | 17 条 | 夜晚4+登场4+转段3+胜利6，Node03-06 全量 |

> 注：`is_busy` 曾由 level-performance 加过（commit 52e2cd8），本次**不参考其实现**，从零写。
> `clear_enemy_bullets` 同理（commit 1cb03ff），不参考。
> 基座 `messages_zh.json` 仅有 `eye_intro_warning` / `eye_phase_2` / `eye_defeated` 三条旧消息，
> 故事线对话全部需重新录入（文本来源：用户腾讯文档 storyboard Node03-06）。

## 数据流（克苏鲁之眼关卡）

```
level_001.tres: LevelDefinition
segments = [① NightSegment, ② BossSegment]

LevelManager._consume_segments():
│
├─ 段① NightSegment
│    _run_night():
│      ├─ 播 4 条开场对话（夜晚降临台词）
│      ├─ AudioManager.play_bgm("boss_intro")        ← 名字查表，不写死资源
│      ├─ scene_change_requested.emit("night_fall")  ← 背景意图信号（视觉待美术）
│    _wait_for_completion({wait_messages_done: true})  ← 对话播完即推进
│
├─ 段② BossSegment
│    _run_boss():
│      ├─ await entrance_delay(0.5)
│      ├─ 锁玩家输入 set_input_enabled(false)
│      ├─ spawn boss_base.tscn @ (316,134)
│      ├─ 连信号 phase_changed / died / external_event_requested
│      ├─ AudioManager.play_bgm("boss_theme")
│    _wait_for_completion({await_signal: "boss_died"})   ← 等 Boss 死
│
├─ （Boss 战斗中）信号响应：
│    phase_changed(1) → 解锁输入（入场完成）
│    phase_changed(2) → phase_message_ids[2] → 播"气息变得更强了……"
│    external_event_requested("phase_transition_performance")
│                     → 转段演出：对话 + 音乐分层 + 背景意图
│    died → 胜利流程：清屏敌弹 → 锁输入 → Victory stinger → 胜利对话 → flag 日志
```

## 错误处理与边界

| 情况 | 行为 |
|---|---|
| `level_definition` 为 null | 警告 + return，不崩溃（保持基座） |
| 段类型未知 | 警告 + 跳过该段，不崩溃 |
| `completion` 为 null | 段立即完成（动作做完即推进） |
| 完成条件全为空字段 | 同上，立即完成 |
| `await_signal` 指向未注册信号 | 警告 + 视为立即完成（防死锁） |
| 消息/音乐/输入相关服务缺失 | 各自判空警告，单步失败不中断流程 |
| Boss 战斗中途段被跳过 | 信号无监听者静默，不影响 |

**防死锁保障**：任何完成条件都有兜底（timeout 或视为完成）；`wait_group_empty` 轮询带上限，
不会让关卡永远卡住。

## 测试策略

无 GDScript LSP，验证走 headless：

1. **加载验证**：`godot --headless --quit-after 30` 主场景无解析/资源错误。
2. **流程日志验证**：`DebugState.debug_log` 观察时序——夜晚段完成 → Boss spawn →
   `phase_changed(1)` 解锁 → 转段事件 → died → 胜利子步序列。
3. **数据可配置性验证**：改 `level_001.tres` 的 `wait_messages_done` / `message_ids` 后流程照跑
   （证明数据驱动成立）。
4. **负向验证**：`completion` 空 / 信号未注册 / 服务缺失时不崩溃不死锁。

## 明确不做（防范围蔓延）

- 不建背景/夜晚视觉层、不建 CanvasModulate/后处理（等美术）。
- 不做 MinionWaveSegment / 小怪波次（本次）；模型通过 `wait_group_empty` 承载未来。
- 不做掉落物系统 / Boss flag 持久化（仅占位）。
- 不做 BGM 资源切分/前奏循环编排。
- 不做 AudioManager 资源装载（配置在 AudioManager 自身）。
- 不改 Boss 自身行为（PhaseMachine/血条/信号），Boss 保持"只提供动作与信号"。

## 开放点（已填推荐默认值，待用户否决）

1. **加新段类型的代价**（推荐默认：接受改 LevelManager 分支）：
   `_run_segment` 按类型分发，加段类型 = 改 LevelManager 加一个 `_run_xxx` 分支。
   符合"不过度设计"；一年加两三个段类型的代价可接受。
   （备选：要求"加段类型完全不动 LevelManager"，需执行器注册/处理器抽象，复杂度上升，不推荐。）
2. **胜利对话 id 存放**（推荐默认：`BossSegment.victory_message_ids`）：
   放 Boss 段内，与 NightSegment 模式一致（段自带自己的演出数据）；胜利是 Boss 段的演出，不属于关卡顶层。
3. **id 处理策略**（用户提问：要不要做工具把 message_id/audio_id 转 enum；推荐默认：**不做 enum 工具，做运行时校验**）：
   - 对话 id 已数据化进段配置（.tres），代码侧魔法字符串基本消除，enum 工具回本场景（引用点多、频繁重命名）尚未出现。
   - enum 工具帮不了 .tres 数据；真正的风险在"段配置里写错 id 运行时才炸"——属运行时校验领域。
   - 推荐：`MessageController` 加载时建合法 id 索引，`show_by_id` 对未知 id 报警（约 5-10 行）；audio 统一用字符串名（`play_bgm("name")`），不维护数字 id enum。
   - 备选 A（enum 生成工具）：`tools/` Python 脚本扫描 json/audio 资源 → 生成 `MessageId.gd`/`AudioId.gd` 常量类（编译期查错 + 重命名安全，但引入生成流程与提交物）。
   - 备选 C（A+B 双保险）：最全，可能过度设计，不推荐。
