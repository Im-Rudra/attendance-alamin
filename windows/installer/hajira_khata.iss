; Inno Setup 6 script for the Windows installer (built by CI; see docs/RELEASE.md).
; Compile:  iscc /DAppVersion=1.0.0 /DSourceDir=build\windows\x64\runner\Release /DOutputDir=out /DOutputName=HajiraKhata-1.0.0-windows-setup windows\installer\hajira_khata.iss
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif
#ifndef OutputName
  #define OutputName "HajiraKhata-windows-setup"
#endif

[Setup]
; Never change AppId: it is how a newer setup upgrades an older install in place.
AppId={{6F0B7C52-3E4D-4B1A-9C65-2A8D1F7E40B3}
AppName=Hajira Khata
AppVersion={#AppVersion}
AppVerName=Hajira Khata {#AppVersion}
AppPublisher=Hajira Khata
DefaultDirName={autopf}\Hajira Khata
DefaultGroupName=Hajira Khata
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\attendance_alamin.exe
UninstallDisplayName=Hajira Khata
SetupIconFile=..\runner\resources\app_icon.ico
OutputDir={#OutputDir}
OutputBaseFilename={#OutputName}
; Per-machine (Program Files) by default; the user may pick "just for me" in the dialog.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Includes the VC++ runtime DLLs the workflow copies into the Release folder.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Hajira Khata"; Filename: "{app}\attendance_alamin.exe"
Name: "{autodesktop}\Hajira Khata"; Filename: "{app}\attendance_alamin.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\attendance_alamin.exe"; Description: "{cm:LaunchProgram,Hajira Khata}"; Flags: nowait postinstall skipifsilent
