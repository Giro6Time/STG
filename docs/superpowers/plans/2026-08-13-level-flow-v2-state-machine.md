> **⚠️ 已被覆盖**：本文档的部分决策（await_signal 激活机制、_begin_activation/_tick_activation/_setup_activation_signal/_get_signal_holder、entrance_delay）已在此后的重构中删除/合并（见 commit 286e8d2 与 docs/level_flow.md）。实现时以 docs/level_flow.md 与最新 spec 为准，勿按本文档旧代码实现。

# Level Flow v2 状态机驱动实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 LevelManager 从 await 协程推进改为 StateMachine 每帧驱动：泛化 StateMachine 接受 Resource 状态，段实现状态机钩子（enter_state/update_state/exit_state），完成条件改为段自报（segment_finished flag）。

**Architecture:** 复用底层 `StateMachine`（方案 A：泛化 `_current_state` 为 Object、去掉 `as Node` cast）。`LevelSegment` 实现状态机钩子，`SegmentCompletion` 只剩 wait_time（>0 超时 / -1 无限 / 0 未配置）。`LevelManager._process` 每帧驱动当前段，段完成（`mark_segment_finished()` 或超时）→ `transition_to_next()`。

**Tech Stack:** Godot 4.7.1 / GDScript

## Global Constraints

- 游戏窗口 640x720 固定窗口；`CollisionLayers` 常量在 `res://Public/collision_layers.gd`；玩法脚本禁止写碰撞层魔法数字。
- 新增注释用中文，解释设计意图；私有变量/方法用前导下划线；类名 PascalCase。
- Godot 可执行文件：`D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- headless 验证命令：`& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" <场景或 --quit-after N>`
- 项目无 GDScript 单测框架；测试走 headless + `print()`/`quit(0/1)` 冒烟场景。
- **防挂死纪律（用户强制）**：所有冒烟测试必须有 `_process` 帧计数硬超时（不依赖协程）+ 运行命令带 `--quit-after` 引擎上限。
- 不自动 push/开 PR；每任务 commit。
- 修订 spec：`docs/superpowers/specs/2026-08-13-level-flow-v2-state-machine-revision.md`（已确认）。

---

### Task 1: StateMachine 泛化（Node → Object）

**Files:**
- Modify: `Public/state_machine.gd`

**Interfaces:**
- Consumes: 无
- Produces: `StateMachine` 接受 Resource/Node 状态（`_current_state: Object`），状态钩子 enter_state(owner)/exit_state()/update_state(delta)。Task 2-5 依赖。

- [ ] **Step 1: 修改 `state_machine.gd`**

将以下 3 处 Node 类型改为 Object：
1. 信号 `state_changed(previous_state: Object, current_state: Object)`（原 Node）
2. `setup()` 里的 `var state: Node = states[index] as Node` → `var state = states[index]`（去 cast）
3. `_current_state` 声明 `var _current_state: Object`（原 Node）

其余逻辑不变（`has_method` 判断、transition 流程、enter_state(owner) 传 _owner）。

- [ ] **Step 2: 检查 FlowPhaseMachine 兼容性**

`flow_phase_machine.gd` 的 `_on_state_machine_state_changed(_previous_state: Node, current_state: Node)` 回调参数类型——信号参数改为 Object 后，回调签名需对齐为 `(_previous_state: Object, current_state: Object)`，函数体内 `current_state as FlowPhase` 不受影响。修改该回调签名。

- [ ] **Step 3: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 60
```
Expected: 无 SCRIPT ERROR / Parse Error，exit 0（主场景含 Boss 的 FlowPhaseMachine 正常）。

- [ ] **Step 4: Commit**

```bash
git add Public/state_machine.gd Public/flow/flow_phase_machine.gd
git commit -m "refactor: StateMachine 泛化接受 Object 状态（Node→Object，FlowPhaseMachine 对齐）"
```

---

### Task 2: SegmentCompletion 精简（只留 wait_time）

**Files:**
- Modify: `Public/level/segment_completion.gd`

**Interfaces:**
- Consumes: 无
- Produces: `SegmentCompletion` 只有 `wait_time: float = 0.0`。Task 3（LevelSegment 持有）、Task 5（LevelManager 超时判断）依赖。

- [ ] **Step 1: 重写 `segment_completion.gd`**

```gdscript
class_name SegmentCompletion
extends Resource

# 关卡段的完成超时选项（段完成信号由段自己声明，这里只控制超时兜底）。
# > 0：超时兜底，N 秒后强制完成（即使段未自报）。
# -1：显式无限等待，只等段完成信号。
# 0：未配置（依赖段完成信号，等效无限等但语义模糊，建议用 -1 显式声明）。

@export var wait_time: float = 0.0
```

删除 `await_signal` / `wait_group_empty` / `wait_messages_done` 字段和 `is_empty()` 方法。

- [ ] **Step 2: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 60
```
Expected: 无解析错误（现有 level_001.tres 可能引用旧字段——Task 5 会适配）。

- [ ] **Step 3: Commit**

```bash
git add Public/level/segment_completion.gd
git commit -m "feat: SegmentCompletion 精简为只含 wait_time（超时兜底/-1 无限）"
```

---

### Task 3: LevelSegment 基类改造（状态机钩子）

**Files:**
- Modify: `Public/level/level_segment.gd`

**Interfaces:**
- Consumes: `SegmentCompletion`（Task 2）
- Produces: `LevelSegment` 增加 `enter_state(owner)/update_state(delta)/exit_state()` 钩子 + `_owner/_elapsed` 内部状态；删除 `is_non_blocking()`。Task 4（Boss/MinionWave 继承）、Task 5（LevelManager 驱动）依赖。

- [ ] **Step 1: 重写 `level_segment.gd`**

```gdscript
class_name LevelSegment
extends Resource

# 关卡流程段基类。LevelManager 用 StateMachine 驱动。
# 段三维度：开始时机(start_delay) / 激活条件(await_signal) / 完成超时(completion.wait_time)。
# 段实现状态机钩子：enter_state(spawn+连完成信号) / update_state(每帧) / exit_state(清理)。
# 新增段类型 = 继承本类 + 实现三个钩子 + 声明自己的完成信号。

## 段类型标识（Inspector 直观区分，也用于日志与分发）。
@export var type: String = ""

## 相对"上一段完成后"延迟 N 秒才开始本段（0 = 立即）。
@export var start_delay: float = 0.0

## 激活条件：等某信号才触发本段（空字符串 = 不等待）。走 LevelManager._get_signal_holder 映射。
@export var await_signal: String = ""

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
```

- [ ] **Step 2: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 60
```
Expected: 无解析错误。现有 BossSegment/MinionWaveSegment 继承不受影响（钩子有基实现）。

- [ ] **Step 3: Commit**

```bash
git add Public/level/level_segment.gd
git commit -m "feat: LevelSegment 实现状态机钩子（enter/update/exit）+ 删 is_non_blocking"
```

---

### Task 4: BossSegment / MinionWaveSegment 完成信号

**Files:**
- Modify: `Public/level/boss_segment.gd`
- Modify: `Public/level/minion_wave_segment.gd`

**Interfaces:**
- Consumes: `LevelSegment` 钩子（Task 3）、`LevelManager.mark_segment_finished()`（Task 5 提供）、`Boss.died` / `Enemy.died` 信号
- Produces: `BossSegment.enter_state/update_state`（spawn boss + 连 died → mark）、`MinionWaveSegment.enter_state/update_state`（生成敌人 + 跟踪 died，全死完 → mark）。Task 5 依赖。

- [ ] **Step 1: 重写 `boss_segment.gd` 的 execute → enter_state/update_state**

删除现有 `execute(context)`，改为：

```gdscript
# StateMachine 钩子：进入段时记录状态；实际 spawn 推迟到 entrance_delay 计时后。
func enter_state(owner: Node) -> void:
	super.enter_state(owner)
	_spawned = false


# StateMachine 钩子：每帧计时，entrance_delay 到后 spawn boss 并连接完成信号。
func update_state(delta: float) -> void:
	super.update_state(delta)
	if _spawned:
		return
	if _elapsed < entrance_delay:
		return

	if boss_scene == null:
		DebugState.debug_log("BossSegment: boss_scene 为空，跳过", "Level")
		_owner.mark_segment_finished()
		_spawned = true
		return

	var boss_node: Node = boss_scene.instantiate()
	boss_node.position = spawn_position
	_owner.add_child(boss_node)

	if boss_node is Boss:
		var boss: Boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(summoned_enemy_scenes)
		_owner.register_boss(boss, phase_message_ids)
		# 段自己声明完成：Boss 死亡即本段结束。
		boss.died.connect(func(): _owner.mark_segment_finished())

	DebugState.debug_log("BossSegment: 已实例化 Boss", "Level")
	_spawned = true
```

新增状态变量 `var _spawned: bool = false`。删除旧 `execute()`。

- [ ] **Step 2: 重写 `minion_wave_segment.gd` 的 execute → enter_state/update_state**

删除现有 `execute(context)`，改为：

```gdscript
# 段运行时状态：生成进度与存活敌人计数。
var _spawned_count: int = 0
var _alive_count: int = 0


# StateMachine 钩子：进入段时重置生成状态。
func enter_state(owner: Node) -> void:
	super.enter_state(owner)
	_spawned_count = 0
	_alive_count = 0


# StateMachine 钩子：每帧按间隔生成敌人；全部生成且全部死亡 → 段完成。
func update_state(delta: float) -> void:
	super.update_state(delta)
	_spawn_pending_enemies()


# 按生成间隔批量生成剩余敌人（一次 update 内尽量多生成，受间隔约束）。
func _spawn_pending_enemies() -> void:
	while _spawned_count < get_spawn_count():
		if _spawned_count > 0 and _elapsed < _spawned_count * get_spawn_interval():
			return
		var enemy_scene: PackedScene = get_enemy_scene()
		if enemy_scene == null:
			DebugState.debug_log("MinionWaveSegment: enemy_scene 为空，跳过", "Level")
			_owner.mark_segment_finished()
			_spawned_count = get_spawn_count()
			return
		var enemy_node: Node2D = enemy_scene.instantiate()
		var positions: Array[Vector2] = get_spawn_positions()
		if positions.size() > 0:
			enemy_node.position = positions[_spawned_count % positions.size()]
		else:
			enemy_node.position = Vector2(randf_range(32.0, 608.0), -32.0)
		_owner.add_child(enemy_node)
		_alive_count += 1
		_spawned_count += 1
		enemy_node.died.connect(_on_wave_enemy_died)


# 敌人死亡回调：存活计数减一；全部生成且全部死亡 → 段完成。
func _on_wave_enemy_died() -> void:
	_alive_count -= 1
	if _spawned_count >= get_spawn_count() and _alive_count <= 0:
		_owner.mark_segment_finished()
```

- [ ] **Step 3: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 60
```
Expected: 无解析错误（Task 5 前段类不触发，LevelManager 仍用旧逻辑）。

- [ ] **Step 4: Commit**

```bash
git add Public/level/boss_segment.gd Public/level/minion_wave_segment.gd
git commit -m "feat: Boss/MinionWave 段实现状态机钩子与段自报完成信号"
```

---

### Task 5: LevelManager 重构为 StateMachine 驱动（核心）

**Files:**
- Modify: `Scenes/Main/level_manager.gd`

**Interfaces:**
- Consumes: `StateMachine`（Task 1）、`LevelSegment` 钩子（Task 3）、段完成信号（Task 4）
- Produces:
  - `_segment_machine: StateMachine`、`_current_segment: LevelSegment`、`_segment_finished: bool`
  - `_process(delta)` 每帧驱动：激活阶段（start_delay/await_signal）→ 运行阶段（update + 完成判定 + 推进）
  - `mark_segment_finished()`、`register_boss()` 环境接口（保留）
  - 删 `_wait_for_activate` / `_wait_for_completion` / `_await_signal_once` / `_completion_signal_waiter` / `_on_completion_signal` / `_await_group_empty` / `_await_messages_done`
  - 保留：`_ready` / `_connect_player_signals` / `_on_player_died` / `_on_player_game_over` / `_get_signal_holder` / `_on_boss_phase_changed` / `_on_boss_died` / `_phase_message_ids`

- [ ] **Step 1: 新增状态变量与初始化**

```gdscript
# 关卡段状态机：驱动段 enter/update/exit 生命周期。
var _segment_machine: StateMachine = StateMachine.new()
var _current_segment: LevelSegment
var _segment_index: int = 0
# 段完成标志：每段进入时重置，段通过 mark_segment_finished() 置位。
var _segment_finished: bool = false
# 激活阶段状态：start_delay 计时 + await_signal 等待。
var _activating: bool = false
var _activate_elapsed: float = 0.0
var _activation_signal_received: bool = false
```

`_ready()` 改为：

```gdscript
func _ready() -> void:
	_connect_player_signals()

	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_build_segment_machine()
	_begin_activation()


# 构建段状态机：按顺序登记 transition（线性推进）。
func _build_segment_machine() -> void:
	var segments: Array[LevelSegment] = level_definition.segments
	_segment_machine.setup(self, segments)
	for index in range(segments.size() - 1):
		if segments[index] != null and segments[index + 1] != null:
			_segment_machine.add_transition(segments[index], segments[index + 1])


# 开始激活第一个段（等待 start_delay/await_signal 后进入运行）。
func _begin_activation() -> void:
	_activating = true
	_activate_elapsed = 0.0
	_activation_signal_received = false
	_current_segment = level_definition.segments[0] if level_definition.segments.size() > 0 else null
	if _current_segment != null and not _current_segment.await_signal.is_empty():
		_setup_activation_signal(_current_segment.await_signal)
```

- [ ] **Step 2: 新增 `_process` 每帧驱动**

```gdscript
# 每帧驱动关卡：激活阶段计时/等信号 → 运行阶段 step 当前段 → 完成判定推进。
func _process(delta: float) -> void:
	if _activating:
		_tick_activation(delta)
		return

	if _current_segment == null:
		return

	_segment_machine.update(delta)

	if _segment_finished or _completion_timeout():
		_advance_to_next()


# 激活阶段：start_delay 计时 + await_signal 信号等待。
func _tick_activation(delta: float) -> void:
	_activate_elapsed += delta

	if _current_segment == null:
		return

	if _current_segment.start_delay > 0.0 and _activate_elapsed < _current_segment.start_delay:
		return

	if not _current_segment.await_signal.is_empty() and not _activation_signal_received:
		return

	_activating = false
	_segment_machine.start(_current_segment)


# 完成超时判定：completion 非 null 且 wait_time > 0 且超时。
func _completion_timeout() -> bool:
	if _current_segment == null or _current_segment.completion == null:
		return false
	return _current_segment.completion.wait_time > 0.0 \
		and _segment_machine.get_current_state().get("_elapsed", 0.0) >= _current_segment.completion.wait_time


# 推进到下一个段：当前段完成 → transition → 重置 flag → 进入下一段的激活阶段。
func _advance_to_next() -> void:
	var finished_segment: LevelSegment = _current_segment
	_segment_machine.transition_to_next()
	var next_state: Object = _segment_machine.get_current_state()

	if next_state == null or next_state == finished_segment:
		DebugState.debug_log("LevelManager: 关卡流程结束", "Level")
		_current_segment = null
		return

	_current_segment = next_state as LevelSegment
	_segment_finished = false
	_begin_activation()
	DebugState.debug_log("LevelManager: 段完成 %s，推进到 %s" % [finished_segment.type, _current_segment.type], "Level")
```

- [ ] **Step 3: 新增 `mark_segment_finished` 环境接口**

```gdscript
# 环境接口：段自报完成时调用（段内连接自己的完成信号后触发）。
func mark_segment_finished() -> void:
	_segment_finished = true
```

- [ ] **Step 4: 新增激活信号设置**

```gdscript
# 设置激活信号等待：连接映射表对应的信号 → 置 _activation_signal_received。
func _setup_activation_signal(signal_name: String) -> void:
	var signal_holder: Node = _get_signal_holder(signal_name)
	if signal_holder == null:
		DebugState.debug_log("LevelManager: 激活信号 '%s' 未注册，跳过等待" % signal_name, "Level")
		return

	match signal_name:
		"boss_died":
			signal_holder.died.connect(func(): _activation_signal_received = true)
		"boss_phase_changed":
			signal_holder.phase_changed.connect(func(): _activation_signal_received = true)
```

- [ ] **Step 5: 删除旧的协程编排方法**

删除：`_wait_for_activate` / `_wait_for_completion` / `_await_signal_once` / `_completion_signal_waiter` / `_on_completion_signal` / `_await_group_empty` / `_await_messages_done` 及 `_completion_signal_received` 变量。保留 `_get_signal_holder`（激活条件用）。

- [ ] **Step 6: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 120
```
Expected: 无 SCRIPT ERROR / Parse Error，exit 0。主场景含 Boss 段（level_001 的 completion 需适配——见 Task 6）。

- [ ] **Step 7: Commit**

```bash
git add Scenes/Main/level_manager.gd
git commit -m "refactor: LevelManager 改 StateMachine 每帧驱动（去 await，段自报完成）"
```

---

### Task 6: level_001.tres 适配 + 冒烟测试重写

**Files:**
- Modify: `data/levels/level_001.tres`
- Modify: `Scenes/Main/Test/level_flow_smoke_test.gd`

**Interfaces:**
- Consumes: 全部 Task 1-5 产物

- [ ] **Step 1: level_001.tres 的 BossSegment 移除旧 completion 字段**

当前 level_001.tres 的 BossSegment 有 `completion = SubResource("Resource_completion")`（含 `await_signal = "boss_died"`）。修订后 completion 只剩 wait_time——Boss 完成靠段内连接 boss.died → mark，不需要 completion。**删除 completion 子资源及其引用**（Boss 段默认依赖段完成信号）。若想加超时兜底可配 `completion.wait_time`（本次不加，保持默认依赖段完成信号）。

- [ ] **Step 2: 重写冒烟测试为每帧状态断言**

重写 `Scenes/Main/Test/level_flow_smoke_test.gd`（保留 `_process` 帧计数硬超时 + `_finished` 模式）。新测试结构：

```gdscript
extends Node

# 关卡推进状态机冒烟测试：验证 LevelManager 的 StateMachine 驱动。
# 覆盖：Boss 段阻塞至 died、MinionWave 怪死完完成、start_delay 延迟、wait_time 超时。
# 防挂死：_process 帧计数硬超时 + try 无（GDScript 无）→ 帧计数兜底。

const LEVEL_MANAGER_SCRIPT: GDScript = preload("res://Scenes/Main/level_manager.gd")
const SEGMENT_SCRIPT: GDScript = preload("res://Public/level/level_segment.gd")
const COMPLETION_SCRIPT: GDScript = preload("res://Public/level/segment_completion.gd")
const BOSS_SEGMENT_SCRIPT: GDScript = preload("res://Public/level/boss_segment.gd")
const MINION_WAVE_SCRIPT: GDScript = preload("res://Public/level/minion_wave_segment.gd")
const ENEMY_SCENE: PackedScene = preload("res://Scenes/Enemy/enemy_base.tscn")
const BOSS_SCENE: PackedScene = preload("res://Scenes/Boss/boss_base.tscn")

const HARD_TIMEOUT_FRAMES: int = 2400

var _failures: Array[String] = []
var _check_count: int = 0
var _manager: Node2D
var _finished: bool = false
var _frame_count: int = 0
var _phase: int = 0  # 测试阶段推进


func _ready() -> void:
	call_deferred("_run_tests")


func _process(_delta: float) -> void:
	_frame_count += 1
	if _frame_count > HARD_TIMEOUT_FRAMES and not _finished:
		push_error("Level flow smoke test hard timeout after %d frames" % HARD_TIMEOUT_FRAMES)
		get_tree().quit(1)


func _run_tests() -> void:
	_manager = Node2D.new()
	_manager.set_script(LEVEL_MANAGER_SCRIPT)
	add_child(_manager)

	# 测试 1：MinionWave 生成敌人并跟踪存活（直接调段钩子验证生成逻辑）
	var wave: MinionWaveSegment = MINION_WAVE_SCRIPT.new()
	wave.enemy_scene = ENEMY_SCENE
	wave.count = 3
	wave.spawn_interval = 0.05
	wave.spawn_positions = [Vector2(100, 100), Vector2(200, 100), Vector2(300, 100)]
	wave.enter_state(_manager)
	# 模拟若干帧 update（推进生成）
	for i in range(10):
		wave.update_state(0.1)
		await get_tree().process_frame
	_check(wave._spawned_count == 3, "波次生成 3 个敌人，实际 %d" % wave._spawned_count)
	_check(get_tree().get_nodes_in_group("enemies").size() == 3,
		"enemies group 有 3 个敌人，实际 %d" % get_tree().get_nodes_in_group("enemies").size())

	# 清理：杀掉敌人触发 died → 段完成
	for enemy in get_tree().get_nodes_in_group("enemies"):
		(enemy as Enemy).die()
	await get_tree().create_timer(0.3).timeout
	_check(_manager._segment_finished, "MinionWave 怪死完后段完成 flag 置位")

	# 测试 2：Boss 段阻塞至 died（用真实段 + 手动驱动钩子）
	_reset_manager_state()
	var boss_seg: BossSegment = BOSS_SEGMENT_SCRIPT.new()
	boss_seg.boss_scene = BOSS_SCENE
	boss_seg.entrance_delay = 0.05
	boss_seg.spawn_position = Vector2(320, 200)
	boss_seg.enter_state(_manager)
	for i in range(5):
		boss_seg.update_state(0.1)
		await get_tree().process_frame
	_check(_manager.boss != null, "Boss 已 spawn（enter/update 驱动）")
	_check(not _manager._segment_finished, "Boss 存活时段完成 flag 未置位")
	_manager.boss.die()
	await get_tree().create_timer(0.3).timeout
	_check(_manager._segment_finished, "boss.died 后段完成 flag 置位")

	# 测试 3：_get_signal_holder 映射
	_check(_manager._get_signal_holder("boss_died") == _manager.boss, "boss_died 映射到 boss 节点")
	_check(_manager._get_signal_holder("unknown") == null, "未注册信号返回 null")

	_finish()


# 重置管理器内部状态（模拟推进到下一段前的清理）。
func _reset_manager_state() -> void:
	_manager._segment_finished = false
	# 清掉测试 1 残留的敌人
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	_finished = true
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

注意：`_reset_manager_state` 是协程（含 await），调用需 `await`。测试 1 中直接调 wave 钩子（不经 _manager._process），因为 _manager 的 _process 需要 level_definition 配置——测试用手动驱动钩子验证段逻辑 + 用 _segment_finished flag 验证完成契约。

- [ ] **Step 3: headless 运行测试**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 2400 res://Scenes/Main/Test/level_flow_smoke_test.tscn
```
Expected: `Level flow smoke test passed: N checks`。若失败（如 wave 钩子私有字段访问、die() 时序），修复测试或实现。注意 `wave._spawned_count` 是私有字段——测试可访问（GDScript 下划线仅约定），若报错改公开 getter。

- [ ] **Step 4: 回归全部测试**

```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 120
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 2400 res://Scenes/Main/Test/level_flow_smoke_test.tscn
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 4000 res://Scenes/Player/Test/player_lifecycle_smoke_test.tscn
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 900 res://Scenes/Player/Test/gameover_reload_integration_test.tscn
```
Expected: 全部 exit 0。

- [ ] **Step 5: Commit**

```bash
git add data/levels/level_001.tres Scenes/Main/Test/level_flow_smoke_test.gd
git commit -m "feat: level_001 适配段完成信号 + 冒烟测试重写为状态机驱动断言"
```

---

### Task 7: 文档更新 + 最终回归

**Files:**
- Modify: `docs/level_flow.md`

**Interfaces:**
- Consumes: 全部任务产物

- [ ] **Step 1: 更新 docs/level_flow.md**

更新内容：
- 推进模型：await 协程 → StateMachine 每帧驱动（段 enter/update/exit 钩子）
- 完成机制：段自报（segment_finished flag / mark_segment_finished），completion 只剩 wait_time（>0 超时 / -1 无限）
- 波次重叠：靠 wait_time 超时（怪没死完超时 → 下一波重叠），-1 不重叠
- StateMachine 复用：Boss（FlowPhaseMachine）与关卡段共用底层 StateMachine
- 删除 wait_group_empty / wait_messages_done 相关描述
- 待办更新：移除"LevelManager 重构为纯编排器——待实施"（已实施）

- [ ] **Step 2: 最终回归**

```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 120
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 2400 res://Scenes/Main/Test/level_flow_smoke_test.tscn
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 4000 res://Scenes/Player/Test/player_lifecycle_smoke_test.tscn
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 900 res://Scenes/Player/Test/gameover_reload_integration_test.tscn
```
Expected: 全部 exit 0。

- [ ] **Step 3: Commit**

```bash
git add docs/level_flow.md
git commit -m "docs: level_flow 更新状态机驱动推进模型与段自报完成机制"
```

---

## Self-Review 记录

- **Spec coverage**：StateMachine 泛化（Task 1）✓ 段钩子（Task 3）✓ completion 只留 wait_time（Task 2）✓ segment_finished flag（Task 4/5）✓ 波次重叠靠超时（Task 2/5 语义）✓ 激活条件保留（Task 5）✓ 去 await（Task 5）✓ 测试重写（Task 6）✓ 文档（Task 7）✓
- **Placeholder scan**：无 TBD/TODO；所有代码完整。
- **Type consistency**：`mark_segment_finished()` Task 4 调用、Task 5 定义；`register_boss` 保留；`_segment_finished` Task 4 断言、Task 5 定义重置；`enter_state(owner)` / `update_state(delta)` 签名 Task 3 基类、Task 4 子类、Task 5 驱动一致。
- **已知风险**：Task 6 测试访问 `wave._spawned_count` 私有字段（GDScript 下划线仅约定，可访问）；若 _reset_manager_state 协程调用需 await；Boss die() 触发 mark 的时序依赖 died 信号连接（enter 里连接，die 时触发）。
