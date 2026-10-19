@echo off
setlocal

REM ============================================================
REM  ChemEPlugins - Combined Installer Builder
REM  Version : 1.2.3
REM  Output  : dist\ChemEPlugins_Setup_1.2.3_x64.exe
REM
REM  当前只打包 ChemE-Organic Chemistry / ChemE-Entropy 两款插件；
REM  ChemE-Transcription 尚未完成，开关默认关闭。
REM  安装时由用户勾选安装哪款插件（默认全部安装）。
REM
REM  共存说明：本安装包使用独立 AppId，不会卸载旧版安装包
REM  （Organic Chemistry 1.x 等）安装的旧插件；当前两款插件自改名
REM  起使用新 Plugin Code / Bundle ID，与旧插件在宿主中共存。
REM ============================================================

set "APP_NAME=ChemEPlugins"
set "APP_VERSION=1.2.3"
set "SCRIPT_DIR=%~dp0"

REM ---------- 组件开关 ----------
REM 生物化学 ChemE-Transcription 尚未开发完成，默认不打包；
REM 待其完成并产出 VST3 后，将此开关置 1 即可一并打包。
set "INCLUDE_TRANSCRIPTION=0"
set "ISS_FILE=%SCRIPT_DIR%iisaacbeats_science_series_installer.iss"
set "DIST_DIR=%SCRIPT_DIR%dist"
set "OUTPUT_EXE=%DIST_DIR%\ChemEPlugins_Setup_%APP_VERSION%_x64.exe"

echo ============================================================
echo  %APP_NAME% Installer Builder  v%APP_VERSION%
echo ============================================================

if not exist "%ISS_FILE%" (
  echo [ERROR] 未找到安装脚本: "%ISS_FILE%"
  exit /b 1
)

REM ---------- 探测 ChemE-Organic Chemistry VST3 产物 ----------
REM 以 bundle 内实际二进制为准，避免匹配残留的空 bundle 目录。
set "OC_VST3_DIR="
if exist "%SCRIPT_DIR%Organic Chemistry\cmake-build-ninja\OrganicChemistry_artefacts\Release\VST3\ChemE-Organic Chemistry.vst3\Contents\x86_64-win\ChemE-Organic Chemistry.vst3" (
  set "OC_VST3_DIR=Organic Chemistry\cmake-build-ninja\OrganicChemistry_artefacts\Release\VST3"
)
if not defined OC_VST3_DIR if exist "%SCRIPT_DIR%Organic Chemistry\cmake-build-release-visual-studio\OrganicChemistry_artefacts\Release\VST3\ChemE-Organic Chemistry.vst3\Contents\x86_64-win\ChemE-Organic Chemistry.vst3" (
  set "OC_VST3_DIR=Organic Chemistry\cmake-build-release-visual-studio\OrganicChemistry_artefacts\Release\VST3"
)
if not defined OC_VST3_DIR if exist "%SCRIPT_DIR%Organic Chemistry\cmake-build-release\OrganicChemistry_artefacts\Release\VST3\ChemE-Organic Chemistry.vst3\Contents\x86_64-win\ChemE-Organic Chemistry.vst3" (
  set "OC_VST3_DIR=Organic Chemistry\cmake-build-release\OrganicChemistry_artefacts\Release\VST3"
)
if not defined OC_VST3_DIR (
  echo [ERROR] 未找到 ChemE-Organic Chemistry 的 VST3 构建产物。
  echo [HINT] 请先在 "Organic Chemistry" 目录完成 Release 构建。
  exit /b 1
)

REM ---------- 探测 ChemE-Entropy VST3 产物 ----------
set "ENTROPY_VST3_DIR="
if exist "%SCRIPT_DIR%Entropy\cmake-build-ninja\Entropy_artefacts\Release\VST3\ChemE-Entropy.vst3\Contents\x86_64-win\ChemE-Entropy.vst3" (
  set "ENTROPY_VST3_DIR=Entropy\cmake-build-ninja\Entropy_artefacts\Release\VST3"
)
if not defined ENTROPY_VST3_DIR if exist "%SCRIPT_DIR%Entropy\cmake-build-release-visual-studio\Entropy_artefacts\Release\VST3\ChemE-Entropy.vst3\Contents\x86_64-win\ChemE-Entropy.vst3" (
  set "ENTROPY_VST3_DIR=Entropy\cmake-build-release-visual-studio\Entropy_artefacts\Release\VST3"
)
if not defined ENTROPY_VST3_DIR if exist "%SCRIPT_DIR%Entropy\cmake-build-release\Entropy_artefacts\Release\VST3\ChemE-Entropy.vst3\Contents\x86_64-win\ChemE-Entropy.vst3" (
  set "ENTROPY_VST3_DIR=Entropy\cmake-build-release\Entropy_artefacts\Release\VST3"
)
if not defined ENTROPY_VST3_DIR (
  echo [ERROR] 未找到 ChemE-Entropy 的 VST3 构建产物。
  echo [HINT] 请先在 "Entropy" 目录运行 build.ps1 完成 Release 构建。
  exit /b 1
)

REM ---------- 探测 ChemE-Transcription VST3 产物 ----------
set "TRANSCRIPTION_VST3_DIR="
if exist "%SCRIPT_DIR%Transcription\cmake-build-ninja\Transcription_artefacts\Release\VST3\ChemE-Transcription.vst3\Contents\x86_64-win\ChemE-Transcription.vst3" (
  set "TRANSCRIPTION_VST3_DIR=Transcription\cmake-build-ninja\Transcription_artefacts\Release\VST3"
)
if not defined TRANSCRIPTION_VST3_DIR if exist "%SCRIPT_DIR%Transcription\cmake-build-release-visual-studio\Transcription_artefacts\Release\VST3\ChemE-Transcription.vst3\Contents\x86_64-win\ChemE-Transcription.vst3" (
  set "TRANSCRIPTION_VST3_DIR=Transcription\cmake-build-release-visual-studio\Transcription_artefacts\Release\VST3"
)
if not defined TRANSCRIPTION_VST3_DIR if exist "%SCRIPT_DIR%Transcription\cmake-build-release\Transcription_artefacts\Release\VST3\ChemE-Transcription.vst3\Contents\x86_64-win\ChemE-Transcription.vst3" (
  set "TRANSCRIPTION_VST3_DIR=Transcription\cmake-build-release\Transcription_artefacts\Release\VST3"
)
if "%INCLUDE_TRANSCRIPTION%"=="1" if not defined TRANSCRIPTION_VST3_DIR (
  echo [ERROR] 未找到 ChemE-Transcription 的 VST3 构建产物。
  echo [HINT] 请先在 "Transcription" 目录运行 build.ps1 完成 Release 构建。
  exit /b 1
)

REM ---------- 提取组件版本号（单一来源：各自 CMakeLists.txt 的 project() VERSION） ----------
REM 系列包版本独立于组件版本；组件真实版本仅用于安装向导勾选项描述。
set "OC_VERSION="
for /f "tokens=3" %%V in ('findstr /b /c:"project(OrganicChemistry VERSION" "%SCRIPT_DIR%Organic Chemistry\CMakeLists.txt"') do set "OC_VERSION=%%V"
if not defined OC_VERSION set "OC_VERSION=1.2.1"

set "ENTROPY_VERSION="
for /f "tokens=3" %%V in ('findstr /b /c:"project(Entropy VERSION" "%SCRIPT_DIR%Entropy\CMakeLists.txt"') do set "ENTROPY_VERSION=%%V"
if not defined ENTROPY_VERSION set "ENTROPY_VERSION=1.1.0"

set "TRANSCRIPTION_VERSION="
for /f "tokens=3" %%V in ('findstr /b /c:"project(Transcription VERSION" "%SCRIPT_DIR%Transcription\CMakeLists.txt"') do set "TRANSCRIPTION_VERSION=%%V"
if not defined TRANSCRIPTION_VERSION set "TRANSCRIPTION_VERSION=1.0.0"

if "%INCLUDE_TRANSCRIPTION%"=="1" (
  echo [INFO] 组件版本: ChemE-Organic Chemistry v%OC_VERSION% / ChemE-Entropy v%ENTROPY_VERSION% / ChemE-Transcription v%TRANSCRIPTION_VERSION%
) else (
  echo [INFO] 组件版本: ChemE-Organic Chemistry v%OC_VERSION% / ChemE-Entropy v%ENTROPY_VERSION%
)

if not exist "%DIST_DIR%" (
  mkdir "%DIST_DIR%"
)

set "ISCC_PATH=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" set "ISCC_PATH=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" set "ISCC_PATH=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"

if not exist "%ISCC_PATH%" (
  echo [ERROR] 未找到 ISCC.exe，请先安装 Inno Setup 6。
  echo 你可以运行: winget install --id JRSoftware.InnoSetup -e
  exit /b 1
)

echo [INFO] 编译器: "%ISCC_PATH%"
echo [INFO] ChemE-Organic Chemistry VST3: "%OC_VST3_DIR%"
echo [INFO] ChemE-Entropy VST3:            "%ENTROPY_VST3_DIR%"
if "%INCLUDE_TRANSCRIPTION%"=="1" echo [INFO] ChemE-Transcription VST3:      "%TRANSCRIPTION_VST3_DIR%"

echo [INFO] 开始打包 ...
echo ------------------------------------------------------------

if "%INCLUDE_TRANSCRIPTION%"=="1" (
  "%ISCC_PATH%" /DMyAppVersion="%APP_VERSION%" /DOC_VERSION="%OC_VERSION%" /DENTROPY_VERSION="%ENTROPY_VERSION%" /DTRANSCRIPTION_VERSION="%TRANSCRIPTION_VERSION%" /DOC_VST3_DIR="%OC_VST3_DIR%" /DENTROPY_VST3_DIR="%ENTROPY_VST3_DIR%" /DTRANSCRIPTION_VST3_DIR="%TRANSCRIPTION_VST3_DIR%" /DINCLUDE_TRANSCRIPTION "%ISS_FILE%"
) else (
  "%ISCC_PATH%" /DMyAppVersion="%APP_VERSION%" /DOC_VERSION="%OC_VERSION%" /DENTROPY_VERSION="%ENTROPY_VERSION%" /DOC_VST3_DIR="%OC_VST3_DIR%" /DENTROPY_VST3_DIR="%ENTROPY_VST3_DIR%" "%ISS_FILE%"
)

if errorlevel 1 (
  echo ------------------------------------------------------------
  echo [ERROR] 打包失败，请查看上方日志。
  exit /b 1
)

echo ------------------------------------------------------------
if exist "%OUTPUT_EXE%" (
  echo [OK] 打包完成
  echo      输出: "%OUTPUT_EXE%"
) else (
  echo [OK] 打包完成
  echo      输出目录: "%DIST_DIR%"
)
endlocal

echo.
echo 按任意键退出...
pause >nul
exit /b 0
