# 2026-08-12 玩家生命周期系统设计（Player Lifecycle）

> 背景：STG 项目"游戏循环"尚未闭合——玩家死亡直接 `queue_free()`，没有残机、无敌帧、
> 重生和死亡清屏。本设计补齐 A1：残机 + 无敌帧 + 死亡重生 + 死亡清屏。
> 范围限定玩家侧；Boss 联动（死亡停火）、HUD/UI、Game Over 界面均不在本 stage。

## 目标

1. 玩家被弹后有明确后果：残机 -1（默认 1 血，被弹即"死"，保留东方 STG 手感）。
2. 死亡后有完整流程：清屏 → 短暂等待 → 固定安全位重生 → 无敌帧保护。
3. 明确边界：**Player 自身行为**（状态机、无敌计时、残机扣减、闪烁）与
   **Player 发布事件由外部执行**（清屏、Game Over 响应）分离。

## 已确认决策

1. **方案 A（Player 自我管理生命周期）**：Player 不销毁自身，内部跑
   "死亡 → 重生"状态机；对外发 `died` / `respawned` / `game_over` 事件，外部负责
   清屏与残机归零判定。不引入外部重新实例化玩家的复杂度。
2. **命体系 = HP 制 + 残机制混合**：保留 `take_damage(damage)` 与 HP 概念，
   叠加残机（lives）。`max_hp` 默认 **1**（被弹即死、残机-1，东方感）；
   结构保留未来血 > 1 的拓展（受伤不死的场景）。
3. **残机扣减时机**：进入死亡状态**立即**扣残机，`died` 事件带出扣减后的剩余
   残机；外部收到一次广播即可决定"重生 or Game Over"，时序干净。
4. **死亡清屏 = `clear_enemy_bullets()`**：仅回收敌方子弹，保留玩家弹继续飞行。
   与 `docs/superpowers/specs/2026-08-10-level-flow-redesign.md` 规划的能力对齐，
   本 stage 实现该能力，胜利清屏后续复用。
5. **通用无敌计时器**：`_invincible_timer` 统一管理，受伤无敌 ~1s / 重生无敌 ~3s
   只是参数；无敌期间玩家闪烁（Sprite 可见性交替）且正常移动射击。
6. **死亡 → 重生时间线**：受击判定 → 血 ≤ 0 进入死亡（隐藏 + 锁输入 + 停止）
   → 等待 ~1.0s → 重生（位置重置固定安全位 `(320, 600)`，恢复满血，
   进入 3s 无敌）→ 解锁输入。
7. **Game Over**：残机耗尽 → Player 销毁自身 + 发 `game_over` 事件；
   外部（A1 暂挂 LevelManager）响应 = 锁输入 + debug 日志 + `reload_current_scene()`。
8. **外部监听者**：A1 最小接入——LevelManager（main.tscn 根）连接 Player 信号。
   信号接口按最终形态设计，Player 不关心监听者是谁；后续 level-flow-redesign
   重构 LevelManager 编排时无缝迁移。
9. **只做玩家侧**：不做 Boss 死亡停火/无敌联动（留给后续 stage）。

## 结构边界

```
Player（自身行为，内部状态机）
├── 受击判定：take_damage() → HP 扣减
│   ├── 血 > 0 → 受伤无敌（1s）继续战斗
│   └── 血 ≤ 0 → 死亡状态
├── 死亡状态：立即残机 -1 → 隐藏 + 锁输入 + 停止
│   └── 发信号 died(lives_left)     ← 事件，外部执行
├── 重生流程：1.0s 延迟 → 固定安全位 (320,600) → 恢复满血 → 3s 无敌 → 解锁输入
│   └── 发信号 respawned            ← 事件，供外部同步
└── 残机耗尽 → 销毁自身 + 发 game_over  ← 事件，外部执行

外部（LevelManager，A1 最小接入）
├── 监听 died → 调 BulletLayer.clear_enemy_bullets()（清敌弹留玩家弹）
├── 监听 died → lives_left > 0 ? 等待重生 : 触发 Game Over
└── 监听 game_over → 锁输入 + 日志 + reload_current_scene()
```

## Player 内部状态

玩家状态用轻量枚举 + 标志位表达，不引入完整状态机类（当前只有一个节点需要）：

| 状态 | 说明 |
|---|---|
| `ALIVE` | 正常游玩，可受伤 |
| `DEAD` | 死亡流程中：隐藏、锁输入、等待重生延迟 |
| （终态） | 残机耗尽：`queue_free()` 销毁自身 + 发 `game_over`，无重生 |

- 无敌帧独立于状态存在：`_invincible_timer > 0` 期间不受伤、闪烁、正常移动射击。
- 受伤但未死（未来血 > 1）：不进入 `DEAD`，仅触发短暂无敌帧。

## 关键接口

```gdscript
# Player 对外信号（最终形态，监听者不关心）
signal died(lives_left: int)        # 进入死亡状态时发出，lives_left 为扣减后剩余
signal respawned                    # 重生完成（位置重置 + 无敌生效）后发出
signal game_over                    # 残机耗尽，Player 即将销毁

# Player 新增导出
@export var max_lives: int = 3      # 初始残机数
@export var respawn_delay: float = 1.0
@export var respawn_position: Vector2 = Vector2(320, 600)
@export var respawn_invincible_time: float = 3.0
@export var hurt_invincible_time: float = 1.0
```

```gdscript
# BulletLayer 新增能力（胜利清屏/死亡清屏共用出口）
func clear_enemy_bullets() -> void  # 仅回收敌方子弹，保留玩家弹
```

## 边界与错误处理

| 情况 | 行为 |
|---|---|
| 无敌期间被弹 | `take_damage()` 直接返回（现有 `DebugState.invincible_enabled` 分支保留） |
| 死亡流程中再次被弹 | 玩家已隐藏，无碰撞；状态机保证不会二次进入死亡 |
| 重生位置在弹幕中 | 重生带 3s 无敌，足够脱离；Boss 联动停火留后续 stage |
| BulletLayer 缺失 | `clear_enemy_bullets()` 判空跳过，不崩溃 |
| 残机耗尽 | Player `queue_free()` + 发 `game_over`；外部重载场景 |

## 测试策略

1. **加载验证**：`godot --headless --quit-after 30` 主场景无解析/资源错误。
2. **流程日志验证**：`DebugState.debug_log` 观察——受击 → 死亡 → `died` →
   清屏 → 重生 → `respawned` → 无敌结束时序。
3. **负向验证**：无敌期间被弹不扣血；死亡流程中不二次死亡；残机耗尽走 Game Over。
4. 无 GDScript LSP，验证走 headless + 日志，不虚报已验证。

## 明确不做（防范围蔓延）

- 不做 HUD/UI（分数、残机显示、Game Over 界面）——用户明确 UI 后期做。
- 不做 Boss 死亡联动（停火/无敌）——留给关卡流程 stage。
- 不做玩家火力系统（Power/子机）——独立 stage。
- 不重构现有 `set_input_enabled` / `take_damage` 调用方。
- 不新建 GameFlow 节点——A1 监听暂挂 LevelManager，level-flow-redesign 时迁移。

## 开放点（已填推荐默认值，待用户否决）

1. **残机初始值**（推荐默认 `max_lives = 3`）：与东方惯例一致；也可配置为 2/4。
2. **重生安全位**（推荐默认 `(320, 600)`）：屏幕中下，避开弹幕密集区。
3. **Game Over 重载方式**（推荐默认 `reload_current_scene()`）：重开当前关卡；
   未来结算界面做好后改为切场景。
