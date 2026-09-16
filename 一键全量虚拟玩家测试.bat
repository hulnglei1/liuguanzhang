@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ========================================================
echo   【魂穿刘关张】AI 虚拟玩家全量真机模拟驱动测试
echo   全链路 100%% 物理鼠标/键盘事件注入 · 杜绝白盒假通过
echo ========================================================
echo.
.\godot_bin\Godot_v4.3-stable_win64_console.exe --path game -s tests/test_virtual_player.gd
echo.
echo 测试运行完毕。
pause
