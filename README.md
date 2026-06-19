# STG

Godot 4.x 纵向弹幕射击游戏原型。项目目前处在基础游戏循环完成后的早期开发阶段，已经具备玩家移动、慢速判定点显示、玩家射击、敌人发射、命中扣血、敌人死亡和子弹对象池回收。

## 当前进度

- 项目名称已改为 `STG`。
- 主场景为 `res://Scenes/Main/main.tscn`。
- 窗口尺寸为 640 x 720，固定窗口，使用 `canvas_items` 拉伸模式。
- 玩家可以用方向键移动，按 Shift 慢速移动，按 Z 连续射击。
- 玩家慢速移动时会显示判定点。
- 主场景中已有一个基础敌人实例。
- 敌人会按冷却时间向下发射番茄子弹。
- 玩家子弹命中敌人后调用 `take_damage()`，敌人生命值归零后销毁。
- 敌人子弹命中玩家后调用 `take_damage()`，玩家生命值归零后销毁。
- 子弹通过 `BulletLayer` 统一生成、越界清理和对象池回收。

## 项目结构

```text
Art/
  EnemyAirframe-tomato/        敌人和敌人子弹素材
  SelfAirframe-Nue/            玩家、玩家子弹和判定点素材
Public/
  collision_layers.gd          碰撞层和碰撞 mask 常量
Scenes/
  Main/                        主场景
  Player/                      玩家场景与控制脚本
  Enemy/                       基础敌人场景与脚本
  BulletLayer/                 子弹管理层和对象池
  Bullet/BulletBase/           通用基础子弹
  Bullet/ConcreateScene/       具体子弹场景，例如 TomatoBullet
```

## 碰撞层约定

碰撞层常量定义在 `res://Public/collision_layers.gd`，脚本类名为 `CollisionLayers`。

| 常量 | 数值 | 含义 |
| --- | ---: | --- |
| `CollisionLayers.PLAYER` | `1` | 玩家 |
| `CollisionLayers.PLAYER_BULLET` | `2` | 玩家子弹 |
| `CollisionLayers.ENEMY` | `4` | 敌人 |
| `CollisionLayers.ENEMY_BULLET` | `8` | 敌人子弹 |

当前碰撞关系：

| 对象 | Layer | Mask |
| --- | --- | --- |
| Player | `PLAYER` | `ENEMY | ENEMY_BULLET` |
| PlayerBullet | `PLAYER_BULLET` | `ENEMY` |
| Enemy | `ENEMY` | `PLAYER | PLAYER_BULLET` |
| EnemyBullet | `ENEMY_BULLET` | `PLAYER` |

说明：`Layer` 表示“我是谁”，`Mask` 表示“我检测谁”。

## 核心脚本

### `Scenes/Player/player.gd`

负责玩家移动、慢速移动、射击、判定点显示、受伤和死亡。

### `Scenes/Enemy/enemy_base.gd`

负责敌人生命值、接触伤害和定时发射敌人子弹。

### `Scenes/Bullet/BulletBase/bullet_base.gd`

通用子弹基类。负责移动、命中检测、伤害调用和回收入口。子弹生成时可通过初始化数据设置速度、方向、伤害、`collision_layer` 和 `collision_mask`。

### `Scenes/BulletLayer/bullet_layer.gd`

负责子弹对象池、生成、回收和越界清理。

## 当前已知优化点

- 将对象池生命周期抽象为类似 `on_spawned()` / `on_despawned()` 的回调，让具体子弹自己重置动画、粒子、拖尾和内部状态。
- `TomatoBullet` 使用对象池复用后，动画是否从第一帧重播需要后续统一设计。
- `Player` 和 `Enemy` 目前通过 `current_scene.get_node("BulletLayer")` 查找子弹层，后续可改成注入、组查找或 `NodePath` 配置。
- 建议让具体子弹场景自身也保存正确默认 layer/mask，避免直接拖入场景测试时行为不一致。
- `collision_layers.gd` 当前命名合理：文件名使用 snake_case，类名保持 `CollisionLayers`。
- 后续需要补充游戏状态管理，例如玩家死亡、敌人死亡特效、分数、关卡流程和重开。

## 运行方式

1. 使用 Godot 打开项目目录。
2. 运行主场景 `Scenes/Main/main.tscn`。
3. 方向键移动，Shift 慢速移动，Z 射击。

