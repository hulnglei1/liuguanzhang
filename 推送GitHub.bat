@echo off
chcp 65001 >nul
title 正在推送到 GitHub - 混穿刘关张
cd /d "E:\阿雷\混穿刘关张游戏"

echo ========================================================
echo   目标仓库: https://github.com/hulnglei1/liuguanzhang
echo ========================================================
echo.
echo 正在连接 GitHub，接下来会自动弹出浏览器授权窗口...
echo (请在弹出的网页中点击【Sign in with your browser】或【Authorize】)
echo.

git push -u origin main

echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================================
    echo   🎉 推送成功！代码已同步到 GitHub 私有仓库！
    echo ========================================================
) else (
    echo ========================================================
    echo   推送遇到问题，请检查网络或授权。
    echo ========================================================
)
echo.
echo 按任意键关闭本窗口...
pause >nul
