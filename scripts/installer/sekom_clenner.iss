; Inno Setup Script for sekom_clenner (Flutter Windows)
; Build prerequisites:
; 1) flutter build windows --release
; 2) Compile this script with Inno Setup Compiler (ISCC.exe or GUI)

#define MyAppName "sekom_clenner"
#define MyAppPublisher "Sekom"
#define MyAppVersion "1.0.0"
#define MyAppExeName "sekom_clenner.exe"

[Setup]
; Use a fixed GUID to keep upgrades/patches consistent
AppId={{1C0E2F7E-8E3E-4B2F-B2B5-1A85C5D9B2A1}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Sekom\{#MyAppName}
DefaultGroupName=Sekom
UninstallDisplayIcon={app}\resources\app_icon.ico
DisableProgramGroupPage=yes
WizardStyle=modern

; Outputs
OutputDir=dist\installer
OutputBaseFilename={#MyAppName}-{#MyAppVersion}-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico

; Compression
Compression=lzma2
SolidCompression=yes

; 64-bit only (Flutter Windows builds are x64)
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; Install to Program Files, require admin
PrivilegesRequired=admin

; Optional UI tweaks
DisableDirPage=no
DisableReadyMemo=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: checkedonce

[Files]
; NOTE:
; Paths here are relative to this script's directory: scripts\installer\
; Sealed Flutter Windows release output
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

; Native helper (optional but recommended)
Source: "..\..\native\publish\SekomHelper.exe"; DestDir: "{app}"; Flags: ignoreversion

; App icon file for shortcuts/uninstall
Source: "..\..\windows\runner\resources\app_icon.ico"; DestDir: "{app}\resources"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\resources\app_icon.ico"; IconIndex: 0
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\resources\app_icon.ico"; IconIndex: 0

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan {#MyAppName} sekarang"; Flags: nowait postinstall skipifsilent

