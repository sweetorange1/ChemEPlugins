#!/usr/bin/env bash
# =============================================================================
# iisaacbeats Science Series — macOS 组合安装包脚本
# -----------------------------------------------------------------------------
# 把一个安装器同时携带 ChemE-Organic Chemistry / ChemE-Entropy /
# ChemE-Transcription 三款插件（每款含 VST3 + AU 两种格式），
# 安装向导中可勾选要安装的组件。
#
# 设计原则：
#   1) 本脚本不触碰编译；请在三个项目目录分别完成 Release 构建。
#   2) 校验各产物为 Universal 二进制（arm64 + x86_64）。
#   3) （可选）codesign 签名（--sign "Developer ID Application: ..."）。
#   4) pkgbuild 打组件 pkg，productbuild 合成一个安装器 .pkg。
#   5) （可选）hdiutil 生成 .dmg。
#
# 前置条件：
#   * ChemE-Organic Chemistry 产物：Organic Chemistry/build/OrganicChemistry_artefacts/Release/{VST3,AU}
#   * ChemE-Entropy 产物：Entropy/build/Entropy_artefacts/Release/{VST3,AU}
#   * ChemE-Transcription 产物：Transcription/build/Transcription_artefacts/Release/{VST3,AU}
#   * macOS 自带 pkgbuild / productbuild / hdiutil / lipo
#
# 输出目录：dist/
#   * iisaacbeats_ScienceSeries_Setup_<ver>_macOS.pkg
#   * iisaacbeats_ScienceSeries_Setup_<ver>_macOS.dmg（默认生成）
#
# 用法：
#   chmod +x build_installer_mac.sh
#   ./build_installer_mac.sh                              # 打 pkg + dmg（不签名）
#   ./build_installer_mac.sh --no-dmg                     # 只打 pkg（不签名）
#   ./build_installer_mac.sh --sign "Developer ID Application: ..."   # 签名后打包
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 系列安装器版本（与 Windows iss 的 MyAppVersion 一致；三款产品各自版本见其 CMakeLists）
APP_VERSION="1.2.1"
# 生物化学 ChemE-Transcription 尚未开发完成，默认不打包；完成后置 1。
INCLUDE_TRANSCRIPTION=0
APP_NAME="ChemEPlugins"
APP_PUBLISHER="iisaacbeats.cn"

OC_VST3_SRC="${SCRIPT_DIR}/Organic Chemistry/build/OrganicChemistry_artefacts/Release/VST3/ChemE-Organic Chemistry.vst3"
ENTROPY_VST3_SRC="${SCRIPT_DIR}/Entropy/build/Entropy_artefacts/Release/VST3/ChemE-Entropy.vst3"
TRANSCRIPTION_VST3_SRC="${SCRIPT_DIR}/Transcription/build/Transcription_artefacts/Release/VST3/ChemE-Transcription.vst3"
OC_AU_SRC="$(ls -d "${SCRIPT_DIR}"/Organic\ Chemistry/build/OrganicChemistry_artefacts/Release/AU/*.component 2>/dev/null | head -n1 || true)"
ENTROPY_AU_SRC="$(ls -d "${SCRIPT_DIR}"/Entropy/build/Entropy_artefacts/Release/AU/*.component 2>/dev/null | head -n1 || true)"
TRANSCRIPTION_AU_SRC="$(ls -d "${SCRIPT_DIR}"/Transcription/build/Transcription_artefacts/Release/AU/*.component 2>/dev/null | head -n1 || true)"

DIST_DIR="${SCRIPT_DIR}/dist"
STAGING_DIR="${SCRIPT_DIR}/.pkg_staging"

OC_VST3_PKG_ID="cn.iisaacbeats.cheme.organic.vst3"
OC_AU_PKG_ID="cn.iisaacbeats.cheme.organic.au"
ENTROPY_VST3_PKG_ID="cn.iisaacbeats.cheme.entropy.vst3"
ENTROPY_AU_PKG_ID="cn.iisaacbeats.cheme.entropy.au"
TRANSCRIPTION_VST3_PKG_ID="cn.iisaacbeats.cheme.transcription.vst3"
TRANSCRIPTION_AU_PKG_ID="cn.iisaacbeats.cheme.transcription.au"
PRODUCT_PKG_ID="cn.iisaacbeats.scienceseries.installer"

MAKE_DMG=1
SIGN_IDENTITY=""
for arg in "$@"; do
  case "$arg" in
    --no-dmg) MAKE_DMG=0 ;;
    --sign) SIGN_IDENTITY="__NEXT__" ;;
    -h|--help)
      echo "用法: $0 [--no-dmg] [--sign \"Developer ID Application: ...\"]"
      exit 0
      ;;
    *)
      if [[ "$SIGN_IDENTITY" == "__NEXT__" ]]; then
        SIGN_IDENTITY="$arg"
      else
        echo "[WARN] 未知参数: $arg（已忽略）"
      fi
      ;;
  esac
done
if [[ "$SIGN_IDENTITY" == "__NEXT__" ]]; then
  SIGN_IDENTITY=""
fi

# ---------- 1) 校验产物 ----------
require_bundle() {
  local label="$1" path="$2"
  if [[ ! -d "$path" ]]; then
    echo "[ERROR] 未找到 ${label} 产物: $path"
    echo "        请先在对应项目目录以 Release 配置完成构建。"
    exit 1
  fi
  echo "[INFO] ${label}: $path"
}
require_bundle "ChemE-Organic Chemistry VST3" "$OC_VST3_SRC"
require_bundle "ChemE-Entropy VST3"         "$ENTROPY_VST3_SRC"
require_bundle "ChemE-Organic Chemistry AU" "$OC_AU_SRC"
require_bundle "ChemE-Entropy AU"           "$ENTROPY_AU_SRC"
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
  require_bundle "ChemE-Transcription VST3"   "$TRANSCRIPTION_VST3_SRC"
  require_bundle "ChemE-Transcription AU"     "$TRANSCRIPTION_AU_SRC"
fi

# ---------- 2) 校验 Universal 二进制 ----------
check_universal() {
  local label="$1" bundle="$2"
  local bin
  bin="$(ls "$bundle/Contents/MacOS/" 2>/dev/null | head -n1 || true)"
  if [[ -z "$bin" ]]; then
    echo "[ERROR] 在 ${bundle} 中未找到可执行文件 Contents/MacOS/*"
    exit 1
  fi
  bin="$bundle/Contents/MacOS/$bin"
  local archs
  archs="$(lipo -archs "$bin" 2>/dev/null || true)"
  echo "[INFO] ${label} 架构: ${archs}"
  if [[ "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
    echo "[ERROR] ${label} 不是 Universal 二进制（当前: ${archs}），请重新 configure + 完整重编。"
    exit 1
  fi
}
check_universal "OC VST3"   "$OC_VST3_SRC"
check_universal "OC AU"     "$OC_AU_SRC"
check_universal "Entropy VST3" "$ENTROPY_VST3_SRC"
check_universal "Entropy AU"   "$ENTROPY_AU_SRC"
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
  check_universal "Transcription VST3" "$TRANSCRIPTION_VST3_SRC"
  check_universal "Transcription AU"   "$TRANSCRIPTION_AU_SRC"
fi

# ---------- 3) 准备 staging ----------
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/oc_vst3_root/Library/Audio/Plug-Ins/VST3"
mkdir -p "$STAGING_DIR/oc_au_root/Library/Audio/Plug-Ins/Components"
mkdir -p "$STAGING_DIR/entropy_vst3_root/Library/Audio/Plug-Ins/VST3"
mkdir -p "$STAGING_DIR/entropy_au_root/Library/Audio/Plug-Ins/Components"
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
  mkdir -p "$STAGING_DIR/transcription_vst3_root/Library/Audio/Plug-Ins/VST3"
  mkdir -p "$STAGING_DIR/transcription_au_root/Library/Audio/Plug-Ins/Components"
fi
mkdir -p "$STAGING_DIR/components"
mkdir -p "$STAGING_DIR/resources"
mkdir -p "$DIST_DIR"

echo "[INFO] 拷贝插件产物到 staging..."
cp -R "$OC_VST3_SRC"            "$STAGING_DIR/oc_vst3_root/Library/Audio/Plug-Ins/VST3/"
cp -R "$OC_AU_SRC"              "$STAGING_DIR/oc_au_root/Library/Audio/Plug-Ins/Components/"
cp -R "$ENTROPY_VST3_SRC"       "$STAGING_DIR/entropy_vst3_root/Library/Audio/Plug-Ins/VST3/"
cp -R "$ENTROPY_AU_SRC"         "$STAGING_DIR/entropy_au_root/Library/Audio/Plug-Ins/Components/"
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
  cp -R "$TRANSCRIPTION_VST3_SRC" "$STAGING_DIR/transcription_vst3_root/Library/Audio/Plug-Ins/VST3/"
  cp -R "$TRANSCRIPTION_AU_SRC"   "$STAGING_DIR/transcription_au_root/Library/Audio/Plug-Ins/Components/"
fi

# ---------- 3.5) 可选 codesign ----------
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "[INFO] 使用身份签名: $SIGN_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$STAGING_DIR/oc_vst3_root/Library/Audio/Plug-Ins/VST3/ChemE-Organic Chemistry.vst3"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$STAGING_DIR/oc_au_root/Library/Audio/Plug-Ins/Components/$(basename "$OC_AU_SRC")"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$STAGING_DIR/entropy_vst3_root/Library/Audio/Plug-Ins/VST3/ChemE-Entropy.vst3"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$STAGING_DIR/entropy_au_root/Library/Audio/Plug-Ins/Components/$(basename "$ENTROPY_AU_SRC")"
  if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
      "$STAGING_DIR/transcription_vst3_root/Library/Audio/Plug-Ins/VST3/ChemE-Transcription.vst3"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
      "$STAGING_DIR/transcription_au_root/Library/Audio/Plug-Ins/Components/$(basename "$TRANSCRIPTION_AU_SRC")"
  fi
else
  echo "[INFO] 未指定签名身份，跳过 codesign（产物为未签名版本，分发时建议签名）"
fi

# ---------- 4) 打组件 pkg ----------
OC_VST3_PKG="$STAGING_DIR/components/OC-VST3.pkg"
OC_AU_PKG="$STAGING_DIR/components/OC-AU.pkg"
ENTROPY_VST3_PKG="$STAGING_DIR/components/Entropy-VST3.pkg"
ENTROPY_AU_PKG="$STAGING_DIR/components/Entropy-AU.pkg"
TRANSCRIPTION_VST3_PKG="$STAGING_DIR/components/Transcription-VST3.pkg"
TRANSCRIPTION_AU_PKG="$STAGING_DIR/components/Transcription-AU.pkg"

build_component() {
  local root="$1" id="$2" out="$3"
  echo "[INFO] pkgbuild → ${id}..."
  pkgbuild --root "$root" --identifier "$id" --version "$APP_VERSION" --install-location "/" "$out"
}
build_component "$STAGING_DIR/oc_vst3_root"            "$OC_VST3_PKG_ID"            "$OC_VST3_PKG"
build_component "$STAGING_DIR/oc_au_root"              "$OC_AU_PKG_ID"              "$OC_AU_PKG"
build_component "$STAGING_DIR/entropy_vst3_root"       "$ENTROPY_VST3_PKG_ID"       "$ENTROPY_VST3_PKG"
build_component "$STAGING_DIR/entropy_au_root"         "$ENTROPY_AU_PKG_ID"         "$ENTROPY_AU_PKG"
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
  build_component "$STAGING_DIR/transcription_vst3_root" "$TRANSCRIPTION_VST3_PKG_ID" "$TRANSCRIPTION_VST3_PKG"
  build_component "$STAGING_DIR/transcription_au_root"   "$TRANSCRIPTION_AU_PKG_ID"   "$TRANSCRIPTION_AU_PKG"
fi

# ---------- 5) Distribution.xml ----------
DIST_XML="$STAGING_DIR/Distribution.xml"
cat > "$DIST_XML" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>${APP_NAME} ${APP_VERSION}</title>
    <organization>${APP_PUBLISHER}</organization>
    <domains enable_localSystem="true"/>
    <options customize="allow" require-scripts="false" rootVolumeOnly="true" hostArchitectures="x86_64,arm64"/>
    <welcome file="welcome.txt" mime-type="text/plain"/>
    <choices-outline>
        <line choice="default">
            <line choice="organic"/>
            <line choice="entropy"/>
XML
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
cat >> "$DIST_XML" <<XML
            <line choice="transcription"/>
XML
fi
cat >> "$DIST_XML" <<XML
        </line>
    </choices-outline>
    <choice id="default" title="${APP_NAME}" description="${APP_NAME} ${APP_VERSION} - Chemistry plugin series bundle"/>
    <choice id="organic" visible="true" title="ChemE-Organic Chemistry - Organic chemistry synthesizer" description="Molecular editor bell synthesizer (VST3 + AU)">
        <pkg-ref id="${OC_VST3_PKG_ID}"/>
        <pkg-ref id="${OC_AU_PKG_ID}"/>
    </choice>
    <choice id="entropy" visible="true" title="ChemE-Entropy - Physical chemistry entropy degradation effect" description="Carrier timeline degradation effect (VST3 + AU)">
        <pkg-ref id="${ENTROPY_VST3_PKG_ID}"/>
        <pkg-ref id="${ENTROPY_AU_PKG_ID}"/>
    </choice>
XML
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
cat >> "$DIST_XML" <<XML
    <choice id="transcription" visible="true" title="ChemE-Transcription - Biochemistry transcription synthesizer" description="Gene-to-sound subtractive synthesizer (VST3 + AU)">
        <pkg-ref id="${TRANSCRIPTION_VST3_PKG_ID}"/>
        <pkg-ref id="${TRANSCRIPTION_AU_PKG_ID}"/>
    </choice>
XML
fi
cat >> "$DIST_XML" <<XML
    <pkg-ref id="${OC_VST3_PKG_ID}" version="${APP_VERSION}" onConclusion="none">OC-VST3.pkg</pkg-ref>
    <pkg-ref id="${OC_AU_PKG_ID}" version="${APP_VERSION}" onConclusion="none">OC-AU.pkg</pkg-ref>
    <pkg-ref id="${ENTROPY_VST3_PKG_ID}" version="${APP_VERSION}" onConclusion="none">Entropy-VST3.pkg</pkg-ref>
    <pkg-ref id="${ENTROPY_AU_PKG_ID}" version="${APP_VERSION}" onConclusion="none">Entropy-AU.pkg</pkg-ref>
XML
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
cat >> "$DIST_XML" <<XML
    <pkg-ref id="${TRANSCRIPTION_VST3_PKG_ID}" version="${APP_VERSION}" onConclusion="none">Transcription-VST3.pkg</pkg-ref>
    <pkg-ref id="${TRANSCRIPTION_AU_PKG_ID}" version="${APP_VERSION}" onConclusion="none">Transcription-AU.pkg</pkg-ref>
XML
fi
cat >> "$DIST_XML" <<XML
</installer-gui-script>
XML

cat > "$STAGING_DIR/resources/welcome.txt" <<TXT
${APP_NAME} ${APP_VERSION}

Chemistry plugin series bundle. This installer contains the following plugins:

  • ChemE-Organic Chemistry - a bell synthesizer where molecules become timbre
    (VST3 / AU, shared by all users)
  • ChemE-Entropy - physical chemistry entropy degradation effect: pick a
    carrier and date, and hear time's arrow disorder the sound (VST3 / AU)
TXT
if [ "$INCLUDE_TRANSCRIPTION" = "1" ]; then
cat >> "$STAGING_DIR/resources/welcome.txt" <<TXT
  • ChemE-Transcription - biochemistry transcription synthesizer mapping
    genetic information to sound (VST3 / AU)
TXT
fi
cat >> "$STAGING_DIR/resources/welcome.txt" <<TXT

Universal binary: supports both Apple Silicon (arm64) and Intel (x86_64) Macs.

You can choose which plugins to install in the next step.

After installation, rescan the plugin directory in your DAW.

Publisher: ${APP_PUBLISHER}
TXT

# ---------- 6) productbuild ----------
FINAL_PKG="$DIST_DIR/ChemEPlugins_Setup_${APP_VERSION}_macOS.pkg"
echo "[INFO] productbuild → 最终安装器..."
productbuild \
  --distribution "$DIST_XML" \
  --package-path "$STAGING_DIR/components" \
  --resources "$STAGING_DIR/resources" \
  --identifier "$PRODUCT_PKG_ID" \
  --version "$APP_VERSION" \
  "$FINAL_PKG"

echo "[OK] 已生成安装包: $FINAL_PKG"

# ---------- 6.5) 可选签名 ----------
if [[ -n "$SIGN_IDENTITY" ]]; then
  SIGNED_PKG="$DIST_DIR/ChemEPlugins_Setup_${APP_VERSION}_macOS_signed.pkg"
  echo "[INFO] productsign → 签名安装器..."
  productsign --sign "$SIGN_IDENTITY" "$FINAL_PKG" "$SIGNED_PKG"
  mv -f "$SIGNED_PKG" "$FINAL_PKG"
  echo "[OK] 安装器已签名: $FINAL_PKG"
fi

# ---------- 7) 可选 dmg ----------
if [[ "$MAKE_DMG" == "1" ]]; then
  FINAL_DMG="$DIST_DIR/ChemEPlugins_Setup_${APP_VERSION}_macOS.dmg"
  DMG_STAGING="$STAGING_DIR/dmg"
  rm -rf "$DMG_STAGING"
  mkdir -p "$DMG_STAGING"
  cp "$FINAL_PKG" "$DMG_STAGING/"

  cat > "$DMG_STAGING/README.txt" <<TXT
${APP_NAME} ${APP_VERSION} - macOS Installation Notes

1. Double-click ChemEPlugins_Setup_${APP_VERSION}_macOS.pkg to start the installer.
2. If Gatekeeper blocks the first run, allow it in System Settings > Privacy & Security.
3. After installation, rescan the VST3 / AU plugin directory in your DAW to see the installed ChemE plugins.
4. This package does not uninstall older plugins (e.g. Organic Chemistry 1.x); old and new plugins coexist in the host.

Publisher: ${APP_PUBLISHER}
TXT

  rm -f "$FINAL_DMG"
  echo "[INFO] hdiutil → dmg..."
  hdiutil create \
    -volname "${APP_NAME} ${APP_VERSION}" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$FINAL_DMG" >/dev/null
  echo "[OK] 已生成磁盘映像: $FINAL_DMG"
fi

# ---------- 8) 清理 ----------
rm -rf "$STAGING_DIR"

echo ""
echo "===================================================================="
echo " 打包完成！输出目录: $DIST_DIR"
ls -lh "$DIST_DIR" | awk 'NR>1 {print "   " $9 "   " $5}'
echo "===================================================================="
