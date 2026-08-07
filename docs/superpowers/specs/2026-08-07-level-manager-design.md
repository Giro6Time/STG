# 2026-08-07 LevelManager 关卡加载重构设计（修订版）

## 背景与目标

当前 `main.tscn` 是无脚本的纯场景装配：直接把 `BossBase` 作为常驻实例放进场景树，
`boss_base.gd` 的 `_ready` 里 `phase_machine.setup(self)` 开工即战。

本次重构目标：把关卡从"场景里钉死 Boss"改成**根节点 LevelManager 按关卡配置组装**。
主场景只搭舞台，内容由配置驱动。

**核心认知修正**：Level 是**关卡全流程**，不是"一场 Boss 战"。Boss 只是流程里可能
出现、可能反复出现的环节（如：小怪 → Boss 露脸 → 小怪 → Boss 再出）。因此关卡数据
模型必须是**有序的关卡段序列**，Boss 相关信息退回到 Boss 段中，而不是钉在关卡顶层。

配合大目标：克苏鲁之眼 Boss 演出（背景夜晚、入场、阶段转场、结算）。本次**不含**背景 /
夜晚系统（那是下一 stage）。

## 已确认决策

1. **挂载方式**：根节点 LevelManager（方案 A）。不新增 Autoload。
2. **关卡模型**：`LevelDefinition` 持有 `segments: Array[LevelSegment]`（有序流程段）。
   本次切片只实现 `BossSegment`，但结构不写死：加新段类型 = 新增 Resource 子类 +
   LevelManager 加一个分发分支。
3. **召唤敌人**：本次只做**数据声明 + Boss 提供召唤能力**，真正"波次召唤"留到以后。
4. **实现范围**：加载重构 + 入场编排骨架 + **转阶段消息链路真跑通（B 方案）**。
   不含 `CanvasModulate` / 背景层 / 环境音 / WorldEnvironment。
5. **消息链路（B 方案）**：Boss 转阶段 → `phase_changed` 信号 → LevelManager 查
   `BossSegment.phase_message_ids` → `MessageController.show_by_id()`。消息内容作为
   关卡数据放在 `BossSegment`，不写死在 Boss/LevelManager 代码里。
6. **MessageController 查找**：加 group（`message_controllers`），与 BulletLayer 的
   "静态声明 + 运行时 add_to_group 兜底"双保险模式一致，避免硬查欠账。

## 架构

```
main.tscn（根 = LevelManager，挂 LevelManager.gd 的 Node2D）
├── Player
├── BulletLayer
├── LevelManager (script, 根节点)
│   └── 顺序消费 LevelDefinition.segments，运行时实例化各段内容
├── MessageLayer（含 MessageBox + MessageController，静态声明 group）
├── DebugDrawLayer / DebugOverlay                （基础设施，保留）
```

- `main.tscn` 不再静态放 `BossBase`。
- `LevelManager._ready` → 读 `LevelDefinition` → 按顺序处理 segments → 当前只有
  `BossSegment`：等待入场延迟 → 实例化 Boss → 连接信号 → 触发入场。

## 关卡数据模型（修正后）

```
LevelDefinition (Resource)
└── @export var segments: Array[LevelSegment]      # 关卡全流程，有序

LevelSegment (Resource, 基类)                      # 扩展点：新段类型继承它
└── @export var type: String                        # "boss" / "minion_wave" / ...

BossSegment (Resource, extends LevelSegment)
├── @export var boss_scene: PackedScene
├── @export var spawn_position: Vector2
├── @export var entrance_delay: float               # 本次控制"何时把 Boss 加入场景树"
├── @export var summoned_enemy_scenes: Array[PackedScene]   # 本次只承载数据
└── @export var phase_message_ids: Dictionary       # phase_id → message_id，转阶段发消息
```

示例：未来"小怪→Boss→小怪"插花流程 = 数组里加
`[MinionWaveSegment, BossSegment, MinionWaveSegment]`，形状不变，只加数据。

## 三个边界角色

| 角色 | 内容 | 位置 |
|---|---|---|
| **Boss** | 血量 / PhaseMachine / 血条、自身动画（入场/裂变/消散）、**召唤敌人**、**信号广播**（phase_changed/died/entrance_finished） | `Scenes/Boss/` 场景自带 |
| **LevelManager** | 顺序消费 segments → 实例化各段内容、监听 Boss 信号 → 驱动**场景级演出**（Message、背景、夜晚、玩家锁定、音频切换）、死亡结算入口 | 根节点脚本 |
| **LevelDefinition / LevelSegment / BossSegment** (Resource) | 声明关卡流程、段内容、转阶段消息映射 | `.tres` 资产 |

**核心原则：Boss 只提供"动作"与"信号"，LevelManager 决定"何时叫"与"响应什么"。**
Boss 不直接持有 Message / 背景 / 玩家的引用，也不感知关卡顺序。

### 转阶段发消息的信号通道

```
Boss（转阶段）──phase_changed(phase_id)──> LevelManager._on_boss_phase_changed
                                              └─ 查 BossSegment.phase_message_ids[phase_id]
                                                   └─ MessageController.show_by_id(message_id)
```

- **施动者唯一**：LevelManager。Boss 不知道消息存在，只发信号。
- **数据在关卡**：发哪条消息由 `BossSegment.phase_message_ids` 决定，改数据不动代码。
- 本次切片数据示例：`{2: "eye_phase_2"}`（转进 Phase 2 时发"气息变得更强了……"）。

## 组件职责

### LevelDefinition（Resource，新文件）
- `@export var segments: Array[LevelSegment]`

### LevelSegment（Resource，基类，新文件）
- `@export var type: String`（本次只有 "boss" 分支；未知类型 LevelManager 警告并跳过）

### BossSegment（Resource，新文件）
- `boss_scene` / `spawn_position` / `entrance_delay` / `summoned_enemy_scenes` /
  `phase_message_ids`

### LevelManager（新文件，根节点脚本）
- `@export var level_definition: LevelDefinition`
- `_ready()`：null 则警告并 return；否则按顺序 `_consume_segments()`。
- `_consume_segments()`：遍历 segments，按 `type` 分发（本次只有 `_spawn_boss()`）。
- `_spawn_boss()`：`await entrance_delay` → 实例化 `boss_scene` → `add_child` →
  注入召唤列表 → 连接 `phase_changed` / `died` / `entrance_finished`。
- `_on_boss_phase_changed(phase_id)`：查 `BossSegment.phase_message_ids`，命中则
  `get_first_node_in_group("message_controllers").show_by_id(...)`。
- `_on_boss_died()`：结算入口占位（本次不做实现）。

### Boss（现有 `boss_base.gd`，增量改动）
- 已有：PhaseMachine / 阶段 / 血条 / 信号（died, phase_changed）——保持。
- 新增：`summonable_enemy_scenes` + `set_summonable_enemy_scenes()` +
  `summon_enemy(scene_index)`（能力接口，无触发时机）。
- 新增：`entrance_finished` 信号（入场动画/IntroPhase 播完时 emit；本次是否接线视
  演出 stage 而定，先保留信号出口）。

### MessageController（现有，增量改动）
- 新增：`const GROUP_NAME: String = "message_controllers"` + `_ready` 里
  `add_to_group(GROUP_NAME)`；`message_layer.tscn` 根节点静态声明 group（双保险，
  同 BulletLayer）。

## 数据流

```
LevelManager._ready
  → 读 level_definition（null → 警告并 return）
    → _consume_segments() 遍历 segments
      → [BossSegment] await entrance_delay
          → 实例化 boss_scene，add_child，设 spawn_position
            → 注入 summoned_enemy_scenes → 连接信号
              → Boss._ready 自动启动 IntroPhase（入场）
                → phase_changed(2) → LevelManager 查 phase_message_ids[2]="eye_phase_2"
                    → MessageController.show_by_id("eye_phase_2")
                → died → LevelManager 结算占位
```

## 错误处理与边界

- `level_definition` 未设置 / 为 null：LevelManager 警告并 return，不崩溃。
- `boss_scene` 实例失败 / segments 为空 / 未知 segment type：警告并跳过该段，不崩溃。
- `phase_message_ids` 未命中 phase_id：静默跳过（不是错误，该阶段本就无消息）。
- `message_controllers` group 缺失：警告并跳过发消息，不崩溃。
- Boss 出窗 / 玩家 OOB：维持现状（不在本次范围）。

## 测试

无 GDScript LSP，当前项目靠 Godot headless 加载验证。本次改 `.tscn` 与新增 `.tres` /
资源，验证方式：`godot --headless --quit-after 30` 启动主场景无解析报错，确认 Boss 由
LevelManager 实例化、转阶段（Phase 1 → Phase 2）时消息链路触发。

## 明确不做（防范围蔓延）

- 不做 `CanvasModulate` / 背景层 / 环境音 / WorldEnvironment（下一 stage）。
- 不做掉落物、死亡结算、Boss flag。
- 不做入场/死亡消息接线（本次只接**转阶段**消息链路；入场/死亡消息留演出 stage）。
- 不做玩家输入锁定调用接线（`set_input_enabled` 已存在，留给演出触发）。
- 不做 `MinionWaveSegment` 实体（本次只有 BossSegment；LevelManager 分发分支已留扩展位）。
