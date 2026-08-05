# 音频系统说明

本文档说明当前项目的音效和 BGM 管理方式，方便后续 VibeCoding 时快速接手。

## 核心入口

`AudioManager` 是 Autoload，场景资源位于：

```text
res://Scenes/Audio/audio_manager.tscn
```

脚本位置：

```text
res://Scenes/Audio/audio_manager.gd
```

项目启动后可以直接在任意脚本中调用：

```gdscript
AudioManager.play_sfx("player_shoot")
AudioManager.play_sfx_id(AudioIds.Sfx.PLAYER_SHOOT)
AudioManager.play_sfx_at("enemy_hit", global_position)
AudioManager.play_sfx_follow("laser_loop", boss_node)
AudioManager.stop_sfx(loop_player)

AudioManager.play_bgm("stage_intro", 1.0, 0.5)
AudioManager.play_bgm_id(AudioIds.Bgm.STAGE_INTRO, 1.0, 0.5)
AudioManager.set_bgm_layer_enabled(true, 0.75)
```

## 配置方式

音频配置直接在 Godot Inspector 中完成，不使用额外表格。

1. 打开 `Scenes/Audio/audio_manager.tscn`。
2. 在根节点 `AudioManager` 上配置：
   - `sfx_events`：音效事件数组。
   - `bgm_tracks`：BGM 曲目数组。
   - `initial_sfx_pool_size`：普通音效播放器预热数量。
   - `initial_sfx_2d_pool_size`：2D 音效播放器预热数量。
3. `sfx_events` 元素使用 `AudioSfxEvent` 资源。
4. `bgm_tracks` 元素使用 `AudioBgmTrack` 资源。

### AudioSfxEvent

位置：`res://Public/audio/audio_sfx_event.gd`

关键字段：

- `event_name`：事件名，玩法脚本用这个字符串播放音效。
- `event_id`：可选数字 id，默认 `-1` 表示不用。调用侧如果想用 enum，可以把 enum 值填到这里。
- `stream`：音效资源。
- `volume_db`：默认音量。
- `pitch_scale`：默认音调。
- `bus`：音频总线，默认 `Master`。
- `loop`：是否循环。循环音效需要调用 `stop_sfx()` 或 `stop_sfx_by_event()` 停止。
- `use_2d_player`：是否默认使用 `AudioStreamPlayer2D`。
- `max_instances`：同一事件最多同时播放数量，`0` 表示不限制。
- `same_event_policy`：同一音效重复触发时允许叠加，或打断之前的同名音效。
- `once_per_frame`：同一事件每帧最多播放一次，适合高频命中、擦弹等场景。

### AudioBgmTrack

位置：`res://Public/audio/audio_bgm_track.gd`

关键字段：

- `track_name`：曲目名，玩法脚本用这个字符串播放 BGM。
- `track_id`：可选数字 id，默认 `-1` 表示不用。调用侧如果想用 enum，可以把 enum 值填到这里。
- `primary_stream`：主通道音乐。
- `layer_stream`：第二通道音乐，可用于鼓点、高潮层或危险层。
- `volume_db`：主通道音量。
- `layer_volume_db`：第二通道目标音量。
- `bus`：音频总线。
- `loop`：播放完成后是否重新开始。
- `start_with_layer`：播放曲目时第二通道是否默认开启。

## 音效调用

普通音效：

```gdscript
AudioManager.play_sfx("player_shoot")
```

enum / 数字 id 音效：

```gdscript
enum Sfx {
	PLAYER_SHOOT = 1,
	ENEMY_HIT = 2
}

AudioManager.play_sfx_id(Sfx.PLAYER_SHOOT)
```

指定位置的 2D 音效：

```gdscript
AudioManager.play_sfx_at("enemy_destroyed", enemy.global_position)
```

跟随场景对象的循环音效：

```gdscript
var loop_player: Node = AudioManager.play_sfx_follow("boss_charge_loop", boss)
AudioManager.stop_sfx(loop_player)
```

临时覆盖音量或音调：

```gdscript
AudioManager.play_sfx("graze", {
	"volume_db": -6.0,
	"pitch_scale": 1.15
})
```

## BGM 双通道

每首 BGM 最多有两个通道：

- 主通道：一直播放，例如基础旋律。
- 第二通道：和主通道从同一播放位置开始，用音量淡入淡出来启用或隐藏，例如鼓点。

播放 BGM：

```gdscript
AudioManager.play_bgm("stage_theme", 1.0, 0.5)
```

enum / 数字 id BGM：

```gdscript
enum Bgm {
	STAGE_THEME = 1,
	BOSS_THEME = 2
}

AudioManager.play_bgm_id(Bgm.STAGE_THEME, 1.0, 0.5)
```

进入高潮时打开第二通道：

```gdscript
AudioManager.set_bgm_layer_enabled(true, 0.75)
```

回到平淡阶段时关闭第二通道：

```gdscript
AudioManager.set_bgm_layer_enabled(false, 0.75)
```

查询长度和播放位置：

```gdscript
var length: float = AudioManager.get_bgm_length("stage_theme")
var position: float = AudioManager.get_bgm_playback_position()
```

## 前奏循环后无缝进 Boss 正曲

推荐方案是准备两段音频：

1. `boss_intro_loop`：可以循环的 Boss 前奏。
2. `boss_theme`：正式战斗音乐，开头需要和前奏循环尾部在音乐上能衔接。

播放对话或登场时：

```gdscript
AudioManager.play_bgm("boss_intro_loop", 0.5, 0.0)
```

玩家正式进入战斗前，把正式曲排队到当前循环结束后播放：

```gdscript
AudioManager.queue_bgm_after_current_loop("boss_theme", 0.0)
```

注意：这个排队切换依赖 `AudioStreamPlayer.finished` 信号，因此 `boss_intro_loop` 的音频资源本身不要开启内部 loop；循环交给 `AudioManager` 的 `AudioBgmTrack.loop` 字段处理。这样管理器能在一轮前奏结束的瞬间切到下一首，减少明显跳变。

## 未来拓展点

- 暂停时的沉闷/低通效果可以通过新增 Audio bus effect 或调整 BGM/SFX 总线音量实现。
- 如果后续需要 enum 调用，可以新增 `AudioEventNames.gd` 常量脚本，把字符串集中管理。
- 如果需要更严格的节拍同步，可以在 `AudioBgmTrack` 中补充 BPM、小节长度和入点偏移。

## 测试场景

从 Godot 编辑器直接运行：

```text
res://Scenes/Audio/Test/audio_manager_test.tscn
```

场景会临时载入 `res://data/audio/test/` 中的测试资源，退出时恢复 AudioManager 原配置。面板覆盖字符串和 enum/id 调用、临时音量、2D 定点音效、移动目标跟随、循环停止、同名打断、每帧限播、BGM 淡入淡出、双通道开关、长度显示以及 Boss 前奏结束后切换正式曲。

测试 WAV 位于 `res://Art/Audio/Test/`。需要重新生成时，在项目目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\generate_audio_test_data.ps1
```

自动冒烟测试场景：

```text
res://Scenes/Audio/Test/audio_manager_smoke_test.tscn
```

## 应用正式音频

1. 把正式音频放到项目内，例如 `res://Art/Audio/SFX/` 和 `res://Art/Audio/BGM/`。
2. 在 FileSystem 面板右键目标目录新建 Resource，选择 `AudioSfxEvent` 或 `AudioBgmTrack`，保存为 `.tres`。
3. 将音频文件拖入资源的 `stream`、`primary_stream` 或 `layer_stream`，并设置事件名、可选数字 id、音量和循环等参数。
4. 打开 `res://Scenes/Audio/audio_manager.tscn`，把正式 `.tres` 加入根节点的 `sfx_events` 或 `bgm_tracks` 数组。
5. 在玩法脚本中通过 `AudioManager.play_sfx(...)`、`play_sfx_id(...)` 或 `play_bgm(...)` 调用。

同一首双通道 BGM 的 `primary_stream` 和 `layer_stream` 必须使用相同采样率、相同长度、相同起点并从同一工程时间轴导出，否则运行时即使从相同播放位置启动也可能听到节奏偏移。

Boss 前奏衔接正式曲时，把前奏和正式曲分别导出为两个文件。前奏资源不要启用音频文件内部循环，由 `AudioBgmTrack.loop` 管理；正式曲开头需要在音乐制作阶段与前奏循环尾部自然连接。进入对话时播放前奏，允许开战后调用 `queue_bgm_after_current_loop()`，系统会在当前前奏完整结束时切换。
