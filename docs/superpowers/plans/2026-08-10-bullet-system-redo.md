# 弹幕系统重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从零重写弹幕发射系统，实现统一模型（空间×时间×单位），彻底修正旧架构的语义错误。

**Architecture:** 分层实现：曲线家族（空间）→ TimelineDriver（时间采样器）→ BulletMotion（单弹运动）→ BulletSpawnRule（发射规则）→ BossBulletPattern（组装 + 2 层递归）→ 配置层（Resource 多态）→ 测试场景。每层独立可验证，is-a 一律新类。

**Tech Stack:** Godot 4.7 / GDScript / Resource 多态 / 无外部依赖

## Global Constraints

- 基线：\03c34d\（develop HEAD）。注意：基线已含旧版弹幕基础（ParametricCurve/CircleParametricCurve/ParameterSampler/UniformParameterSampler/BulletSpawnRule/PatternEmitter/BulletBase 等）；已存在的文件 = 重写（Modify），真正新增见任务标注
- 保留：`docs/superpowers/specs/2026-08-10-bullet-system-redesign.md`（重做设计）
- 类层次必须遵循 spec：`BossAttackPattern`（泛攻击）→ `BossBulletPattern`（弹幕，is-a）
- is-a 一律新类，现有类（FlowPattern/Boss/Player 等）不改
- 数据用 Resource 多态，不用枚举决定行为类型
- 无 EmitBehavior 概念（已被统一模型取代）
- TimelineDriver 与空间 sampler 同构（时间采样器）
- 每颗子弹独立运动（motion 策略），可配相同曲线近似刚体
- 2 层递归（sub_shape），更深未来放开
- 注释用中文，类名 PascalCase，文件 snake_case
- 每个任务独立 commit（中文消息）
- 验证方式：Godot 测试场景（项目无 GUT，遵循 audio_manager_test 惯例）

---

## 文件结构总览

```
Public/curve/                  ← 空间层（Task 1-3）
├── parametric_curve.gd        ParametricCurve 基类（sample/tangent/draw_debug_visual）
├── circle_parametric_curve.gd 圆形
├── transform_curve.gd         变换包装（rotation/scale/offset）
├── formula_curve.gd           公式曲线（Expression 求值）
├── point_curve.gd             常数点
└── composite_curve.gd         多曲线合成

Public/sampler/                ← 空间采样（Task 4）
├── parameter_sampler.gd       ParameterSampler 基类（sample_values）
└── uniform_parameter_sampler.gd

Public/emitter/timeline/       ← 时间层（Task 5-6）
├── timeline_driver.gd         TimelineDriver 基类
└── repeat_timeline_driver.gd  RepeatTimelineDriver（次数/间隔/初始等待/循环变量）

Public/emitter/motion/         ← 单弹运动（Task 7-8）
├── bullet_motion.gd           BulletMotion 基类
├── linear_motion.gd
├── burst_two_stage_motion.gd
└── follow_curve_motion.gd

Public/emitter/                ← 发射规则（Task 9）
├── bullet_spawn_rule.gd       BulletSpawnRule（方向预设 + 发射）
└── pattern_emitter.gd         PatternEmitter（执行发射，时间/空间采样驱动）

Scenes/Boss/patterns/          ← 模式层（Task 10-11）
├── attack/boss_attack_pattern.gd  BossAttackPattern（泛攻击基类）
└── attack/boss_bullet_pattern.gd  BossBulletPattern（弹幕，组装 + 2 层递归）

Public/emitter/                ← 配置层（Task 12）
├── bullet_behavior_config.gd  BulletBehaviorConfig（scene + motion）
└── bullet_pattern_config.gd   BulletPatternConfig（完整弹幕配置 + build）

Scenes/Bullet/BulletBase/      ← 子弹（Task 8 依赖）
├── bullet_base.gd             BulletBase（生命周期委托 motion）
└── bullet_base.tscn

Scenes/Bullet/Test/            ← 验证（Task 13）
├── danmaku_test.tscn
├── danmaku_test_runner.gd
└── danmaku_test_player.gd

data/danmaku_tests/            ← 演示用例（Task 14）
├── rotating_ring.tres ... 7 个
```

---

### Task 0: 基线分支与文档

**Files:**
- 无新建；git 操作 + 恢复文档

**Interfaces:**
- 基线 = `a03c34d`（develop HEAD，含旧版弹幕基础：ParametricCurve/SpawnRule/Emitter/BulletBase 等，这些是重写对象）
- 保留 spec：`docs/superpowers/specs/2026-08-10-bullet-system-redesign.md`
- 保留 plan：`docs/superpowers/plans/2026-08-10-bullet-system-redo.md`

- [ ] **Step 1: 从基线新建实现分支**

Run: `git checkout -b feature/bullet-system-redo a03c34d`
Expected: 切到新分支，旧分支 feature/curve-bullet-optimization 原封不动

- [ ] **Step 2: 从旧分支恢复 spec 与 plan 文档**

Run:
```bash
git checkout feature/curve-bullet-optimization -- docs/superpowers/specs/2026-08-10-bullet-system-redesign.md docs/superpowers/plans/2026-08-10-bullet-system-redo.md
```

- [ ] **Step 3: 验证**

Run: `git status --short` 与 `Test-Path` 两个文档
Expected: 两个文档已暂存（A 状态），工作区无其他改动

- [ ] **Step 4: 提交基线 + 文档**

```bash
git add docs/superpowers/
git commit -m "chore: 重做基线——新建分支，保留 spec 与实现计划"
```

### Task 1: 曲线基类 + 采样器基类

**Files:**
- Create: `Public/curve/parametric_curve.gd`
- Create: `Public/sampler/parameter_sampler.gd`

**Interfaces:**
- Produces: `ParametricCurve.sample(t: float) -> Vector2`、`ParametricCurve.tangent(t: float) -> Vector2`、`ParametricCurve.draw_debug_visual(drawer, sampler, origin, color, point_radius, line_width, tangent_length)`
- Produces: `ParameterSampler.sample_values() -> Array[float]`

- [ ] **Step 1: 创建 ParametricCurve 基类**

```gdscript
@tool
class_name ParametricCurve
extends Resource

## 参数曲线基类：把参数 t（0..1）映射为局部坐标。
## 子类只需实现 sample()，tangent() 默认用差分近似；draw_debug_visual 供编辑器预览。

func sample(_t: float) -> Vector2:
	return Vector2.ZERO


func tangent(t: float) -> Vector2:
	var step: float = 0.001
	var before: Vector2 = sample(t - step)
	var after: Vector2 = sample(t + step)
	var delta: Vector2 = after - before
	if delta.length() <= 0.001:
		return Vector2.RIGHT
	return delta.normalized()


func draw_debug_visual(
	drawer: CanvasItem,
	sampler: ParameterSampler,
	origin: Vector2 = Vector2.ZERO,
	color: Color = Color(0.85, 0.3, 1.0, 0.95),
	point_radius: float = 2.5,
	line_width: float = 1.5,
	tangent_length: float = 12.0
) -> void:
	if drawer == null or sampler == null:
		return
	var values: Array[float] = sampler.sample_values()
	var previous_point: Vector2 = Vector2.ZERO
	var has_previous: bool = false
	for index in range(values.size()):
		var t: float = values[index]
		var world_point: Vector2 = origin + sample(t)
		var local_point: Vector2 = drawer.to_local(world_point)
		var tangent_end: Vector2 = drawer.to_local(world_point + tangent(t) * tangent_length)
		if has_previous:
			drawer.draw_line(previous_point, local_point, Color(color.r, color.g, color.b, 0.65), line_width)
		drawer.draw_circle(local_point, point_radius, color)
		drawer.draw_line(local_point, tangent_end, Color(0.4, 1.0, 1.0, 0.75), 1.0)
		previous_point = local_point
		has_previous = true
```

- [ ] **Step 2: 创建 ParameterSampler 基类**

```gdscript
@tool
class_name ParameterSampler
extends Resource

## 参数采样器基类：决定"在曲线上取哪些 t 值"。
## 子类实现 sample_values() 返回参数列表。

func sample_values() -> Array[float]:
	return []
```

- [ ] **Step 3: 提交**

```bash
git add Public/curve/parametric_curve.gd Public/sampler/parameter_sampler.gd
git commit -m "feat: ParametricCurve 与 ParameterSampler 基类（空间层基础）"
```

---

### Task 2: 圆形曲线 + 均匀采样器

**Files:**
- Create: `Public/curve/circle_parametric_curve.gd`
- Create: `Public/sampler/uniform_parameter_sampler.gd`

**Interfaces:**
- Consumes: `ParametricCurve` / `ParameterSampler`（Task 1）
- Produces: `CircleParametricCurve.radius: float`、`CircleParametricCurve.angle_offset_degrees: float`
- Produces: `UniformParameterSampler.start_t / end_t / sample_count / include_end`

- [ ] **Step 1: 创建圆形曲线**

```gdscript
@tool
class_name CircleParametricCurve
extends ParametricCurve

@export var radius: float = 96.0
@export var angle_offset_degrees: float = 90.0

func sample(t: float) -> Vector2:
	var angle: float = TAU * t + deg_to_rad(angle_offset_degrees)
	return Vector2(cos(angle), sin(angle)) * radius

func tangent(t: float) -> Vector2:
	var angle: float = TAU * t + deg_to_rad(angle_offset_degrees)
	return Vector2(-sin(angle), cos(angle)).normalized()
```

- [ ] **Step 2: 创建均匀采样器**

```gdscript
@tool
class_name UniformParameterSampler
extends ParameterSampler

@export var start_t: float = 0.0
@export var end_t: float = 1.0
@export var sample_count: int = 16
@export var include_end: bool = false

func sample_values() -> Array[float]:
	var result: Array[float] = []
	if sample_count <= 0:
		return result
	if sample_count == 1:
		result.append(start_t)
		return result
	var denominator: float = float(sample_count)
	if include_end:
		denominator = float(sample_count - 1)
	for index in range(sample_count):
		var ratio: float = float(index) / denominator
		result.append(lerp(start_t, end_t, ratio))
	return result
```

- [ ] **Step 3: 验证（创建临时预览场景或直接加载资源）**

Run: 在 Godot 打开项目，确认两个类可实例化、无 Parser Error
Expected: 无错误

- [ ] **Step 4: 提交**

```bash
git add Public/curve/circle_parametric_curve.gd Public/sampler/uniform_parameter_sampler.gd
git commit -m "feat: CircleParametricCurve 与 UniformParameterSampler（空间层实现）"
```

### Task 3: 变换曲线

**Files:**
- Create: `Public/curve/transform_curve.gd`

**Interfaces:**
- Consumes: `ParametricCurve`（Task 1）
- Produces: `TransformCurve.base: ParametricCurve`、`rotation_degrees: float`、`scale: Vector2`、`phase_offset: float`、`offset: Vector2`
- **关键**：演化只操作此层的通用变换字段，不碰底层 curve 内部字段（spec 修正）

- [ ] **Step 1: 创建 TransformCurve**

```gdscript
@tool
class_name TransformCurve
extends ParametricCurve

@export var base: ParametricCurve
@export var rotation_degrees: float = 0.0
@export var scale: Vector2 = Vector2.ONE
@export var phase_offset: float = 0.0
@export var offset: Vector2 = Vector2.ZERO

func sample(t: float) -> Vector2:
	var active_base: ParametricCurve = base
	if active_base == null:
		active_base = CircleParametricCurve.new()
	var point: Vector2 = active_base.sample(t + phase_offset)
	return point.rotated(deg_to_rad(rotation_degrees)) * scale + offset
```

- [ ] **Step 2: 验证**

Run: Godot 加载项目，TransformCurve 可实例化，包任意 curve 无错误
Expected: 无 Parser Error

- [ ] **Step 3: 提交**

```bash
git add Public/curve/transform_curve.gd
git commit -m "feat: TransformCurve 通用变换层（演化只碰此层字段）"
```

---

### Task 4: 公式曲线 + 点曲线 + 组合曲线

**Files:**
- Create: `Public/curve/formula_curve.gd`
- Create: `Public/curve/point_curve.gd`
- Create: `Public/curve/composite_curve.gd`

**Interfaces:**
- Consumes: `ParametricCurve`（Task 1）
- Produces: `FormulaCurve.x_expr / y_expr / radius`（Expression 求值）
- Produces: `PointCurve.point: Vector2`
- Produces: `CompositeCurve.curves: Array[ParametricCurve]`、`combine_mode: CombineMode`

- [ ] **Step 1: 创建 FormulaCurve（Expression 求值，Array 传参）**

```gdscript
@tool
class_name FormulaCurve
extends ParametricCurve

@export var x_expr: String = "r * cos(TAU * t)"
@export var y_expr: String = "r * sin(TAU * t)"
@export var radius: float = 96.0

var _x_parsed: Expression = null
var _y_parsed: Expression = null
var _parsed_x_src: String = ""
var _parsed_y_src: String = ""
var _last_error: String = ""

func sample(t: float) -> Vector2:
	if not _ensure_parsed():
		return Vector2.ZERO
	var input: Array = [t, radius]
	var x: Variant = _x_parsed.execute(input)
	var y: Variant = _y_parsed.execute(input)
	if _x_parsed.has_execute_failed() or _y_parsed.has_execute_failed():
		_last_error = "Expression execute failed: %s / %s" % [_x_parsed.get_error_text(), _y_parsed.get_error_text()]
		return Vector2.ZERO
	return Vector2(float(x), float(y))

func _ensure_parsed() -> bool:
	if _parsed_x_src == x_expr and _parsed_y_src == y_expr and _x_parsed != null and _y_parsed != null:
		return true
	_x_parsed = Expression.new()
	_y_parsed = Expression.new()
	_parsed_x_src = x_expr
	_parsed_y_src = y_expr
	var input_names := ["t", "r"]
	var x_err := _x_parsed.parse(x_expr, input_names)
	var y_err := _y_parsed.parse(y_expr, input_names)
	if x_err != OK or y_err != OK:
		_last_error = "Expression parse failed: %s / %s" % [_x_parsed.get_error_text(), _y_parsed.get_error_text()]
		return false
	_last_error = ""
	return true

func get_last_error() -> String:
	return _last_error
```

- [ ] **Step 2: 创建 PointCurve**

```gdscript
@tool
class_name PointCurve
extends ParametricCurve

@export var point: Vector2 = Vector2.ZERO

func sample(_t: float) -> Vector2:
	return point
```

- [ ] **Step 3: 创建 CompositeCurve**

```gdscript
@tool
class_name CompositeCurve
extends ParametricCurve

enum CombineMode { ADD, MULTIPLY }

@export var curves: Array[ParametricCurve] = []
@export var combine_mode: CombineMode = CombineMode.ADD
@export var rotation_degrees: float = 0.0

func sample(t: float) -> Vector2:
	if curves.is_empty():
		return Vector2.ZERO
	var result: Vector2 = curves[0].sample(t)
	for i in range(1, curves.size()):
		var point: Vector2 = curves[i].sample(t)
		match combine_mode:
			CombineMode.ADD:
				result += point
			CombineMode.MULTIPLY:
				result *= point
	if rotation_degrees != 0.0:
		result = result.rotated(deg_to_rad(rotation_degrees))
	return result
```

- [ ] **Step 4: 验证 + 提交**

Run: Godot 加载无错误；FormulaCurve 用玫瑰表达式 `r*(1+0.3*cos(5*TAU*t))*cos(TAU*t)` 采样有非零结果
```bash
git add Public/curve/formula_curve.gd Public/curve/point_curve.gd Public/curve/composite_curve.gd
git commit -m "feat: FormulaCurve/PointCurve/CompositeCurve（空间层完成）"
```

### Task 5: TimelineDriver 基类（时间采样器）

**Files:**
- Create: `Public/emitter/timeline/timeline_driver.gd`

**Interfaces:**
- Produces: `TimelineDriver.initial_delay: float`、`begin()`、`tick(delta) -> bool`（返回 true=到一轮时机）、`get_round() -> int`、`is_completed() -> bool`
- 信号: `round_triggered(round_index: int)`

- [ ] **Step 1: 创建 TimelineDriver 基类**

```gdscript
class_name TimelineDriver
extends Resource

## 时间采样器基类：决定"何时触发一轮发射"。
## 与空间 sampler 同构：空间采样产生 t 列表，时间采样产生 dt 序列。
## 子类实现节奏算法（RepeatTimelineDriver 均匀、未来 UnevenTimelineDriver 不均匀等）。

signal round_triggered(round_index: int)

## 初始等待（秒），任何时间线都可能需要，放基类。
@export var initial_delay: float = 0.0

## 内部状态：当前轮次（从 0 开始）。
var _round: int = 0
var _elapsed: float = 0.0
var _delayed: bool = false
var _completed: bool = false

## 是否已开始（begin 调用后）。
var _started: bool = false


func begin() -> void:
	_round = 0
	_elapsed = 0.0
	_delayed = false
	_completed = false
	_started = true


## 每帧推进。返回 true 表示"本轮触发"（调用方应执行发射）。
func tick(delta: float) -> bool:
	if not _started or _completed:
		return false

	# 初始等待：未到 initial_delay 前不触发任何轮
	if not _delayed:
		_elapsed += delta
		if _elapsed < initial_delay:
			return false
		_delayed = true
		_elapsed = 0.0

	return _advance_time(delta)


## 子类实现：推进时间并返回本轮是否触发。
func _advance_time(_delta: float) -> bool:
	return false


func get_round() -> int:
	return _round


func is_completed() -> bool:
	return _completed


func is_started() -> bool:
	return _started


## 子类在触发一轮时调用。
func _trigger_round() -> bool:
	round_triggered.emit(_round)
	return true
```

- [ ] **Step 2: 提交**

```bash
git add Public/emitter/timeline/timeline_driver.gd
git commit -m "feat: TimelineDriver 基类（时间采样器，含初始等待）"
```

---

### Task 6: RepeatTimelineDriver（均匀时间采样）

**Files:**
- Create: `Public/emitter/timeline/repeat_timeline_driver.gd`

**Interfaces:**
- Consumes: `TimelineDriver`（Task 5）
- Produces: `RepeatTimelineDriver.rounds: int`（≤0 无限）、`interval: float`、循环变量 `var_names / var_inits / var_increments: Array`、`get_vars() -> Dictionary`

- [ ] **Step 1: 创建 RepeatTimelineDriver**

```gdscript
class_name RepeatTimelineDriver
extends TimelineDriver

## 轮次数。≤0 = 无限循环。
@export var rounds: int = 36
## 轮间间隔（秒）。
@export var interval: float = 0.16

## 循环变量（对应 LuaSTG taskrepeat Var 1-4）。
@export var var_names: Array[String] = []
@export var var_inits: Array[float] = []
@export var var_increments: Array[float] = []

## 当前变量值快照（key=变量名）。
var _vars: Dictionary = {}


func begin() -> void:
	super.begin()
	_vars.clear()
	for i in range(var_names.size()):
		if var_names[i] == "":
			continue
		_vars[var_names[i]] = var_inits[i] if i < var_inits.size() else 0.0


func _advance_time(delta: float) -> bool:
	if rounds > 0 and _round >= rounds:
		_completed = true
		return false

	_elapsed += delta
	if _elapsed < interval:
		return false

	_elapsed = 0.0
	# 触发本轮，然后递增变量与轮次
	_trigger_round()
	for i in range(var_names.size()):
		if var_names[i] == "":
			continue
		var inc: float = var_increments[i] if i < var_increments.size() else 0.0
		_vars[var_names[i]] = float(_vars.get(var_names[i], 0.0)) + inc
	_round += 1

	# 无限循环（rounds≤0）永不完成
	if rounds > 0 and _round >= rounds:
		_completed = true
	return true


## 返回当前循环变量值（本轮发射用）。
func get_vars() -> Dictionary:
	return _vars
```

- [ ] **Step 2: 验证（临时场景测试）**

Run: Godot 中实例化 RepeatTimelineDriver，`rounds=3, interval=0.1, initial_delay=0.5`，调用 `begin()` 后按 0.05 步进 tick，确认：前 0.5s 不触发、之后每 0.1s 触发一次、3 次后 completed
Expected: 行为符合上述时序

- [ ] **Step 3: 提交**

```bash
git add Public/emitter/timeline/repeat_timeline_driver.gd
git commit -m "feat: RepeatTimelineDriver 均匀时间采样（次数/间隔/初始等待/循环变量）"
```

### Task 7: BulletMotion 策略家族

**Files:**
- Create: `Public/emitter/motion/bullet_motion.gd`
- Create: `Public/emitter/motion/linear_motion.gd`
- Create: `Public/emitter/motion/burst_two_stage_motion.gd`
- Create: `Public/emitter/motion/follow_curve_motion.gd`

**Interfaces:**
- Produces: `BulletMotion.setup(bullet: BulletBase, init_data: Dictionary)`、`process(bullet: BulletBase, delta: float)`
- Produces: `LinearMotion.speed / acceleration`
- Produces: `BurstTwoStageMotion.burst_speed / burst_acceleration / burst_duration / cruise_speed / cruise_acceleration`
- Produces: `FollowCurveMotion.curve / speed`

- [ ] **Step 1: 创建 BulletMotion 基类**

```gdscript
class_name BulletMotion
extends Resource

## 子弹运动策略基类：定义"子弹发射后如何移动"。
## BulletBase 只持有 motion 引用并委托 process()，自身不保留运动学字段。
## 新增运动方式 = 新建子类。

func setup(_bullet: BulletBase, _init_data: Dictionary = {}) -> void:
	pass

func process(_bullet: BulletBase, _delta: float) -> void:
	pass
```

- [ ] **Step 2: 创建 LinearMotion**

```gdscript
class_name LinearMotion
extends BulletMotion

@export var speed: float = 90.0
@export var acceleration: float = 0.0

var _velocity: Vector2 = Vector2.DOWN
var _speed: float = 90.0

func setup(_bullet: BulletBase, init_data: Dictionary = {}) -> void:
	_velocity = init_data.get("velocity", Vector2.DOWN)
	_speed = speed

func process(bullet: BulletBase, delta: float) -> void:
	_speed = max(_speed + acceleration * delta, 0.0)
	bullet.global_position += _velocity.normalized() * _speed * delta
```

- [ ] **Step 3: 创建 BurstTwoStageMotion**

```gdscript
class_name BurstTwoStageMotion
extends BulletMotion

@export var burst_speed: float = 0.0
@export var burst_acceleration: float = 0.0
@export var burst_duration: float = 0.2
@export var cruise_speed: float = 0.0
@export var cruise_acceleration: float = 0.0

var _velocity: Vector2 = Vector2.DOWN
var _in_burst: bool = false
var _burst_elapsed: float = 0.0
var _burst_speed_actual: float = 0.0
var _cruise_speed_actual: float = 0.0
var _speed: float = 0.0
var _acceleration: float = 0.0

func setup(_bullet: BulletBase, init_data: Dictionary = {}) -> void:
	_velocity = init_data.get("velocity", Vector2.DOWN)
	_in_burst = true
	_burst_elapsed = 0.0
	var launch_speed: float = float(init_data.get("speed", 0.0))
	_burst_speed_actual = burst_speed if burst_speed > 0.0 else launch_speed
	_cruise_speed_actual = cruise_speed if cruise_speed > 0.0 else launch_speed
	if _burst_speed_actual <= 0.0:
		_burst_speed_actual = 300.0
	if _cruise_speed_actual <= 0.0:
		_cruise_speed_actual = 300.0

func process(bullet: BulletBase, delta: float) -> void:
	if _in_burst:
		_burst_elapsed += delta
		if _burst_elapsed >= burst_duration:
			_in_burst = false
			_speed = _cruise_speed_actual
			_acceleration = cruise_acceleration
		else:
			_speed = _burst_speed_actual + burst_acceleration * _burst_elapsed
	else:
		_speed = max(_speed + _acceleration * delta, 0.0)
	bullet.global_position += _velocity.normalized() * _speed * delta
```

- [ ] **Step 4: 创建 FollowCurveMotion**

```gdscript
class_name FollowCurveMotion
extends BulletMotion

@export var curve: ParametricCurve
@export var speed: float = 0.5

var _origin: Vector2 = Vector2.ZERO
var _t: float = 0.0

func setup(bullet: BulletBase, _init_data: Dictionary = {}) -> void:
	_origin = bullet.global_position
	_t = 0.0

func process(bullet: BulletBase, delta: float) -> void:
	if curve == null:
		return
	_t += speed * delta
	bullet.global_position = _origin + curve.sample(_t)
```

- [ ] **Step 5: 提交**

```bash
git add Public/emitter/motion/
git commit -m "feat: BulletMotion 策略家族（Linear/BurstTwoStage/FollowCurve）"
```

---

### Task 8: BulletBase 重构（生命周期委托 motion）

**Files:**
- Modify: `Scenes/Bullet/BulletBase/bullet_base.gd`
- Modify: `Scenes/Bullet/BulletBase/bullet_base.tscn`

**Interfaces:**
- Consumes: `BulletMotion`（Task 7）
- Produces: `BulletBase.setup(owner_layer, spawn_position, init_data)`、`recycle()`、`try_mark_grazed()`、`motion: BulletMotion` 字段

- [ ] **Step 1: 重写 bullet_base.gd**

```gdscript
class_name BulletBase
extends Area2D

## 基础子弹：负责生命周期（生成/回收/碰撞/擦弹）。
## 运动学完全委托给 BulletMotion 策略，自身不保留速度/方向字段。

var damage: int = 1
var has_grazed: bool = false
var lifetime: float = 0.0
var motion: BulletMotion = null

var _age: float = 0.0
var _owner_layer: BulletLayer
var _active: bool = false


func _ready() -> void:
	DebugHelper.register_debug_drawable(self)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(owner_layer: BulletLayer, spawn_position: Vector2, init_data: Dictionary = {}) -> void:
	_owner_layer = owner_layer
	global_position = spawn_position
	damage = init_data.get("damage", 1)
	collision_layer = init_data.get("collision_layer", collision_layer)
	collision_mask = init_data.get("collision_mask", collision_mask)
	has_grazed = false
	lifetime = init_data.get("lifetime", 0.0)

	var motion_config: BulletMotion = init_data.get("motion", null)
	motion = motion_config.duplicate() if motion_config != null else null
	if motion != null:
		motion.setup(self, init_data)

	_age = 0.0
	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	monitoring = true
	monitorable = true


func recycle() -> void:
	if not _active:
		return
	_active = false
	has_grazed = false
	visible = false
	set_process(false)
	set_physics_process(false)
	call_deferred("_do_recycle")


func _do_recycle() -> void:
	monitoring = false
	monitorable = false
	if _owner_layer != null:
		_owner_layer.recycle_bullet(self)


func _process(delta: float) -> void:
	if lifetime > 0.0:
		_age += delta
		if _age >= lifetime:
			recycle()
			return
	if motion != null:
		motion.process(self, delta)


func try_mark_grazed() -> bool:
	if has_grazed or not _active:
		return false
	has_grazed = true
	return true


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		recycle()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		recycle()


func _draw() -> void:
	DebugHelper.draw_collision_shape(self, self as Area2D)
```

- [ ] **Step 2: 确认 bullet_base.tscn 引用**（不改脚本路径，Godot 自动更新 uid）

Run: 打开 bullet_base.tscn，确认 script 指向 bullet_base.gd，无缺失
Expected: 无错误

- [ ] **Step 3: 提交**

```bash
git add Scenes/Bullet/BulletBase/
git commit -m "feat: BulletBase 只做生命周期委托，运动学全归 BulletMotion"
```

### Task 9: BulletSpawnRule + PatternEmitter（发射执行）

**Files:**
- Create: `Public/emitter/bullet_spawn_rule.gd`
- Create: `Public/emitter/pattern_emitter.gd`

**Interfaces:**
- Consumes: `BulletBase`（Task 8）、`BulletMotion`（Task 7）
- Produces: `BulletSpawnRule.direction_mode / bullet_speed / bullet_acceleration / damage / bullet_lifetime / motion`、`spawn_bullet(layer, scene, pos, dir, init_data)`
- Produces: `PatternEmitter.curve / sampler / spawn_rule`、`emit_once(layer, scene, init_data, origin)`（全量）、`emit_begin + emit_next_step + emit_stream_tick`（逐颗）

- [ ] **Step 1: 创建 BulletSpawnRule（方向预设 + 发射）**

```gdscript
class_name BulletSpawnRule
extends Resource

## 发射规则：决定每颗子弹的方向预设，并执行生成。

enum DirectionMode {
	CURVE_TANGENT,
	FROM_ORIGIN,
	AIM_PLAYER,
	FIXED,
	RANDOM_JITTER,
}

@export var bullet_speed: float = 120.0
@export var acceleration: float = 0.0
@export var damage: int = 1
@export var bullet_lifetime: float = 0.0
@export var direction_mode: DirectionMode = DirectionMode.CURVE_TANGENT
@export var fixed_direction: Vector2 = Vector2.DOWN
@export var jitter_degrees: float = 0.0
@export var fallback_direction: Vector2 = Vector2.DOWN

## 运动策略（发射源注入；null 时默认直线）。
var motion: BulletMotion = null

const PLAYER_GROUP: String = "players"


func spawn_from_curve(
	bullet_layer: BulletLayer,
	bullet_scene: PackedScene,
	origin: Vector2,
	local_point: Vector2,
	tangent: Vector2,
	base_init_data: Dictionary = {}
) -> BulletBase:
	var direction: Vector2 = _compute_direction(origin, local_point, tangent)
	return spawn_bullet(bullet_layer, bullet_scene, origin + local_point, direction, base_init_data)


func _compute_direction(origin: Vector2, local_point: Vector2, tangent: Vector2) -> Vector2:
	var direction: Vector2 = fallback_direction
	match direction_mode:
		DirectionMode.CURVE_TANGENT:
			direction = tangent
		DirectionMode.FROM_ORIGIN:
			direction = local_point
		DirectionMode.AIM_PLAYER:
			direction = _get_player_direction(origin)
		DirectionMode.FIXED:
			direction = fixed_direction
		DirectionMode.RANDOM_JITTER:
			direction = tangent.rotated(deg_to_rad(randf_range(-jitter_degrees, jitter_degrees)))
	if jitter_degrees > 0.0 and direction_mode != DirectionMode.RANDOM_JITTER:
		direction = direction.rotated(deg_to_rad(randf_range(-jitter_degrees, jitter_degrees)))
	if direction.length() <= 0.001:
		direction = fallback_direction
	return direction


func _get_player_direction(origin: Vector2) -> Vector2:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return fallback_direction
	var player := tree.get_first_node_in_group(PLAYER_GROUP) as Node2D
	if player == null:
		return fallback_direction
	var delta: Vector2 = player.global_position - origin
	if delta.length() <= 0.001:
		return fallback_direction
	return delta.normalized()


func spawn_bullet(
	bullet_layer: BulletLayer,
	bullet_scene: PackedScene,
	spawn_position: Vector2,
	direction: Vector2,
	base_init_data: Dictionary = {}
) -> BulletBase:
	if bullet_layer == null or bullet_scene == null:
		return null
	var spawn_direction: Vector2 = direction
	if spawn_direction.length() <= 0.001:
		spawn_direction = fallback_direction

	var init_data: Dictionary = base_init_data.duplicate()
	init_data["velocity"] = spawn_direction.normalized()
	init_data["speed"] = bullet_speed
	init_data["acceleration"] = acceleration
	init_data["damage"] = damage
	init_data["lifetime"] = bullet_lifetime

	var active_motion: BulletMotion = motion
	if active_motion == null:
		var default_motion := LinearMotion.new()
		default_motion.speed = bullet_speed
		default_motion.acceleration = acceleration
		active_motion = default_motion
	init_data["motion"] = active_motion

	return bullet_layer.spawn_bullet(bullet_scene, spawn_position, init_data)
```

- [ ] **Step 2: 创建 PatternEmitter（全量 + 逐颗）**

```gdscript
class_name PatternEmitter
extends Resource

## 发射执行器：把"空间采样（curve+sampler）+ 发射规则"变成实际子弹。
## 支持全量（emit_once）与逐颗（emit_begin/emit_next_step/emit_stream_tick）。

enum EmissionMode { BURST_ALL, STREAM }

@export var curve: ParametricCurve
@export var sampler: ParameterSampler
@export var spawn_rule: BulletSpawnRule
@export var emission_mode: EmissionMode = EmissionMode.BURST_ALL
@export var stream_interval: float = 0.08

var _stream_values: Array[float] = []
var _stream_index: int = 0
var _stream_bullet_layer: BulletLayer
var _stream_bullet_scene: PackedScene
var _stream_init_data: Dictionary = {}
var _stream_origin: Vector2 = Vector2.ZERO
var _stream_curve: ParametricCurve
var _stream_timer: float = 0.0


func emit_once(bullet_layer: BulletLayer, bullet_scene: PackedScene, init_data: Dictionary, origin: Vector2) -> void:
	if bullet_layer == null:
		return
	var active_curve := _get_active_curve()
	var active_sampler := _get_active_sampler()
	var active_spawn_rule := _get_active_spawn_rule()
	var values: Array[float] = active_sampler.sample_values()
	for index in range(values.size()):
		var t: float = values[index]
		var local_point: Vector2 = active_curve.sample(t)
		var tangent: Vector2 = active_curve.tangent(t)
		active_spawn_rule.spawn_from_curve(bullet_layer, bullet_scene, origin, local_point, tangent, init_data)


func emit_begin(bullet_layer: BulletLayer, bullet_scene: PackedScene, init_data: Dictionary, origin: Vector2) -> int:
	if bullet_layer == null:
		return 0
	_stream_bullet_layer = bullet_layer
	_stream_bullet_scene = bullet_scene
	_stream_init_data = init_data
	_stream_origin = origin
	_stream_curve = _get_active_curve()
	_stream_values = _get_active_sampler().sample_values()
	_stream_index = 0
	_stream_timer = 0.0
	return _stream_values.size()


func emit_next_step() -> bool:
	if _stream_index >= _stream_values.size():
		return false
	var active_spawn_rule := _get_active_spawn_rule()
	var t: float = _stream_values[_stream_index]
	_stream_index += 1
	var local_point: Vector2 = _stream_curve.sample(t)
	var tangent: Vector2 = _stream_curve.tangent(t)
	active_spawn_rule.spawn_from_curve(_stream_bullet_layer, _stream_bullet_scene, _stream_origin, local_point, tangent, _stream_init_data)
	return _stream_index < _stream_values.size()


func emit_stream_tick(delta: float) -> bool:
	if _stream_index >= _stream_values.size():
		return false
	_stream_timer -= delta
	if _stream_timer > 0.0:
		return true
	_stream_timer = stream_interval
	emit_next_step()
	return _stream_index < _stream_values.size()


func _get_active_curve() -> ParametricCurve:
	if curve != null:
		return curve
	return CircleParametricCurve.new()


func _get_active_sampler() -> ParameterSampler:
	if sampler != null:
		return sampler
	var default_sampler := UniformParameterSampler.new()
	default_sampler.sample_count = 16
	return default_sampler


func _get_active_spawn_rule() -> BulletSpawnRule:
	if spawn_rule != null:
		return spawn_rule
	return BulletSpawnRule.new()
```

- [ ] **Step 3: 提交**

```bash
git add Public/emitter/bullet_spawn_rule.gd Public/emitter/pattern_emitter.gd
git commit -m "feat: BulletSpawnRule 方向预设与 PatternEmitter 全量/逐颗发射"
```

### Task 10: BossAttackPattern 基类（泛攻击）

**Files:**
- Create: `Scenes/Boss/patterns/attack/boss_attack_pattern.gd`

**Interfaces:**
- Consumes: `FlowPattern`（现有，不改）
- Produces: `BossAttackPattern`（泛"Boss 攻击行为"抽象，只放骨架与 owner 访问）

- [ ] **Step 1: 创建 BossAttackPattern（只放通用骨架）**

```gdscript
class_name BossAttackPattern
extends FlowPattern

## 泛"Boss 攻击行为"抽象：Boss 在当前阶段可能的一种行为。
## 弹幕是攻击的一种（BossBulletPattern 继承本类），冲撞/召唤等也是。
## 本类只放通用骨架与宿主访问，不放任何弹幕专用字段。

## 启动攻击 Pattern。
func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	if _is_running:
		DebugState.debug_log("Boss attack start: %s" % get_pattern_label(), "Boss")


## 停止攻击 Pattern。
func stop_pattern() -> void:
	if _is_running:
		DebugState.debug_log("Boss attack stop: %s" % get_pattern_label(), "Boss")
	super.stop_pattern()
```

- [ ] **Step 2: 提交**

```bash
git add Scenes/Boss/patterns/attack/boss_attack_pattern.gd
git commit -m "feat: BossAttackPattern 泛攻击基类（只放骨架，弹幕专用逻辑下沉）"
```

---

### Task 11: BossBulletPattern（弹幕 Pattern，组装 + 2 层递归）

**Files:**
- Create: `Scenes/Boss/patterns/attack/boss_bullet_pattern.gd`

**Interfaces:**
- Consumes: `BossAttackPattern`（Task 10）、`TimelineDriver`（Task 5）、`PatternEmitter`（Task 9）、`BulletSpawnRule`（Task 9）、`BulletPatternConfig`（Task 12）
- Produces: `BossBulletPattern.origin: Vector2`、`emitter: PatternEmitter`、`timeline: TimelineDriver`、`sub_shape: BulletPatternConfig`、`_emit_round(round_index, vars)`

- [ ] **Step 1: 创建 BossBulletPattern**

```gdscript
class_name BossBulletPattern
extends BossAttackPattern

## 弹幕 Pattern：发射"一组子弹"（2 层递归：sub_shape 可为内层子形状）。
## 职责：持有空间（curve/sampler）+ 时间（timeline）+ 发射规则，驱动 timeline 每轮发射。

## 坐标原点（config 解析后注入，世界坐标基准）。
var origin: Vector2 = Vector2.ZERO

## 发射执行器（由 config.build 注入）。
var emitter: PatternEmitter = PatternEmitter.new()

## 时间采样器（由 config.build 注入）。
var timeline: TimelineDriver = null

## 内层子形状配置（2 层递归；null = 每轮直接发单颗）。
var sub_shape: BulletPatternConfig = null


func start_pattern(pattern_owner: Node) -> void:
	super.start_pattern(pattern_owner)
	if timeline != null:
		timeline.begin()


func stop_pattern() -> void:
	super.stop_pattern()
	if timeline != null:
		timeline = null


func update_pattern(runtime_data: FlowPhaseRuntimeData) -> void:
	if not _is_running:
		return
	if timeline == null:
		return

	# STREAM 模式：本轮逐颗推进
	if emitter.emission_mode == PatternEmitter.EmissionMode.STREAM and _streaming:
		if not emitter.emit_stream_tick(runtime_data.delta):
			_streaming = false
			if timeline != null:
				timeline.tick(0.0)  # 空 tick 推进轮次/完成检查
		return

	var triggered: bool = timeline.tick(runtime_data.delta)
	if triggered:
		_apply_evolution(timeline.get_round())
		_emit_round(timeline.get_round(), _get_timeline_vars())
		if emitter.emission_mode == PatternEmitter.EmissionMode.STREAM:
			emitter.emit_begin(_get_bullet_layer(), _get_bullet_scene(), _get_bullet_init_data(), origin)
			_streaming = true
			emitter.emit_next_step()
		else:
			emitter.emit_once(_get_bullet_layer(), _get_bullet_scene(), _get_bullet_init_data(), origin)

	if timeline.is_completed():
		mark_completed()


## 每轮应用演化增量（config.build 注入 TransformCurve 元数据时生效）。
func _apply_evolution(round_index: int) -> void:
	if not has_meta("evolve_transform"):
		return
	var transform: TransformCurve = get_meta("evolve_transform") as TransformCurve
	var angle_inc: float = float(get_meta("angle_increment", 0.0))
	var radius_inc: float = float(get_meta("radius_increment", 0.0))
	if angle_inc != 0.0:
		transform.rotation_degrees = angle_inc * round_index
	if radius_inc != 0.0:
		transform.scale = Vector2.ONE * (1.0 + radius_inc * round_index)


## 本轮发射前的钩子（子类可重写做自定义动作）。
func _emit_round(_round_index: int, _vars: Dictionary) -> void:
	pass


func _get_timeline_vars() -> Dictionary:
	if timeline is RepeatTimelineDriver:
		return (timeline as RepeatTimelineDriver).get_vars()
	return {}


func _get_bullet_layer() -> BulletLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("bullet_layers") as BulletLayer


func _get_bullet_scene() -> PackedScene:
	# bullet_scene 的唯一持有者是 BulletBehaviorConfig（经 sub_shape 链传递）。
	# Pattern 通过 emitter 携带的引用获取；此处由 Task 12 config.build 注入 emitter 持有的 scene。
	if emitter != null and emitter.has_meta("bullet_scene"):
		return emitter.get_meta("bullet_scene") as PackedScene
	return null


func _get_bullet_init_data() -> Dictionary:
	return {
		"collision_layer": CollisionLayers.ENEMY_BULLET,
		"collision_mask": CollisionLayers.PLAYER,
	}
```

> **scene 归属定案**：bullet_scene 唯一持有者是 BulletBehaviorConfig，经 config.build 注入 emitter 元数据，_get_bullet_scene() 从 emitter 读取。

- [ ] **Step 2: 验证**

Run: Godot 加载无 Parser Error
Expected: 无错误（依赖 Task 12 完成后再实际跑）

- [ ] **Step 3: 提交**

```bash
git add Scenes/Boss/patterns/attack/boss_bullet_pattern.gd
git commit -m "feat: BossBulletPattern 弹幕组装（空间×时间×发射规则 + 2 层递归钩子）"
```

---

### Task 12: 配置层（BulletPatternConfig + BulletBehaviorConfig）

**Files:**
- Create: `Public/emitter/bullet_behavior_config.gd`
- Create: `Public/emitter/bullet_pattern_config.gd`

**Interfaces:**
- Consumes: 曲线家族 / TimelineDriver / BulletMotion / PatternEmitter / BossBulletPattern
- Produces: `BulletBehaviorConfig.bullet_scene / motion / damage / bullet_lifetime`
- Produces: `BulletPatternConfig.display_name / duration / origin_mode / origin_offset / curve / sampler / timeline / direction_mode / bullet / sub_shape`、`build() -> BossBulletPattern`

- [ ] **Step 1: 创建 BulletBehaviorConfig**

```gdscript
class_name BulletBehaviorConfig
extends Resource

## 子弹行为配置：scene + motion 策略。

@export var bullet_scene: PackedScene
@export var motion: BulletMotion
@export var damage: int = 1
@export var bullet_lifetime: float = 6.0
```

- [ ] **Step 2: 创建 BulletPatternConfig**

```gdscript
class_name BulletPatternConfig
extends Resource

## 弹幕完整配置：数据只存参数，build() 构造运行时 Pattern。

enum OriginMode { BOSS_LOCAL, WORLD_ABSOLUTE, PLAYER_POSITION }

@export var display_name: String = ""
@export var duration: float = 4.0
@export var origin_mode: OriginMode = OriginMode.BOSS_LOCAL
@export var origin_offset: Vector2 = Vector2.ZERO
@export var curve: ParametricCurve = CircleParametricCurve.new()
@export var sampler: ParameterSampler = UniformParameterSampler.new()
@export var timeline: TimelineDriver
@export var direction_mode: BulletSpawnRule.DirectionMode = BulletSpawnRule.DirectionMode.CURVE_TANGENT
@export var bullet: BulletBehaviorConfig
@export var sub_shape: BulletPatternConfig = null

## 每轮演化（可选，通用变换层，不依赖底层曲线类型）：
## 操作 TransformCurve 的 rotation_degrees / scale，包任意曲线都适用。
@export var angle_increment_per_round: float = 0.0
@export var radius_increment_per_round: float = 0.0


func build(owner_node: Node2D) -> BossBulletPattern:
	var pattern := BossBulletPattern.new()
	pattern.pattern_name = display_name
	pattern.origin = _resolve_origin(owner_node)

	# 构造发射规则与执行器
	var spawn_rule := BulletSpawnRule.new()
	spawn_rule.direction_mode = direction_mode
	spawn_rule.bullet_speed = _get_bullet_speed()
	spawn_rule.damage = _get_damage()
	spawn_rule.bullet_lifetime = _get_lifetime()
	if bullet != null:
		spawn_rule.motion = bullet.motion

	# 需要每轮演化时，把曲线包一层 TransformCurve（操作通用变换字段）
	var emit_curve: ParametricCurve = curve
	if angle_increment_per_round != 0.0 or radius_increment_per_round != 0.0:
		var transform := TransformCurve.new()
		transform.base = curve
		transform.rotation_degrees = 0.0
		transform.scale = Vector2.ONE
		emit_curve = transform
		pattern.set_meta("evolve_transform", transform)
		pattern.set_meta("angle_increment", angle_increment_per_round)
		pattern.set_meta("radius_increment", radius_increment_per_round)

	pattern.emitter = PatternEmitter.new()
	pattern.emitter.curve = emit_curve
	pattern.emitter.sampler = sampler
	pattern.emitter.spawn_rule = spawn_rule
	# 注入 bullet_scene（唯一持有者 BulletBehaviorConfig）
	if bullet != null:
		pattern.emitter.set_meta("bullet_scene", bullet.bullet_scene)

	pattern.timeline = timeline
	pattern.sub_shape = sub_shape
	return pattern


func _resolve_origin(owner_node: Node2D) -> Vector2:
	match origin_mode:
		OriginMode.WORLD_ABSOLUTE:
			return origin_offset
		OriginMode.PLAYER_POSITION:
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				var player := tree.get_first_node_in_group("players") as Node2D
				if player != null:
					return player.global_position + origin_offset
			return origin_offset
		_:
			if owner_node != null:
				return owner_node.global_position + origin_offset
			return origin_offset


func _get_bullet_speed() -> float:
	if bullet != null and bullet.motion is LinearMotion:
		return (bullet.motion as LinearMotion).speed
	return 90.0


func _get_damage() -> int:
	return bullet.damage if bullet != null else 1


func _get_lifetime() -> float:
	return bullet.bullet_lifetime if bullet != null else 6.0
```

- [ ] **Step 3: 验证（临时场景）**

Run: 创建测试 .tres 引用 BulletPatternConfig，build() 出 pattern，无错误
Expected: build 成功，pattern 字段正确

- [ ] **Step 4: 提交**

```bash
git add Public/emitter/bullet_behavior_config.gd Public/emitter/bullet_pattern_config.gd
git commit -m "feat: 配置层 BulletPatternConfig/BulletBehaviorConfig（Resource 多态，数据不决定行为类型）"
```

### Task 13: 测试场景（数据驱动，所见即所得）

**Files:**
- Create: `Scenes/Bullet/Test/danmaku_test.tscn`
- Create: `Scenes/Bullet/Test/danmaku_test_runner.gd`
- Create: `Scenes/Bullet/Test/danmaku_test_player.gd`

**Interfaces:**
- Consumes: `BulletPatternConfig`（Task 12）、`BossBulletPattern`（Task 11）
- Produces: 测试场景，扫描 `data/danmaku_tests/*.tres` 加载全部用例

- [ ] **Step 1: 创建测试场景 runner（扫描 .tres 自动加载）**

```gdscript
extends Node2D

## 弹幕测试场景：扫描 data/danmaku_tests/*.tres 加载全部用例。
## 功能：自动切换/单曲循环(C)/上下个(←→)/重开(R)/隐藏UI(Tab)/搜索/点击跳转。

const TEST_CASES_DIR: String = "res://data/danmaku_tests"

var _test_cases: Array[BulletPatternConfig] = []
var _test_case_names: Array[String] = []
var _demo_index: int = 0
var _pattern: BossBulletPattern
var _elapsed: float = 0.0
var _repeat_current: bool = false

var _ui_layer: CanvasLayer
var _title_label: Label
var _search_edit: LineEdit
var _item_list: ItemList
var _ui_panel: Panel
var _filtered_indices: Array[int] = []


func _ready() -> void:
	_load_test_cases()
	_setup_ui()
	_apply_filter("")
	if _filtered_indices.is_empty():
		push_warning("DanmakuTest: no test cases in %s" % TEST_CASES_DIR)
		return
	_start_demo(_filtered_indices[0])


func _process(delta: float) -> void:
	if _pattern == null:
		return
	_elapsed += delta
	var runtime_data := FlowPhaseRuntimeData.new()
	runtime_data.setup(self, delta, _elapsed)
	_pattern.update_pattern(runtime_data)
	_update_ui()

	if _repeat_current:
		return
	if _elapsed >= _get_current_duration():
		_step_demo(1)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if _search_edit != null and _search_edit.has_focus():
		return
	match event.keycode:
		KEY_LEFT: _step_demo(-1)
		KEY_RIGHT: _step_demo(1)
		KEY_R: _start_demo(_demo_index)
		KEY_C: _repeat_current = not _repeat_current; _update_ui()
		KEY_TAB: _toggle_ui()


func _load_test_cases() -> void:
	_test_cases.clear()
	_test_case_names.clear()
	var dir := DirAccess.open(TEST_CASES_DIR)
	if dir == null:
		push_warning("DanmakuTest: cannot open %s" % TEST_CASES_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var case := load(TEST_CASES_DIR.path_join(file_name)) as BulletPatternConfig
			if case != null:
				_test_cases.append(case)
				_test_case_names.append(case.display_name if case.display_name != "" else file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()


func _step_demo(direction: int) -> void:
	if _filtered_indices.is_empty():
		return
	var pos: int = _filtered_indices.find(_demo_index)
	if pos < 0:
		pos = 0
	pos = wrapi(pos + direction, 0, _filtered_indices.size())
	_start_demo(_filtered_indices[pos])


func _start_demo(index: int) -> void:
	_cleanup_pattern()
	_clear_bullets()
	_demo_index = index
	_elapsed = 0.0
	var test_case: BulletPatternConfig = _test_cases[index]
	_pattern = test_case.build(self)
	_pattern.name = "DemoPattern_%d" % index
	add_child(_pattern)
	_pattern.start_pattern(self)
	_update_ui()


func _get_current_duration() -> float:
	if _demo_index >= 0 and _demo_index < _test_cases.size():
		return _test_cases[_demo_index].duration
	return 4.0


func _clear_bullets() -> void:
	var layer := get_tree().get_first_node_in_group(BulletLayer.GROUP_NAME) as BulletLayer
	if layer != null:
		layer.clear_all()


func _cleanup_pattern() -> void:
	if _pattern == null:
		return
	if _pattern.is_inside_tree():
		_pattern.stop_pattern()
		_pattern.queue_free()
	_pattern = null


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 100
	add_child(_ui_layer)
	_ui_panel = Panel.new()
	_ui_panel.position = Vector2(8, 8)
	_ui_panel.size = Vector2(330, 270)
	_ui_layer.add_child(_ui_panel)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12, 12)
	vbox.size = Vector2(306, 246)
	vbox.add_theme_constant_override("separation", 6)
	_ui_panel.add_child(vbox)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_title_label)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索演示...（回车播第一个匹配）"
	_search_edit.text_changed.connect(_on_search_text_changed)
	_search_edit.text_submitted.connect(_on_search_submitted)
	vbox.add_child(_search_edit)
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	vbox.add_child(_item_list)


func _toggle_ui() -> void:
	if _ui_panel == null:
		return
	_ui_panel.visible = not _ui_panel.visible
	if not _ui_panel.visible and _search_edit != null and _search_edit.has_focus():
		_search_edit.release_focus()


func _apply_filter(keyword: String) -> void:
	_filtered_indices.clear()
	var lower: String = keyword.strip_edges().to_lower()
	for i in range(_test_cases.size()):
		if lower.is_empty() or _test_case_names[i].to_lower().contains(lower):
			_filtered_indices.append(i)
	_item_list.clear()
	for idx in _filtered_indices:
		_item_list.add_item(_test_case_names[idx])
	if not _filtered_indices.has(_demo_index):
		if not _filtered_indices.is_empty():
			_start_demo(_filtered_indices[0])
	_update_ui()


func _on_search_text_changed(new_text: String) -> void:
	_apply_filter(new_text)


func _on_search_submitted(_new_text: String) -> void:
	if not _filtered_indices.is_empty():
		_start_demo(_filtered_indices[0])
	_search_edit.release_focus()


func _on_item_selected(item_index: int) -> void:
	if item_index >= 0 and item_index < _filtered_indices.size():
		_start_demo(_filtered_indices[item_index])


func _update_ui() -> void:
	if _title_label == null:
		return
	var name: String = ""
	if _demo_index >= 0 and _demo_index < _test_case_names.size():
		name = _test_case_names[_demo_index]
	var wave_text := ""
	if _pattern != null and _pattern.timeline is RepeatTimelineDriver:
		var driver := _pattern.timeline as RepeatTimelineDriver
		if driver.rounds <= 0:
			wave_text = "  波次 ∞（已发 %d）" % driver.get_round()
		else:
			wave_text = "  波次 %d/%d" % [driver.get_round(), driver.rounds]
	_title_label.text = "演示 %d/%d: %s%s\n单曲:%s ←/→切换 R重开 C单曲 Tab隐藏" % [
		_demo_index + 1, _test_cases.size(), name, wave_text,
		"ON" if _repeat_current else "OFF"
	]
	var pos: int = _filtered_indices.find(_demo_index)
	if pos >= 0 and pos < _item_list.item_count:
		_item_list.select(pos)
		_item_list.ensure_current_is_visible()
```

- [ ] **Step 2: 创建 danmaku_test.tscn 与 player**

`danmaku_test.tscn`（引用 runner + BulletLayer + MockPlayer）：
```
[gd_scene load_steps=4 format=3]
[ext_resource type="PackedScene" path="res://Scenes/BulletLayer/bullet_layer.tscn" id="1"]
[ext_resource type="Script" path="res://Scenes/Bullet/Test/danmaku_test_runner.gd" id="2"]
[ext_resource type="Script" path="res://Scenes/Bullet/Test/danmaku_test_player.gd" id="3"]
[node name="DanmakuTest" type="Node2D"]
[node name="BulletLayer" parent="." instance=ExtResource("1")]
[node name="Runner" type="Node2D" parent="."]
script = ExtResource("2")
[node name="MockPlayer" type="Node2D" parent="."]
position = Vector2(320, 560)
script = ExtResource("3")
```

`danmaku_test_player.gd`：
```gdscript
extends Node2D
## 模拟玩家：注册 players group，供 AIM_PLAYER 方向模式自机狙。
func _ready() -> void:
	add_to_group("players")
```

- [ ] **Step 3: 提交**

```bash
git add Scenes/Bullet/Test/
git commit -m "feat: 弹幕测试场景（扫描 .tres 数据驱动，列表/搜索/单曲循环/隐藏UI）"
```

---

### Task 14: 演示用例（7 个 .tres 配置）

**Files:**
- Create: `data/danmaku_tests/rotating_ring.tres` / `spiral.tres` / `flower.tres` / `fan_aimed.tres` / `spread_wave.tres` / `burst_two_stage.tres` / `follow_curve.tres`

**Interfaces:**
- Consumes: `BulletPatternConfig`（Task 12）
- 每个 .tres 是一个 BulletPatternConfig 子资源配置

- [ ] **Step 1: 创建旋转环用例（参考模板）**

```text
[gd_resource type="Resource" script_class="BulletPatternConfig" format=3]

[ext_resource type="Script" path="res://Public/emitter/bullet_pattern_config.gd" id="1"]
[ext_resource type="Script" path="res://Public/curve/circle_parametric_curve.gd" id="2"]
[ext_resource type="Script" path="res://Public/sampler/uniform_parameter_sampler.gd" id="3"]
[ext_resource type="Script" path="res://Public/emitter/timeline/repeat_timeline_driver.gd" id="4"]
[ext_resource type="Script" path="res://Public/emitter/motion/linear_motion.gd" id="5"]
[ext_resource type="Script" path="res://Public/emitter/bullet_behavior_config.gd" id="6"]

[sub_resource type="Resource" id="curve"]
script = ExtResource("2")
radius = 96.0

[sub_resource type="Resource" id="sampler"]
script = ExtResource("3")
sample_count = 16

[sub_resource type="Resource" id="timeline"]
script = ExtResource("4")
rounds = 36
interval = 0.1

[sub_resource type="Resource" id="motion"]
script = ExtResource("5")
speed = 90.0

[sub_resource type="Resource" id="bullet"]
script = ExtResource("6")
motion = SubResource("motion")

[resource]
script = ExtResource("1")
display_name = "旋转环"
duration = 4.0
curve = SubResource("curve")
sampler = SubResource("sampler")
timeline = SubResource("timeline")
bullet = SubResource("bullet")
angle_increment_per_round = 10.0
```

> **角度演化定案**：旋转环的"每轮转 10°"通过 `BulletPatternConfig.angle_increment_per_round` 表达（config.build 包一层 TransformCurve，Pattern 每轮更新 rotation_degrees）——操作通用变换层，不依赖底层曲线类型。螺旋同理用 `radius_increment_per_round`（更新 scale）。

- [ ] **Step 2: 创建其余 6 个用例**（同模板，按各自参数）
  - `spiral.tres`：radius 演化（TransformCurve.scale 或 var 半径）
  - `flower.tres`：FormulaCurve 玫瑰 + TransformCurve
  - `fan_aimed.tres`：direction_mode=AIM_PLAYER + jitter
  - `spread_wave.tres`：CompositeCurve 三环
  - `burst_two_stage.tres`：BurstTwoStageMotion
  - `follow_curve.tres`：FollowCurveMotion

- [ ] **Step 3: 运行测试场景验证**

Run: Godot 运行 `Scenes/Bullet/Test/danmaku_test.tscn`
Expected: 7 个用例依次演示，效果符合各自描述

- [ ] **Step 4: 提交**

```bash
git add data/danmaku_tests/
git commit -m "feat: 7 个弹幕演示用例（旋转环/螺旋/花瓣/扇形/扩散波/变速/沿曲线）"
```

---

### Task 15: 收尾——文档 + AGENTS.md

**Files:**
- Create/Modify: `docs/superpowers/plans/2026-08-10-bullet-system-redo.md`（本计划，标记完成）
- Modify: `AGENTS.md`（写入类型关系检查流程）

- [ ] **Step 1: 更新 AGENTS.md 加架构检查**

在 AGENTS.md 添加：
```markdown
## 架构设计检查（改代码前必须逐条回答）

1. 新功能/新类型与现有类型的关系是什么？(is-a / has-a / uses-a / config-of)
2. 本次是"新增文件"还是"修改现有文件"？
3. 若是修改：为什么不能用新建类解决？（写不出理由 = 禁止修改）
4. 被修改的类，其类名承诺的语义是否被篡改？
```

- [ ] **Step 2: 全量验证 + 最终 commit**

Run: 测试场景全 7 用例通过；`git status` 干净
```bash
git add AGENTS.md docs/
git commit -m "docs: 写入类型关系检查流程，标记弹幕重做完成"
```
