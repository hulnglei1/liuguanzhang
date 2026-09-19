# Z-Code 本地执行与协同操作指南 (ZCODE_GUIDE)

> **目标**：本指南专供本地执行 Agent（Z-Code / DeepSeek）阅读与执行。
> Z-Code 作为**本地前哨执行端**，负责前台窗口拉起、自动化截屏及测试执行；Antigravity 作为**多模态视觉与架构端**，负责看图评测 UI、编写战棋逻辑与重构代码。

---

## 一、环境与路径速查表

| 项目 | 路径 |
| :--- | :--- |
| **工程根目录** | 本仓库根目录（如 `D:\huanglei\deepseek\game`） |
| **Godot 游戏源码** | `zcode项目` |
| **Godot 控制台引擎** | `.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe` |
| **Godot 窗口引擎** | `.tools\godot_extracted\Godot_v4.7.2-stable_win64.exe` |
| **前台一键启动脚本** | `启动游戏.bat` / `play.bat` |
| **实机截图输出目录** | `zcode项目\screenshots` |
| **自动化截屏脚本** | `zcode项目\tests\capture_visual_showcase.gd` |

---

## 二、标准执行指令清单

### 1. 前台拉起游戏窗口（让老板亲眼试玩）
在根目录下双击 `启动游戏.bat`，或在 PowerShell 中执行以下命令：
```powershell
Start-Process -FilePath ".\启动游戏.bat"
```
- **执行后检查**：确认进程已启动，桌面已显示游戏主界面。
- **给老板的反馈模板**：“报告老板，游戏窗口已在前台成功拉起，您可以直接点击试玩！”

---

### 2. 一键捕获全场景实机截图（供视觉 AI 审阅）
在 PowerShell 中执行自动化截图流脚本：
```powershell
& ".\.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe" --path "zcode项目" -s res://tests/capture_visual_showcase.gd
```
- **脚本行为**：8~10 秒内自动遍历主城、扫荡、抽卡、图鉴、关羽骑赵云冲锋、龙斩特效、吕布战役等场景，并保存 9 张高清 PNG。
- **执行后检查**：运行 `Get-ChildItem "zcode项目\screenshots"`，确认包含 01~09 号 PNG。
- **给老板的反馈模板**：“报告老板，全套 9 张实机高清截图已生成完毕，存放在 screenshots/ 目录，可通知 Antigravity 进行视觉评审与优化。”

---

### 3. 运行全套 14 组战棋逻辑回归测试
在 PowerShell 中执行以下批量测试命令：
```powershell
$godot = ".\.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe"
$tests = @("test_core.gd", "test_battle_flow.gd", "test_chapter2.gd", "test_chapter3.gd", "test_chapter4.gd", "test_ch2_flow.gd", "test_ch3_flow.gd", "test_ch4_flow.gd", "test_gear.gd", "test_systems.gd", "test_save.gd", "test_e2e_win.gd", "test_p0_p1_p2.gd", "test_v3_features.gd")
$passed = 0
foreach ($t in $tests) {
    Write-Host ">>> Running $t..." -ForegroundColor Cyan
    & $godot --headless --path "zcode项目" -s "res://tests/$t"
    if ($LASTEXITCODE -eq 0) { $passed++ } else { Write-Error "FAILED: $t" }
}
Write-Host "================================" -ForegroundColor Green
Write-Host "测试完成: $passed / $($tests.Count) 全部通过!" -ForegroundColor Green
```

---

## 三、双 AI 协同标准作业流 (SOP)

1. **步骤 1 (Z-Code)**：接收老板指令，执行截屏脚本（指令 2）或拉起前台（指令 1）。
2. **步骤 2 (Z-Code)**：向老板汇报执行状态（如“截图已捕获”或“窗口已弹出”）。
3. **步骤 3 (Antigravity)**：通过多模态眼睛查看 `screenshots/` 中的实机图片，发现排版、色彩或交互问题，修改 GDScript 源代码。
4. **步骤 4 (Z-Code)**：代码修改后，Z-Code 运行回归测试（指令 3）并重新截屏/拉起游戏，完成闭环验证。
