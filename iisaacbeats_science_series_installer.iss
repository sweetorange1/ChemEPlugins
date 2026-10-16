; ============================================================
;  iisaacbeats Science Series — 组合安装脚本
;  一个安装包同时携带 ChemE-Organic Chemistry / ChemE-Entropy /
;  ChemE-Transcription 三款插件，安装向导中可勾选要安装的插件
;  （默认全部安装）。
;
;  产物目录由 build_installer.bat 通过 -DOC_VST3_DIR /
;  -DENTROPY_VST3_DIR / -DTRANSCRIPTION_VST3_DIR 覆盖为实际
;  构建目录（相对系列文件夹）。
;
;  共存策略：
;    - AppId 与旧版安装包（1.0.0 的 A1F2C3D4-... 及内部测试版 2.x
;      的 7E5B4C3D-...）不同，因此安装本包不会触发旧包的升级/卸载
;      流程，不会删除旧包已安装的 "Organic Chemistry.vst3" /
;      "Entropy.vst3"，老用户工程（引用旧插件）不受影响。
;    - 三款插件使用 ChemE 系列的 Plugin Code / Bundle ID，
;      VST3 UID 与旧插件不同，宿主会视为独立插件，新旧共存。
; ============================================================

#define MyAppName "ChemEPlugins"
#define MyAppPublisher "iisaacbeats.cn"
#define MyOcBundle "ChemE-Organic Chemistry.vst3"
#define MyEntropyBundle "ChemE-Entropy.vst3"
#define MyTranscriptionBundle "ChemE-Transcription.vst3"

; 版本号策略：系列包版本独立于组件版本，由发布时指定（当前 1.2.1）；
; 三个组件版本号均由 build_installer.bat 从单一来源提取后经 -D 传入，
; 下方 #ifndef 仅为直接运行 ISCC 时的兜底默认值。
#ifndef MyAppVersion
  #define MyAppVersion "1.2.1"
#endif
#ifndef OC_VERSION
  #define OC_VERSION "1.2.1"
#endif
#ifndef ENTROPY_VERSION
  #define ENTROPY_VERSION "1.0.6"
#endif
#ifndef TRANSCRIPTION_VERSION
  #define TRANSCRIPTION_VERSION "1.0.0"
#endif

#ifndef OC_VST3_DIR
  #define OC_VST3_DIR "Organic Chemistry\cmake-build-ninja\OrganicChemistry_artefacts\Release\VST3"
#endif
#ifndef ENTROPY_VST3_DIR
  #define ENTROPY_VST3_DIR "Entropy\cmake-build-ninja\Entropy_artefacts\Release\VST3"
#endif
#ifndef TRANSCRIPTION_VST3_DIR
  #define TRANSCRIPTION_VST3_DIR "Transcription\cmake-build-ninja\Transcription_artefacts\Release\VST3"
#endif

[Setup]
AppId={{B9A7E5C3-D1F4-4E6B-8A2C-5F3E7D9B1A0C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={commoncf}\VST3\iisaacbeats.cn
OutputDir=dist
OutputBaseFilename=ChemEPlugins_Setup_{#MyAppVersion}_x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
SetupLogging=yes
UsePreviousAppDir=no
DisableProgramGroupPage=yes
DisableDirPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation (all published plugins)"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "organic"; Description: "ChemE-Organic Chemistry - Organic chemistry synthesizer (v{#OC_VERSION})"; Types: full
Name: "entropy"; Description: "ChemE-Entropy - Physical chemistry entropy degradation effect (v{#ENTROPY_VERSION})"; Types: full
#ifdef INCLUDE_TRANSCRIPTION
Name: "transcription"; Description: "ChemE-Transcription - Biochemistry transcription synthesizer (v{#TRANSCRIPTION_VERSION})"; Types: full
#endif

[Files]
Source: "{#OC_VST3_DIR}\{#MyOcBundle}\*"; DestDir: "{app}\{#MyOcBundle}"; Components: organic; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#ENTROPY_VST3_DIR}\{#MyEntropyBundle}\*"; DestDir: "{app}\{#MyEntropyBundle}"; Components: entropy; Flags: ignoreversion recursesubdirs createallsubdirs
#ifdef INCLUDE_TRANSCRIPTION
Source: "{#TRANSCRIPTION_VST3_DIR}\{#MyTranscriptionBundle}\*"; DestDir: "{app}\{#MyTranscriptionBundle}"; Components: transcription; Flags: ignoreversion recursesubdirs createallsubdirs
#endif

[Code]
var
  InstallDirWarningShown: Boolean;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  DefaultVst3Path: string;
begin
  Result := True;

  if CurPageID = wpSelectDir then
  begin
    DefaultVst3Path := ExpandConstant('{commoncf}\VST3\iisaacbeats.cn');

    if (CompareText(RemoveBackslashUnlessRoot(WizardDirValue), RemoveBackslashUnlessRoot(DefaultVst3Path)) <> 0) and (not InstallDirWarningShown) then
    begin
      MsgBox('You selected a non-default VST3 directory. After installation, you may need to add this directory in your DAW and rescan for the plugins to be detected.', mbInformation, MB_OK);
      InstallDirWarningShown := True;
    end;
  end;
end;
