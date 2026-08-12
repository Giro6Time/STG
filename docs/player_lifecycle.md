# 玩家生命周期系统说明

本文说明 A1 引入的玩家生命周期体系：残机、无敌、死亡重生、清屏与 Game Over 的完整闭环。核心目标是让"能被弹打死 → 有代价地重生 → 残机耗尽后 Game Over"形成可玩循环，同时保持系统的边界清晰，便于后续 level-flow-redesign 迁移编排逻辑。

## 设计背景

A1 之前，玩家死亡仅仅是 `queue_free()`，没有后果。打 Boss 失败不会触发任何流程，没有 Game Over，也没有残机概念。这导致游戏缺少"能输"的闭环——玩家只要开了一局，就永远在场上，唯一的退出方式是手动关闭游戏。

A1 的目标不是做一个完整的 Game Over 结算系统，而是用最小接入把"能输"循环闭合。后续 level-flow-redesign 会在 LevelManager 中重新编排 Game Over 流程（结算界面、返回选关等），A1 这里只提供信号出口，不做编排。

## 边界划分

整个生命周期系统有一道明确的边界：**Player 自身行为 vs Player 发布的事件由外部执行**。

### Player 自身行为（内部闭环）

Player 负责自己的状态机和视觉反馈，不关心谁在监听，也不做任何外部副作用。这些行为包括：

- 血量和残机管理：`hp` / `max_hp` / `lives` / `max_lives`
- 无敌计时与闪烁：`_invincible_timer` 和 `_blink_timer` 驱动 sprite 交替可见
- 死亡流程：扣残机 → 隐藏机身 → 锁输入 → 发射 `died` 信号
- 重生流程：回位 → 满血 → 开无敌 → 开输入 → 发射 `respawned` 信号
- Game Over 判断：残机耗尽时发射 `game_over` 信号，然后 `queue_free()`

Player 内部不调 `clear_enemy_bullets()`，不调 `reload_current_scene()`。这些是外部监听者的职责。

### 外部执行（信号 → LevelManager）

`died`、`game_over`、`respawned` 三个信号的监听者目前挂在 LevelManager 上（A1 最小接入方案）。LevelManager 收到信号后执行：

- `died` → 通过 BulletLayer 清掉敌方子弹（`clear_enemy_bullets()`），保留玩家弹继续飞行
- `game_over` → 锁玩家输入 + `reload_current_scene()`
- `respawned` → 当前无额外响应，信号已在接口中预留

这样设计的原因：Player 不关心"死后谁来清屏"、"Game Over 谁来重载"，它只负责发出事件。当前的 LevelManager 只是第一个监听者，后续 level-flow-redesign 可以把游戏流程编排迁移到专门的 GameFlow 节点，Player 的代码不需要任何修改——信号本身就是接口。

## 关键设计决策

### HP + 残机混合体系

默认 `max_hp = 1`，被弹即死、残机减一。这个设计的意图是：

- 当前游戏内容是 Boss 战，一命一残符合 STG 惯例
- `max_hp > 1` 的扩展通道保留：`take_damage()` 在 `hp > 0` 时进入受伤无敌，后续设计多血条 Boss 或特殊机制时不需要重构血量体系

这不是临时的简化，而是有意把"一血即死"当作 `max_hp = 1` 的默认配置，血 > 1 放在拓展方向里自然发生。

### 死亡即扣残机，一次广播决定去向

`_start_death()` 的第一步就是 `lives -= 1`，然后 `died.emit(lives)`。时序是：

```
扣残机 → died 广播（lives 已扣减） → lives > 0 ? 等 respawn_delay 重生 : game_over + queue_free
```

这个时序设计避免了"先广播再扣残机"可能导致的竞态——监听者拿到的是扣减后的值，可以直接判断"这是最后一次死亡还是普通重生"。同时 `game_over` 是一个独立信号，不通过 `died` 的某个特殊值来双重含义，语义清晰。

### 清屏与胜利清屏共用出口

`clear_enemy_bullets()` 通过检测 `collision_layer & ENEMY_BULLET` 位来筛选需回收的子弹，不回收玩家弹。这个方法的设计意图是：

- 玩家死亡清屏和 Boss 胜利清屏（level-flow-redesign 中规划）走同一个逻辑出口
- 避免两套清屏代码产生的行为不一致（比如一边忘回收某类子弹）
- 清屏只做回收，不做销毁，对象池不受影响

### 通用无敌计时器

受伤无敌（1s）和重生无敌（3s）都由同一个 `_invincible_timer` 驱动，闪烁也共用 `_blink_timer`。这不是代码复用洁癖，而是实际需求驱动的：

- 无敌期间 sprite 闪烁是统一的视觉语言，玩家不需要区分"这是受伤无敌还是重生无敌"
- 计时器参数化（`hurt_invincible_time` / `respawn_invincible_time`）允许后续按关卡或难度调整无敌时长
- 无敌期间 `take_damage()` 直接 return，不做血条判定，逻辑清晰

## 信号接口

三个信号按最终形态设计，不依赖任何特定监听者：

| 信号 | 参数 | 触发时机 | 含义 |
|------|------|---------|------|
| `died` | `lives_left: int` | 死亡时，残机已扣减 | "玩家死了一次"，lives_left 是剩余残机数。监听者据此决定重生 or Game Over 等行为 |
| `respawned` | 无 | 重生完成 | "玩家已回位且无敌生效"，可用于 HUD 刷新或演出触发 |
| `game_over` | 无 | 残机耗尽，即将 `queue_free()` | "游戏结束"，Player 即将销毁。监听者应在此之前完成结算或场景切换 |

`died` 的 `lives_left` 参数是扣减后的值，不是扣减前。这是刻意设计的：监听者只需要知道"还剩几条命"，不需要自己再算一次。

## 拓展方向

当前实现刻意留了以下几个拓展点：

- **Boss 死亡联动**：Player 死亡时暂停 Boss 射击 / 让 Boss 无敌 / 清屏，后续 stage 在 LevelManager 的 `_on_player_died()` 中添加对 Boss 的信号调用即可
- **残机 / HP 数值配置**：`max_lives` / `max_hp` / `hurt_invincible_time` / `respawn_invincible_time` 已全部参数化为 `@export`，可直接在 Inspector 或关卡配置中按难度调整
- **Game Over 结算界面**：当前 `_on_player_game_over()` 只做 `reload_current_scene()`，替换为切场景到结算界面只需要改 LevelManager 的一行逻辑，`game_over` 信号无需变动
- **重生位动态选择**：当前 `respawn_position` 固定 (320, 600)，可以扩展为根据弹幕密度或最近的 SafetyZone 动态计算

## 已知取舍

- **重生位固定**：`respawn_position = (320, 600)` 是屏幕中下方，未做弹幕密度避让。这意味着存在重生瞬间被密集弹幕再次击中的风险。已知取舍，后续如有需要可引入 SafetyZone 概念
- **Boss 死亡联动不做**：玩家死亡时 Boss 不会停火或进入无敌。这个交互留后续 stage
- **HUD / UI 不做**：残机显示、Game Over 画面等 UI 不在 A1 范围。用户偏好后期集中做 UI
- **LevelManager 作为临时监听者**：当前 LevelManager 承载了清屏和场景重载逻辑，这是 A1 最小接入的选择。level-flow-redesign 会把游戏流程编排迁移到专门的 GameFlow 节点，LevelManager 届时回归"关卡内容装配"的职责
