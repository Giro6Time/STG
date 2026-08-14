# 2026-08-14 分数系统设计（Score System）

> 背景：STG 项目已有 GrazeContext（Autoload）统计擦弹并**自持** `graze_score`，
> 但项目没有全局分数容器、没有 Boss 击破分、没有分数 HUD。
> 本 stage 落地方案 1：**ScoreManager（Autoload）作为唯一分数来源**，
> 擦弹分汇入 + Boss 击破分（固定常量）+ 最小分数 HUD。
> 掉物系统、死亡演出、转场衔接均不在本 stage（列入后续计划）。

## 目标

1. 全局唯一分数账本：`add_score / get_score / reset`，跨场景存活（Autoload）。
2. 擦弹分汇入：ScoreManager 监听 `GrazeContext.grazed` 信号自动加分。
3. Boss 击破分：`LevelManager._on_boss_died()` 加固定常量 `1000`。
4. 分数 HUD：顶部居中 Label，监听 `score_changed` 刷新，最小实现。
5. **消除双份计分**：GrazeContext 现有 `graze_score`/`score_per_graze` 职责移交 ScoreManager。

## 设计原则（本设计的依据）

| 原则 | 落地方式 |
|---|---|
| **单一职责 (SRP)** | ScoreManager 只做分数账本；GrazeContext 只做擦弹统计；ScoreHUD 只做显示。评分规则集中在 ScoreManager。 |
| **信息专家** | "每次擦弹加多少分" 由 ScoreManager 持有 `SCORE_PER_GRAZE`；GrazeContext 不关心分。 |
| **依赖倒置 (DIP)** | 上游只依赖信号（抽象事件）不依赖具体类：ScoreManager 监听 `grazed`，HUD 监听 `score_changed`；ScoreManager 不引用任何场景节点。 |
| **开闭 (OCP)** | 新增分数来源 = 新增一处 `add_score()` 调用/信号监听，不改 ScoreManager 内部。 |
| **Tell, Don't Ask** | 调用方 `add_score(amount)` 告知，不读改写。 |
| **最少知识** | LevelManager 只调 ScoreManager 公开接口，不碰 HUD；HUD 不反向引用计分逻辑。 |

## 架构与数据流

```
GrazeContext (统计)
  │  grazed(total_graze, frame_graze_count)   ← 不再带 added_score（评分规则移交）
  ▼
ScoreManager (唯一账本, Autoload)
  │  add_score(frame_graze_count * SCORE_PER_GRAZE)
  │  signal score_changed(score)
  ▼
ScoreHUD (CanvasLayer + Label) → 刷新文本
  ▲
LevelManager._on_boss_died() → ScoreManager.add_score(BOSS_DEFEAT_SCORE)
```

## 关键接口

```gdscript
# Public/score_manager.gd (Autoload: ScoreManager)
signal score_changed(score: int)
const SCORE_PER_GRAZE: int = 10
const BOSS_DEFEAT_SCORE: int = 1000
func add_score(amount: int) -> void   # 负数忽略；加分后广播 score_changed
func get_score() -> int
func reset() -> void                  # 清零并广播（Game Over 重开新一局）
```

```gdscript
# Public/graze_context.gd（改造）
signal grazed(total_graze: int, frame_graze_count: int)   # 删除 added_score 参数
var total_graze: int = 0                                   # 保留统计
# 删除：score_per_graze、graze_score 及其计分逻辑
```

```gdscript
# Scenes/Main/level_manager.gd（改造）
func _on_boss_died() -> void:
    ScoreManager.add_score(ScoreManager.BOSS_DEFEAT_SCORE)
    # 原有占位日志保留
```

## 接入点（改动文件清单）

1. `Public/score_manager.gd`（新建）+ `project.godot` 注册 Autoload `ScoreManager`
2. `Public/graze_context.gd`：删 `score_per_graze`/`graze_score`，`grazed` 去 `added_score` 参数
3. `Scenes/Debug/debug_overlay.gd`：`GrazeContext.graze_score` → `ScoreManager.get_score()`
4. `Scenes/Main/level_manager.gd`：`_on_boss_died()` 加分
5. `Scenes/Main/level_manager.gd`：`_on_player_game_over()` 重载场景前调 `ScoreManager.reset()`（新一局从 0 开始）
6. `Scenes/Score/score_hud.gd` + `score_hud.tscn`（新建）+ 挂入 `Scenes/Main/main.tscn`

## 边界与错误处理

| 情况 | 行为 |
|---|---|
| `add_score` 传负数 | 忽略（记 debug 日志），不产生负分 |
| Game Over 重载场景 | `_on_player_game_over()` 先 `reset()` 再 reload，新一局从 0 开始 |
| Boss died 重复触发 | `die()` 后 `queue_free()`，信号只发一次；LevelManager 每次 `register_boss` 重新连接，天然幂等 |
| 测试场景无 HUD | ScoreHUD 节点缺失时打日志跳过，不崩 |
| 无 GrazeContext（测试隔离） | ScoreManager 监听前判空，Autoload 未注册时跳过连接 |

## 测试策略（沿用项目 smoke test 约定）

`Scenes/Main/Test/score_system_smoke_test.gd + .tscn`，headless 运行：

1. **add_score 累加**：`add_score(100)` → `get_score() == 100`；再 `add_score(50)` → `150`。
2. **负数忽略**：`add_score(-10)` → 分数不变。
3. **score_changed 广播**：监听信号，`add_score` 后收到新值。
4. **reset 清零**：加分后 `reset()` → `0`，且广播。
5. **擦弹汇入**：调 `GrazeContext.request_graze()`（或直发 `grazed`）→ 等帧 → `get_score()` 增加 `count * SCORE_PER_GRAZE`。
6. **Boss 击破分**：模拟 `register_boss` + `boss.die()` → `get_score()` 增加 `BOSS_DEFEAT_SCORE`。
7. 防挂死：`_process` 帧计数硬超时 + `get_tree().quit(0/1)`（与 level_flow_smoke_test 一致）。

## 明确不做（防范围蔓延）

- 不做掉落物系统（Power/点道具/奖残）——B 计划。
- 不做 Boss 死亡演出/清屏——C 计划。
- 不做流程转场/结算界面——D 计划。
- 不美化 HUD 样式（Label 最小实现，UI 统一重做另立任务）。
- 不改 GrazeContext 的 `request_graze` 入口与擦弹判定逻辑。
- 不重构 `debug_overlay` 其余部分。
