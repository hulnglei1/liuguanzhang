@echo off
chcp 65001 >nul
title 同步代码到 GitHub - 魂穿刘关张
cd /d "%~dp0"

echo ========================================================
echo   目标仓库: https://github.com/hulnglei1/liuguanzhang
echo   工作目录: %CD%
echo ========================================================
echo.

echo [1/3] 检查 Git 分支...
for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set BRANCH=%%i
echo       当前分支: %BRANCH%

echo.
echo [2/3] 拉取远端最新代码...
git pull --rebase origin %BRANCH%
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ！拉取失败，可能是网络问题或本地有未提交改动冲突。
    echo    已中止推送，请先处理。
    echo.
    pause
    exit /b 1
)

echo.
echo [3/3] 提交本地改动并推送...
git add -A

REM 提交信息：优先用第一个命令行参数，否则用「更新时间戳」自动生成
if "%~1"=="" (
    set MSG=chore: 本地改动同步 %DATE% %TIME%
) else (
    set MSG=%~1
)

git diff --cached --quiet
if %ERRORLEVEL% EQU 0 (
    echo       没有需要提交的改动，直接推送已有的本地提交...
) else (
    git commit -m "%MSG%"
)

git push -u origin %BRANCH%

echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================================
    echo   推送成功！代码已同步到 GitHub 私有仓库！
    echo ========================================================
) else (
    echo ========================================================
    echo   推送遇到问题，请检查网络或授权。
    echo ========================================================
)
echo.
echo 按任意键关闭本窗口...
pause >nul
