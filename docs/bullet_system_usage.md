# 弹幕系统使用说明

本文档说明重做后的弹幕发射系统（统一模型：空间 × 时间 × 单位），方便后续 VibeCoding 时快速接手。

## 设计核心

弹幕发射被拆成三个正交维度，各自独立可配：

- **空间**：一颗子弹的初始位置从哪来 → 参数曲线（`ParametricCurve`）+ 参数采样器（`ParameterSampler`）。
- **时间**：什么时候发射一轮 → 时间采样器（`TimelineDriver`）。
- **单位**：每颗子弹生成后怎么动 → 运动策略（`BulletMotion`）。

三者通过 `BulletPatternConfig`（Resource 多态）组装成 `BossBulletPattern`，数据只存参数，行为由类型决定。

## 快速上手：跑通测试场景

从 Godot 编辑器直接运行：

```text
res://Scenes/Bullet/Test/danmaku_test.tscn
```

场景自动扫描 `res://data/danmaku_tests/*.tres`，列表展示全部用例，可直接切换查看。

操作：

| 按键 | 作用 |
|---|---|
| ← / → | 上一个 / 下一个用例 |
| R | 重新播放当前用例 |
| C | 单曲循环开关 |
| Tab | 隐藏 / 显示 UI 面板 |
| 搜索框 | 输入关键字过滤，回车播放第一个匹配 |

## 核心入口：BulletPatternConfig

位置：`res://Public/emitter/bullet_pattern_config.gd`

一个 `.tres` 配置就是一个完整弹幕。关键字段：

| 字段 | 含义 |
|---|---|
| `display_name` / `duration` | 显示名 / 演示时长 |
| `origin_mode` | 坐标系：`BOSS_LOCAL`（Boss 位置）、`WORLD_ABSOLUTE`（世界坐标）、`PLAYER_POSITION`（玩家位置） |
| `origin_offset` | 在选定坐标系上的偏移 |
| `curve` / `sampler` | 空间：发射分布形状与采样 |
| `timeline` | 时间：轮次节奏 |
| `direction_mode` | 子弹方向预设（见 BulletSpawnRule） |
| `bullet` | 子弹行为（见 BulletBehaviorConfig） |
| `sub_shape` | 内层子形状（套娃，见下文） |
| `angle_increment_per_round` / `radius_increment_per_round` | 每轮演化：旋转角度 / 半径缩放 |

`build(owner_node)` 把配置变成可运行的 `BossBulletPattern`，返回后调用 `start_pattern(owner)` 开始播放。

## 空间层：曲线与采样器

### 曲线（`res://Public/curve/`）

| 类 | 用途 | 关键字段 |
|---|---|---|
| `ParametricCurve` | 基类：`sample(t)` 映射局部坐标，`tangent(t)` 默认差分近似 | — |
| `CircleParametricCurve` | 圆形 | `radius`、`angle_offset_degrees` |
| `FormulaCurve` | 表达式曲线（`Expression` 求值，变量 `t`、`r`） | `x_expr`、`y_expr`、`radius` |
| `PointCurve` | 常数点 | `point` |
| `CompositeCurve` | 多曲线合成（ADD/MAX 等） | `curves`、`combine_mode` |
| `TransformCurve` | 通用变换包装（旋转/缩放/偏移/相位），演化只碰这层字段 | `base`、`rotation_degrees`、`scale`、`offset`、`phase_offset` |

### 采样器（`res://Public/sampler/`）

| 类 | 用途 | 关键字段 |
|---|---|---|
| `ParameterSampler` | 基类：产生参数 `t` 列表 | — |
| `UniformParameterSampler` | 均匀采样 | `start_t`、`end_t`、`sample_count`、`include_end` |

## 时间层：TimelineDriver

位置：`res://Public/emitter/timeline/`

| 类 | 用途 | 关键字段 |
|---|---|---|
| `TimelineDriver` | 基类：时间采样器，与空间 sampler 同构 | `initial_delay`（初始等待） |
| `RepeatTimelineDriver` | 均匀轮次 | `rounds`（≤0 无限）、`interval`、循环变量 `var_names`/`var_inits`/`var_increments`（对应 LuaSTG taskrepeat Var 1-4） |

`tick(delta)` 返回 `true` 表示本轮触发（调用方执行发射）。

## 单位层：BulletMotion

位置：`res://Public/emitter/motion/`

| 类 | 用途 | 关键字段 |
|---|---|---|
| `BulletMotion` | 基类：每颗子弹的运动策略 | — |
| `LinearMotion` | 匀速 / 匀加速直线 | `speed`、`acceleration` |
| `BurstTwoStageMotion` | 两段式：先爆发后巡航 | `burst_speed`、`burst_acceleration`、`burst_duration`、`cruise_speed`、`cruise_acceleration` |
| `FollowCurveMotion` | 沿曲线运动 | `curve`、`speed` |

子弹本体 `BulletBase`（`res://Scenes/Bullet/BulletBase/bullet_base.gd`）只做生命周期（生成/回收/碰撞/擦弹），运动学完全委托给 `BulletMotion`。

## 发射规则与执行器

位置：`res://Public/emitter/`

| 类 | 职责 |
|---|---|
| `BulletSpawnRule` | 决定每颗子弹的方向预设并生成：`direction_mode` 支持 `CURVE_TANGENT`（沿曲线切线）、`FROM_ORIGIN`（径向向外）、`AIM_PLAYER`（瞄准玩家）、`FIXED`（固定方向）、`RANDOM_JITTER`（随机抖动）；另有 `bullet_speed`/`acceleration`/`damage`/`bullet_lifetime`/`jitter_degrees` |
| `PatternEmitter` | 执行发射：`emission_mode` 支持 `BURST_ALL`（全量一轮）与 `STREAM`（逐颗）；`emit_once` 返回本轮子弹数组（套娃用） |

## 子弹行为配置：BulletBehaviorConfig

位置：`res://Public/emitter/bullet_behavior_config.gd`

| 字段 | 含义 |
|---|---|
| `bullet_scene` | 子弹场景（唯一持有者，经 `config.build` 注入 emitter） |
| `motion` | 运动策略实例 |
| `damage` / `bullet_lifetime` | 伤害 / 存活时间 |

## 套娃：sub_shape

`BulletPatternConfig.sub_shape` 可嵌套另一个 `BulletPatternConfig`，实现 2 层递归发射：

- 外层每轮生成的**每颗母弹**会绑定一个内层子 pattern（`_bind_sub_shapes`）。
- 内层 origin **每帧跟随母弹位置**，用内层自己的 `curve`/`sampler`/`timeline` 从母弹身上持续发射。
- 母弹被回收（对象池）时，内层子 pattern 自动停止并释放（`recycled` 信号）。

典型效果：外层母弹向下移动，内层每 0.12s 从母弹当前位置喷一圈子弹并沿径向散开 → 一个向下移动且不断扩大的圆圈。演示见 `data/danmaku_tests/nested_ring.tres`（外层 FormulaCurve 单轮母弹 + 内层圆环）。

## 示例：新建一个弹幕用例

1. 在 Godot FileSystem 面板 `data/danmaku_tests/` 右键新建 Resource，选择 `BulletPatternConfig`。
2. 配置 `curve`（如 `CircleParametricCurve`）、`sampler`（如 `UniformParameterSampler`）、`timeline`（如 `RepeatTimelineDriver`）、`bullet`（`BulletBehaviorConfig`，`bullet_scene` 拖入番茄子弹 `TomatoBullet.tscn`）。
3. 需要演化时填 `angle_increment_per_round` / `radius_increment_per_round`（自动包一层 `TransformCurve`）。
4. 保存为 `.tres`，运行测试场景即可自动出现。

参考现有用例：`data/danmaku_tests/` 下的 8 个演示（旋转环 / 螺旋 / 花朵 / 瞄准扇形 / 扩散波 / burst 两段式 / 沿曲线 / 套娃环）。

## 模式层与宿主

- `BossAttackPattern`（`res://Scenes/Boss/patterns/attack/boss_attack_pattern.gd`）：泛"Boss 攻击行为"骨架，只放通用生命周期，不放弹幕字段。
- `BossBulletPattern`（同目录）：弹幕模式，is-a 继承，持有 curve/sampler/timeline/emitter，驱动每轮发射与套娃。
- 均继承 `FlowPattern`（`res://Public/flow/flow_pattern.gd`），遵循 start/update/stop 生命周期，宿主通过 `start_pattern(owner)` 注入。

## 未来拓展点

- 不均匀节奏：新建 `UnevenTimelineDriver extends TimelineDriver`。
- 分段节奏：新建 `PhasedTimelineDriver`。
- 更复杂运动：新建 `BulletMotion` 子类。
- 更多曲线形状：新建 `ParametricCurve` 子类。
- 更深递归（3 层以上）：配置层 `sub_shape` 已支持递归嵌套，放开即可。
