@echo off
REM ===== 成长印记 开发环境初始化脚本 =====
REM 每次开发前运行此脚本，或在终端中执行: dev-env

REM --- Flutter 环境（解决 AppData 权限问题）---
set APPDATA=C:\src\flutter-appdata
set LOCALAPPDATA=C:\src\flutter-localappdata
set TEMP=C:\src\flutter-temp
set TMP=C:\src\flutter-temp
set PUB_CACHE=C:\src\pub-cache
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn

REM --- PATH 追加 ---
set PATH=C:\src\flutter\bin;C:\Program Files\Docker\Docker\resources\bin;C:\Users\ASUS\AppData\Local\Programs\Python\Python311;C:\Users\ASUS\AppData\Local\Programs\Python\Python311\Scripts;%PATH%

REM --- 显示环境状态 ---
echo ========================================
echo   成长印记 开发环境已加载
echo ========================================
echo.
flutter --version 2>nul | findstr "Flutter"
python --version 2>nul
docker --version 2>nul
echo.
echo MySQL: docker exec growth-mark-mysql mysqladmin ping -uroot -pgrowthmark123 2>nul
echo Redis: docker exec growth-mark-redis redis-cli ping 2>nul
echo.
echo 环境变量:
echo   APPDATA = %APPDATA%
echo   PUB_CACHE = %PUB_CACHE%
echo   FLUTTER_STORAGE_BASE_URL = %FLUTTER_STORAGE_BASE_URL%
echo ========================================
