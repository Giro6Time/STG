# AudioManager Test Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有 AudioManager 建立可运行、可听取、可自动验证的测试数据与测试场景。

**Architecture:** 独立 `.tres` 描述测试事件和曲目，测试场景启动时临时注入 Autoload。自动化场景直接调用真实 AudioManager，交互场景用按钮展示调用方式，两者共用同一批测试资源。

**Tech Stack:** Godot 4.7、GDScript、Godot Resource、PCM WAV、PowerShell 资源生成脚本。

## Global Constraints

- 面向开发者的文档和关键代码注释使用中文。
- 测试数据不得写入正式 `audio_manager.tscn`。
- 不引入第三方插件或额外配置表。
- 使用固定 Godot 路径 `C:\Users\31391\Documents\Godot-STG\GodotEngine\godot.windows.opt.tools.64.exe` 验证。

---

### Task 1: 自动化冒烟测试入口

**Files:**
- Create: `Scenes/Audio/Test/audio_manager_smoke_test.gd`
- Create: `Scenes/Audio/Test/audio_manager_smoke_test.tscn`

**Interfaces:**
- Consumes: `AudioManager.rebuild_config_index()`、SFX/BGM 公共播放接口。
- Produces: 无头测试退出码，0 表示通过，1 表示至少一项失败。

- [ ] 先创建引用尚不存在测试资源的测试场景。
- [ ] 运行 Godot 并确认因测试数据缺失而失败。
- [ ] 在后续任务补齐真实资源后重新运行，确认所有断言通过。

### Task 2: 测试音频与资源配置

**Files:**
- Create: `tools/generate_audio_test_data.ps1`
- Create: `Art/Audio/Test/*.wav`
- Create: `data/audio/test/*.tres`

**Interfaces:**
- Produces: `test_ping`、`test_hit`、`test_follow_loop`、`test_interrupt`、`test_once_per_frame` 音效事件，以及 `test_stage`、`test_boss_intro`、`test_boss` BGM 曲目。

- [ ] 创建可重复执行的 PCM WAV 生成脚本。
- [ ] 生成短音效、循环声、双通道音乐和前奏/正式曲测试音。
- [ ] 创建对应 `AudioSfxEvent` 与 `AudioBgmTrack` 资源。
- [ ] 运行冒烟测试，确认资源可导入且公共接口可调用。

### Task 3: 交互测试场景与文档

**Files:**
- Create: `Scenes/Audio/Test/audio_manager_test.gd`
- Create: `Scenes/Audio/Test/audio_manager_test.tscn`
- Modify: `docs/audio_system.md`

**Interfaces:**
- Consumes: Task 2 的测试资源。
- Produces: 可从编辑器直接运行的音频控制面板和移动 2D 声源。

- [ ] 创建分组按钮和实时状态显示。
- [ ] 接入字符串/id、循环、2D、双通道、淡入淡出与排队切歌示例。
- [ ] 无头加载交互场景，确认无解析错误。
- [ ] 补充正式音频导入、资源创建、挂载与调用说明。
- [ ] 运行完整无头测试和 `git diff --check`。
