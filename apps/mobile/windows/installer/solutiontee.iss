; SolutionTee CBT for Windows — installer (D-166). Built by .github/workflows/android-apk.yml (job "windows"):
;   ISCC.exe /DAppVersion=1.2.3 /DBuildDir=<flutter build output> /DOutDir=<folder> solutiontee.iss
; Installs for the current user only (no administrator prompt), adds Start menu and desktop shortcuts and an
; uninstaller, and opens the app when done. A newer installer updates in place (the app runs it silently).

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\direct\runner\Release"
#endif
#ifndef OutDir
  #define OutDir "..\..\build\installer"
#endif

[Setup]
AppId={{8F3C2B1E-6A4D-4C2B-9E1F-5A7D3C9B2E10}
AppName=SolutionTee CBT
AppVersion={#AppVersion}
AppVerName=SolutionTee CBT {#AppVersion}
AppPublisher=SolutionTee
AppPublisherURL=https://cbt.solutiontee.com
AppSupportURL=https://cbt.solutiontee.com
AppUpdatesURL=https://cbt.solutiontee.com
VersionInfoVersion=1.0.0.0
VersionInfoProductName=SolutionTee CBT
VersionInfoDescription=SolutionTee CBT installer
DefaultDirName={localappdata}\Programs\SolutionTee CBT
DefaultGroupName=SolutionTee CBT
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutDir}
OutputBaseFilename=SolutionTee-CBT-Setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\SolutionTeeCBT.exe
UninstallDisplayName=SolutionTee CBT
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=force
CloseApplicationsFilter=SolutionTeeCBT.exe
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SolutionTee CBT"; Filename: "{app}\SolutionTeeCBT.exe"
Name: "{autodesktop}\SolutionTee CBT"; Filename: "{app}\SolutionTeeCBT.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\SolutionTeeCBT.exe"; Description: "Open SolutionTee CBT"; Flags: nowait postinstall
