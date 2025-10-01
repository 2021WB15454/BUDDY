# BUDDY AI Assistant - Windows Installer Script
# This script creates a Windows MSI installer package
# Requires: Advanced Installer or Inno Setup

param(
    [string]$Version = "1.0.0",
    [string]$OutputPath = ".\output",
    [switch]$Sign = $false
)

$ErrorActionPreference = "Stop"

Write-Host "🤖 BUDDY Windows Installer Builder" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Configuration
$AppName = "BUDDY AI Assistant"
$Publisher = "BUDDY Team"
$InstallDir = "{pf}\BUDDY"
$AppId = "{{B7DD7C8A-1F2E-4B3D-8A9C-5E6F7D8E9F0A}}"

# Create output directory
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force
}

# Create Inno Setup script
$InnoScript = @"
; BUDDY AI Assistant - Inno Setup Script
[Setup]
AppId=$AppId
AppName=$AppName
AppVersion=$Version
AppPublisher=$Publisher
AppPublisherURL=https://github.com/2021WB15454/BUDDY
AppSupportURL=https://github.com/2021WB15454/BUDDY/issues
AppUpdatesURL=https://github.com/2021WB15454/BUDDY/releases
DefaultDirName=$InstallDir
DefaultGroupName=$AppName
AllowNoIcons=yes
LicenseFile=LICENSE
OutputDir=$OutputPath
OutputBaseFilename=BUDDY-Setup-v$Version
SetupIconFile=assets\icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1
Name: "autostart"; Description: "Start BUDDY automatically with Windows"; GroupDescription: "Startup Options"
Name: "firewall"; Description: "Configure Windows Firewall for BUDDY"; GroupDescription: "Network Settings"

[Files]
; Core Python files
Source: "packages\core\*"; DestDir: "{app}\core"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "packages\core\buddy\*"; DestDir: "{app}\core\buddy"; Flags: ignoreversion recursesubdirs createallsubdirs

; Desktop application
Source: "apps\desktop\dist\*"; DestDir: "{app}\desktop"; Flags: ignoreversion recursesubdirs createallsubdirs

; Dependencies
Source: "requirements.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "package.json"; DestDir: "{app}"; Flags: ignoreversion

; Assets and resources
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs

; Scripts
Source: "scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs

; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "DEPLOYMENT_GUIDE.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

; Python runtime (if bundled)
Source: "runtime\python\*"; DestDir: "{app}\runtime\python"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: ShouldInstallPython

; Node.js runtime (if bundled)
Source: "runtime\nodejs\*"; DestDir: "{app}\runtime\nodejs"; Flags: ignoreversion recursesubdirs createallsubdirs; Check: ShouldInstallNodeJS

[Icons]
Name: "{group}\$AppName"; Filename: "{app}\BUDDY.exe"; IconFilename: "{app}\assets\icon.ico"
Name: "{group}\$AppName Configuration"; Filename: "{app}\config.exe"; IconFilename: "{app}\assets\config.ico"
Name: "{group}\{cm:UninstallProgram,$AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\$AppName"; Filename: "{app}\BUDDY.exe"; IconFilename: "{app}\assets\icon.ico"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\$AppName"; Filename: "{app}\BUDDY.exe"; IconFilename: "{app}\assets\icon.ico"; Tasks: quicklaunchicon

[Registry]
; Auto-start registry entry
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "BUDDY"; ValueData: """{app}\BUDDY.exe"" --minimized"; Flags: uninsdeletevalue; Tasks: autostart

; Application registration
Root: HKLM; Subkey: "Software\BUDDY"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "Software\BUDDY"; ValueType: string; ValueName: "Version"; ValueData: "$Version"; Flags: uninsdeletekey

[Run]
; Install Python dependencies
Filename: "{app}\runtime\python\python.exe"; Parameters: "-m pip install -r ""{app}\requirements.txt"""; StatusMsg: "Installing Python dependencies..."; Flags: runhidden waituntilterminated; Check: ShouldInstallPython

; Install Node.js dependencies
Filename: "{app}\runtime\nodejs\npm.cmd"; Parameters: "install --prefix ""{app}\desktop"""; StatusMsg: "Installing Node.js dependencies..."; Flags: runhidden waituntilterminated; Check: ShouldInstallNodeJS

; Configure firewall
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""BUDDY AI"" dir=in action=allow protocol=TCP localport=8000"; StatusMsg: "Configuring Windows Firewall..."; Flags: runhidden waituntilterminated; Tasks: firewall

; Start BUDDY service
Filename: "{app}\BUDDY.exe"; Parameters: "--install-service"; StatusMsg: "Installing BUDDY service..."; Flags: runhidden waituntilterminated

; Launch BUDDY
Filename: "{app}\BUDDY.exe"; Description: "{cm:LaunchProgram,$AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop BUDDY service
Filename: "{app}\BUDDY.exe"; Parameters: "--uninstall-service"; Flags: runhidden waituntilterminated

; Remove firewall rule
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""BUDDY AI"""; Flags: runhidden waituntilterminated

[Code]
function ShouldInstallPython: Boolean;
begin
  Result := not FileExists(ExpandConstant('{sys}\python.exe')) and 
            not FileExists(ExpandConstant('{pf}\Python311\python.exe'));
end;

function ShouldInstallNodeJS: Boolean;
begin
  Result := not FileExists(ExpandConstant('{pf}\nodejs\node.exe'));
end;

procedure InitializeWizard;
begin
  WizardForm.LicenseAcceptedRadio.Checked := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  // Check if BUDDY is running and close it
  if FindWindowByClassName('BUDDYMainWindow') <> 0 then
  begin
    if MsgBox('BUDDY is currently running. Setup needs to close it before continuing. Close BUDDY now?', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      Exec(ExpandConstant('{app}\BUDDY.exe'), '--shutdown', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end
    else
    begin
      Result := 'Please close BUDDY manually and try again.';
      Exit;
    end;
  end;
  
  Result := '';
end;
"@

# Write Inno Setup script
$InnoScript | Out-File -FilePath "BUDDY-Setup.iss" -Encoding UTF8

Write-Host "✅ Inno Setup script created: BUDDY-Setup.iss" -ForegroundColor Green

# Create Windows batch launcher
$BatchLauncher = @"
@echo off
title BUDDY AI Assistant
cd /d "%~dp0"

echo 🤖 Starting BUDDY AI Assistant...
echo ================================

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found. Using bundled runtime...
    set PYTHON_PATH=%~dp0runtime\python\python.exe
) else (
    set PYTHON_PATH=python
)

REM Check if Node.js is available
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Node.js not found. Using bundled runtime...
    set NODE_PATH=%~dp0runtime\nodejs\node.exe
    set NPM_PATH=%~dp0runtime\nodejs\npm.cmd
) else (
    set NODE_PATH=node
    set NPM_PATH=npm
)

REM Start BUDDY Core
echo 🚀 Starting BUDDY Core...
start /min cmd /c "cd core && %PYTHON_PATH% start_buddy_simple.py"

REM Wait for core to initialize
timeout /t 5 /nobreak >nul

REM Start Desktop App
echo 🖥️ Starting Desktop Interface...
cd desktop
start /min cmd /c "%NPM_PATH% run dev"

echo ✅ BUDDY is starting up!
echo 🌐 Web Interface: http://localhost:8000
echo 🖥️ Desktop App: http://localhost:3000
echo.
echo Press any key to open BUDDY in your browser...
pause >nul

start http://localhost:8000

echo BUDDY is now running in the background.
echo Close this window to keep BUDDY running.
pause
"@

$BatchLauncher | Out-File -FilePath "BUDDY.bat" -Encoding ASCII

Write-Host "✅ Windows launcher created: BUDDY.bat" -ForegroundColor Green

# Create PowerShell installer
$PowerShellInstaller = @"
# BUDDY AI Assistant - PowerShell Installer
#Requires -RunAsAdministrator

param(
    [string]`$InstallPath = "`$env:ProgramFiles\BUDDY",
    [switch]`$Silent = `$false,
    [switch]`$SkipDependencies = `$false
)

`$ErrorActionPreference = "Stop"

if (!`$Silent) {
    Write-Host "🤖 BUDDY AI Assistant Installer" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""
}

# Create installation directory
if (!(Test-Path `$InstallPath)) {
    New-Item -ItemType Directory -Path `$InstallPath -Force | Out-Null
}

# Download and extract BUDDY
`$DownloadUrl = "https://github.com/2021WB15454/BUDDY/archive/refs/heads/main.zip"
`$TempZip = "`$env:TEMP\BUDDY-main.zip"

Write-Host "📥 Downloading BUDDY..." -ForegroundColor Blue
Invoke-WebRequest -Uri `$DownloadUrl -OutFile `$TempZip

Write-Host "📦 Extracting files..." -ForegroundColor Blue
Expand-Archive -Path `$TempZip -DestinationPath `$env:TEMP -Force
Copy-Item -Path "`$env:TEMP\BUDDY-main\*" -Destination `$InstallPath -Recurse -Force

# Install dependencies if not skipped
if (!`$SkipDependencies) {
    Write-Host "🔧 Installing dependencies..." -ForegroundColor Blue
    
    # Install Python if not present
    if (!(Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "📥 Installing Python..." -ForegroundColor Yellow
        `$PythonUrl = "https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
        `$PythonInstaller = "`$env:TEMP\python-installer.exe"
        Invoke-WebRequest -Uri `$PythonUrl -OutFile `$PythonInstaller
        Start-Process -FilePath `$PythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
    }
    
    # Install Node.js if not present
    if (!(Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "📥 Installing Node.js..." -ForegroundColor Yellow
        `$NodeUrl = "https://nodejs.org/dist/v18.18.0/node-v18.18.0-x64.msi"
        `$NodeInstaller = "`$env:TEMP\node-installer.msi"
        Invoke-WebRequest -Uri `$NodeUrl -OutFile `$NodeInstaller
        Start-Process -FilePath "msiexec" -ArgumentList "/i `$NodeInstaller /quiet" -Wait
    }
    
    # Refresh environment variables
    `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Install Python packages
    Write-Host "📦 Installing Python packages..." -ForegroundColor Blue
    & python -m pip install -r "`$InstallPath\packages\core\requirements.txt"
    & python -m pip install SpeechRecognition pydub pyaudio
    
    # Install Node.js packages
    Write-Host "📦 Installing Node.js packages..." -ForegroundColor Blue
    Set-Location "`$InstallPath\apps\desktop"
    & npm install
    & npm run build
}

# Create Windows Service
Write-Host "⚙️ Creating Windows Service..." -ForegroundColor Blue
`$ServiceScript = @"
import win32serviceutil
import win32service
import win32event
import subprocess
import os
import sys

class BUDDYService(win32serviceutil.ServiceFramework):
    _svc_name_ = "BUDDYAIService"
    _svc_display_name_ = "BUDDY AI Assistant"
    _svc_description_ = "BUDDY AI Assistant Core Service"
    
    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        self.process = None
    
    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        if self.process:
            self.process.terminate()
        win32event.SetEvent(self.hWaitStop)
    
    def SvcDoRun(self):
        os.chdir(r"`$InstallPath\packages\core")
        self.process = subprocess.Popen([sys.executable, "start_buddy_simple.py"])
        win32event.WaitForSingleObject(self.hWaitStop, win32event.INFINITE)

if __name__ == '__main__':
    win32serviceutil.HandleCommandLine(BUDDYService)
"@

`$ServiceScript | Out-File -FilePath "`$InstallPath\buddy_service.py" -Encoding UTF8

# Install service
& python "`$InstallPath\buddy_service.py" install

# Configure firewall
Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Blue
netsh advfirewall firewall add rule name="BUDDY AI" dir=in action=allow protocol=TCP localport=8000

# Create shortcuts
Write-Host "🔗 Creating shortcuts..." -ForegroundColor Blue
`$WshShell = New-Object -comObject WScript.Shell
`$Shortcut = `$WshShell.CreateShortcut("`$env:Public\Desktop\BUDDY AI Assistant.lnk")
`$Shortcut.TargetPath = "`$InstallPath\BUDDY.bat"
`$Shortcut.WorkingDirectory = `$InstallPath
`$Shortcut.IconLocation = "`$InstallPath\assets\icon.ico"
`$Shortcut.Save()

# Start menu shortcut
`$StartMenuPath = "`$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
`$Shortcut = `$WshShell.CreateShortcut("`$StartMenuPath\BUDDY AI Assistant.lnk")
`$Shortcut.TargetPath = "`$InstallPath\BUDDY.bat"
`$Shortcut.WorkingDirectory = `$InstallPath
`$Shortcut.IconLocation = "`$InstallPath\assets\icon.ico"
`$Shortcut.Save()

# Cleanup
Remove-Item `$TempZip -Force
Remove-Item "`$env:TEMP\BUDDY-main" -Recurse -Force

Write-Host ""
Write-Host "✅ BUDDY AI Assistant installed successfully!" -ForegroundColor Green
Write-Host "📁 Installation location: `$InstallPath" -ForegroundColor Cyan
Write-Host "🚀 Use desktop shortcut or Start Menu to launch BUDDY" -ForegroundColor Yellow
Write-Host ""

if (!`$Silent) {
    `$Launch = Read-Host "Launch BUDDY now? (Y/N)"
    if (`$Launch -eq "Y" -or `$Launch -eq "y") {
        Start-Process "`$InstallPath\BUDDY.bat"
    }
}
"@

$PowerShellInstaller | Out-File -FilePath "installers\windows\Install-BUDDY.ps1" -Encoding UTF8

Write-Host "✅ PowerShell installer created: installers\windows\Install-BUDDY.ps1" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Windows installer package created!" -ForegroundColor Green
Write-Host "📁 Files created:" -ForegroundColor Yellow
Write-Host "  - BUDDY-Setup.iss (Inno Setup script)" -ForegroundColor White
Write-Host "  - BUDDY.bat (Application launcher)" -ForegroundColor White  
Write-Host "  - installers\windows\Install-BUDDY.ps1 (PowerShell installer)" -ForegroundColor White