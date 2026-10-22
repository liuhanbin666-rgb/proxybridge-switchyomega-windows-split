@echo off
setlocal
chcp 65001 >nul
title ProxyBridge + SwitchyOmega 分流向导
set "SCRIPT=%~dp0SplitProxy.ps1"
if not exist "%SCRIPT%" (
  echo 缺少同目录的 SplitProxy.ps1。请将两个文件放在一起。
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo 向导未完成，退出码：%RC%
pause
exit /b %RC%
