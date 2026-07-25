; Inno Setup script for Lawyer Office (Windows)
; Requires: Inno Setup 6+ installed on a Windows build machine.
; Build steps:
;   1) flutter build windows --release
;   2) Compile this script with ISCC.exe

#define MyAppName "مكتب المحامي"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Lawyer Office"
#define MyAppExeName "lawyer_office.exe"
; Update this path to your Flutter Release output if different:
#define ReleaseDir "..\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{A7C3E2D1-9F44-4B2A-8C11-LAWOFFICE2026}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\\LawyerOffice
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=LawyerOffice_Setup_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=
UninstallDisplayIcon={app}\\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"
Name: "{autodesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
