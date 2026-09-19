# 05. 动画生成与切图（Slicing）流水线规范

> 核心解答：**动画从何而来？单张生图之后，到底如何切图、拆件并让棋子动起来？**
> 本规范针对 2D 游戏开发中三种主流动画技术路径，提供从生图到切图的完整工业化落地方案。

---

## 一、2D 战棋动画的三种技术路径对比

动画绝不是凭空产生的，无论哪种方案，都必须经历 **“生成原画 ➔ 切图/拆件 ➔ 引擎驱动”** 的过程：

| 动画路线 | 切图形式 (Slicing) | 动画驱动原理 | 优点 | 缺点 | 适用场景 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **方案 A：序列帧动画 (SpriteSheet)** | **网格等分切图**（或打包图集） | 像翻连环画，按 8~12 FPS 顺序轮播每一帧切片 | 动作夸张、最符合传统手绘/像素质感 | AI 生成多帧动作极易形变、闪烁抽搐；包体大 | 关键技能定格挥刀（2~4帧短循环） |
| **方案 B：骨骼切件动画 (Cutout/Spine)** | **解剖拆件切图**（头/躯干/四肢/武器） | 类似皮影戏，各部件绑定骨骼与旋转锚点，程序驱动旋转插值 | 动作极其丝滑平滑、可随时更换武器装备、包体极小 | 前期拆件（补全被遮挡图层）与绑骨复杂度极高 | 大型主角、高规格 Boss 复杂待机 |
| **方案 C：单体切片+程序化动效 (Procedural)** | **单体轮廓切图**（纯净单张带透明通道） | 引擎代码控制 Position 颠簸、Scale 呼吸缩放、Shader 闪白颤动 | **零形变风险、出图成本最低、在 52px 格子下最清晰** | 身体本身不会大幅度摆动四肢 | **中小型 SRPG、卡牌、小棋盘兵种（本项目首选）** |

---

## 二、方案 A：AI 序列帧网格切图流水线 (SpriteSheet Slicing)

如果希望武将拥有真实的待机呼吸或挥刀动作，标准作业流如下：

### 1. 生成动作序列图（4 帧或 6 帧大图）
- **Prompt 控制**：
  ```text
  character sprite sheet, 4 frames animation cycle of Guan Yu swinging blade,
  isolated transparent background, side view facing right, equal spacing,
  consistent character design across frames
  ```
- **输出样式**：一张水平横排的包含 4 个等距动作姿态的大图（如 `768 × 192` 像素，包含 4 帧 `192 × 192`）。

### 2. 自动化等分切图 (Automated Slicing)
使用自动化 Python 脚本按网格切分为独立帧：
```
大图 (768x192) ──► tools/slice_spritesheet.py ──►
   ├── frame_00.png (192x192) [待机准备]
   ├── frame_01.png (192x192) [后摆蓄力]
   ├── frame_02.png (192x192) [向前下劈]
   └── frame_03.png (192x192) [收刀定格]
```

### 3. Godot 引擎配置
- 在 Godot 中将 `Sprite2D` 替换为 `AnimatedSprite2D`。
- 新建 `SpriteFrames` 资源，将切片帧拖入 `attack` 动作槽，设置帧率 `FPS = 8`，`Loop = false`。

---

## 三、方案 B：骨骼拆件切图流水线 (Cutout / Layered Slicing)

如果希望实现类似《少年三国志》、《暗黑地牢》的丝滑微动皮影戏风格：

### 1. AI 出图与图层分拆 (Layer Segmentation)
使用 Segment Anything (SAM) 或 Photoshop 创成式填充，将单张原画分层切成 8~10 个独立图层：
1. `head.png`：头部与头盔（含颈部旋转锚点）
2. `torso.png`：躯干胸甲（主躯干承重）
3. `arm_left.png` / `arm_right.png`：上臂与小臂
4. `hand_weapon.png`：手握青龙偃月刀（可独立替换武器）
5. `cape.png`：披风（后续挂载物理摆动）
6. `legs.png`：腿部与战靴

> **切图核心关键：遮挡面补全**。把手臂切开后，身体被手臂挡住的地方必须用修图工具补齐，否则骨骼旋转时身体会出现穿帮破洞。

### 2. 导入 Godot Skeleton2D
- 在 Godot 场景中创建 `Skeleton2D`，按解剖学布置骨骼链。
- 将切出的部件挂在对应骨骼节点下，使用 Godot 自带的 `AnimationPlayer` 为骨骼打关键帧（实现待机缓慢呼吸、受击后仰）。

---

## 四、方案 C：立绘图层差分切图 (Portrait Expression Slicing)

剧情对白中立绘的“眨眼、张嘴、表情变化”的切图规范：

### 1. 基础身躯切片 (Base Layer)
- `guanyu_body.png`：无表情的完整身躯与面部底色。

### 2. 局部器官差分切片 (Facial Overlays)
通过图层对齐切出五官局部（固定坐标叠加）：
- `guanyu_face_normal.png`（从容闭口微须）
- `guanyu_face_angry.png`（横眉怒目、呲牙大喝）
- `guanyu_face_shock.png`（眼球圆睁、冷汗滴落）

在对白引擎中，只需切换局部器官切片，无需每次加载整张 900×1200 的大图，**从根源上杜绝切换表情时身体发生抽动跳跃**。

---

## 五、自动化切图工具脚本预留 (`tools/slice_sheet.py`)

为项目提供开箱即用的多格序列帧切图脚本：

```python
# 示例命令：将一张 4 帧并排大图自动切分为 4 张标准 192x192 单位帧
python tools/slice_sheet.py --input "guanyu_attack_sheet.png" --cols 4 --rows 1 --out "assets/units/guanyu_attack/"
```
- **自动贴底居中**：每个切片帧单独计算包围盒，确保脚底位置在切片过程中不产生上下像素跳动。
- **自动重命名导出**：按 `{name}_{index:02d}.png` 格式导出，无缝适配 Godot 引擎。
