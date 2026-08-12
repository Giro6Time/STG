# 玩家生命周期系统（Player Lifecycle）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 STG 玩家补齐残机、无敌帧、死亡重生、死亡清屏，明确"Player 自身行为"与"Player 发布事件由外部执行"的边界。

**Architecture:** Player 内部持有状态机（ALIVE/DEAD）、残机、HP、统一无敌计时器；对外发 `died(lives_left)` / `respawned` / `game_over` 信号。LevelManager（main.tscn 根）作为 A1 最小外部监听者，响应 `died` 清屏敌弹、响应 `game_over` 重载场景。`BulletLayer` 新增 `clear_enemy_bullets()` 能力（与 level-flow-redesign spec 对齐）。

**Tech Stack:** Godot 4.7.1 / GDScript

## Global Constraints

- 游戏窗口 640x720，固定窗口，`canvas_items` 拉伸。
- `CollisionLayers` 常量在 `res://Public/collision_layers.gd`，`ENEMY_BULLET = 8`。玩法脚本禁止写碰撞层魔法数字。
- 大量运行时对象走对象池；回收时重置状态（可见性、碰撞、动画）。
- Debug 功能默认不影响正常玩法；临时 print 用 `DebugState.debug_log()`。
- 新增到玩法脚本的注释用中文，解释设计意图；不要求每个函数都写注释。
- 私有变量/方法用前导下划线；类名 PascalCase；常量 UPPER_SNAKE_CASE。
- 可选节点用 `get_node_or_null()` 或空值检查。
- Godot 可执行文件：`D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- 验证命令统一：`& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after <N>`（N 为帧数）
- 项目无 GDScript 单测框架，验证走 headless 加载 + `DebugState.debug_log` 日志断言。
- 不自动 push/建 PR；每个任务结束 commit。

---

### Task 1: BulletLayer 新增 `clear_enemy_bullets()` 能力

**Files:**
- Modify: `Scenes/BulletLayer/bullet_layer.gd`（在 `clear_all()` 方法后新增）

**Interfaces:**
- Consumes: `BulletBase.collision_layer`（引擎属性，位掩码）、`BulletBase.recycle()`、`CollisionLayers.ENEMY_BULLET`
- Produces: `BulletLayer.clear_enemy_bullets() -> void` —— 仅回收 `collision_layer` 含 `ENEMY_BULLET` 位的活跃子弹，玩家弹保留。Task 4（LevelManager）依赖此方法。

- [ ] **Step 1: 在 `bullet_layer.gd` 中 `clear_all()` 方法后新增 `clear_enemy_bullets()`**

在 `clear_all()` 方法（当前第 63-68 行）之后插入：

```gdscript
# 仅回收敌方子弹（碰撞层含 ENEMY_BULLET 位），保留玩家弹继续飞行。
# 玩家死亡清屏 / Boss 胜利清屏共用此出口。
func clear_enemy_bullets() -> void:
	for child in active_bullets.get_children():
		if child is BulletBase:
			var bullet: BulletBase = child as BulletBase
			if (bullet.collision_layer & CollisionLayers.ENEMY_BULLET) != 0:
				bullet.recycle()
```

- [ ] **Step 2: headless 验证脚本无解析错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `SCRIPT ERROR` / `Parse Error` 输出，退出码 0。任务仅新增方法未接线，行为无变化。

- [ ] **Step 3: Commit**

```bash
git add Scenes/BulletLayer/bullet_layer.gd
git commit -m "feat: BulletLayer 新增 clear_enemy_bullets()（仅清敌弹，死亡/胜利清屏共用）"
```

---

### Task 2: Player 新增信号、导出与生命周期状态变量

**Files:**
- Modify: `Scenes/Player/player.gd`

**Interfaces:**
- Consumes: 无（本任务只加声明与初始化）
- Produces:
  - 信号 `died(lives_left: int)` / `respawned` / `game_over`
  - 导出 `max_lives: int = 3`、`respawn_delay: float = 1.0`、`respawn_position: Vector2 = Vector2(320, 600)`、`respawn_invincible_time: float = 3.0`、`hurt_invincible_time: float = 1.0`
  - 变量 `lives: int`、`_is_dead: bool`、`_invincible_timer: float`、`_blink_timer: float`
  - 常量 `BLINK_INTERVAL: float = 0.1`

Task 3（死亡/重生逻辑）与 Task 4（LevelManager 接入）依赖这些声明。

- [ ] **Step 1: 修改 `player.gd` 头部：`max_hp` 默认值改为 1，新增信号**

把 `@export var max_hp: int = 3`（第 5 行）改为 `1`，并在类开头（`extends CharacterBody2D` 后、`@export` 前）新增信号声明：

```gdscript
# A1 玩家生命周期：信号由外部监听者（LevelManager）执行清屏与 Game Over 响应。
signal died(lives_left: int)   # 进入死亡状态时发出，lives_left 为扣减后的剩余残机
signal respawned               # 重生完成（位置重置 + 无敌生效）后发出
signal game_over               # 残机耗尽，Player 即将销毁
```

- [ ] **Step 2: 新增 A1 导出变量（放在 `fire_interval` 之后）**

```gdscript
@export var max_lives: int = 3
@export var respawn_delay: float = 1.0
@export var respawn_position: Vector2 = Vector2(320, 600)
@export var respawn_invincible_time: float = 3.0
@export var hurt_invincible_time: float = 1.0
```

- [ ] **Step 3: 新增运行时变量与常量（放在现有 `var hp: int = 0` 附近）**

```gdscript
# A1 玩家生命周期状态
const BLINK_INTERVAL: float = 0.1   # 无敌期间闪烁交替间隔

var lives: int = 0
var _is_dead: bool = false
var _invincible_timer: float = 0.0
var _blink_timer: float = 0.0
```

- [ ] **Step 4: `_ready()` 中初始化 `lives = max_lives`**

在 `_ready()`（当前第 29-33 行）的 `hp = max_hp` 旁新增：

```gdscript
	hp = max_hp
	lives = max_lives
```

- [ ] **Step 5: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误。新变量未接线，行为无变化。

- [ ] **Step 6: Commit**

```bash
git add Scenes/Player/player.gd
git commit -m "feat: Player 声明生命周期信号/导出/状态变量，max_hp 默认改 1"
```

---

### Task 3: Player 无敌帧逻辑（受击无敌 + 闪烁）

**Files:**
- Modify: `Scenes/Player/player.gd`

**Interfaces:**
- Consumes: Task 2 声明的 `_invincible_timer` / `_blink_timer` / `BLINK_INTERVAL` / `hurt_invincible_time`
- Produces: `_update_invincibility(delta: float) -> void`（Task 4 无需感知，Player 内部）

- [ ] **Step 1: 修改 `_process()` 调用无敌帧更新**

把 `_process()`（当前第 65-66 行）改为：

```gdscript
func _process(delta: float) -> void:
	_hurted = false
	_update_invincibility(delta)
```

- [ ] **Step 2: 新增 `_update_invincibility()` 方法（放在 `_process()` 之后）**

```gdscript
# 无敌帧递减与闪烁：无敌期间机身 sprite 交替可见；计时归零时恢复可见。
func _update_invincibility(delta: float) -> void:
	if _invincible_timer <= 0.0:
		return

	_invincible_timer -= delta
	_blink_timer -= delta

	if _blink_timer <= 0.0:
		_blink_timer = BLINK_INTERVAL
		$Sprite2D.visible = not $Sprite2D.visible

	if _invincible_timer <= 0.0:
		_invincible_timer = 0.0
		$Sprite2D.visible = true
```

- [ ] **Step 3: 修改 `take_damage()` 加入无敌与受伤无敌**

把 `take_damage()`（当前第 133-145 行）改为：

```gdscript
# 处理玩家受伤：无敌期间忽略；血 > 0 触发短暂受伤无敌；血 ≤ 0 进入死亡流程。
func take_damage(damage: int) -> void:
	if DebugState.invincible_enabled:
		DebugState.debug_log("Player damage ignored: %d" % damage, "Player")
		return
	if _is_dead or _invincible_timer > 0.0:
		return
	if(_hurted == true): # 同一帧只能受伤一次，为后续清空弹幕做准备 
		return
	_hurted = true
	hp -= damage
	DebugState.debug_log("Player hit: %d/%d (-%d)" % [hp, max_hp, damage], "Player")
	print("Player HP: ", hp)

	if hp <= 0:
		_start_death()
	else:
		# 受伤未死：进入短暂无敌，避免被弹幕连续命中。
		_invincible_timer = hurt_invincible_time
		_blink_timer = 0.0
```

- [ ] **Step 4: 临时加桩 `_start_death()`（Task 4 填充完整流程）**

Task 3 先加桩，让脚本可解析、行为不变（仍走旧 `die()`）：

```gdscript
# 死亡流程入口：Task 4 填充残机扣减/隐藏/重生；当前先保留旧 die() 行为。
func _start_death() -> void:
	die()
```

- [ ] **Step 5: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误。逻辑未接线到死亡流程，行为不变。

- [ ] **Step 6: Commit**

```bash
git add Scenes/Player/player.gd
git commit -m "feat: Player 无敌帧与受伤无敌逻辑（闪烁 + 计时器）"
```

---

### Task 4: Player 死亡 → 重生 → Game Over 完整流程

**Files:**
- Modify: `Scenes/Player/player.gd`

**Interfaces:**
- Consumes: Task 2 全部声明；Task 3 的 `take_damage()` 调用 `_start_death()`
- Produces:
  - `_start_death() -> void`（完整实现：扣残机 → 发 `died` → 隐藏 → 延迟 → 重生或销毁）
  - `_respawn() -> void`（位置重置、满血、3s 无敌、解锁、发 `respawned`）
  - 删除旧 `die()` 方法

- [ ] **Step 1: 用完整实现替换 Task 3 的 `_start_death()` 桩**

```gdscript
# 进入死亡流程：立即扣残机并广播 died（外部执行清屏）；剩余残机大于 0 延迟重生，
# 否则销毁自身并广播 game_over（外部响应重载场景）。
func _start_death() -> void:
	_is_dead = true
	velocity = Vector2.ZERO
	lives -= 1
	DebugState.debug_log("Player died, lives left: %d" % lives, "Player")

	# 隐藏机身与判定点，锁定输入，避免死亡流程中继续移动/射击。
	visible = false
	set_input_enabled(false)

	died.emit(lives)

	if lives <= 0:
		game_over.emit()
		queue_free()
		return

	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(self) or _is_dead == false:
		return
	_respawn()


# 重生：回到固定安全位、恢复满血、进入重生无敌帧并广播 respawned。
func _respawn() -> void:
	_is_dead = false
	position = respawn_position
	hp = max_hp
	visible = true
	$Sprite2D.visible = true
	_invincible_timer = respawn_invincible_time
	_blink_timer = 0.0
	set_input_enabled(true)
	DebugState.debug_log("Player respawned", "Player")
	respawned.emit()
```

- [ ] **Step 2: 删除旧 `die()` 方法（当前第 149-151 行）**

```gdscript
# 玩家死亡时移除自身节点。
func die() -> void:
	queue_free()
```

删除。检查全文确认无其他调用点（Task 3 已把唯一调用点改为 `_start_death()`）。

- [ ] **Step 3: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析错误。运行期死亡流程需 Task 5 接线 LevelManager 后通过日志验证。

- [ ] **Step 4: Commit**

```bash
git add Scenes/Player/player.gd
git commit -m "feat: Player 死亡→重生→GameOver 流程（残机扣减/隐藏/固定位重生/销毁）"
```

---

### Task 5: LevelManager 外部响应接入

**Files:**
- Modify: `Scenes/Main/level_manager.gd`

**Interfaces:**
- Consumes: `Player.died` / `Player.game_over` / `Player.set_input_enabled()`；`BulletLayer.GROUP_NAME`；`BulletLayer.clear_enemy_bullets()`（Task 1）
- Produces: `_connect_player_signals()` / `_on_player_died(lives_left: int)` / `_on_player_game_over()`

- [ ] **Step 1: `_ready()` 中调用玩家信号连接**

把 `_ready()`（当前第 16-21 行）改为：

```gdscript
func _ready() -> void:
	_connect_player_signals()

	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_consume_segments()
```

- [ ] **Step 2: 新增玩家信号连接与响应方法（放在 `_consume_segments()` 之前）**

```gdscript
# 连接玩家生命周期信号：死亡清屏由本管理器响应，Game Over 重载场景。
func _connect_player_signals() -> void:
	var player: Player = get_node_or_null("Player") as Player
	if player == null:
		DebugState.debug_log("LevelManager: 找不到 Player，跳过玩家生命周期接入", "Level")
		return

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if not player.game_over.is_connected(_on_player_game_over):
		player.game_over.connect(_on_player_game_over)


# 玩家死亡：清掉屏幕上的敌方子弹（保留玩家弹），重生安全交由 Player 状态机。
func _on_player_died(_lives_left: int) -> void:
	var layer := get_tree().get_first_node_in_group(BulletLayer.GROUP_NAME) as BulletLayer
	if layer == null:
		DebugState.debug_log("LevelManager: 找不到 bullet_layers，跳过死亡清屏", "Level")
		return

	layer.clear_enemy_bullets()
	DebugState.debug_log("LevelManager: 死亡清屏完成", "Level")


# 玩家残机耗尽：锁输入 + 重载当前场景（未来结算界面接入后改为切场景）。
func _on_player_game_over() -> void:
	DebugState.debug_log("LevelManager: Game Over，重载场景", "Level")

	var player: Player = get_node_or_null("Player") as Player
	if player != null:
		player.set_input_enabled(false)

	get_tree().reload_current_scene()
```

- [ ] **Step 3: headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 60
```
Expected: 无解析错误；日志出现 `LevelManager: 已实例化 Boss`，无脚本错误。

- [ ] **Step 4: Commit**

```bash
git add Scenes/Main/level_manager.gd
git commit -m "feat: LevelManager 接入玩家死亡清屏与 GameOver 重载"
```

---

### Task 6: 里程碑文档更新

**Files:**
- Create: `docs/player_lifecycle.md`

**Interfaces:**
- Consumes: 本计划全部实现内容

- [ ] **Step 1: 编写 `docs/player_lifecycle.md`**

内容要点（按项目里程碑文档约定：写"为什么这么设计"，不写文件清单）：
- 设计动机：死亡原本 `queue_free()`，无后果；A1 补齐残机/无敌/重生/清屏，闭合"能输"循环。
- 结构边界：Player 自身行为（状态机、无敌计时、残机扣减、闪烁）vs Player 发布事件外部执行（`died`→清屏、`game_over`→重载场景）。
- 关键决策：HP+残机混合（`max_hp=1` 默认被弹即死，保留血 >1 拓展）；死亡即扣残机，`died` 一次广播决定重生 or Game Over；`clear_enemy_bullets()` 与 level-flow-redesign 胜利清屏共用出口；统一无敌计时器（受伤 1s/重生 3s 参数化）。
- 信号接口：`died(lives_left)` / `respawned` / `game_over` 最终形态，监听者无关。
- 拓展方向：Boss 死亡联动（停火/无敌）后续 stage；残机/HP 数值配置；Game Over 结算界面。
- 已知取舍：重生位固定 (320,600) 未做弹幕密度避让；Boss 联动不做。

- [ ] **Step 2: headless 验证（最终回归）**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 60
```
Expected: 无解析错误。

- [ ] **Step 3: Commit**

```bash
git add docs/player_lifecycle.md
git commit -m "docs: 玩家生命周期系统说明（残机/无敌/死亡重生/清屏边界）"
```

---

### Task 7: 运行期行为验证（手动）

**Files:** 无（验证任务）

- [ ] **Step 1: 启动游戏手动验证**

Run（非 headless，看窗口）：
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path "D:\Dev\Godot\无聊的飞"
```

Expected 时序（对照 `DebugState.debug_log` 或屏幕表现）：
1. Boss 入场（Phase 1 开始攻击）后，主动撞弹。
2. 日志出现 `Player hit: 0/1 (-1)` → `Player died, lives left: 2`。
3. 屏幕上敌方子弹瞬间清空（玩家弹保留）。
4. 玩家隐藏 ~1 秒后，在 (320,600) 附近重生，机身闪烁约 3 秒后常亮。
5. 日志出现 `Player respawned`。
6. 重复撞弹 3 次（共 4 次死亡，残机 3→0）。
7. 最后一次死亡日志 `Player died, lives left: 0` → `LevelManager: Game Over，重载场景`，场景重载、Boss 重新入场。

- [ ] **Step 2: 无敌帧负向验证**

重生无敌期间撞弹：日志**不应**出现新的 `Player hit`；闪烁结束后再撞弹应正常受伤。

---

## Self-Review 记录

- **Spec coverage**：残机（Task 2/4）✓ 无敌帧（Task 3/4）✓ 死亡重生（Task 4）✓ 死亡清屏（Task 1/5）✓ 外部监听 LevelManager（Task 5）✓ Game Over 重载（Task 5）✓ 文档（Task 6）✓
- **Placeholder scan**：无 TBD/TODO；所有代码块完整。
- **Type consistency**：`died(lives_left: int)` 在 Task 2 声明、Task 4 emit、Task 5 接收，签名一致；`clear_enemy_bullets()` 在 Task 1 定义、Task 5 调用，一致；`_start_death()` Task 3 桩 → Task 4 完整，一致。
