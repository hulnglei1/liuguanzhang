@echo off
chcp 65001 >nul
title 魂穿刘关张 - 早期原型启动器
echo 正在启动早期原型场景...
start "" "%~dp0..\.tools\godot_extracted\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
exit /b 0
