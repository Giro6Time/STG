# 2026-08-10 弹幕系统重做设计（推翻重做版）

## 背景与目标

当前 `feature/curve-bullet-optimization` 分支上的弹幕系统"跑起来正确"但**架构语义错误**：
- `BossAttackPattern` 被塞入弹幕专用字段，扭曲了"Boss 攻击行为"的泛语义
- is-a 关系被做成了"修改现有类"，而不是新建类
- 配置用枚举让数据决定行为类型，而不是 Resource 多态

**重做方式**：从分支起点（`a03c34d`，即 develop HEAD）开始，**全部删除现有弹幕代码重写**。
讨论中确认的**正确设计沿用，代码全部重写**。

**设计目标**：
- 类型关系正确（is-a 一律新类，现有类不改）
- 组合优于继承（组件/策略模式）
- 数据只存参数，行为由代码类决定（Resource 多态）
- 职责清晰：Driver 管"何时发"，EmitBehavior 管"每轮发什么"，Pattern 管组装

## 设计范围

本次只重做**弹幕发射相关系统**，不涉及：关卡/LevelManager、PhaseMachine 编排层、玩家、敌人、消息框、音频。

---

## 一、核心统一模型

**发射 = 空间（curve + sampler）× 时间（timeline）× 单位（动作）**

```
空间维度：curve（几何）+ sampler（采样）→ 决定"一组位置"
时间维度：timeline（时间采样器）       → 决定"一组时刻"（dt 序列）
单位维度：每个时刻发射什么（单颗 / 子形状）
```

TimelineDriver 与空间 sampler **同构**：空间 sampler 产生 t 列表（每 t 对应 curve 一点），时间 timeline 产生 dt 序列（多少步、每步多长）。`RepeatTimelineDriver` = 均匀时间采样器，未来 `UnevenTimelineDriver` = 不均匀。

## 二、类层次（类型关系图）

```
BossAttackPattern（泛"Boss 攻击行为"抽象）
│   只放：start/stop/update 骨架、owner 访问（现有 FlowPattern 扩展）
└── BossBulletPattern（弹幕 Pattern —— 弹幕是攻击的一种，is-a）
    ├── origin：坐标原点（config 解析，支持参考系）
    ├── curve：外层形状（ParametricCurve 子类）
    ├── sampler：外层采样（ParameterSampler 子类）
    ├── timeline：发射时间线（TimelineDriver 子类）← 时间采样器
    ├── direction：发射方向（DirectionMode 预设）
    ├── bullet：子弹行为（BulletBehaviorConfig：scene + motion）← 组合
    └── 2 层递归：内层子形状（一组子弹的分布）

TimelineDriver（Resource 基类：时间采样器，管"何时发"）
├── initial_delay（初始等待，通用属性）
├── begin() / tick(delta) / get_round() / is_completed()
└── RepeatTimelineDriver（均匀：次数/间隔/循环变量×4）
    └── 未来：UnevenTimelineDriver 等（继承，不均匀节奏）

BulletMotion（策略基类，沿用现有设计，重写代码）
├── LinearMotion / BurstTwoStageMotion / FollowCurveMotion
```

## 三、职责划分（核心）

| 组件 | 管什么 | 不管什么 |
|---|---|---|
| `TimelineDriver` | **何时**触发（dt 序列，含初始等待） | 发什么、往哪发 |
| `BossBulletPattern` | 组装：持有 curve/sampler/timeline/direction/bullet + 驱动 timeline + 每轮发射 | 具体位置计算以外的逻辑 |
| `BulletMotion` | 子弹**发射后怎么动** | 发射本身 |

**无 EmitBehavior**：每轮动作由"递归单位"表达——每个时间步发射的内容 = 单颗子弹或子形状。用户自定义 = 通过配置组合（形状/方向/时序/行为），极端需求写子类（BulletMotion/Curve/TimelineDriver）。
| `BulletMotion` | 子弹**发射后怎么动** | 发射本身 |
| 配置层 | 存参数 | 决定行为类型 |

**Pattern 零默认实现**：`BossBulletPattern` 只有 `_emit_round` 委托，不含任何内置的角度/半径逻辑。常见行为全在 `EmitBehavior` 组件里，Inspector 选组件 + 填参数即可。

## 三、坐标原点（Origin）

进配置层，支持多种参考系：

```
BulletPatternConfig.origin_mode: OriginMode   ← 参考系
BulletPatternConfig.origin_offset: Vector2    ← 相对偏移

OriginMode:
├── BOSS_LOCAL      世界坐标 = Boss 位置 + offset
├── WORLD_ABSOLUTE  世界坐标 = offset（固定点）
└── PLAYER_POSITION 世界坐标 = 玩家位置 + offset
```

- 动态参考系（玩家）每轮发射前重新解析
- `HIT_POSITION` 不做：命中引爆归子弹命中行为（`BulletBase._on_area_entered`）

## 四、发射链路（数据流，含 2 层递归）

```
TimelineDriver.tick(delta)
    ↓ 到 dt 时刻，触发一轮
BossBulletPattern._emit_round(round_index, vars)
    ↓ 空间采样：外层 curve + sampler 得"一组局部起点"
    ↓ 每个起点：
    │   ├── [简单] 直接发单颗子弹：
    │   │       BulletSpawnRule.spawn_bullet(
    │   │           layer, scene, origin + 局部点, direction, motion)
    │   └── [2 层递归] 内层子形状：
    │           内层 curve + sampler 得"组内分布"
    │           每组内每点发一颗（相对外层起点）
    │           每颗子弹独立运动（motion；配相同曲线可近似刚体）
```

**每颗子弹独立运动**——出生后各自按 motion 飞（可配相同运动曲线近似刚体，也可各自乱飞）。

## 五、配置层（Resource 多态）

```
BulletPatternConfig（Resource 基类）
├── display_name / duration
├── origin_mode / origin_offset
├── curve: ParametricCurve         ← 外层形状
├── sampler: ParameterSampler      ← 外层采样
├── timeline: TimelineDriver       ← 子资源（RepeatTimelineDriver 等）
├── direction_mode: DirectionMode
├── bullet: BulletBehaviorConfig   ← 子资源（scene + motion）
├── sub_shape: BulletPatternConfig ← 可选，2 层递归（内层子形状，null = 单颗）
└── build() → BossBulletPattern
```

- **数据不决定行为类型**：`.tres` 只存参数；行为类型由 config 的**子资源多态**表达（Inspector 选哪个 EmitBehavior 子类 = 哪种行为）
- 配置层是**正式的游戏配置数据**（非"测试用例"概念）

## 六、未来扩展（继承而非修改）

| 需求 | 做法 |
|---|---|
| 不均匀节奏（打 3 轮停 2 秒） | 新建 `UnevenTimelineDriver extends TimelineDriver` |
| 分段节奏 | 新建 `PhasedTimelineDriver` |
| 新子弹运动 | 新建 `BulletMotion` 子类 |
| 新曲线 | 新建 `ParametricCurve` 子类 |
| 更深递归（3 层以上） | 配置层 `sub_shape` 已支持链式嵌套，放开即得 |

**扩展点全部是"新增子类"，现有类不改**。

## 七、保留沿用（代码重写但设计沿用）

1. BulletMotion 策略模式（Linear/BurstTwoStage/FollowCurve）
2. 曲线家族（ParametricCurve + Circle/Transform/Formula/Point/Composite）
3. DirectionMode 发射方向预设
4. 数据驱动测试场景（`.tres` 配置即加载，所见即所得）
5. is-a 一律新类、配置 Resource 多态、BossBulletPattern 中间层
6. TimelineDriver 与空间 sampler 同构（时间采样器）

## 八、验证方式

- Godot 测试场景 `Scenes/Bullet/Test/danmaku_test.tscn`（重写）
- 7 个演示用例（旋转环/螺旋/花瓣/扇形/扩散波/变速/沿曲线）作为 `.tres` 配置
- 每完成一个组件（TimelineDriver / BulletPattern / Motion / 配置层）即可单独验证

## 待确认/待细化（写实现计划前需定）

1. `BossBulletPattern` 与现有 `FlowPattern` 的接口衔接（start/update/stop 生命周期）
2. 2 层递归中"内层子形状"的相对坐标如何传递（外层起点 → 内层 origin）
3. 测试场景保留哪些交互（列表/搜索/单曲循环/隐藏UI 是否都保留）——已确认全保留
