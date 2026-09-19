@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo   【魂穿刘关张】端到端战棋通关链路验证测试
echo ========================================================
echo.
"%~dp0.tools\godot_extracted\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0zcode项目" -s res://tests/test_e2e_win.gd
echo.
echo 测试运行完毕。
pause
