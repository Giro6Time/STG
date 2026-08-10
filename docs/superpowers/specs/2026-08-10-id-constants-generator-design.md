# 2026-08-10 ID 常量生成器设计（ID Constants Generator）

> 背景：用户在 boss 流程重做设计中提出——要不要做工具把 message_id / audio_id 自动转成 enum。
> 裁决：**做生成工具，且本期先行单独开工**；boss 流程重做延后（其 spec `2026-08-10-level-flow-redesign.md` 保留，
> 工具完成后回来重估）。

## 背景与目标

当前代码里 message_id / audio_id 是魔法字符串：

```gdscript
controller.show_by_id("eye_phase_2")   # 拼错只在运行时静默
AudioManager.play_bgm("test_boss")
```

目标：用生成器把项目里的 id 汇总成 GDScript 常量类，调用处获得**编译期检查 + IDE 自动补全**。

## 已确认决策

1. **自动化路径**：D——先手动后自动化。本期只做生成器脚本 + 手动命令；pre-commit hook / 编辑器插件留后续单独一期。
2. **生成物形态**：常量类统一。`class_name MessageId` / `class_name AudioId`，内部 `const StringName`。
   - 原因：message id 是字符串，GDScript `enum` 是整型装不下；常量类字符串/数字通吃且效果等价。
3. **audio 内容**：只生成名字常量（`track_name` / `event_name`），统一走名字 API
   （`play_bgm("...")` / `play_sfx("...")`）；数字 id（`track_id` / `event_id`）与 `play_*_id` API 废弃不用。
4. **生成物路径**：`Public/ids/` 子目录（`Public/ids/message_ids.gd` + `Public/ids/audio_ids.gd`），收拢后续 id 类。
5. **重名处理**：扫描到重复 id（两个 .tres 同名 / JSON key 重复）→ **报错退出**，绝不静默去重。
   重复是配置错误，应尽早暴露。

## 输入 → 输出

| 源 | 解析方式 | 生成物 |
|---|---|---|
| `data/messages/messages_zh.json` | JSON 顶层键 | `Public/ids/message_ids.gd` |
| `data/audio/**/*.tres` | 按 `script_class` 区分 BGM/SFX，读 `track_name` / `event_name` 字段 | `Public/ids/audio_ids.gd` |

## 生成物形态

```gdscript
# 自动生成，勿手改 —— 由 tools/gen_id_constants.py 生成
class_name MessageId

const EYE_INTRO_WARNING: StringName = &"eye_intro_warning"
const EYE_PHASE_2: StringName = &"eye_phase_2"
const EYE_DEFEATED: StringName = &"eye_defeated"
```

```gdscript
class_name AudioId

# BGM
const TEST_BOSS: StringName = &"test_boss"
const TEST_BOSS_INTRO: StringName = &"test_boss_intro"
# SFX
const TEST_HIT: StringName = &"test_hit"
```

**命名转换**：`snake_case` → `SCREAMING_SNAKE_CASE`（`eye_intro_warning` → `EYE_INTRO_WARNING`）。
对非 snake_case 的源名（如含数字/大写混合）：统一转为全大写 + 下划线，保证常量名合法；转换后冲突按重名规则报错。

**分类注释**：`AudioId` 内 BGM 段注释 `# BGM`、SFX 段注释 `# SFX`（按 .tres 的 script_class 分组）。

## 生成脚本（`tools/gen_id_constants.py`）

- 纯 Python 标准库（json + 文本解析 .tres），无第三方依赖——与 `export_messages.py` 同目录惯例。
- **解释器**：本机 PATH 无 python（WindowsApps 仅为 stub），使用 **Codex runtime Python 3.12.13**：
  `C:\Users\31391\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`
  （所有命令一律用此绝对路径调用，不依赖 PATH。）
- **扫描范围**：`data/audio/` 递归扫描全部 `*.tres`（不限定单目录，与现有测试/正式音频分层兼容）。
- **幂等**：重复运行输出一致（排序输出，不依赖文件扫描顺序）。
- 文件头写入"自动生成，勿手改"警告注释。
- 输出到 `Public/ids/`（目录不存在则创建）。
- 校验：重复 id / 转换后常量名非法 → 报错退出（非零 exit code）。

### CLI

```powershell
$PY = "C:\Users\31391\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

& $PY tools/gen_id_constants.py          # 全量生成
& $PY tools/gen_id_constants.py --check  # 只检查是否 stale，不写文件（CI/hook 预留，本期实现）
```

> 注：`export_messages.py` 的 `--input/--output` 风格不沿用——本生成器从固定项目路径扫描，无需参数（除 `--check`）。

## 错误处理与边界

| 情况 | 行为 |
|---|---|
| messages_zh.json 缺失 | 报错退出 |
| audio 目录无 .tres | 生成空 AudioId（仅类声明），不报错 |
| .tres 无 script_class / 非 BGM/SFX | 跳过该文件（其他资源类型不参与） |
| 重复 id（BGM 内 / SFX 内 / 跨类型同名） | 报错退出，列出重复项 |
| 转换后常量名非法 / 冲突 | 报错退出 |
| `--check` 时生成物 stale | 报错退出（提示先运行全量生成） |

## 测试

- **手动验证**：运行全量生成 → 用 Godot headless 加载确认两个新类无解析错误
  （`godot --headless --quit-after 30`）。
- **幂等验证**：连续运行两次，输出文件字节一致（或 git diff 为空）。
- **stale 验证**：改源（如 json 加一个 key）→ `--check` 应报 stale。
- **负向验证**：临时构造重复 id → 应报错退出。

## 明确不做（防范围蔓延）

- ❌ 不实现自动化触发（pre-commit hook / 编辑器插件）——后续单独一期。
- ❌ 不生成数字 id 常量（决定只走名字 API）。
- ❌ 不替换现有代码里的魔法字符串为常量引用——那是各系统（boss 流程重做等）开工时一并做的活。
- ❌ 不做源文件的 watcher / 热更新。

## 后续方向（本期不做，记录）

- **自动化一期**：pre-commit hook（`--check` 拦截 stale）+ 可选编辑器插件（保存时重生成）。
- **回接 boss 流程重做**：工具完成后，回来重估 `2026-08-10-level-flow-redesign.md`，
  `show_by_id` / `play_bgm` 调用点改用 `MessageId.XXX` / `AudioId.XXX`。
