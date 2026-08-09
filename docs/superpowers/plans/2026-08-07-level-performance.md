# 克苏鲁之眼关卡演出整合 Implementation Plan（Level Performance）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 LevelManager 之上串联完整演出流程——夜晚降临(NightSegment) → Boss 登场(输入锁定/解锁) → 转阶段演出(外部事件桥) → 胜利(消散/掉落/stinger/对话/flag 占位)，用占位美术跑通全链路。

**Architecture:** 双层驱动 + 外部事件桥（反向代理）。LevelManager 编排关卡级流程（夜晚/登场/胜利）并响应 Boss 信号；Boss 自己跑 PhaseMachine 判转段/死亡，通过 `BossExternalEventPattern.external_event_requested` 与 `died` 信号让 LevelManager 做全局演出。背景/夜晚视觉不建（仅 `scene_change_requested` 信号接口 + 日志占位，等美术）。对话全量录入 `messages_zh.json`；音乐用现有完整版 BGM（`test_boss`）+ `set_bgm_layer_enabled` 分层。

**Tech Stack:** Godot 4.x + GDScript。验证走 `godot --headless --path <project> --quit-after 30` 启动主场景无解析错误 + DebugState 日志序列。

## Global Constraints

- 项目实际路径 `D:\Dev\Godot\无聊的飞`（git 仓库在 `game/` 子目录；外层 `Godot-STG` 是空 git 根，**不要**污染）。
- Godot exe：`D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`。
- GDScript 用中文注释，只解释设计意图，不逐行水注释。
- 不自动 push / 不 commit 除非用户明确要求（每次 Task 只提供 commit 命令，交执行者/用户决定）。
- 改 `.tscn`/`.tres`/`project.godot`/`.json` 格外谨慎，保留 UID / 现有消息条目 / UTF-8 编码。
- `messages_zh.json` 必须是合法 JSON 且 UTF-8（现有 3 条 `eye_intro_warning`/`eye_phase_2`/`eye_defeated` 保留不动，只追加）。
- `DebugState.debug_log(message: String, key: String = "General")`；`MessageController.GROUP_NAME = "message_controllers"`。
- Autoload：`AudioManager`（GameAudioManager，`play_bgm/play_sfx_id/set_bgm_layer_enabled/stop_bgm/rebuild_config_index`）、`DebugState`。
- BGM 轨道资源：`res://data/audio/test/test_stage.tres`(101)/`test_boss_intro.tres`(102)/`test_boss.tres`(103)；SFX：`test_hit`(event_id=2)。
- 玩家节点：`get_tree().current_scene.get_node_or_null("Player")`，接口 `set_input_enabled(bool)`。
- 背景/夜晚视觉本 stage 不实现；掉落物/Boss flag 持久化/BGM 切分不做（占位或日志）。
- 现有 `BossSegment.phase_message_ids`（{2: eye_phase_2}）保留兼容，不动。

---

### Task 1: 录入 Node03-06 全部对话到 messages_zh.json

**Files:**
- Modify: `data/messages/messages_zh.json`（在现有 3 条之后追加 17 条，不删除任何现有条目）

**Interfaces:**
- Produces: 消息 id `night_01..04`（夜晚 4 条）、`entrance_01..04`（登场 4 条）、`transition_01..03`（转段 3 条）、`victory_01..06`（胜利 6 条），字段格式与现有条目一致（speaker/text/duration/typewriter/chars_per_second/priority/interrupt_policy）。
- Consumes: 无。
- Later tasks use: `show_by_id("night_01")` 等（Task 4/6）。

- [ ] **Step 1: 编辑 `data/messages/messages_zh.json`**

在文件末尾（`"eye_defeated": {...}` 条目之后、闭合 `}` 之前）追加以下条目（注意逗号：`eye_defeated` 条目末尾加 `,`；文本内控制 tag 用 `[color=#..]`/`[pause=0.4]`/`[slow]`/`[fast]`，与现有条目一致；`[间隔]`/`[停顿]`/`[信号断开]` 转成 `[pause=0.5]`）：

```json
  "night_01": {
	"speaker": "鵺",
	"text": "这里也会天黑？",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 22,
	"priority": 11,
	"interrupt_policy": "queue"
  },
  "night_02": {
	"speaker": "旁白",
	"text": "你感到有个[pause=0.3][slow][color=#32FF82]邪恶的东西[/color][/slow][pause=0.5]在看着你……",
	"duration": 3.0,
	"typewriter": true,
	"chars_per_second": 20,
	"priority": 12,
	"interrupt_policy": "queue"
  },
  "night_03": {
	"speaker": "鵺",
	"text": "呜哇...谁在说话？！",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 26,
	"priority": 13,
	"interrupt_policy": "queue"
  },
  "night_04": {
	"speaker": "荷取",
	"text": "……刚才仪器跳了一下。[pause=0.5]没事，一切都在可控范围内",
	"duration": 3.0,
	"typewriter": true,
	"chars_per_second": 22,
	"priority": 14,
	"interrupt_policy": "queue"
  },
  "entrance_01": {
	"speaker": "旁白",
	"text": "[fast][color=#AF4BFF]克苏鲁之眼已苏醒！！！[/color][/fast]",
	"duration": 2.5,
	"typewriter": true,
	"chars_per_second": 28,
	"priority": 21,
	"interrupt_policy": "interrupt"
  },
  "entrance_02": {
	"speaker": "鵺",
	"text": "噢噢噢噢噢噢噢噢！！",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 30,
	"priority": 22,
	"interrupt_policy": "queue"
  },
  "entrance_03": {
	"speaker": "鵺",
	"text": "居然还有这种东西！",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 24,
	"priority": 23,
	"interrupt_policy": "queue"
  },
  "entrance_04": {
	"speaker": "荷取",
	"text": "嗯……[pause=0.5]先记录下来。",
	"duration": 2.5,
	"typewriter": true,
	"chars_per_second": 22,
	"priority": 24,
	"interrupt_policy": "queue"
  },
  "transition_01": {
	"speaker": "鵺",
	"text": "什么？发生什么了？",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 26,
	"priority": 31,
	"interrupt_policy": "interrupt"
  },
  "transition_02": {
	"speaker": "荷取",
	"text": "原来如此...看来这里的夜晚，也有很多值得研究的东西。",
	"duration": 3.0,
	"typewriter": true,
	"chars_per_second": 22,
	"priority": 32,
	"interrupt_policy": "queue"
  },
  "transition_03": {
	"speaker": "荷取",
	"text": "加油啊，打败它就有更多实验数据了！",
	"duration": 2.5,
	"typewriter": true,
	"chars_per_second": 26,
	"priority": 33,
	"interrupt_policy": "queue"
  },
  "victory_01": {
	"speaker": "鵺",
	"text": "哈哈哈哈，也不过如此嘛",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 24,
	"priority": 51,
	"interrupt_policy": "interrupt"
  },
  "victory_02": {
	"speaker": "旁白",
	"text": "[fast][color=#66AAFF]克苏鲁之眼已被击败！[/color][/fast]",
	"duration": 2.5,
	"typewriter": true,
	"chars_per_second": 28,
	"priority": 52,
	"interrupt_policy": "queue"
  },
  "victory_03": {
	"speaker": "荷取",
	"text": "很好，数据收集完毕，干的漂亮。",
	"duration": 2.5,
	"typewriter": true,
	"chars_per_second": 24,
	"priority": 53,
	"interrupt_policy": "queue"
  },
  "victory_04": {
	"speaker": "荷取",
	"text": "等等[pause=0.5]，诶，发生了什[pause=0.5]，眼球？！为什么？哇啊啊[pause=0.5][slow]信号断开[/slow]",
	"duration": 4.0,
	"typewriter": true,
	"chars_per_second": 22,
	"priority": 54,
	"interrupt_policy": "queue"
  },
  "victory_05": {
	"speaker": "鵺",
	"text": "..？你在说什么呢？",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 20,
	"priority": 55,
	"interrupt_policy": "queue"
  },
  "victory_06": {
	"speaker": "鵺",
	"text": "喂？...不管了！",
	"duration": 2.0,
	"typewriter": true,
	"chars_per_second": 26,
	"priority": 56,
	"interrupt_policy": "queue"
  }
```

- [ ] **Step 2: 校验 JSON 合法**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `Message JSON` 解析错误 / `Message id not found` 警告（headless 下若不加日志仍成功启动即可；重点是无 JSON 语法错误导致 controller `_ready` 加载失败）。

- [ ] **Step 3: Commit（可选，仅用户要求）**

```bash
git add data/messages/messages_zh.json
git commit -m "feat: 录入克苏鲁之眼演出 Node03-06 全部对话"
```

---

### Task 2: 新建 NightSegment 资源类 + LevelDefinition 加 victory_message_ids

**Files:**
- Create: `Public/level/night_segment.gd`（+ Godot 自动生成 `.uid`）
- Modify: `Public/level/level_definition.gd`

**Interfaces:**
- Produces: `NightSegment`（`extends LevelSegment`，兄弟类，不继承 phase_message_ids），字段：
  `type="night"`（默认）、`wait_before_start: float`、`message_ids: Array[String]`、`bgm_track: String`、`bgm_fade_in/bgm_fade_out: float`、`scene_ambience_key: String`。
- Produces: `LevelDefinition.victory_message_ids: Array[String]`（胜利对话序列，Node06 共 6 条）。
- Consumes: `LevelSegment`（已有，`@export var type: String`）。
- Later tasks use: Task 4 引用 NightSegment 类型；Task 6 读 `victory_message_ids`。

- [ ] **Step 1: 创建 `Public/level/night_segment.gd`**

```gdscript
class_name NightSegment
extends LevelSegment

# 夜晚降临段：声明开场等待、对话序列、夜晚 BGM 与背景意图 key。
# 背景视觉本 stage 不实现，scene_ambience_key 仅作为接口参数发出（见 LevelManager）。
@export var wait_before_start: float = 0.0
@export var message_ids: Array[String] = []
@export var bgm_track: String = ""
@export var bgm_fade_in: float = 1.0
@export var bgm_fade_out: float = 1.0
@export var scene_ambience_key: String = "night_fall"
```

- [ ] **Step 2: 修改 `Public/level/level_definition.gd`**

在 `segments` 导出之后追加：

```gdscript
class_name LevelDefinition
extends Resource

# 关卡全流程声明：一个有序的流程段列表。Boss/敌人/演出都作为"段"出现，可插花、可重复。
@export var segments: Array[LevelSegment] = []

## 胜利对话序列（storyboard Node06）。Boss died 后由 LevelManager 依序播放；可为空（跳过对话）。
@export var victory_message_ids: Array[String] = []
```

- [ ] **Step 3: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `night_segment.gd` / `level_definition.gd` 解析或类型错误。

- [ ] **Step 4: Commit（可选）**

```bash
git add Public/level/night_segment.gd Public/level/night_segment.gd.uid Public/level/level_definition.gd
git commit -m "feat: 新增 NightSegment 段类型与 LevelDefinition 胜利对话字段"
```

---

### Task 3: Boss 增加外部事件转发与消散动画

**Files:**
- Modify: `Scenes/Boss/boss_base.gd`

**Interfaces:**
- Produces: Boss 新增 `signal external_event_requested(event_name: String, payload: Dictionary)`（转发场景内 `BossExternalEventPattern` 的事件）。
- Produces: Boss 死亡流程改为：`died.emit()` → 消散动画（scale/modulate 淡出）→ `queue_free()`（而非立即释放），供 LevelManager 胜利演出期间 Boss 仍可见。
- Consumes: `BossExternalEventPattern.external_event_requested`（Task 4 在场景中配置）、`FlowPattern`。
- Later tasks use: Task 5 连接 `boss.external_event_requested`；Task 6 依赖 `died` 后 Boss 不立即消失。

- [ ] **Step 1: 信号区加转发信号**

在 `signal entrance_finished`（第 10 行）后追加：

```gdscript
signal external_event_requested(event_name: String, payload: Dictionary)
```

- [ ] **Step 2: `_ready` 末尾转发场景内外部事件**

在 `_ready()` 中 `phase_machine.setup(self)` 之后追加调用：

```gdscript
	phase_machine.setup(self)
	_forward_external_events()
```

- [ ] **Step 3: 新增两个方法（放在 `summon_enemy` 之后、类末尾）**

```gdscript
# 转发场景内所有 BossExternalEventPattern 的事件到 Boss 对外信号，
# 保持"Boss 只发信号，LevelManager 决定响应"的边界，不感知演出细节。
func _forward_external_events() -> void:
	var patterns := find_children("*", "BossExternalEventPattern", true, false)
	for pattern in patterns:
		var callback := Callable(self, "_on_pattern_external_event")
		if not pattern.external_event_requested.is_connected(callback):
			pattern.external_event_requested.connect(callback)


func _on_pattern_external_event(event_name: String, payload: Dictionary, _pattern: FlowPattern) -> void:
	external_event_requested.emit(event_name, payload)


# 死亡：关闭阶段流程、广播死亡事件，然后播消散占位动画（缩至 0 + 淡出）后释放。
# 消散期间 Boss 仍保留在场景树，LevelManager 的胜利演出（掉落/对话）可并行进行。
func _play_dissolve() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()
```

- [ ] **Step 4: 改造 `die()`**

将现有：

```gdscript
func die() -> void:
	DebugState.debug_log("Boss destroyed", "Boss")
	if phase_machine != null:
		phase_machine.shutdown()

	died.emit()
	queue_free()
```

改为：

```gdscript
func die() -> void:
	DebugState.debug_log("Boss destroyed", "Boss")
	if phase_machine != null:
		phase_machine.shutdown()

	died.emit()
	await _play_dissolve()
```

- [ ] **Step 5: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `boss_base.gd` 解析 / 类型错误。

- [ ] **Step 6: Commit（可选）**

```bash
git add Scenes/Boss/boss_base.gd
git commit -m "feat: Boss 转发外部事件并增加死亡消散占位动画"
```

---

### Task 4: 在 Boss 场景 Phase2To3Transition 配置转段演出事件

**Files:**
- Modify: `Scenes/Boss/boss_base.tscn`（在 `Phases/Phase2To3Transition/Patterns` 下加 `BossExternalEventPattern` 节点）

**Interfaces:**
- Produces: Boss 转段（Phase2→Phase3，storyboard Node05"克眼第三阶段裂开大嘴"）时发出 `external_event_requested("phase_transition_performance", {})`。
- Consumes: `BossExternalEventPattern`（已有脚本，`event_name/payload/complete_on_request` 导出）。
- Later tasks use: Task 5 的 LevelManager 分发逻辑按 `"phase_transition_performance"` 匹配。

- [ ] **Step 1: 读取当前 `boss_base.tscn` 的 ext_resource 编号**

`ext_resource` 当前到 `id="13_uniform_sampler"`。用 `id="14_ext_event"` 新增脚本引用，`id="15_...` 不需要（无需额外资源）。

- [ ] **Step 2: 在 `[ext_resource]` 块末尾追加脚本引用**

```ini
[ext_resource type="Script" uid="uid://cwcgv60gbgbb3" path="res://Scenes/Boss/patterns/boss_external_event_pattern.gd" id="14_ext_event"]
```

> 已确认 `boss_external_event_pattern.gd.uid` 内容为 `uid://cwcgv60gbgbb3`；现有 ext_resource 均带 `uid=` 属性，保持一致。

- [ ] **Step 3: 在 `Phases/Phase2To3Transition/Patterns` 下追加节点**

在 `Phase2To3Transition/Patterns/Wait` 节点定义之后追加：

```ini
[node name="TransitionPerformance" type="Node" parent="Phases/Phase2To3Transition/Patterns"]
script = ExtResource("14_ext_event")
event_name = "phase_transition_performance"
complete_on_request = true
```

- [ ] **Step 4: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `boss_base.tscn` 解析错误；日志出现 `Boss external event requested: ...`（若转段可达）。

- [ ] **Step 5: Commit（可选）**

```bash
git add Scenes/Boss/boss_base.tscn
git commit -m "feat: Boss Phase2To3Transition 配置转段演出外部事件"
```

---

### Task 5: MessageController 增加空闲查询 + LevelManager 注入音频

**Files:**
- Modify: `Scenes/Message/message_controller.gd`（加 `is_busy()` 公开方法）
- Modify: `Scenes/Main/level_manager.gd`（音频配置注入）

**Interfaces:**
- Produces: `MessageController.is_busy() -> bool`（当前正在显示或队列非空）。
- Produces: `LevelManager._ensure_audio_config()`（注入 BGM/SFX 测试轨道，供夜晚/Boss/胜利使用）。
- Consumes: `GameAudioManager`（Autoload `AudioManager`）、测试音频资源路径。
- Later tasks use: Task 6 用 `is_busy()` 等待对话队列播完。

- [ ] **Step 1: 在 `message_controller.gd` 加公开空闲查询**

在 `show_by_id` 之前追加：

```gdscript
# 当前是否正在显示消息或队列非空。LevelManager 用它等待一段对话序列播完。
func is_busy() -> bool:
	if _message_box == null:
		return false
	return _message_box.is_busy() or not _queue.is_empty()
```

- [ ] **Step 2: 在 `level_manager.gd` 顶部加常量**

在 `var boss: Boss` 之后追加：

```gdscript
# 演出用音频轨道（现有完整版 BGM + 测试 SFX；后期替换为正式资源后仅改此处）。
const BGM_TRACKS: Array[AudioBgmTrack] = [
	preload("res://data/audio/test/test_boss_intro.tres"),
	preload("res://data/audio/test/test_boss.tres"),
]
const SFX_EVENTS: Array[AudioSfxEvent] = [
	preload("res://data/audio/test/test_hit.tres"),
]
```

- [ ] **Step 3: 在 `level_manager.gd` 的 `_ready` 开头调用音频注入**

将 `_ready` 改为：

```gdscript
func _ready() -> void:
	_ensure_audio_config()

	if level_definition == null:
		DebugState.debug_log("LevelManager: level_definition 为空，跳过", "Level")
		return

	_consume_segments()
```

- [ ] **Step 4: 新增 `_ensure_audio_config` 方法（放在 `_consume_segments` 之前）**

```gdscript
# Autoload 的 audio_manager.tscn 未预置轨道，运行时注入测试资源（与测试场景同模式）。
func _ensure_audio_config() -> void:
	if AudioManager.bgm_tracks.is_empty():
		AudioManager.bgm_tracks = BGM_TRACKS
	if AudioManager.sfx_events.is_empty():
		AudioManager.sfx_events = SFX_EVENTS
	AudioManager.rebuild_config_index()
```

- [ ] **Step 5: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `message_controller.gd` / `level_manager.gd` 解析错误；无 `BGM track not found` 警告。

- [ ] **Step 6: Commit（可选）**

```bash
git add Scenes/Message/message_controller.gd Scenes/Main/level_manager.gd
git commit -m "feat: MessageController 空闲查询与 LevelManager 音频注入"
```

---

### Task 6: LevelManager 演出编排（夜晚/登场/转段/胜利 + 输入锁定 + 背景接口）

**Files:**
- Modify: `Scenes/Main/level_manager.gd`

**Interfaces:**
- Consumes: `NightSegment`（Task 2）、`BossSegment`（已有）、`Boss` 信号（`phase_changed/external_event_requested/died`，Task 3）、`MessageController`（Task 5 `is_busy`）、`Player.set_input_enabled`、`AudioManager`。
- Produces: `LevelManager.scene_change_requested(scene_key: String, params: Dictionary)` 信号（背景意图接口出口，本 stage 仅日志）。
- Produces: 完整演出序列（见 Step 2-6）。
- Later tasks use: Task 7 的 `level_001.tres` 配置。

- [ ] **Step 1: 顶部加信号与状态变量**

在 `class_name LevelManager` 之后追加：

```gdscript
# 背景/场景切换意图接口出口：本 stage 不建视觉层，仅日志占位，待美术确认交互方式后接入。
signal scene_change_requested(scene_key: String, params: Dictionary)
```

- [ ] **Step 2: `_consume_segments` 支持 NightSegment**

将 `_consume_segments` 改为：

```gdscript
# 按顺序处理每个流程段；本次支持 night/boss 段，未知类型警告并跳过。
func _consume_segments() -> void:
	for segment in level_definition.segments:
		if segment is NightSegment:
			await _play_night_segment(segment as NightSegment)
		elif segment is BossSegment:
			await _spawn_boss(segment as BossSegment)
		else:
			DebugState.debug_log(
				"LevelManager: 未知关卡段类型 '%s'，跳过" % (segment.type if segment else "null"),
				"Level"
			)
```

- [ ] **Step 3: 新增 `_play_night_segment`（夜晚降临演出）**

放在 `_spawn_boss` 之前：

```gdscript
# 夜晚降临：等待 → 依序播放开场对话 → 切 BGM → 发背景意图（日志占位）→ 进入下一段。
func _play_night_segment(segment: NightSegment) -> void:
	if segment.wait_before_start > 0.0:
		await get_tree().create_timer(segment.wait_before_start).timeout

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	for msg_id in segment.message_ids:
		if controller != null:
			controller.show_by_id(msg_id)

	if not segment.bgm_track.is_empty():
		AudioManager.play_bgm(segment.bgm_track, segment.bgm_fade_in, segment.bgm_fade_out)

	_request_scene_change(segment.scene_ambience_key, {"source": "night_segment"})

	# 等对话队列播完再放行 Boss 段（占位演出顺序可感知）。
	if controller != null:
		while controller.is_busy():
			await get_tree().process_frame

	DebugState.debug_log("LevelManager: 夜晚段完成", "Level")
```

- [ ] **Step 4: 改造 `_spawn_boss`（锁输入 + 连外部事件 + 切 Boss BGM）**

将 `_spawn_boss` 改为：

```gdscript
# 等待入场延迟后实例化 Boss、注入召唤列表、锁定玩家输入并连接所需信号。
func _spawn_boss(segment: BossSegment) -> void:
	if segment.boss_scene == null:
		DebugState.debug_log("LevelManager: boss_scene 为空，跳过本段", "Level")
		return

	await get_tree().create_timer(segment.entrance_delay).timeout

	_set_player_input_enabled(false)

	var boss_node: Node = segment.boss_scene.instantiate()
	boss_node.position = segment.spawn_position
	add_child(boss_node)

	if boss_node is Boss:
		boss = boss_node as Boss
		boss.set_summonable_enemy_scenes(segment.summoned_enemy_scenes)
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.external_event_requested.connect(_on_boss_external_event)
		boss.died.connect(_on_boss_died)
		AudioManager.play_bgm("test_boss", 1.0, 0.5)

	# 记录本段的转阶段消息映射，供 phase_changed 时查询。
	_phase_message_ids = segment.phase_message_ids

	DebugState.debug_log("LevelManager: 已实例化 Boss，输入已锁定", "Level")
```

- [ ] **Step 5: 扩展 `_on_boss_phase_changed`（Phase1 解锁输入）**

改为：

```gdscript
# Boss 转阶段：Phase1（Intro 结束进入正式战斗）解锁玩家输入；
# 若该阶段在 BossSegment 配置了消息，则通过 MessageController 发送。
func _on_boss_phase_changed(phase_id: int) -> void:
	if phase_id == 1:
		_set_player_input_enabled(true)
		DebugState.debug_log("LevelManager: Boss 入场完成，输入解锁", "Level")

	var msg_id: String = str(_phase_message_ids.get(phase_id, ""))
	if msg_id.is_empty():
		return

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	if controller == null:
		DebugState.debug_log("LevelManager: 找不到 message_controllers，跳过消息 %s" % msg_id, "Level")
		return

	controller.show_by_id(msg_id)
```

- [ ] **Step 6: 新增外部事件分发 + 转段演出 + 胜利流程 + 工具方法**

> ⚠️ 现有 `level_manager.gd` 已有一个 `_on_boss_died()` 占位（"结算入口待接入"）。本步**新增** `_on_boss_external_event`/`_play_phase_transition`/`_spawn_drop_placeholder`/`_set_player_input_enabled`/`_request_scene_change`，并**替换**现有 `_on_boss_died()`（见下方代码块，整段替换旧占位，不要重复定义）。

在 `_on_boss_phase_changed` 之后追加/替换以下代码：

```gdscript
# Boss 转段/演出外部事件分发：数据在 Boss 场景的 Pattern 配置，LevelManager 按事件名响应。
func _on_boss_external_event(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"phase_transition_performance":
			_play_phase_transition(payload)
		_:
			DebugState.debug_log("LevelManager: 未识别外部事件 %s" % event_name, "Level")


# 转段演出（storyboard Node05）：对话 + 音乐下一层 + 背景意图（日志占位）。
func _play_phase_transition(_payload: Dictionary) -> void:
	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	for msg_id in ["transition_01", "transition_02", "transition_03"]:
		if controller != null:
			controller.show_by_id(msg_id)

	AudioManager.set_bgm_layer_enabled(true, 0.8)
	_request_scene_change("phase_transition", {"source": "boss_external_event"})
	DebugState.debug_log("LevelManager: 转段演出已触发", "Level")


# 胜利演出（storyboard Node06）：暂停输入 → stinger → 掉落占位 → 胜利对话 → flag 日志。
func _on_boss_died() -> void:
	DebugState.debug_log("LevelManager: Boss 死亡，进入胜利流程", "Level")

	_set_player_input_enabled(false)
	AudioManager.play_sfx_id(2)  # test_hit 占位 Victory stinger
	_spawn_drop_placeholder()
	_request_scene_change("victory_clear", {"source": "boss_died"})

	var controller := get_tree().get_first_node_in_group(MessageController.GROUP_NAME) as MessageController
	for msg_id in level_definition.victory_message_ids:
		if controller != null:
			controller.show_by_id(msg_id)

	# boss_flag 更新占位：无持久化系统，仅日志。
	DebugState.debug_log("LevelManager: boss_flag 更新占位（后续接入存档）", "Level")


# 掉落占位：Boss 位置生成一个短暂闪烁的色块，随后消失（真实掉落系统留后续）。
func _spawn_drop_placeholder() -> void:
	if boss == null or not is_instance_valid(boss):
		return

	var drop := ColorRect.new()
	drop.size = Vector2(14, 14)
	drop.position = boss.position - drop.size * 0.5
	drop.color = Color(1.0, 0.85, 0.3, 1.0)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drop)

	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(drop, "modulate:a", 0.2, 0.15)
	tween.tween_property(drop, "modulate:a", 1.0, 0.15)
	tween.finished.connect(drop.queue_free)


# 统一玩家输入开关；找不到 Player 时仅日志（不崩溃）。
func _set_player_input_enabled(enabled: bool) -> void:
	var player := get_tree().current_scene.get_node_or_null("Player") as Node
	if player == null:
		DebugState.debug_log("LevelManager: 找不到 Player，输入锁定跳过", "Level")
		return
	if player.has_method("set_input_enabled"):
		player.set_input_enabled(enabled)


# 背景/场景切换意图接口出口：本 stage 仅日志，视觉待美术确认后接入。
func _request_scene_change(scene_key: String, params: Dictionary) -> void:
	scene_change_requested.emit(scene_key, params)
	DebugState.debug_log("LevelManager: 背景意图 %s（视觉待接入）" % scene_key, "Level")
```

- [ ] **Step 7: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `level_manager.gd` 解析错误。

- [ ] **Step 8: Commit（可选）**

```bash
git add Scenes/Main/level_manager.gd
git commit -m "feat: LevelManager 演出编排（夜晚/登场/转段/胜利/输入锁定/背景接口）"
```

---

### Task 7: 更新 level_001.tres（NightSegment 段 + 胜利对话配置）

**Files:**
- Modify: `data/levels/level_001.tres`

**Interfaces:**
- Consumes: `NightSegment`（Task 2）、`LevelDefinition.victory_message_ids`（Task 2）、消息 id（Task 1）。
- Produces: 关卡流程 = `[NightSegment(夜晚), BossSegment(现有)]`，`victory_message_ids = victory_01..06`。

- [ ] **Step 1: 读取当前 `level_001.tres`**

现有结构（18 行）：`ext_resource` 到 `id="4_boss_scene"`，一个 `Resource_boss_seg` 子资源。

- [ ] **Step 2: 重写 `level_001.tres`**

替换为（`load_steps=5`：新增 night_segment.gd 脚本引用；保留原 boss ext_resource；新增 night 子资源；LevelDefinition 加 `victory_message_ids`）：

```
[gd_resource type="Resource" script_class="LevelDefinition" load_steps=5 format=3]

[ext_resource type="Script" path="res://Public/level/level_definition.gd" id="1_define"]
[ext_resource type="Script" path="res://Public/level/level_segment.gd" id="2_seg"]
[ext_resource type="Script" path="res://Public/level/boss_segment.gd" id="3_boss"]
[ext_resource type="Script" path="res://Public/level/night_segment.gd" id="4_night"]
[ext_resource type="PackedScene" uid="uid://2r1iin0pml1l" path="res://Scenes/Boss/boss_base.tscn" id="5_boss_scene"]

[sub_resource type="Resource" id="Resource_night_seg"]
script = ExtResource("4_night")
type = "night"
wait_before_start = 0.8
message_ids = Array[String](["night_01", "night_02", "night_03", "night_04"])
bgm_track = "test_boss_intro"
bgm_fade_in = 1.5
bgm_fade_out = 0.5
scene_ambience_key = "night_fall"

[sub_resource type="Resource" id="Resource_boss_seg"]
script = ExtResource("3_boss")
type = "boss"
boss_scene = ExtResource("5_boss_scene")
entrance_delay = 0.5
spawn_position = Vector2(316, 134)
phase_message_ids = {2: &"eye_phase_2"}

[resource]
script = ExtResource("1_define")
segments = Array[ExtResource("2_seg")]([SubResource("Resource_night_seg"), SubResource("Resource_boss_seg")])
victory_message_ids = Array[String](["victory_01", "victory_02", "victory_03", "victory_04", "victory_05", "victory_06"])
```

- [ ] **Step 3: 验证加载无错误**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无 `level_001.tres` 资源错误；无 `Message id not found` 警告。

- [ ] **Step 4: Commit（可选）**

```bash
git add data/levels/level_001.tres
git commit -m "feat: 关卡配置接入夜晚段与胜利对话序列"
```

---

### Task 8: 全链路 headless 验证

**Files:** 无（验证 + 收尾）。

- [ ] **Step 1: 启动主场景 headless 验证**

Run:
```powershell
& "D:\Game\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\Dev\Godot\无聊的飞" --quit-after 30
```
Expected: 无解析/资源/脚本错误。日志中出现（若 debug 开启可见）：`LevelManager: 夜晚段完成`、`LevelManager: 已实例化 Boss，输入已锁定`、`LevelManager: Boss 入场完成，输入解锁`、`LevelManager: 转段演出已触发`、`LevelManager: Boss 死亡，进入胜利流程`、`LevelManager: boss_flag 更新占位`。

- [ ] **Step 2: 手动验收（可选，非 headless 可观察项）**

运行主场景（非 headless），确认画面可见：夜晚对话依序打字机显示 → Boss 登场（输入短暂锁定后恢复）→ 血条出现 → 转段时对话+音乐层切换 → 胜利时 Boss 消散淡出 + 掉落色块闪烁 + 胜利对话。

- [ ] **Step 3: 收尾（用户要求时才做）**

回读 `level_manager.gd`/`boss_base.gd`/`level_001.tres` 确认无残留占位错误、注释符合中文风格；不写额外文档（记忆约定：文档按需、用户要求才写）。

---

### 收尾验收（非独立任务）

- [ ] 夜晚段：`wait_before_start` 后 4 条夜晚对话依序显示，`test_boss_intro` BGM 渐入。
- [ ] 登场：Boss spawn 后玩家输入锁定，`phase_changed(1)`（Intro→Phase1）解锁。
- [ ] 转段：Phase2→Phase3 时 `BossExternalEventPattern` 发出事件 → `transition_01..03` 对话 + `set_bgm_layer_enabled(true)`。
- [ ] 胜利：`died` 后输入暂停、Boss 消散淡出、掉落色块闪烁、`victory_01..06` 对话、`boss_flag` 日志占位。
- [ ] `scene_change_requested` 全程仅日志（无视觉层），注释待美术。
- [ ] `phase_message_ids={2: eye_phase_2}` 兼容保留（Phase2 转段消息不受影响）。
