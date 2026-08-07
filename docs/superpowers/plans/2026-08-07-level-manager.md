# LevelManager 关卡加载重构 Implementation Plan（修订版）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把关卡从 `main.tscn` 静态钉死 `BossBase` 改成：根节点 `LevelManager` 读取 `LevelDefinition`（含 `segments` 流程段序列）按顺序实例化关卡内容，并真跑通"Boss 转阶段 → 发消息"链路。

**Architecture:** 关卡数据模型 = 有序段序列 `LevelDefinition.segments: Array[LevelSegment]`（本次只有 `BossSegment` 子类，为将来"小怪→Boss→小怪"插花留扩展位）。三层边界——`LevelSegment/BossSegment`（Resource，只声明内容）、`LevelManager`（根节点脚本，负责顺序消费段、实例化、驱动场景级演出）、`Boss`（自身行为 + 信号广播，不持有场景级引用）。

**Tech Stack:** Godot 4.x + GDScript。验证走 `--headless` 启动主场景确认无解析错误、Boss 由 LevelManager 实例化、转阶段消息触发。

## Global Constraints

- 项目实际路径 `D:\Dev\Godot\无聊的飞`，git 仓库在该 `game/` 子目录（外层 `Godot-STG` 是空 git 根，**不要**污染）。
- Godot exe：`D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`。
- GDScript 用中文注释，只解释设计意图/清晰行为，不逐行水注释。
- 不自动 push / 不 commit 除非用户明确要求（每次 Task 只提供 commit 命令，交执行者/用户决定是否执行）。
- 改 `.tscn`/`.tres`/`project.godot` 格外谨慎，保留 Godot 生成的 UID / resource id / 引用。
- `BulletLayer.GROUP_NAME = "bullet_layers"`；`DebugState.debug_log(msg, tag)`。
- 现有消息 id：`eye_intro_warning` / `eye_phase_2` / `eye_defeated`（位于 `data/messages/messages_zh.json`）。
- 不做背景/夜晚/Environmental（下一 stage）、不做掉落/死亡结算/Boss flag、不做入场与死亡消息接线、不做玩家输入锁定实际接线。
- 尚未创建目录：`Public/level/`、`data/levels/`（需在 Task 1 创建）。

---

### Task 1: 新建关卡数据模型（LevelSegment 基类 + BossSegment + LevelDefinition + 样例资产）

**Files:**
- Create: `Public/level/level_segment.gd`
- Create: `Public/level/boss_segment.gd`
- Create: `Public/level/level_definition.gd`
- Create: `data/levels/level_001.tres`

**Interfaces:**
- Produces: `LevelSegment`（`extends Resource`，`@export var type: String`）。
- Produces: `BossSegment`（`extends LevelSegment`），导出 `boss_scene: PackedScene`、`spawn_position: Vector2`、`entrance_delay: float`、`summoned_enemy_scenes: Array[PackedScene]`、`phase_message_ids: Dictionary`。
- Produces: `LevelDefinition`（`extends Resource`，`@export var segments: Array[LevelSegment]`）。
- Produces: `data/levels/level_001.tres` —— 含一个 `BossSegment`（`boss_scene=boss_base.tscn`、`spawn_position=(316,134)`、`entrance_delay=0.5`、`phase_message_ids={2:"eye_phase_2"}`），后续 Task 3/4 引用它。

- [ ] **Step 1: 创建目录**

```powershell
New-Item -ItemType Directory -Force -Path "D:\Dev\Godot\无聊的飞\Public\level"
New-Item -ItemType Directory -Force -Path "D:\Dev\Godot\无聊的飞\data\levels"
```

- [ ] **Step 2: 写 `level_segment.gd`**

```gdscript
class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 按 type 分发消费；新段类型继承本类并自定义字段。
@export var type: String = ""
```

- [ ] **Step 3: 写 `boss_segment.gd`**

```gdscript
class_name BossSegment
extends LevelSegment

# Boss 登场段：声明本段要实例化哪个 Boss、何时入场、可召唤的敌人与转阶段消息。
@export var boss_scene: PackedScene
## 入场前等待。本次控制"何时把 Boss 加入场景树"（真实入场动画留给演出 stage）。
@export var entrance_delay: float = 0.0
## Boss 出生位置（屏幕坐标）。
@export var spawn_position: Vector2 = Vector2.ZERO
## 召唤敌人声明。本次只承载数据并提供能力接口，真正波次时机留到以后。
@export var summoned_enemy_scenes: Array[PackedScene] = []
## 转阶段消息映射：phase_id -> 消息 id（写入 messages_zh.json）。LevelManager 在转阶段时触发。
@export var phase_message_ids: Dictionary = {}
```

（说明：`type = "boss"` 会在 `.tres` 里显式设置，而非代码默认——让 LevelSegment 基类不预设类型字符串，由子类/资产声明。）

- [ ] **Step 4: 写 `level_definition.gd`**

```gdscript
class_name LevelDefinition
extends Resource

# 关卡全流程声明：一个有序的流程段列表。Boss/敌人/演出都作为"段"出现，可插花、可重复。
@export var segments: Array[LevelSegment] = []
```

- [ ] **Step 5: 写样例关卡资产 `level_001.tres`**

```
[gd_resource type="Resource" script_class="LevelDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://Public/level/level_definition.gd" id="1_define"]
[ext_resource type="Script" path="res://Public/level/level_segment.gd" id="2_seg"]
[ext_resource type="Script" path="res://Public/level/boss_segment.gd" id="3_boss"]
[ext_resource type="PackedScene" uid="uid://2r1iin0pml1l" path="res://Scenes/Boss/boss_base.tscn" id="4_boss_scene"]

[sub_resource type="Resource" id="Resource_boss_seg"]
script = ExtResource("3_boss")
type = "boss"
boss_scene = ExtResource("4_boss_scene")
entrance_delay = 0.5
spawn_position = Vector2(316, 134)
phase_message_ids = {2: &"eye_phase_2"}

[resource]
script = ExtResource("1_define")
segments = Array[ExtResource("2_seg")]([SubResource("Resource_boss_seg")])
```

（注意 `phase_message_ids` 用 `&"eye_phase_2"` StringName 可读性好；若 Godot 报类型，改为普通字符串 `"eye_phase_2"`。） `summoned_enemy_scenes` 留空数组（默认即可，不用写进 .tres）。

- [ ] **Step 6: 验证资源可正常加载**

```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```

Expected: 项目加载无 `LevelSegment` / `BossSegment` / `LevelDefinition` / `level_001.tres` 解析或资源错误（仅仓库原有 pre-existing warning 可忽略）。

- [ ] **Step 7: Commit（可选，仅用户要求）**

```bash
git add Public/level/
git add data/levels/level_001.tres
git commit -m "feat: 关卡段数据模型 (LevelSegment/BossSegment/LevelDefinition)"
```

---

### Task 2 — 给 MessageController 加 group 查找

**Files:**
- Modify: `Scenes/Message/message_controller.gd`
- Modify: `Scenes/Message/message_layer.tscn`

**Interfaces:**
- Produces: `MessageController.GROUP_NAME = "message_controllers"`，`_ready` 时加入该 group。
- Produces: `message_layer.tscn` 根节点静态声明 `groups=["message_controllers"]`（双保险，早于任何 `_ready`，兼容后续 LevelManager 用 group 查找）。

- [ ] **Step 1: 读当前 `message_controller.gd` 与 `message_layer.tscn`**

确认现有 class 声明与节点结构。`message_controller.gd` 类名是 `MessageController`，`message_layer.tscn` 根节点是 `CanvasLayer` 名为 `MessageLayer`。

- [ ] **Step 2: 在 `message_controller.gd` 加 group**

在类顶部（`class_name` / `extends` 之后）加：

```gdscript
const GROUP_NAME: String = "message_controllers"
```

并在 `_ready()` 开头加：

```gdscript
	add_to_group(GROUP_NAME)
```

（与 `bullet_layer.gd` 保持同样的"静态声明 + 运行时 add_to_group 兜底"双保险模式，兼容代码实例化无 .tscn 场景。）

- [ ] **Step 3: 在 `message_layer.tscn` 根节点静态声明 group**

把根节点：

```
[node name="MessageLayer" type="CanvasLayer" unique_id=1405286134]
layer = 40
```
改为：
```
[node name="MessageLayer" type="CanvasLayer" unique_id=1405286134]
layer = 40
groups = ["message_controllers"]
```

- [ ] **Step 4: 验证加载无错误**

```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `message_controller.gd` / `message_layer.tscn` 解析错误。

- [ ] **Step 5: Commit（可选）**

```bash
git add Scenes/Message/message_controller.gd Scenes/Message/message_layer.tscn
git commit -m "feat: MessageController 支持 group 查找"
```

---

### Task 3: 给 Boss 增加召唤能力接口与入场完成信号

**Files:**
- Modify: `Scenes/Boss/boss_base.gd`

**Interfaces:**
- Consumes: `BossSegment.summoned_enemy_scenes`（由 Task 4 的 LevelManager 注入给 Boss）。
- Produces: Boss 新增 `signal entrance_finished`、`@export var summonable_enemy_scenes: Array[PackedScene]`、`set_summonable_enemy_scenes(scenes)`、`summon_enemy(scene_index) -> Enemy`。

- [ ] **Step 1: 在信号区加 `entrance_finished`**

将 `boss_base.gd` 信号区（现 `signal died` 附近）加：

```gdscript
signal entrance_finished
```

- [ ] **Step 2: 在导出变量区加召唤列表**

在 `bullet_scene` 导出附近加：

```gdscript
## 本场战斗可召唤的敌人场景；由 LevelManager 依据 BossSegment 注入，本次只提供能力借口，不设时机。
@export var summonable_enemy_scenes: Array[PackedScene] = []
```

- [ ] **Step 3: 在类末尾追加两个方法**

```gdscript
# 由外部（LevelManager）注入本次可召唤的敌人场景列表。
func set_summonable_enemy_scenes(scenes: Array[PackedScene]) -> void:
	summonable_enemy_scenes = scenes


# 召唤一个敌人：从召唤列表取指定场景实例化为 owner 挂入父节点（即关卡），避免跟随 Boss 移动。
func summon_enemy(scene_index: int = 0) -> Enemy:
	if scene_index < 0 or scene_index >= summonable_enemy_scenes.size():
		return null
	var scene: PackedScene = summonable_enemy_scenes[scene_index]
	if scene == null:
		return null
	var enemy: Enemy = scene.instantiate() as Enemy
	if enemy == null:
		return null
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(enemy)
	return enemy
```

- [ ] **Step 4: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `boss_base.gd` 解析 / 类型错误。此刻 `summon_enemy` 无调用方，属预期。

- [ ] **Step 5: Commit（可选）**

```bash
git add Scenes/Boss/boss_base.gd
git commit -m "feat: Boss 增加召唤能力接口与入场完成信号"
```

---

### Task 4: 新建 `LevelManager` 根节点脚本（含段消费与转阶段消息）

**Files:**
- Create: `Scenes/Main/level_manager.gd`

**Interfaces:**
- Consumes: `LevelDefinition` / `BossSegment`（字段见 Task 1）、`Boss` 信号（phase_changed/died/entrance_finished）、`MessageController.show_by_id(id)`、group `message_controllers`。
- Produces: 可被 `main.tscn` 根节点挂载的类型（`extends Node2D`），导出 `level_definition: LevelDefinition`。

- [ ] **Step 1: 写 `level_manager.gd`**

```gdscript
extends Node2D
class_name LevelManager

# 关卡装配器：读取 LevelDefinition，顺序消费流程段并实例化内容。
# LevelManager 只在"何时叫 Boss / 何时发消息"，Boss 只提供动作与信号，双方不互相持有 UI/背景/玩家引用。

@export var level_definition: LevelDefinition

## 当前 BossSegment 的转阶段消息映射（phase_id -> message_id），由当前段配置而来。
var _phase_message_ids: Dictionary = {}

var boss: Boss


# 按关卡配置异步装配：null 则警告并返回。
func _ready() -> void:
	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_consume_segments()


# 按顺序处理每个流程段；本次只有 boss 段，未知类型警告并跳过。
func _consume_segments() -> void:
	for segment in level_definition.segments:
		if segment is BossSegment:
			await _spawn_boss(segment as BossSegment)
		else:
			DebugState.debug_log(
				"LevelManager: 未知关卡段类型 '%s'，跳过" % (segment.type if segment else "null"),
				"Level"
			)


# 等待入场延迟后实例化 Boss、注入召唤列表并连接所需信号。
func _spawn_boss(segment: BossSegment) -> void:
	if segment.boss_scene == null:
		DebugState.debug_log("LevelManager: boss_scene 为空，跳过本段", "Level")
		return

	await get_tree().create_timer(segment.entrance_delay).timeout

	var boss_node: Node = segment.boss_scene.instantiate()
	boss_node.position = segment.spawn_position
	add_child(boss_node)

	if boss_node is Boss:
		boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(segment.summoned_enemy_scenes)
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.died.connect(_on_boss_died)
		# entrance_finished: 本次保留出口信号，接入真实解锁/演出留给演出 stage。

	# 记录本段的转阶段消息映射，供 phase_changed 时查询。
	_phase_message_ids = segment.phase_message_ids

	DebugState.debug_log("LevelManager: 已实例化 Boss", "Level")


# Boss 转阶段：若该阶段在 BossSegment 配置了消息，则通过 MessageController 发送。
# 数据在关卡配置里，LevelManager 只是"转发"。
func _on_boss_phase_changed(phase_id: int) -> void:
	var msg_id: String = str(_phase_message_ids.get(phase_id, ""))
	if msg_id.is_empty():
		return

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	if controller == null:
		DebugState.debug_log("LevelManager: 找不到 message_controllers，跳过消息 %s" % msg_id, "Level")
		return

	controller.show_by_id(msg_id)


# Boss 死亡：结算入口占位（掉物/恢复/flag 留演出 stage）。
func _on_boss_died() -> void:
	DebugState.debug_log("LevelManager: Boss 死亡，结算入口待接入", "Level")
```

- [ ] **Step 2: 验证加载无错误**

Run:
```powershell
cd C:\Users\31391\Documents\Godot-STG   # 或 D:\Dev\Godot\无聊的飞
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 项目加载无 `level_manager.gd` 解析错误。（本 Task 尚未把该脚本挂到 Main，只验证脚本可解析。）

- [ ] **Step 3: Commit（可选）**

```bash
git add Scenes/Main/level_manager.gd
git commit -m "feat: 新增 LevelManager 根节点关卡装配器（含段消费与转阶段消息）"
```

---

### Task 5: 改造 `main.tscn`

**Files:**
- Modify: `Scenes/Main/main.tscn`

**Interfaces:**
- Consumes: `Scenes/Main/level_manager.gd`（根脚本）、`data/levels/level_001.tres`（根节点配置导出）。
- Produces: 根节点 `Main` 挂脚本并 `level_definition = ExtResource(level_001.tres)`，移除静态 `BossBase`。

- [ ] **Step 1: 读当前 `main.tscn` 全文**

确认现有资源引用 id（`1_1r6ip` Player、`2_lixft` BulletLayer、`4_debug` DebugOverlay、`5_debug_draw` DebugDrawLayer、`6_message_layer` MessageLayer），以及 `3_boss`（BossBase 的 ext_resource，将删除）。

- [ ] **Step 2: 修改 `main.tscn`**

1. 删除 `[ext_resource type="PackedScene" uid="uid://2r1iin0pml1l" path="res://Scenes/Boss/boss_base.tscn" id="3_boss"]`。
2. 在 `[ext_resource]` 块末尾追加：
   ```
   [ext_resource type="Script" path="res://Scenes/Main/level_manager.gd" id="7_level_manager"]
   [ext_resource type="Resource" path="res://data/levels/level_001.tres" id="8_level_001"]
   ```
3. 根节点改为：
   ```
   [node name="Main" type="Node2D"]
   script = ExtResource("7_level_manager")
   level_definition = ExtResource("8_level_001")
   ```
   （注意：LevelManager 导出变量是 `level_definition`，保持与脚本一致。）
4. 删除 `[node name="BossBase" parent="." ...]` 整行。
5. 其余基础设施（Player/BulletLayer/DebugDrawLayer/MessageLayer/DebugOverlay）保留。

- [ ] **Step 3: 运行主场景确认 Boss 由 LevelManager 实例化**

Run:
```powershell
cd "D:\Dev\Godot\无聊的飞"
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `main.tscn`/`level_manager.gd`/`level_001.tres` 解析错误；运行中无 `BossBase` 静态依赖报错。

- [ ] **Step 4: 手动验证转阶段消息链路（可选，非必须）**

跑几秒（按玩家真实战斗推进到 Phase 2 判定 `eye_phase_2` 是否出现）。无法自动完成时说明已做静态验证与代码路径审查。

- [ ] **Step 5: Commit（可选）**

```bash
git add Scenes/Main/main.tscn Scenes/Main/level_manager.gd data/levels/level_001.tres Public/level/ data/levels/
git commit -m "feat: 用 LevelManager+LevelSegment 取代静态 Boss 装配并接转阶段消息"
```

---

### 收尾验收（非独立任务）

- [ ] **回读 `main.tscn` 确认无 BossBase 静态节点、根节点 script 与配置已挂、Player/BulletLayer/Debug/Message 保留。**
- [ ] **确认 `viewport`/尺寸 640x720、Player 等基础设施没被破坏。**
- [ ] **运行主场景，确认 Boss 在 `entrance_delay` 后出现、阶段正常推进（Intro→Phase1→Phase2），且 Phase2 触发 `eye_phase_2` 消息（若可观察）。**
- [ ] **（用户要求时）写 `docs/level_manager.md` 记录本系统与后续波次/演出扩展边界。默认不写文档（用户要求才写）。**