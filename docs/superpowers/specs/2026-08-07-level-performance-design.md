# 2026-08-07 克苏鲁之眼关卡演出整合设计（Level Performance）

> 故事线来源：用户腾讯文档共享知识库（Node 03 夜晚降临 / Node 04 Boss 登场 / Node 05 Phase Transition / Node 06 Victory）。本文档只描述**技术实现设计**，不重写故事线。

## 背景与目标

`feature/level-manager` 已完成：LevelManager 读取 `LevelDefinition.segments` 顺序实例化
Boss、转阶段消息链路（`phase_changed` → `phase_message_ids` → `MessageController.show_by_id`）
已真跑通。本 stage 在之上串联**完整关卡演出**：夜晚降临 → Boss 登场 → 转阶段演出 → 胜利。

**范围约束（用户明确）**：
- 缺美术，全部用**占位**：画面可见用淡出/闪烁/色块，流程件（对话/音乐/输入锁定/信号）真实实现。
- **背景/夜晚视觉本 stage 不实现**，只留信号接口占位 + debug 日志 + 待办项（等美术确认交互方式）。
- 掉落物系统 / Boss flag 持久化无现成设施，本次做占位（画面闪烁 + 日志）。
- 音乐当前只有完整版 BGM + 测试数据，本 stage 用现有 BGM + `set_bgm_layer_enabled` 分层；前奏循环/主旋律切分留后期调试。

## 架构（双层驱动 + 外部事件桥）

核心原则延续 spec：**Boss 只提供动作与信号，LevelManager 决定何时叫与响应什么**（反向代理）。

```
main.tscn
├── Player
├── BulletLayer
├── LevelManager                 ← 总管理器：编排关卡级流程 + 响应信号做全局演出
├── MessageLayer                 ← 对话（已有）
├── DebugDrawLayer / DebugOverlay
└── [背景/夜晚] 不建视觉层，仅信号接口占位
```

**驱动分工：**

| 阶段 | 驱动者 | 说明 |
|---|---|---|
| 夜晚降临 (Node03) | LevelManager | 消费 `NightSegment`：等待 → 对话序列 → BGM 切换 → 背景意图信号(日志占位) → 进下一段 |
| Boss 登场 (Node04) | LevelManager | `spawn` Boss → 锁玩家输入 → 入场 → **`phase_changed(1)`（Intro→Phase1）解锁输入** → 血条出现（现有） |
| 转阶段 (Node05) | Boss 发信号 | Boss 转 Phase2 → **外部事件桥** `external_event_requested` → LevelManager 响应：对话 + 音乐分层 + 背景意图(日志占位) |
| 胜利 (Node06) | Boss 发信号 | Boss `died` → LevelManager：消散淡出(占位) + Victory stinger + 掉落闪烁(占位) + 暂停输入 + 对话 + boss_flag 日志占位 |

> **解锁输入时机说明**：`entrance_finished` 信号仅在 `boss_base.gd` 声明、**当前从未 emit**（属预留出口）。
> 玩家锁定持续到 `phase_changed(1)`（IntroPhase `auto_transition_after=0.8` 结束后转 Phase1）才解锁——
> 对应 storyboard "短暂锁定随后恢复"。解锁在现有 `_on_boss_phase_changed` 内扩展：除转发消息外，
> 首次收到 `phase_id==1` 时调 `Player.set_input_enabled(true)`。

## 段模型（数据驱动，兄弟类）

```
LevelDefinition.segments: Array[LevelSegment]
  [0] NightSegment      ← 新（extends LevelSegment 的兄弟类，不继承 phase_message_ids）
  [1] BossSegment       ← 已有，保留（转段事件走外部事件桥，不扩展字段）
```

### NightSegment（新 Resource）
- `@export var type: String = "night"`（LevelSegment 基类已有 type 字段）
- `@export var wait_before_start: float`：夜晚开场前等待
- `@export var message_ids: Array[String]`：开场对话序列（Node03 共 4 条）
- `@export var bgm_track: String`：夜晚 BGM 名（现有完整版 BGM）
- `@export var bgm_fade_in: float = 1.0` / `bgm_fade_out: float = 1.0`
- `@export var scene_ambience_key: String`：背景意图 key（仅发信号，视觉留待美术）

### BossSegment（已有，不改结构）
- 转阶段演出**不写死在 BossSegment**，改由 Boss 场景内配置 `BossExternalEventPattern` 发出。
- 胜利演出由 LevelManager 响应 `died` 时调用；对话 id 列表由 `LevelDefinition` 层新增可选字段承载（见下文）。

### LevelDefinition（已有，可选扩展字段）
- 新增可选 `@export var victory_message_ids: Array[String] = []`：胜利对话序列（Node06 共 6 条）。
- 无则胜利仅做无对话的占位演出（消失/掉落/stinger/flag 日志），不崩溃。

## 信号桥：BossExternalEventPattern（已有，本次接线）

- `BossExternalEventPattern.external_event_requested(event_name: String, payload: Dictionary, pattern)` 信号已存在，**当前无人监听**。
- 本次：LevelManager `_ready` 监听 Boss 的该信号（Boss 自身转发或直接连线），按 `event_name` 分发：
  - `"phase_transition_performance"`：转阶段演出（对话 + `set_bgm_layer_enabled` + 背景意图日志）
  - 预留：`"victory"`、`"entrance"` 等命名，后续阶段扩展。
- 事件命名风格参照现有 Debug 日志风格（`"Boss external event requested: ..."`）。

## 背景接口占位（不建视觉）

- LevelManager 新增信号 `scene_change_requested(scene_key: String, params: Dictionary)`（接口出口）。
- 本 stage：收到背景意图仅 `DebugState.debug_log` + 注释 `# TODO(美术): 背景交互方式待美术确认后接入`。
- 该接口是后续 `BackgroundLayer`/夜晚视觉的接入点。

## 消息/对话（全量录入 messages_zh.json）

storyboard Node03-06 对话全部录入 `data/messages/messages_zh.json`：
- 夜晚：鵺×1 + 旁白×1 + 鵺×1 + 荷取×1（Node03，4 条）
- 登场：旁白×1 + 鵺×2 + 荷取×1（Node04，4 条）
- 转段：鵺×1 + 荷取×2（Node05，3 条）
- 胜利：鵺×1 + 旁白×1 + 荷取×2 + 鵺×2（Node06，6 条）

字段沿用现有格式：`speaker / text / duration / typewriter / chars_per_second / priority / interrupt_policy`；文本内控制 tag（`[color=#..]` `[pause]` `[slow]` `[fast]`）沿用 storyboard 原文配色。

## 音乐（现有完整 BGM + 分层）

- 夜晚：`AudioManager.play_bgm(track, fade_in, fade_out)`（Node03 "Boss 前奏"）
- 登场：切 Boss Theme（现有 BGM 复用）
- 转段：`AudioManager.set_bgm_layer_enabled(true, fade)`（Node05 "音乐下一层"）
- 胜利：`AudioManager.play_sfx_id` Victory stinger（现有测试数据可用则用，否则日志占位）
- 前奏循环→主旋律切分：留后期（依赖 BGM 资源切分，本 stage 不做）

## 玩家输入（已有接口，本次接线）

- `Player.set_input_enabled(bool)` 已存在。
- Node04 登场：LevelManager spawn 前锁 → `phase_changed(1)`（Intro→Phase1）解锁。
- Node06 胜利：`died` 后暂停输入（storyboard "暂停输入"）。

## 胜利占位演出（Node06，画面可见）

`LevelManager._on_boss_died()` 由占位升级为：
1. 暂停玩家输入
2. Boss 消散：`Tween` Scale 缩至 0 淡出（占位动画）
3. `AudioManager` Victory stinger
4. 掉落占位：生成 1 个闪烁色块节点（ColorRect/Node2D，短暂闪烁后消失）
5. 胜利对话序列 `victory_message_ids`（storyboard Node06）
6. `boss_flag` 更新：仅 `DebugState.debug_log` 占位（无持久化系统）
7. `scene_change_requested("victory_clear", ...)` 背景意图信号（日志占位）

## 错误处理与边界

- `NightSegment` 无 `message_ids` / `bgm_track` 为空：警告并跳过对应动作，不崩溃。
- 外部事件 `event_name` 未识别：警告并跳过（日志）。
- `scene_change_requested` 无监听者：信号无连接不发警告（Godot 默认行为），本 stage 无实现方。
- Boss 场景未配置外部事件 Pattern：转段演出静默跳过，不影响战斗。
- 胜利流程中任一子步失败：日志警告，不中断后续子步。

## 测试（headless 验证）

无 GDScript LSP，验证走：
- `godot --headless --path <project> --quit-after 30` 主场景启动无解析错误。
- 运行中观察 `DebugState` 日志确认：夜晚段消费 → Boss spawn → `phase_changed(1)` 解锁输入 → 转段事件 → died → 胜利子步序列。
- 对话/音乐/输入锁若无法 headless 观察，说明静态验证与代码路径审查。

## 明确不做（防范围蔓延）

- 不建背景/夜晚视觉层、不建 CanvasModulate/后处理（等美术）。
- 不做真实掉落物系统 / Boss flag 持久化（仅占位）。
- 不做 BGM 资源切分/前奏循环编排（后期调试）。
- 不改 `BossSegment.phase_message_ids` 既有转段消息链路（保留兼容；新转段演出走外部事件桥）。
- 不做 MinionWaveSegment / 小怪波次。
