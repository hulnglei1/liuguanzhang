# 《魂穿刘关张，诸侯们被整麻了》 · 游戏化项目

基于小说「魂穿刘关张，诸侯们被整麻了」（蓝色三角形）的**曹操传式战棋**游戏化项目。

## ⬇️ 下载试玩

| 版本 | 链接 | 说明 |
|---|---|---|
| **Windows 单文件版** | https://github.com/hulnglei1/liuguanzhang/releases/download/v0.1.0/liuguanzhang-v0.2.0-win64.zip | 解压后双击 `魂穿刘关张.exe`，无需安装 Godot |
| 国内镜像（Gitee） | _待开通_ | 80 MB 单文件包，走 Gitee Release，国内下载更快 |
| 源码 | https://github.com/hulnglei1/liuguanzhang | Godot 4.7 + GDScript，47 项自动化测试 |

> 提示：GitHub 在国内访问不稳定时，优先用 Gitee 镜像；两个地址指向同一份文件。

## 设计决策（已定）

- **游戏模式**：曹操传式关卡制战棋（SRPG）——最适合承载小说的反转叙事 + 搞笑对白 + 武将技组合机制。
- **开发方式**：从零开发，**不用**曹操传 MOD 编辑器（机制无法自由定制、素材有版权、仅 PC 可跑）。
- **技术栈**：**Godot 4.7.2 + GDScript**（项目内置绿色免安装引擎，无需本地预装环境）。
- **视口规格**：1280×720 标准宽屏。
- **当前进度**：已实装前四章完整战役关卡（汜水关斩华雄、虎牢关三英战吕布、渭桥大战裸衣许褚、泰山郡破占山王），含完整主城大营、军机祈赏抽奖、诸侯图鉴与存档系统。

## 目录结构速览

- `zcode项目/`：**当前游戏主工程源码**（场景 `scenes/`、脚本 `scripts/`、数据 `data/`、测试 `tests/`）。
- `.tools/godot_extracted/`：**内置 Godot 4.7.2 绿色引擎**（含带窗可执行程序与 Console 调试程序）。
- `sanguo_tactics/`：早期技术验证原型（已归档，现以 `zcode项目` 为主）。
- `js/`：极早期纯前端 Canvas 设想残留草稿（已弃用）。

## 怎么跑起来

### 方式一：直接双击脚本（推荐）
- **直接试玩（纯游戏窗口）**：双击根目录下的 **`启动游戏.bat`**。
- **开发者/调试启动（带控制台日志）**：双击根目录下的 **`play.bat`**。
- **全自动可视化实机操作演示**：双击 **`可视化演示_虚拟玩家实机操作.bat`**。

### 方式二：命令行启动
在项目根目录下打开终端（PowerShell 或 CMD）：
```powershell
# 启动图形界面游玩
.\.tools\godot_extracted\Godot_v4.7.2-stable_win64.exe --path "zcode项目"

# 或带调试日志输出
.\.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe --path "zcode项目"
```

### 方式三：运行自动化回归测试套件
```powershell
.\.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe --headless --path "zcode项目" -s res://tests/test_e2e_win.gd
```
