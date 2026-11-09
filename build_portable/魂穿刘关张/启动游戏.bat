@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "" "游戏运行器.exe" --main-pack "魂穿刘关张.pck" --resolution 1280x720
