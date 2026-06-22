# Codex Project Guidelines

This document defines how Codex should modify code in this project.

Before starting any new development task, Codex should read this file and follow all guidelines described here.

---

# Godot / GDScript Coding Guidelines

## Core Principles

* Always prioritize keeping the project openable, runnable, and editable in the Godot Editor.
* Do not introduce unnecessary architecture or abstractions merely to make the code look more sophisticated.
* Prefer small, incremental changes that can be validated quickly.
* Avoid modifying multiple systems at once unless explicitly requested by the user.
* Be extremely careful when editing `.tscn` files. Do not break Godot-generated resource references.
* Documentation intended for AI agents should be written in English.
* Documentation, comments, README files, and other developer-facing text should be written in Chinese.
* 新增到玩法脚本里的代码注释应使用中文，优先解释设计意图、玩法含义或不明显的行为，不要重复描述简单代码本身。

---

## GDScript Syntax Rules

* Avoid syntax that may have version compatibility issues across Godot releases.
* Do not use fancy or experimental language features that may cause compilation failures.
* Make conditional checks explicit whenever possible.

Example:

```gdscript
if (flags & FLAG_VISIBLE) != 0:
	pass
```

* Prefer explicit array iteration:

```gdscript
for index in range(items.size()):
	var item = items[index]
```

* Avoid type inference using `:=`.
* Prefer explicit type declarations:

```gdscript
var speed: float = 100.0
```

instead of:

```gdscript
var speed := 100.0
```

* Do not assume arbitrary `Node` objects expose dynamic properties safely.
* Prefer explicit types, methods, or safe wrappers when accessing node data.
* Use `get_node_or_null()` for optional nodes.
* Avoid hardcoded absolute scene paths in reusable scenes.
* If new autoloads, input mappings, or project settings are introduced, explicitly mention them in the task summary.

---

## Naming Conventions

### Files

Use `snake_case`.

Examples:

```text
debug_state.gd
collision_layers.gd
```

### Classes

Use `PascalCase`.

Examples:

```text
DebugState
CollisionLayers
```

### Constants

Use `UPPER_SNAKE_CASE`.

Examples:

```gdscript
const PLAYER_SPEED = 300.0
```

### Private Members and Internal Methods

Use a leading underscore.

Examples:

```gdscript
var _fire_timer: Timer

func _refresh_logs() -> void:
	pass
```

---

## Debug Feature Guidelines

* Debug functionality must be disabled by default.
* Debug functionality must work while running inside the editor.
* Debug functionality must be removable or disabled for release builds.
* Debug input handling, overlays, logging, collision visualization, and related tools should be centrally managed.
* Do not scatter temporary `print()` statements throughout gameplay code.
* Debug code must never interfere with the normal gameplay loop.
* The first version of any debug UI should prioritize stability and readability over visual complexity.

---

## Collision Layer Guidelines

* Do not use magic numbers such as `1`, `2`, `4`, `8`, etc. directly in gameplay scripts.
* Define collision layers and masks through centralized constants.

---

## Object Pooling Guidelines

* Systems that may create large numbers of runtime instances should use object pooling.
* Pooled objects should support lifecycle callbacks similar to:

```gdscript
func on_spawned(init_data: Dictionary) -> void:
	pass

func on_despawned() -> void:
	pass
```

---

# Development Workflow

## Before Starting Work

* Check the current Git branch.
* Check the working tree status.
* Make sure current
## Git Workflow

This project follows a simplified Git Flow style.

### Branch Roles

- `main`
  - Represents stable milestone releases.
  - Only updated when a major development stage is completed.
  - Typically corresponds to a playable/demo/release build update.
  - Avoid committing daily development work directly to `main`.

- `develop`
  - Primary integration branch for active development.
  - All completed features should eventually be merged into `develop`.
  - Daily development progress is tracked here.

### Feature Development

For every new feature, bugfix, or experiment:

1. Create a new branch from `develop`.
2. Implement the feature within that branch.
3. Keep changes focused on a single task whenever possible.
4. Open a Pull Request targeting `develop`.
5. Perform code review before merging.
6. Merge into `develop` after the feature is verified.

Example:

```text
develop
 ├─ feature/player-shooting
 ├─ feature/enemy-spawn
 ├─ feature/debug-overlay
 └─ fix/bullet-despawn
```
## During Development

* If the user requests phased implementation, complete one phase at a time.
* Provide a summary after each phase before proceeding.

## Git

* Do not create commits automatically unless explicitly requested by the user.

## Validation

* If Godot cannot be executed for verification, explicitly state that validation was not performed.

## Cleanup

* If temporary files, corrupted directories, generated junk files, or unrelated outputs are created during development, explicitly mention them and clean them up before finishing the task.
