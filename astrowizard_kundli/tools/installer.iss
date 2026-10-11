; Inno Setup script: one AstroWizardKundaliSetup.exe installer for Windows 10/11 (64-bit).
; Built by the GitHub workflow (job "windows"). SourceDir is passed with /DSourceDir=...
#ifndef OutName
  #define OutName "AstroWizardKundaliSetup"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppName=AstroWizard Kundali Software
AppVersion=1.0
AppPublisher=AstroWizard
DefaultDirName={autopf}\AstroWizard Kundali Software
DefaultGroupName=AstroWizard Kundali Software
OutputBaseFilename={#OutName}
OutputDir=..\installer_out
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\astrowizard_kundli.exe

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\AstroWizard Kundali Software"; Filename: "{app}\astrowizard_kundli.exe"
Name: "{autodesktop}\AstroWizard Kundali Software"; Filename: "{app}\astrowizard_kundli.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Run]
Filename: "{app}\astrowizard_kundli.exe"; Description: "Start AstroWizard Kundali Software"; Flags: nowait postinstall skipifsilent
