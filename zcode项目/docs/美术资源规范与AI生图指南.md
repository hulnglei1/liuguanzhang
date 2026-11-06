# 美术资源规范与 AI 生图指南

> 适用版本：`zcode项目` @ 2026-09-17
> 配套工具：`tools/normalize_art.py`（自动规整）、`tools/check_art.py`（合规校验）、`tools/make_art_template.py`（重刷母版）
> 配套母版：`docs/art/*.png`（把母版丢进 AI 工具当构图参考，比文字描述管用）

**核心原则：所有约束都能被脚本检查。** 出图后跑 `check_art.py`，不合规的地方它会直接指出来——不靠肉眼、不靠记忆。

---

## 一、先看母版（约束的视觉版本）

| 母版 | 用途 |
|---|---|
| [`docs/art/母版_立绘_900x1200.png`](art/母版_立绘_900x1200.png) | 立绘对齐参考：中心线、头顶线、脚底线、安全区 |
| [`docs/art/母版_单位_192x192.png`](art/母版_单位_192x192.png) | 战场单位对齐参考 |
| [`docs/art/母版_地块_104x104_平铺.png`](art/母版_地块_104x104_平铺.png) | 地块 + 3×3 无缝拼接示意 |
| [`docs/art/示意_常见错误对比.png`](art/示意_常见错误对比.png) | **四种典型错误长什么样**（浮空/站偏/灰边） |

**工作流建议**：把母版图直接喂给 AI 工具（图生图 / 参考图 / ControlNet 骨架），让构图由母版决定、风格由 prompt 决定。这样 90% 的"对不上"在生成阶段就避免了。

---

## 二、三类资源的硬指标

| 项 | 立绘 portraits | 战场单位 units | 地块 tiles | UI 图标 icons |
|---|---|---|---|---|
| **画布** | 900 × 1200（3:4） | 192 × 192（1:1） | 104 × 104（1:1） | 128 × 128（1:1） |
| **人物高度占比** | 83%（996px） | 88%（169px） | — | 80% |
| **脚底位置** | 距底边 ≤10px（贴底） | 距底边 ≤8px（贴底） | 铺满不透明 | — |
| **水平位置** | 居中，偏移 ≤3% | 居中，偏移 ≤3% | 四方连续 | 居中 |
| **安全区** | 四周留 ≥6px（描边/发丝不能出画） | ≥4px | 0 | ≥6px |
| **半透明像素** | <3% | <3% | 0（必须满不透明） | <3% |
| **朝向** | 正面略侧 3/4，统一朝左前 | 统一朝右（面对敌方） | — | — |
| **光源** | 左上 45°，暗部朝右下 | 左上 45° | 左上 45°，暗部右下 | 左上 45° |
| **格式** | PNG-24 + Alpha | 同 | 同 | 同 |
| **命名** | `{unit_id}_{emotion}.png` | `{unit_id}.png` | `{tile}_01.png` | `{name}_icon.png` |

> **为什么死死卡住"脚底贴底 + 居中"**：游戏是把贴图按"脚底 = 格子中心"摆放的（`battle.gd` 的 `_make_unit_node`）。人物在画布里矮一截，游戏里就浮空；偏一格，换人时整个画面会跳。这两条是脚本必检项。

> **为什么卡"高度占比"**：占比不一致 = 关羽看起来比张飞高大一圈，或者小兵比主将还高。占比一致，人物大小才由美术设定（而不是由画布填满程度）决定。

---

## 三、色板（从当前游戏画面实采，出图请往这上面靠）

```
深墨底    #090B0F    面板底    #191C23    面板深     #121417
棋盘深绿  #172115    棋盘浅绿  #1E281B    网格线     #494E56
主金      #EAC65B    暗金      #594C38    正文米白   #EDE3CC
我方蓝    #2D6BAD    敌方红    #AD3833    系统青     #6BD9C7
```

**用色规则**：
- 主金 `#EAC65B` 只用于：边框、描边、标题、稀有高亮。**不要大面积铺金**（会廉价）
- 角色主色遵循阵营：我方偏蓝绿系、敌方偏红褐系，但**不要整块纯色**，要有明暗两到三阶
- 出完图统一做一次"色板贴近"：`tools/normalize_art.py --saturate 0.92`（多批出图偏色时尤其要做）

---

## 四、工具链（这是"不跑偏"的保障）

### 4.1 出图 → 规整 → 校验，三步

```bash
# 1. 规整：任意尺寸的原图 → 标准画布（自动裁边、缩放、居中、贴底）
python tools/normalize_art.py --kind portraits --dry-run 原图/*.png     # 先预览
python tools/normalize_art.py --kind portraits 原图/*.png              # 实际处理
python tools/normalize_art.py --kind portraits --name guanyu_normal.png 关羽.png   # 指定命名

# 2. 校验：不合规的地方会逐条列出来
python tools/check_art.py              # 全部
python tools/check_art.py portraits    # 只查立绘

# 3. 入库：把文件放进 assets/portraits/（校验通过后再放）
```

`normalize_art.py` 会做四件事：裁掉透明边 → 按规范占比缩放 → 贴到标准画布（居中+贴底）→ 可选统一饱和度。
**注意**：它是"按透明边界"对齐的，所以原图里如果有散落的火星、烟尘、飘带碎片，会被算进边界导致人物被缩小。**出图时要求"干净背景、无散落元素"**。

### 4.2 校验判定表

| 检查项 | FAIL（必须修） | WARN（建议修） |
|---|---|---|
| 文件名 | 不匹配命名正则 → 代码加载不到 | — |
| 画布尺寸 | 与规范不一致 | — |
| 脚底贴底 | 离底边 >10px（单位 >8px） | 离底边 1-10px |
| 水平居中 | 偏移 >3% | 偏移 >1.5% |
| 高度占比 | 超出区间 ±8% | 超出 ±5% 以内 |
| 半透明灰边 | 占比 >8% | 占比 >3% |
| 地块铺满 | 不透明像素 <99% | — |

### 4.3 规范变了怎么办

改 `tools/make_art_template.py` 里的数值 → 重跑 → 母版和新标准一起刷新。**不要手改 PNG 母版**。

---

## 五、逐类出图模板（prompt 可直接抄）

### 5.1 通用风格锚（每次都要带）

**中文**（即梦 / 通义万相 / 可灵）：
```
中国风水墨工笔混合风格，三国题材战棋游戏美术，墨玉青绿主色调，
金色描边勾线，体积光，厚涂质感，暗部压深，高光集中，
人物正面略侧四分之三视角，左上45度光源，画面干净无背景杂物，无文字，无logo，无边框
```

**英文**（Midjourney / SD / Flux）：
```
Chinese ink-wash combined with semi-realistic digital painting,
Three Kingdoms tactical RPG art, jade-green and ink-black palette,
gold rim light and outline, volumetric lighting, thick-paint,
character at 3/4 front view, light source from upper left,
clean isolated subject, plain background, no text, no logo, no border, no watermark
```

**固定负面词**（最后三个是关键，不排掉风格会飘回去）：
```
lowres, blurry, bad anatomy, extra fingers, extra limbs, jpeg artifacts,
signature, watermark, text, ui, frame, border, multiple views,
pixel art, flat vector, chibi
```

### 5.2 武将立绘

```
{风格锚}，
[角色描述]，全身立绘，站姿，面向左前方，脚底对齐画布下边缘，人物高占画面约 83%，
纯色浅灰背景（便于抠图），无地面阴影，无场景元素
```
角色描述：
| id | 描述 |
|---|---|
| liubei | 刘备，双手过膝、耳垂及肩，仁厚面相，绿袍，双股剑 |
| guanyu | 关羽，面如重枣、美髯及胸，绿袍金甲，青龙偃月刀 |
| zhangfei | 张飞，黑面虬髯、豹头环眼，玄色铁甲，丈八蛇矛 |
| zhaoyun | 赵云，白袍银甲，年轻英武，亮银枪，白马伴身 |
| gongsunzan | 公孙瓒，白马义从统领，白袍轻甲，角弓 |
| wuanguo | 武安国，孔融部将，粗壮猛汉，重锤 |
| xuchu | 许褚，虎痴，赤膊壮汉披甲，虎头大刀 |
| huaxiong | 华雄，西凉重甲，凶悍，大刀 |
| lubu | 吕布，赤金身甲，方天画戟，桀骜神情，赤兔马 |
| zangba | 臧霸，泰山山贼王，皮甲兽裘，环首刀 |

### 5.3 战场单位

```
{风格锚}，
三国战棋战场单位，[兵种]，三分身比例（头身比约 1:2.5），面向右侧，站姿，
[武器]，脚底对齐下边缘，中心构图，纯色浅灰背景，无地面阴影
```
兵种：`dao_bing`（刀兵·皮甲环首刀）`gong_bing`（弓兵·角弓短甲）`qi_bing`（骑兵·长枪马铠）`luan_bing`（乱兵·布衣锄耙）`taishan`（泰山贼·兽皮短斧）

> **战场单位不要做成全身写实**——只在 52px 格子里显示，全身细节全糊。三分身比例辨识度最高。

### 5.4 地块

```
{风格锚}，
俯视 45 度中国古代军营地表贴图，[草地/泥地/夯土墙/木栅栏/寨门/高地岩台]，
无缝四方连续，光照来自左上，暗部朝右下，四边可拼接，
不含人物、不含阴影投到画面外、无文字
```

### 5.5 UI 图标

```
{风格锚}，游戏 UI 图标，[剑/盾/技能/声望/图鉴/抽奖]，圆角方形底板，金色描边，
单一物件居中，纯色背景，简洁易识别
```

---

## 六、待产清单（可直接当 checklist）

**P0 · 立绘（8 张）**：`liubei` `guanyu` `zhangfei` `zhaoyun` ×（`normal` + 1 个情绪）
**P0 · 战场单位（10 张）**：上述 4 主角 + `gongsunzan` `wuanguo` `huaxiong` `lubu` `xuchu` `zangba`
**P1 · 兵种（8 张）**：`dao_bing` `gong_bing` `qi_bing` `luan_bing` × 2 阵营换色
**P1 · 地块（6-8 张）**：`grass_01` `dirt_01` `hill_01` `fence_01` `wall_01` `gate_01`
**P2 · 其余敌将立绘（5 张）**：`huaxiong` `lubu` `xuchu` `zangba` `changxi`
**P2 · UI 图标（10 张）**：或直接下 Kenney（CC0）
**P3 · 章节封面（4-5 张）**：兼做宣传素材

**建议的推进顺序**：先用 3-4 张试错把风格锚定下来（关羽 normal / 张飞 normal / 赵云 normal + 一张地块），跑一遍 `normalize + check` 确认流程顺畅，再批量出剩下的。**别一次性出 40 张**——风格没定就批量，返工更贵。

---

## 七、常见"对不上"的六种表现

| 游戏里看到 | 根因 | 修法 |
|---|---|---|
| 角色浮空，脚不着地 | 画布底部有透明边 | `normalize_art.py` 会自动贴底；或手工把人物下移到底边 |
| 有的高有的矮，比例不一 | 高度占比不一致 | 统一走 `normalize_art.py`，别手工裁 |
| 角色站偏、换人时画面跳 | 没水平居中 | 同上（脚本强制居中） |
| 深色背景上泛一圈白边 | 抠图残留半透明 | 重新抠（rembg / 稿定），或 `check_art.py` 报警后手工清边 |
| 地块拼接有缝 | 地块没铺满或有半透明边 | 地块必须 100% 不透明，四边可接 |
| 整体色调跟游戏不搭 | 多批出图偏色 | 统一 `--saturate 0.92`，或 PS 的 Match Color |

---

## 八、入库与代码对接

| 资源 | 放置目录 | 加载器 | 缺图时行为 |
|---|---|---|---|
| 立绘 | `assets/portraits/` | `scripts/ui/portrait_loader.gd` | 自动隐藏，不报错 |
| 战场单位（静态） | `assets/units/{id}.png` | `scripts/ui/unit_art.gd` | 回退到色块 + 书法字 |
| 战场单位（序列帧） | `assets/units/{id}_idle/`、`assets/units/{id}_attack/` | 同上 `load_frames_for()` | 缺哪个用另一个占位；都没有则用静态图 |
| 地块 | `assets/tiles/` | 待接入 | — |

### 8.1 单位序列帧规范（呼吸 + 攻击）

```
assets/units/guanyu_idle/0.png     ← 呼吸/待机，循环播放，3 fps
assets/units/guanyu_idle/1.png
assets/units/guanyu_idle/2.png
assets/units/guanyu_idle/3.png
assets/units/guanyu_attack/0.png   ← 攻击，单次播放，10 fps
assets/units/guanyu_attack/1.png
assets/units/guanyu_attack/2.png
assets/units/guanyu_attack/3.png
```

| 项 | 要求 |
|---|---|
| 画布 | 与静态图一致：**192×192**，脚底贴底、水平居中（三套帧必须严格同尺寸同锚点，否则播放时会「抖」） |
| 帧数 | **呼吸 2–4 帧**（幅度要小，只是微动）；**攻击 4–6 帧**（起手→挥出→收势） |
| 编号 | `0.png` 起顺延；**不能断档**（加载器遇空号即停） |
| 尺寸一致 | 若某帧大小不同，Godot 会按各自尺寸绘制 → 单位"乱跳"。切图时务必统一画布 |
| 素材来源 | 用 `tools/slice_sheet.py` 从精灵图切；GIF 用下面的一行命令切 |
| 朝向 | 默认朝右绘制（代码会在攻击时按目标自动 `flip_h`，不用出左右两套） |

**把 GIF 切成序列帧**（本机已验证可用）：

```bash
python -c "
from PIL import Image
import os
src='动图.gif'; out='assets/units/guanyu_idle'
os.makedirs(out, exist_ok=True)
im=Image.open(src)
for i in range(getattr(im,'n_frames',1)):
    im.seek(i); im.convert('RGBA').save(os.path.join(out,'%d.png'%i))
print('切出', im.n_frames, '帧')
"
```

> 攻击时的**朝向翻转**和**前冲 14px 回弹**由代码实现，美术只需出朝向一致的动作序列。

- **可以一张一张补**，任何时候游戏都能跑
- 对话 JSON 可显式指定立绘：`{"speaker":"关羽","text":"…","portrait":"guanyu","emotion":"angry"}`
- ⚠️ **新加的 PNG 必须让 Godot 导入一次**（编辑器会自动做；命令行跑 `--headless --import`），否则加载器找不到文件
- `.import` 与 `.godot/` 已忽略；**图片本身要提交**（别把 `assets/` 加进 `.gitignore`）

---

## 九、版权与合规

1. 核对 AI 工具的商业使用条款（多数国产工具已明确可商用，看订阅档位）
2. 不要生成"某三国志/某游戏同名武将立绘"这种指向性描述，避免撞既有 IP 的视觉特征
3. 用第三方免费素材时，在 `assets/CREDITS.md` 登记：文件名 / 来源 URL / 许可证 / 是否修改
4. 小说原文（`docs/*.txt`）有版权，已被 `.gitignore` 排除，**不要提交进仓库**

---

## 附：为什么不用现成的三国素材包

三国题材免费素材确实存在（B.B.Bits 三国系列、Niao_K 中式角色包），但**清一色 16×16 像素风**。本项目是 1280×720 下 52px 格子 + 程序化发光特效（青龙、音波圈、震屏、全屏闪光），像素小人塞进去会撕裂成两种画风，而且这些包普遍禁止再分发。

**结论**：地形与人物自产（AI 生图 + 统一风格锚）；**UI 图标与音效用 Kenney（CC0）最划算**，无版权风险。

---

## 九、实际执行约定（2026-11-06 起）

早期规范写的是「立绘 900×1200 / 单位 192×192」。实际落地时，关羽那套资产是
**512×512 立绘 + 256×256 单位**，并经用户确认以此为标准继续产出。
为避免返工，后续批次一律按下列口径执行：

| 资产 | 实际尺寸 | 说明 |
|---|---|---|
| 武将立绘 | **512×512** PNG，透明底 | 半身胸像；只有 `normal`，情绪表情后补 |
| 战场单位 | **256×256** PNG，透明底 | Q 版全身，脚底贴底 |
| 序列帧 | 待机 2-4 帧 / 攻击 4 帧 | 目前只有关羽有；其余先用单图 + 代码动效 |

**原始出图统一保存 1024×1024**（`美术资产处理中心/3_原始出图_raw/batch_YYYYMMDD/`）。
将来若要改回 900×1200，直接用原始图重新规整即可，**不需要重新生成**。

### 新增工具：`tools/normalize_to_reference.py`

按"标杆资产"（关羽）的包围盒对齐新图，保证换人时不跳大小、不浮脚底：

```bash
# 战场单位：按高度对齐（披风宽的角色不会被压矮）
python tools/normalize_to_reference.py \
  --src 原始出图.png --ref assets/units/guanyu.png \
  --out assets/units/liubei.png --crop-bottom 70 --crop-right 70 --policy height

# 立绘：宽高取小，避免裁到肩膀
python tools/normalize_to_reference.py \
  --src 原始出图.png --ref assets/portraits/guanyu_normal.png \
  --out assets/portraits/liubei_normal.png --crop-bottom 70 --crop-right 70
```

- `--crop-bottom/--crop-right`：AI 出图右下角常带水印，先裁掉再规整
- 内部自动调 `rembg` 抠图；抠完按参考资产的「左右中心 + 底边」落位

### 已产出（2026-11-06）

| 角色 | 立绘 | 战场单位 |
|---|---|---|
| 关羽 | ✅（原有） | ✅（原有，含 4 帧待机 / 4 帧攻击） |
| 刘备 | ✅ `liubei_normal.png` | ✅ `liubei.png` |
| 张飞 | ✅ `zhangfei_normal.png` | ✅ `zhangfei.png` |
| 赵云 | ✅ `zhaoyun_normal.png` | ✅ `zhaoyun.png` |

### 待解决的观感问题

深绿袍（刘备/关羽）+ 黑甲（张飞）落在深绿棋盘上，**对比度偏低**。
方案（代码侧，约 0.2 天）：给有贴图的单位加一圈极淡的描边光/背光轮廓，
或把棋盘整体提亮 5-8%。不需要改图。
