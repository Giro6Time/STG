# 消息框系统说明

本文档说明如何维护事件驱动的信息框系统，以及如何从 Excel 生成 Godot 运行时使用的 JSON。

## Excel 字段

Excel 默认位置是 `tools/message_exporter/messages_zh.xlsx`，字段如下：

```text
id,speaker,text,duration,typewriter,chars_per_second,priority,interrupt_policy
```

- `id`：消息唯一标识，不能为空，不写入 JSON value，而是作为 JSON 外层 key。
- `speaker`：说话者，可以为空。
- `text`：消息正文，不能为空，可以包含文本控制标记。
- `duration`：文本完整显示后的停留秒数，默认 `3.0`。
- `typewriter`：是否启用打字机，默认 `true`。
- `chars_per_second`：默认打字速度，默认 `24`。
- `priority`：预留优先级字段，默认 `0`。
- `interrupt_policy`：当前消息框忙时的处理策略，可选 `queue`、`interrupt`、`ignore`，默认 `queue`。

## 转换命令

在项目根目录执行：

```bash
python tools/message_exporter/export_messages.py --input tools/message_exporter/messages_zh.xlsx --output data/messages/messages_zh.json
```

工具会校验空 id、空 text、重复 id 和非法 `interrupt_policy`。输出 JSON 使用 UTF-8，并保留中文可读文本。

## JSON 格式

生成后的 JSON 示例：

```json
{
  "eye_intro_warning": {
    "speaker": "System",
    "text": "你感觉有一个[pause=0.3][slow][color=#ff5a7a]邪恶的存在[/color][/slow][pause=0.5]正在注视着你……",
    "duration": 3.0,
    "typewriter": true,
    "chars_per_second": 24,
    "priority": 10,
    "interrupt_policy": "queue"
  }
}
```

## Godot 调用方式

`MessageLayer` 可以直接放入 `Main` 场景。它包含：

- `MessageBox`：负责 UI、打字机和自动隐藏。
- `MessageController`：负责加载 JSON、按 id 查询、队列和打断策略。

其他节点只需要拿到 `MessageController` 后调用：

```gdscript
controller.show_by_id("eye_intro_warning")
```

如果要配置其他语言或其他表格，可以在 Inspector 中修改 `MessageController.messages_json_path`。

## 文本标记

第一版支持以下控制标记：

- `[slow]...[/slow]`：中间文本速度为 `chars_per_second * 0.5`。
- `[fast]...[/fast]`：中间文本速度为 `chars_per_second * 2.0`。
- `[pause=0.5]`：暂停 0.5 秒，标记本身不会显示。
- `[color=#ff5577]...[/color]`：中间文本使用指定颜色，支持 `#rgb`、`#rrggbb`、`#rrggbbaa`，也支持少量英文色名如 `red`、`yellow`、`cyan`。

标记格式错误时，系统会尽量按普通文本处理，避免因为文案问题导致游戏崩溃。

## 当前限制

- 当前不绑定玩家输入跳过文本，因为这是弹幕射击游戏，不是剧情对话游戏。
- `finish_current_text_immediately()` 已保留给未来内部逻辑使用。
- `priority` 字段目前只随数据保留，暂不参与队列排序。

## 快速验证

可以运行 `Scenes/Message/message_test.tscn`。该场景启动后会依次显示：

1. `eye_intro_warning`
2. `eye_phase_2`
3. `eye_defeated`
