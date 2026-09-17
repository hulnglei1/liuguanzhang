@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo   【魂穿刘关张，诸侯们被整麻了】SRPG 战棋启动中...
echo   1280x720 宽屏视口 · Godot 4.7.2
echo ========================================================
echo.
".tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe" --path "zcode项目"
echo.
echo 游戏进程已结束。
pause
