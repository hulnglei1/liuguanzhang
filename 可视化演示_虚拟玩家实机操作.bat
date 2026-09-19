@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo   【魂穿刘关张】AI 虚拟玩家可视化慢速真实演示
echo   窗口将在您的桌面上弹出，带您亲眼观看 AI 像真人一样操作！
echo   演示完毕后窗口不关闭，您可以直接上手接管游玩！
echo ========================================================
echo.
"%~dp0.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0zcode项目" -s res://tests/demo_virtual_player_live.gd
pause
