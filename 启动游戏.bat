@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo   【魂穿刘关张，诸侯们被整麻了】SRPG 战棋启动中...
echo   1280x720 宽屏视口 · 墨玉金边战术仪表盘 · 全新原著手感
echo ========================================================
echo.
.\godot_bin\Godot_v4.3-stable_win64_console.exe --path game
echo.
echo 游戏进程已结束。
pause
