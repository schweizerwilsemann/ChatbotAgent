@echo off
REM ============================================================
REM  run_flutter.bat — Run Flutter app with flavor selection
REM ============================================================
REM  Usage:
REM    run_flutter.bat                (interactive menu)
REM    run_flutter.bat appDev         (Dev debug build)
REM    run_flutter.bat appDevRelease  (Dev backend, release-style config)
REM    run_flutter.bat appProd        (Prod release build)
REM    run_flutter.bat appDev --clean (Dev debug + flutter clean)
REM ============================================================

set FLAVOR=%1
set CLEAN=%2

if "%FLAVOR%"=="" goto :menu

:run
if "%CLEAN%"=="--clean" (
    echo Cleaning project...
    flutter clean
    flutter pub get
)

if /I "%FLAVOR%"=="appDev" (
    echo.
    echo === Running appDev (debug) ===
    echo.
    flutter run --flavor appDev
    goto :eof
)

if /I "%FLAVOR%"=="appDevRelease" (
    echo.
    echo === Running appDevRelease ===
    echo.
    flutter run --flavor appDevRelease
    goto :eof
)

if /I "%FLAVOR%"=="appProd" (
    echo.
    echo === Running appProd ===
    echo.
    flutter run --flavor appProd
    goto :eof
)

echo Unknown flavor: %FLAVOR%
echo Valid options: appDev, appDevRelease, appProd
goto :eof

:menu
echo.
echo ================================
echo  Select a flavor to run:
echo ================================
echo  1. appDev      (debug, hot-reload)
echo  2. appDevRelease (dev backend, release-style config)
echo  3. appProd     (release, production)
echo ================================
set /p CHOICE="Enter 1, 2, or 3: "

if "%CHOICE%"=="1" set FLAVOR=appDev
if "%CHOICE%"=="2" set FLAVOR=appDevRelease
if "%CHOICE%"=="3" set FLAVOR=appProd

if "%FLAVOR%"=="" (
    echo Invalid choice.
    goto :eof
)

goto :run
