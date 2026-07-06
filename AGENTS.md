# Codex 项目说明

本项目是 Godot 4.x 的纵向弹幕射击游戏原型，偏东方 STG。当前已有玩家移动、慢速判定点、玩家射击、敌人/Boss、弹幕对象池、擦弹、调试显示、消息框和 Boss 阶段流程系统。

主场景：`res://Scenes/Main/main.tscn`

窗口：640 x 720，固定窗口，`canvas_items` 拉伸。

## 目录速览

- `Art/`：玩家、敌人、子弹等素材。
- `Public/`：跨场景复用的基础脚本，例如碰撞层、调试状态、擦弹上下文、状态机、流程系统、消息数据加载、曲线和发射器。
- `Scenes/Main/`：主场景。
- `Scenes/Player/`：玩家场景和控制脚本。
- `Scenes/Enemy/`：基础敌人。
- `Scenes/Boss/`：Boss、本体血条、移动/攻击/等待等 Pattern。
- `Scenes/BulletLayer/`：弹幕生成、对象池、越界回收。
- `Scenes/Bullet/`：通用子弹基类和具体子弹场景。
- `Scenes/Debug/`：调试绘制和调试面板。
- `Scenes/Message/`：消息框 UI、控制器和测试场景。
- `data/messages/`：运行时消息 JSON。
- `docs/`：系统说明文档。
- `tools/`：辅助工具，例如消息表导出。

## 开发原则

- 优先保证项目能被 Godot Editor 打开、运行和编辑。
- 小步修改，尽量只改当前任务相关的系统。
- 不为了“显得高级”增加抽象；只有在减少重复、降低复杂度或符合现有模式时才抽象。
- 修改 `.tscn`、`.tres`、`project.godot` 时要格外谨慎，避免破坏 Godot 生成的资源引用、UID 和 Inspector 配置。
- 新增 Autoload、InputMap、项目设置、主场景配置或碰撞层约定时，在最终说明中明确指出。
- 不自动提交、不自动建分支、不自动发 PR，除非用户明确要求。

## 中文要求

- 面向开发者的文档、README、代码注释、任务总结优先使用中文。
- 新增到玩法脚本里的代码注释应使用中文，优先解释设计意图、玩法含义或不明显的行为，不要重复描述简单代码本身。
- 不要求每个函数都写注释；复杂逻辑、关键入口、生命周期回调、跨系统交互处应写清楚。
- 保留已有中文注释风格，修改附近代码时顺手修正明显过时或误导的注释。

## GDScript 风格

- 文件名使用 `snake_case`，类名使用 `PascalCase`，常量使用 `UPPER_SNAKE_CASE`。
- 私有变量和内部方法使用前导下划线，例如 `_fire_timer`、`_refresh_state()`。
- 重要导出变量、节点引用和公开方法尽量写明确类型。
- 可以使用项目中已有的 GDScript 写法；不要为了风格统一进行大规模机械重写。
- 条件判断要清楚，涉及 bit mask 时写成显式比较，例如 `(flags & FLAG_VISIBLE) != 0`。
- 可选节点使用 `get_node_or_null()` 或空值检查。
- 避免在可复用场景里硬编码绝对场景路径；优先使用导出 `NodePath`、group、父节点注入或当前项目已有的查找方式。

## 碰撞与弹幕

- 碰撞层常量集中在 `res://Public/collision_layers.gd` 的 `CollisionLayers` 中。
- 玩法脚本里不要直接写 `1`、`2`、`4`、`8` 这类碰撞层魔法数字。
- 大量生成的运行时对象应优先走对象池，当前弹幕由 `BulletLayer` 统一生成、回收和越界清理。
- 回收对象时注意重置会影响复用的状态，例如动画、粒子、拖尾、命中/擦弹标记、可见性和碰撞状态。

## Debug 约定

- Debug 功能默认不应影响正常玩法。
- 临时 `print()` 不要散落在玩法逻辑中；优先使用现有 `DebugState.debug_log()`。
- 调试绘制、碰撞可视化、面板显示尽量接入现有 Debug 系统。

## 已有系统参考

- Boss 阶段/弹幕流程：见 `docs/phase_machine_flow.md`。
- 消息框和 Excel 导出 JSON：见 `docs/message_system.md`。
- 输入：方向键移动，Shift 慢速，Z 射击，调试快捷键见 `project.godot`。
- Autoload：`DebugState`、`GrazeContext`。

## 验证

- 能运行 Godot 时，优先验证主场景 `Scenes/Main/main.tscn`。
- 消息框相关改动可运行 `Scenes/Message/message_test.tscn`。
- 如果当前环境无法启动 Godot，就说明未做运行验证，并列出已做的静态检查。

## 需要避免的过度要求

以下旧要求不再作为硬性规则：

- 每个任务都必须 fetch、建分支、开 PR。
- 每个 GDScript 函数都必须有中文注释。
- 禁止所有 `:=` 或强制把所有循环改成索引循环。
- 为简单功能预先设计复杂框架。
- 为了“规范”大规模重排场景文件或机械改写无关脚本。
