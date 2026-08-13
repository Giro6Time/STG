# Level Flow v2 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重做关卡数据结构与 LevelManager 推进模型：段三维度（start_delay / await_signal / completion），支持波次重叠、条件触发、段类型扩展。

**Architecture:** `LevelSegment` 基类携带三维度字段，`SegmentCompletion` 为独立 Resource（OR 语义完成条件）。`LevelManager` 改为"扫描段 → start_delay 计时 → 激活条件检查 → 类型分发执行 → completion 推进"的模型，Boss 段阻塞（等 boss_died）、MinionWaveSegment 非阻塞（completion=null）。`Enemy` 新增 died 信号支撑 `wait_group_empty`。

**Tech Stack:** Godot 4.7.1 / GDScript（Resource 数据驱动）

## Global Constraints

- 游戏窗口 640x720 固定窗口；`CollisionLayers` 常量在 `res://Public/collision_layers.gd`；玩法脚本禁止写碰撞层魔法数字。
- 新增注释用中文，解释设计意图；私有变量/方法用前导下划线；类名 PascalCase；常量 UPPER_SNAKE_CASE。
- 可选节点用 `get_node_or_null()` 或空值检查；group 查找用 `get_first_node_in_group()`。
- Godot 可执行文件：`D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- headless 验证命令：`& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" <场景或 --quit-after N>`
- 项目无 GDScript 单测框架；测试走 headless + `print()`/`quit(0/1)` 冒烟场景（参考 `Scenes/Player/Test/player_lifecycle_smoke_test.gd` 模式：`call_deferred` + `_check` + `quit`）。
- `debug_log()` 只写内存日志不打印控制台；冒烟测试必须用 `print()`。
- 不自动 push/开 PR；每任务 commit。
- Spec：`docs/superpowers/specs/2026-08-13-level-flow-v2-design.md`（已确认，不 review 直接实现）。

---

### Task 1: `SegmentCompletion` 完成条件资源类

**Files:**
- Create: `Public/level/segment_completion.gd`

**Interfaces:**
- Consumes: 无
- Produces: `class_name SegmentCompletion extends Resource`，字段 `wait_time: float` / `await_signal: String` / `wait_group_empty: String` / `wait_messages_done: bool`。Task 2（LevelSegment 持有）、Task 6（LevelManager 判断）依赖。

- [ ] **Step 1: 创建 `segment_completion.gd`**

```gdscript
class_name SegmentCompletion
extends Resource

# 关卡段的完成条件：多字段任一满足即完成（OR 语义）。
# 全部为空时视为"立即完成"（等价于 completion 为 null 的非阻塞行为）。

## 等 N 秒后完成（0 = 不用时间条件）。
@export var wait_time: float = 0.0
## 等某信号后完成（如 "boss_died"）；空字符串 = 不用。
@export var await_signal: String = ""
## 等某 group 节点清空后完成（如 "enemies"）；空字符串 = 不用。
@export var wait_group_empty: String = ""
## 等 MessageController 消息流播完后完成。
@export var wait_messages_done: bool = false


# 判断是否存在任何有效完成条件。
func is_empty() -> bool:
	return wait_time <= 0.0 \
		and await_signal.is_empty() \
		and wait_group_empty.is_empty() \
		and not wait_messages_done
```

- [ ] **Step 2: headless 验证加载**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `SCRIPT ERROR` / `Parse Error`，退出码 0。新类未引用，行为无变化。

- [ ] **Step 3: Commit**

```bash
git add Public/level/segment_completion.gd
git commit -m "feat: SegmentCompletion 完成条件资源（OR 语义，四字段）"
```

---

### Task 2: `LevelSegment` 基类升级（段三维度）

**Files:**
- Modify: `Public/level/level_segment.gd`

**Interfaces:**
- Consumes: `SegmentCompletion`（Task 1）
- Produces: `LevelSegment` 新增字段 `start_delay: float = 0.0`、`await_signal: String = ""`、`completion: SegmentCompletion`。Task 3（MinionWave 继承）、Task 5（Boss 继承）、Task 6（LevelManager 读取）依赖。

- [ ] **Step 1: 重写 `level_segment.gd`**

```gdscript
class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 按类型分发消费。
# 段三维度：开始时机(start_delay) / 激活条件(await_signal) / 完成语义(completion)。
# 新增段类型 = 继承本类 + LevelManager 加一个分发分支。

## 段类型标识（Inspector 直观区分，也用于日志与分发）。
@export var type: String = ""

## 相对"上一段触发"后延迟 N 秒才开始本段（0 = 立即）。
@export var start_delay: float = 0.0

## 激活条件：等某信号才触发本段（空字符串 = 不等待）。
## 与 completion.await_signal 的区别：这是"开始"条件，completion 里是"完成"条件。
@export var await_signal: String = ""

## 完成语义：null 或空 = 非阻塞（触发即完成，不等待）。
## 非空 = 阻塞，等 OR 条件任一满足才推进下一段。
@export var completion: SegmentCompletion


# 判断本段是否为非阻塞（无有效完成条件即触发即完成）。
func is_non_blocking() -> bool:
	return completion == null or completion.is_empty()
```

- [ ] **Step 2: headless 验证加载**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误。现有 BossSegment 继承不受影响（新字段有默认值）。

- [ ] **Step 3: Commit**

```bash
git add Public/level/level_segment.gd
git commit -m "feat: LevelSegment 基类升级（start_delay/await_signal/completion 三维度）"
```

---

### Task 3: `Enemy` 新增 died 信号 + `MinionWaveSegment`

**Files:**
- Modify: `Scenes/Enemy/enemy_base.gd`
- Create: `Public/level/minion_wave_segment.gd`

**Interfaces:**
- Consumes: `LevelSegment`（Task 2）
- Produces:
  - `Enemy` 新增 `signal died`（在 `die()` 中 emit，`queue_free` 前）
  - `class_name MinionWaveSegment extends LevelSegment`，字段 `enemy_scene: PackedScene` / `count: int = 0` / `spawn_interval: float = 0.5` / `spawn_positions: Array[Vector2]`
  - `MinionWaveSegment.get_enemy_scene() -> PackedScene`、`get_spawn_count() -> int`、`get_spawn_interval() -> float`、`get_spawn_positions() -> Array[Vector2]`
  - Task 6（LevelManager 执行波次）、Task 7（wait_group_empty 依赖 Enemy.died）依赖。

- [ ] **Step 1: `enemy_base.gd` 新增 died 信号**

在 `class_name Enemy` 声明后、现有导出前新增：

```gdscript
# 敌人死亡信号：用于关卡段完成条件（wait_group_empty）计数与结算钩子。
signal died
```

在 `die()` 方法（当前第 58-60 行，`queue_free()` 前）新增 emit：

```gdscript
func die() -> void:
	died.emit()
	queue_free()
```

- [ ] **Step 2: 创建 `minion_wave_segment.gd`**

```gdscript
class_name MinionWaveSegment
extends LevelSegment

# 小怪波次段：声明本波刷什么敌人、刷多少、何时刷。非阻塞（completion 默认 null），
# 触发即完成，配合 start_delay 形成并行波次（不等待上一波清空）。

## 本波次生成的敌人场景。
@export var enemy_scene: PackedScene
## 本波次敌人总数。
@export var count: int = 0
## 相邻敌人生成间隔（秒）。
@export var spawn_interval: float = 0.5
## 生成位置列表（世界坐标）；为空时默认在屏幕顶部随机。
@export var spawn_positions: Array[Vector2] = []


func get_enemy_scene() -> PackedScene:
	return enemy_scene


func get_spawn_count() -> int:
	return count


func get_spawn_interval() -> float:
	return spawn_interval


func get_spawn_positions() -> Array[Vector2]:
	return spawn_positions
```

- [ ] **Step 3: headless 验证加载**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误。

- [ ] **Step 4: Commit**

```bash
git add Scenes/Enemy/enemy_base.gd Public/level/minion_wave_segment.gd
git commit -m "feat: Enemy died 信号 + MinionWaveSegment 波次段（非阻塞）"
```

---

### Task 4: `MessageController.is_busy()` 查询能力

**Files:**
- Modify: `Scenes/Message/message_controller.gd`

**Interfaces:**
- Consumes: 现有 `_queue` 与 MessageBox 的 `is_busy()`（MessageBox 已有该方法）
- Produces: `MessageController.is_busy() -> bool`（队列非空或当前消息框忙）。Task 6（wait_messages_done）依赖。

- [ ] **Step 1: 新增 `is_busy()` 方法**

在 `MessageController` 类中新增（放在 `clear_queue()` 附近）：

```gdscript
# 消息系统是否仍忙：队列未清空或消息框正在显示。供关卡段完成条件轮询。
func is_busy() -> bool:
	if _queue.size() > 0:
		return true
	if _message_box != null and _message_box.is_busy():
		return true
	return false
```

- [ ] **Step 2: headless 验证加载**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误。新方法未调用，行为无变化。

- [ ] **Step 3: Commit**

```bash
git add Scenes/Message/message_controller.gd
git commit -m "feat: MessageController.is_busy() 消息流查询（关卡完成条件用）"
```

---

### Task 5: `BossSegment` 适配新基类

**Files:**
- Modify: 无（仅验证）

**Interfaces:**
- Consumes: `LevelSegment`（Task 2）
- Produces: `BossSegment` 保留全部现有字段（继承三维度）。Task 6 依赖其 `boss_scene` / `spawn_position` / `phase_message_ids` / `summoned_enemy_scenes` / `entrance_delay`。

- [ ] **Step 1: 确认 BossSegment 兼容性（不改代码）**

现有 `boss_segment.gd` 继承 `LevelSegment`（Task 2 加了字段），自动获得三维度。`entrance_delay` 保留为 Boss 特有字段（入场演出等待）。无代码改动。

- [ ] **Step 2: headless 验证加载**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误；`level_001.tres` 中的 BossSegment 正常加载（`type = "boss"` 与三维度默认值兼容）。

---

### Task 6: `LevelManager` 推进模型重构（核心）

**Files:**
- Modify: `Scenes/Main/level_manager.gd`

**Interfaces:**
- Consumes: `LevelSegment` 三维度（Task 2）、`MinionWaveSegment`（Task 3）、`BossSegment`（Task 5）、`MessageController.is_busy()`（Task 4）、`Enemy.died`（Task 3）
- Produces:
  - `_run_segment(segment: LevelSegment) -> void`（按类型分发：BossSegment → `_spawn_boss`，MinionWaveSegment → `_spawn_wave`，未知 → 警告跳过）
  - `_wait_for_completion(segment: LevelSegment) -> void`（异步等待 completion OR 条件）
  - `_wait_for_activate(segment: LevelSegment) -> void`（等待 start_delay + await_signal 激活条件）
  - 信号映射表 `_get_signal_holder(signal_name: String) -> Node`
  - `_await_signal_once(signal_name: String) -> void`、`_on_completion_signal(_arg = null)`、`_completion_signal_received: bool`
  - 保留 `_connect_player_signals` / `_on_player_died` / `_on_player_game_over` / `_on_boss_phase_changed` 不变

- [ ] **Step 1: 重写 `_consume_segments` 为三段式推进**

把 `_consume_segments()` 替换为：

```gdscript
# 按顺序消费每个流程段：等待激活 → 执行段动作 → 等待完成（非阻塞段立即推进）。
func _consume_segments() -> void:
	for segment in level_definition.segments:
		if segment == null:
			continue
		await _wait_for_activate(segment)
		_run_segment(segment)
		await _wait_for_completion(segment)
```

- [ ] **Step 2: 新增 `_run_segment` 类型分发**

```gdscript
# 按段类型分发执行动作；未知类型警告并跳过。
func _run_segment(segment: LevelSegment) -> void:
	if segment is BossSegment:
		await _spawn_boss(segment as BossSegment)
	elif segment is MinionWaveSegment:
		_spawn_wave(segment as MinionWaveSegment)
	else:
		DebugState.debug_log("LevelManager: 未知关卡段类型 '%s'，跳过" % segment.type, "Level")
```

- [ ] **Step 3: 新增 `_wait_for_activate`（start_delay + await_signal）**

```gdscript
# 等待段激活条件：start_delay 计时（相对上一段触发）后，等待 await_signal 信号。
# await_signal 为空则只等 start_delay。
func _wait_for_activate(segment: LevelSegment) -> void:
	if segment.start_delay > 0.0:
		await get_tree().create_timer(segment.start_delay).timeout

	if not segment.await_signal.is_empty():
		await _await_signal_once(segment.await_signal)
```

- [ ] **Step 4: 新增 `_get_signal_holder` 信号映射表**

```gdscript
# 信号名 → 持有者节点映射。Resource 不持有场景对象，LevelManager 维护映射。
# 新增信号名 = 这里加一行。
func _get_signal_holder(signal_name: String) -> Node:
	match signal_name:
		"boss_died":
			return boss
		"boss_phase_changed":
			return boss
		_:
			return null
```

- [ ] **Step 5: 新增 `_wait_for_completion`（OR 语义）与信号等待**

```gdscript
# 等待段完成：非阻塞（无有效 completion）立即返回；阻塞则 OR 条件任一满足即返回。
# 防死锁：wait_time 超时兜底，wait_group_empty 轮询带上限。
func _wait_for_completion(segment: LevelSegment) -> void:
	if segment.is_non_blocking():
		return

	var completion: SegmentCompletion = segment.completion

	if completion.wait_time > 0.0:
		await get_tree().create_timer(completion.wait_time).timeout
		return

	if not completion.await_signal.is_empty():
		await _await_signal_once(completion.await_signal)
		return

	if not completion.wait_group_empty.is_empty():
		await _await_group_empty(completion.wait_group_empty)
		return

	if completion.wait_messages_done:
		await _await_messages_done()
		return

	# completion 存在但全空：视为立即完成（防御）。
	DebugState.debug_log("LevelManager: 完成条件为空，立即推进", "Level")


# 等待某信号触发一次。信号名 → 实际信号通过 _get_signal_holder + match 解析。
func _await_signal_once(signal_name: String) -> void:
	var signal_holder: Node = _get_signal_holder(signal_name)
	if signal_holder == null:
		DebugState.debug_log(
			"LevelManager: 信号 '%s' 未注册，视为立即完成" % signal_name,
			"Level"
		)
		return

	_completion_signal_received = false
	match signal_name:
		"boss_died":
			if not signal_holder.died.is_connected(_on_completion_signal):
				signal_holder.died.connect(_on_completion_signal)
			await _completion_signal_waiter()
		"boss_phase_changed":
			if not signal_holder.phase_changed.is_connected(_on_completion_signal):
				signal_holder.phase_changed.connect(_on_completion_signal)
			await _completion_signal_waiter()
		_:
			DebugState.debug_log("LevelManager: 信号 '%s' 未处理" % signal_name, "Level")


# 轮询等待完成信号接收标志（信号回调置位）。
func _completion_signal_waiter() -> void:
	while not _completion_signal_received:
		await get_tree().process_frame


# 完成信号回调：设置接收标志。
func _on_completion_signal(_arg = null) -> void:
	_completion_signal_received = true
```

- [ ] **Step 6: 新增 `_await_group_empty` 与 `_await_messages_done`**

```gdscript
# 轮询等待某 group 清空；带上限（默认 60 秒）防死锁。
func _await_group_empty(group_name: String) -> void:
	var elapsed: float = 0.0
	while get_tree().get_nodes_in_group(group_name).size() > 0:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		if elapsed > 60.0:
			DebugState.debug_log(
				"LevelManager: 等待 group '%s' 清空超时，强制推进" % group_name,
				"Level"
			)
			return


# 轮询等待消息流播完（MessageController.is_busy）。
func _await_messages_done() -> void:
	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	if controller == null:
		DebugState.debug_log("LevelManager: 找不到 message_controllers，跳过消息等待", "Level")
		return

	while controller.is_busy():
		await get_tree().create_timer(0.1).timeout
```

- [ ] **Step 7: 新增 `_spawn_wave` 波次执行**

```gdscript
# 执行小怪波次：按间隔依次生成敌人。非阻塞（completion=null），触发即完成。
func _spawn_wave(segment: MinionWaveSegment) -> void:
	var scene: PackedScene = segment.get_enemy_scene()
	if scene == null:
		DebugState.debug_log("LevelManager: 波次 enemy_scene 为空，跳过", "Level")
		return

	var positions: Array[Vector2] = segment.get_spawn_positions()
	var count: int = segment.get_spawn_count()

	for index in range(count):
		if index > 0 and segment.get_spawn_interval() > 0.0:
			await get_tree().create_timer(segment.get_spawn_interval()).timeout

		var enemy_node: Node = scene.instantiate()
		if positions.size() > 0:
			enemy_node.position = positions[index % positions.size()]
		else:
			enemy_node.position = Vector2(
				randf_range(32.0, 608.0),
				-32.0
			)
		add_child(enemy_node)
		DebugState.debug_log("LevelManager: 波次生成敌人 %d/%d" % [index + 1, count], "Level")
```

- [ ] **Step 8: 新增状态变量 `_completion_signal_received`**

在 `var boss: Boss` 附近新增：

```gdscript
# 完成信号接收标志：供 _completion_signal_waiter 轮询。
var _completion_signal_received: bool = false
```

- [ ] **Step 9: headless 验证主场景加载**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 120
```
Expected: 无 `SCRIPT ERROR` / `Parse Error`。`level_001.tres` 的 BossSegment 正常消费，现有 Boss 战流程行为不变。

- [ ] **Step 10: Commit**

```bash
git add Scenes/Main/level_manager.gd
git commit -m "feat: LevelManager 推进模型重构（三段式：激活/执行/完成 + 类型分发 + 波次）"
```

---

### Task 7: 冒烟测试（推进模型行为验证）

**Files:**
- Create: `Scenes/Main/Test/level_flow_smoke_test.gd`
- Create: `Scenes/Main/Test/level_flow_smoke_test.tscn`

**Interfaces:**
- Consumes: 全部 Task 1-6 产物
- Produces: 自动化验证：非阻塞段立即推进、start_delay 生效、Boss 段阻塞至 died、wait_group_empty 生效。

- [ ] **Step 1: 创建测试脚本 `level_flow_smoke_test.gd`**

```gdscript
extends Node

# 关卡推进模型冒烟测试：验证 LevelManager 的三段式推进。
# 覆盖：非阻塞段立即推进、start_delay 生效、completion.await_signal 阻塞至信号、
# wait_group_empty 生效。使用 print() 输出（debug_log 不打印控制台）。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const SEGMENT_SCRIPT: GDScript = preload("res://Public/level/level_segment.gd")
const COMPLETION_SCRIPT: GDScript = preload("res://Public/level/segment_completion.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/Enemy/enemy_base.tscn")

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_manager = Node2D.new()
	_manager.set_script(LEVEL_MANAGER_SCRIPT)
	add_child(_manager)

	# 测试 1：MinionWaveSegment 生成敌人
	var wave: MinionWaveSegment = MINION_WAVE_SCRIPT.new()
	wave.enemy_scene = ENEMY_SCENE
	wave.count = 3
	wave.spawn_interval = 0.05
	wave.spawn_positions = [Vector2(100, 100), Vector2(200, 100), Vector2(300, 100)]
	_manager._spawn_wave(wave)
	await get_tree().create_timer(0.3).timeout
	_check(get_tree().get_nodes_in_group("enemies").size() == 3,
		"波次生成 3 个敌人，实际 %d" % get_tree().get_nodes_in_group("enemies").size())

	# 清理测试敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await get_tree().process_frame

	# 测试 2：wait_group_empty 完成条件（空 group 立即完成）
	var seg: LevelSegment = SEGMENT_SCRIPT.new()
	var comp: SegmentCompletion = COMPLETION_SCRIPT.new()
	comp.wait_group_empty = "enemies"
	seg.completion = comp
	_manager.level_definition = LevelDefinition.new()
	_manager.level_definition.segments = [seg]
	_manager._wait_for_completion(seg)
	await get_tree().create_timer(0.3).timeout
	_check(true, "空 group 的 wait_group_empty 立即完成（无异常即通过）")

	# 测试 3：_get_signal_holder 映射
	var fake_holder: Node = Node.new()
	_manager.boss = fake_holder
	_check(_manager._get_signal_holder("boss_died") == fake_holder, "boss_died 映射到 boss 节点")
	_check(_manager._get_signal_holder("unknown") == null, "未注册信号返回 null")

	if _failures.is_empty():
		print("Level flow smoke test passed: %d checks" % _check_count)
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error("Level flow smoke test failed: %s" % failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failures.append(message)
```

- [ ] **Step 2: 创建测试场景 `level_flow_smoke_test.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Scenes/Main/Test/level_flow_smoke_test.gd" id="1_test"]

[node name="LevelFlowSmokeTest" type="Node"]
script = ExtResource("1_test")
```

- [ ] **Step 3: headless 运行测试**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" res://Scenes/Main/Test/level_flow_smoke_test.tscn
```
Expected: `Level flow smoke test passed: N checks`。若失败，修复测试或实现（注意：若 enemy_base.tscn 不在预期路径，用 `glob` 确认实际路径并修正 preload；`_spawn_wave` 内 `add_child` 的敌人若缺场景结构报错，测试只验证生成数量即可）。

- [ ] **Step 4: Commit**

```bash
git add Scenes/Main/Test/level_flow_smoke_test.gd Scenes/Main/Test/level_flow_smoke_test.tscn
git commit -m "test: Level Flow 推进模型冒烟测试（波次/完成条件/信号映射）"
```

---

### Task 8: `level_001.tres` 适配 + 文档

**Files:**
- Modify: `data/levels/level_001.tres`
- Create: `docs/level_flow.md`

**Interfaces:**
- Consumes: 全部任务产物

- [ ] **Step 1: 更新 `level_001.tres`（Boss 段设 completion）**

把 `data/levels/level_001.tres` 整个替换为（Boss 段阻塞至 Boss 死亡）：

```
[gd_resource type="Resource" script_class="LevelDefinition" load_steps=6 format=3]

[ext_resource type="Script" path="res://Public/level/level_definition.gd" id="1_define"]
[ext_resource type="Script" path="res://Public/level/level_segment.gd" id="2_seg"]
[ext_resource type="Script" path="res://Public/level/boss_segment.gd" id="3_boss"]
[ext_resource type="PackedScene" uid="uid://2r1iin0pml1l" path="res://Scenes/Boss/boss_base.tscn" id="4_boss_scene"]
[ext_resource type="Script" path="res://Public/level/segment_completion.gd" id="5_completion"]

[sub_resource type="Resource" id="Resource_completion"]
script = ExtResource("5_completion")
await_signal = "boss_died"

[sub_resource type="Resource" id="Resource_boss_seg"]
script = ExtResource("3_boss")
type = "boss"
boss_scene = ExtResource("4_boss_scene")
entrance_delay = 0.5
spawn_position = Vector2(316, 134)
phase_message_ids = {2: &"eye_phase_2"}
completion = SubResource("Resource_completion")

[resource]
script = ExtResource("1_define")
segments = Array[ExtResource("2_seg")]([SubResource("Resource_boss_seg")])
```

- [ ] **Step 2: 创建 `docs/level_flow.md` 里程碑文档**

内容要点（按项目文档约定：为什么这么设计，不写文件清单）：
- 段三维度模型（start_delay / await_signal / completion）与各自职责
- OR 完成条件语义 + 防死锁保障
- 波次重叠原理（非阻塞 + start_delay 并行）
- 信号映射表约定（LevelManager 维护，新增信号名加一行）
- 段类型扩展方式（继承 + 分发分支）
- flag 系统留扩展点（required_flag 将来放条件段子类）

- [ ] **Step 3: 最终 headless 回归**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 120
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" res://Scenes/Main/Test/level_flow_smoke_test.tscn
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" res://Scenes/Player/Test/player_lifecycle_smoke_test.tscn
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" res://Scenes/Player/Test/gameover_reload_integration_test.tscn
```
Expected: 全部无解析错误，冒烟测试全通过。

- [ ] **Step 4: Commit**

```bash
git add data/levels/level_001.tres docs/level_flow.md
git commit -m "feat: level_001 配 Boss 段完成条件 + 关卡流程里程碑文档"
```
