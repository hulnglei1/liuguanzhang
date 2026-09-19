# 02. AI 资产生成标准操作流程 (SOP)

> 目标：从“单张生图”到“标准入库”，全过程工业化、脚本化，杜绝手工反复微调与返工。

```
       [步骤 1: 提示词装配]
                 │
                 ▼
       [步骤 2: 垫图/ControlNet 生图] ── (借助 docs/art/ 视觉母版控制构图)
                 │
                 ▼
       [步骤 3: 纯净抠图与去白边] ── (rembg / Segment Anything)
                 │
                 ▼
       [步骤 4: 脚本自动规整] ──── (运行 tools/normalize_art.py)
                 │
                 ▼
       [步骤 5: 自动化合规门禁] ── (运行 tools/check_art.py)
                 │
                 ▼
       [步骤 6: 引擎导入与实机验证] ─ (Godot 物理视口试玩与截图审阅)
```

---

## 阶段一：提示词装配与母版垫图 (Prompt & Control)

### 1. 核心黄金组合：【风格锚】+【角色特征】+【母版约束】

#### 【通用风格锚】（严禁省略，保证跨批次画风一致）
```text
中文（即梦 / 通义万相 / 可灵）：
中国风水墨工笔混合风格，三国题材战棋游戏美术，墨玉青绿与深墨主色调，金色描边勾线，
厚涂质感，体积光，暗部压深，高光集中，左上45度光源，画面干净无背景杂物，纯色浅灰单色背景，
无文字，无logo，无边框，无水印
```

```text
英文（Midjourney / SD / Flux）：
Chinese ink-wash semi-realistic digital painting, Three Kingdoms tactical RPG art,
jade-green and ink-black palette, gold rim light and delicate outline, volumetric lighting,
thick-paint texture, light source from upper-left 45 degree, clean isolated subject,
plain light grey background, no text, no logo, no frame, no watermark
```

#### 【通用负向提示词 (Negative Prompt)】
```text
lowres, blurry, bad anatomy, deformed limbs, extra fingers, missing limbs, jpeg artifacts,
signature, watermark, text, subtitle, ui, frame, border, split view, multiple views,
modern objects, western armor, bright cartoon, flat vector, chibi (仅立绘排斥chibi)
```

### 2. 强构图控制（强烈推荐）
- **不要仅靠文字 prompt 抽奖！**
- 将项目提供的母版作为 ControlNet（Canny / Depth / OpenPose）或图生图垫图：
  - 立绘参考：`zcode项目/docs/art/母版_立绘_900x1200.png`
  - 棋盘单位参考：`zcode项目/docs/art/母版_单位_192x192.png`
  - 地块连续参考：`zcode项目/docs/art/母版_地块_104x104_平铺.png`

---

## 阶段二：AI 生图与同一角色多表情控制

### 1. 武将立绘多表情生成策略
- 先出主立绘：生成 `normal`（通常/从容）表情，记录并锁定 Seed / 角色参考图（Midjourney `--cref` 或 SD Reactor/IP-Adapter）。
- 衍生分支表情（`angry` 怒、`shock` 惊、`happy` 喜、`sad` 悲）：
  - 保持身体与盔甲姿态不变，仅通过 Inpainting（局部重绘）修改面部神情与嘴型，保证在对话切换表情时身体绝对不产生跳帧与平移。

### 2. 棋盘单位 (Units) 批量生成策略
- 强制设定“三分身”与“统一朝右侧”视角。
- 输出单图必须为单角色，禁止背景有散落飞箭、火星粒子、碎石，否则会导致自动裁边时缩放失真。

---

## 阶段三：自动化背景透明化 (Background Removal)

AI 输出的图通常带单色浅灰背景，需提取纯透明通道（Alpha）：
1. **推荐工具**：
   - 本地脚本：使用 `rembg` (基于 BiRefNet / U2Net 架构，支持一键批量抠图)：
     ```bash
     rembg p input_raw/ output_nobg/
     ```
   - 在线工具：Photoshop 创成式抠图 / 稿定抠图 / 剪映抠图。
2. **硬性要求**：抠图边缘羽化半径不得大于 1px，严禁留有一圈刺眼的浅灰或白色半透明亮边（Dark UI 界面下会产生白边穿帮）。

---

## 阶段四：脚本自动规整对齐 (Normalization)

将任意尺寸的原图通过项目自带工具一键裁边、缩放、贴底居中并统一色板：

```powershell
cd d:\huanglei\deepseek\game\zcode项目

# 规整武将立绘（自动缩放至900x1200、高度占比83%、脚底贴底）
python tools/normalize_art.py --kind portraits --name guanyu_normal.png "D:\AI出图\关羽_通常.png"

# 规整棋盘单位（自动缩放至192x192、高度占比88%、居中且脚底贴底）
python tools/normalize_art.py --kind units --name guanyu.png "D:\AI出图\关羽_棋子.png"

# 规整地块贴图
python tools/normalize_art.py --kind tiles --name grass_01.png "D:\AI出图\草地.png"
```

---

## 阶段五：自动化合规门禁校验 (Lint & Gate Check)

在资源放入正式目录后，运行 `check_art.py` 进行 100% 机器合规扫描：

```powershell
cd d:\huanglei\deepseek\game\zcode项目
python tools/check_art.py
```
- **退出码 0**：全部 PASS，允许提交进 Git 入库。
- **报告 FAIL**：必须修复（如尺寸不符、脚底悬空、偏心过大）。
- **报告 WARN**：视情况微调（如高度微超 3%）。

---

## 阶段六：引擎实机热载与多模态审阅

1. **资源导入**：
   将合格资源放入对应目录：
   - 立绘：`zcode项目/assets/portraits/`
   - 棋盘单位：`zcode项目/assets/units/`
   - 地块：`zcode项目/assets/tiles/`
2. **触发 Godot 识别**：
   ```powershell
   & "..\.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe" --headless --path "." --editor --quit
   ```
3. **前台拉起实测**：
   双击根目录 `启动游戏.bat`，在 1280×720 实际视口中检查：
   - 棋盘角色缩放到 52px 格子后是否依然清晰可辨。
   - 移动时脚底是否稳稳落在网格中心。
   - 对话框展开时立绘有无遮挡文字。
