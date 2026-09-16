# 《魂穿刘关张，诸侯们被整麻了》Godot 4 架构设计说明书

---

## 一、架构设计理念（Data-Driven + Event-Driven）
为了实现高可维护性与 AI Agent 的顺畅代码协作，本项目遵循**数据驱动（Data-Driven）与事件解耦（Event-Driven）**原则：
1. **纯数据与表现解耦**：所有武将属性、技能数值均作为 Godot 4 纯文本资源（`Resource` / `.tres`）存放，不硬编码在场景中。
2. **状态机驱动回合（FSM）**：回合流转、走位高亮、技能选定、敌人行动全部由严格的状态机管理，避免逻辑竞态条件。
3. **原生轮子最大化复用**：网格寻路使用官方 `AStarGrid2D`，特效使用 `GPUParticles2D` 与 `Tween`，UI 使用节点树配合 `%` 唯一名称（Unique Name）。

---

## 二、场景树结构设计（Scene Hierarchy）

```
Main (Node2D, 主场景挂载 main.gd)
├── GridManager (Node, 挂载 grid_manager.gd, 封装 AStarGrid2D)
├── MapLayer (Node2D, 渲染地图格子与地形)
├── UnitManager (Node2D, 挂载 unit_manager.gd, 包含战场所有单位)
│   ├── Unit_GuanYu (CharacterBody2D/Area2D, 实例化的 Unit.tscn)
│   ├── Unit_ZhangFei (Unit.tscn)
│   ├── Unit_LiuBei (Unit.tscn)
│   ├── Unit_HuaXiong (Unit.tscn)
│   └── ...
├── RangeIndicatorLayer (Node2D, 绘制可移动蓝色网格与技能红色威胁区)
├── FXLayer (Node2D, 特效层)
│   ├── DragonMissile (Line2D/GPUParticles2D, 贯穿全图的青龙激光束)
│   ├── SonicWave (Ring Shockwave, 张飞战吼)
│   └── Camera2D (挂载相机震屏控制器)
├── TurnManager (Node, 挂载 turn_manager.gd, 回合调度器)
└── UILayer (CanvasLayer, UI 界面层)
    ├── %HUD (Top-level 状态栏与操作面板)
    │   ├── TurnLabel (当前回合与阶段)
    │   ├── UnitInfoPanel (选中单位属性与关羽龙气进度条)
    │   └── ActionMenu (行动菜单：移动、绝技、画饼、合体、待命)
    ├── %DialogBox (剧情对白框，带立绘与打字机效果)
    ├── %BarrageLayer (搞笑原著弹幕浮动层)
    └── %GachaPanel (战后占领东海郡霸业抽奖界面)
```

---

## 三、核心模块与类设计

### 1. `GridManager.gd`（网格系统）
- **职责**：封装 `AStarGrid2D`，管理 16×10 棋盘。
- **关键函数**：
  - `grid_to_world(grid_pos: Vector2i) -> Vector2`
  - `world_to_grid(world_pos: Vector2) -> Vector2i`
  - `get_walkable_cells(start: Vector2i, move_range: int) -> Array[Vector2i]`
  - `get_path_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]`
  - `set_cell_solid(grid_pos: Vector2i, is_solid: bool)`

### 2. `TurnManager.gd`（回合状态机）
- **状态枚举**：
  - `PLAYER_STANDBY`：等待玩家点击选择我方单位；
  - `PLAYER_SELECT_MOVE`：高亮移动范围，计算步数；
  - `PLAYER_UNIT_MOVING`：播放移动动画，更新蓄力步数；
  - `PLAYER_CHOOSE_ACTION`：弹出行动菜单（攻击/青龙斩/战吼/画饼/骑乘）；
  - `PLAYER_RESOLVE_ACTION`：执行技能动画与伤害结算；
  - `ENEMY_TURN`：敌方 AI 依次执行行动；
  - `GAME_OVER`：胜利或失败结算。
- **核心信号（Signals）**：
  - `turn_changed(new_turn: int, is_player: bool)`
  - `unit_selected(unit: Unit)`
  - `action_completed()`

### 3. `UnitData.gd`（武将数据资源）
```gdscript
class_name UnitData
extends Resource

@export var id: String = ""
@export var unit_name: String = ""
@export var title: String = ""
@export var faction: String = "player" # player / enemy / ally
@export var max_hp: int = 400
@export var atk: int = 50
@export var def_val: int = 20
@export var move_range: int = 3
@export var avatar_char: String = "将"
```

### 4. `NovelSkillPipeline.gd`（小说专属技能管线）
- **关羽逻辑**：
  - 监听移动步数：`current_dragon_charge += moved_distance`
  - 伤害公式：`damage = base_atk * (1.0 + current_dragon_charge * 0.3)`
  - 若 `current_dragon_charge >= 10`：开启全图无遮挡贯穿。
  - 马哥体力判定：每步消耗 10 点体力；低于 20 点时挂上 `Status.EXHAUSTED`；执行【画饼】时解除并回复 60 点。
- **张飞逻辑**：
  - 【燕人咆哮】：获取目标周围 2 格敌人，沿直线计算推动方向向量 `dir = (enemy_pos - zhangfei_pos).sign()`，强制位移 2 格，附加眩晕状态。
- **赵云合体逻辑**：
  - 关羽在赵云邻格激活【骑乘合体】，隐藏关羽单位实体，将赵云单位附加关羽的青龙蓄力属性，合体期间无视马哥疲惫。

---

## 四、技术规范与约束（AI Agent 遵守准则）
1. **语言版本**：纯 Godot 4.x GDScript，使用强类型注解（如 `var hp: int = 100`）。
2. **异步规范**：严格使用 `await`，禁止 Godot 3 的 `yield()`。
3. **节点检索规范**：UI 节点全部勾选“Access as Unique Name”，代码中通过 `$%NodeName` 访问，严禁写脆弱的相对路径字符串。
4. **渲染规范**：采用纯矢量/程序化代码绘制（`_draw()`）配合神级 Canvas 几何图形与像素三国风格，不强依赖外部体积庞大的私有图片资源，确保轻量与极速加载。
