# BUDDY Windows Installer Script
# Save as: setup-buddy-windows.ps1
# Run: powershell -ExecutionPolicy Bypass -File setup-buddy-windows.ps1

param(
    [string]$InstallPath = "$env:USERPROFILE\BUDDY",
    [switch]$SkipDependencies,
    [switch]$CreateShortcuts
)

Write-Host "🤖 BUDDY AI Assistant - Windows Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "⚠️  This script should be run as Administrator for best results." -ForegroundColor Yellow
}

# Function to check if command exists
function Test-Command($command) {
    try {
        Get-Command $command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Check Python installation
Write-Host "🔍 Checking Python installation..." -ForegroundColor Blue
if (-not (Test-Command "python")) {
    if (-not $SkipDependencies) {
        Write-Host "❌ Python not found. Installing Python..." -ForegroundColor Red
        
        # Download and install Python
        $pythonUrl = "https://www.python.org/ftp/python/3.11.6/python-3.11.6-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"
        
        Write-Host "📥 Downloading Python 3.11.6..." -ForegroundColor Blue
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
        
        Write-Host "🚀 Installing Python..." -ForegroundColor Blue
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1" -Wait
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        Remove-Item $pythonInstaller
    } else {
        Write-Host "❌ Python not found. Please install Python 3.11+ from python.org" -ForegroundColor Red
        exit 1
    }
}

# Check Node.js installation
Write-Host "🔍 Checking Node.js installation..." -ForegroundColor Blue
if (-not (Test-Command "node")) {
    if (-not $SkipDependencies) {
        Write-Host "❌ Node.js not found. Installing Node.js..." -ForegroundColor Red
        
        # Download and install Node.js
        $nodeUrl = "https://nodejs.org/dist/v18.18.0/node-v18.18.0-x64.msi"
        $nodeInstaller = "$env:TEMP\node-installer.msi"
        
        Write-Host "📥 Downloading Node.js 18.18.0..." -ForegroundColor Blue
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller
        
        Write-Host "🚀 Installing Node.js..." -ForegroundColor Blue
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $nodeInstaller, "/quiet" -Wait
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        Remove-Item $nodeInstaller
    } else {
        Write-Host "❌ Node.js not found. Please install Node.js 18+ from nodejs.org" -ForegroundColor Red
        exit 1
    }
}

# Check Git installation
Write-Host "🔍 Checking Git installation..." -ForegroundColor Blue
if (-not (Test-Command "git")) {
    if (-not $SkipDependencies) {
        Write-Host "❌ Git not found. Installing Git..." -ForegroundColor Red
        
        # Download and install Git
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
        $gitInstaller = "$env:TEMP\git-installer.exe"
        
        Write-Host "📥 Downloading Git..." -ForegroundColor Blue
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
        
        Write-Host "🚀 Installing Git..." -ForegroundColor Blue
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        Remove-Item $gitInstaller
    } else {
        Write-Host "❌ Git not found. Please install Git from git-scm.com" -ForegroundColor Red
        exit 1
    }
}

# Create installation directory
Write-Host "📁 Creating installation directory: $InstallPath" -ForegroundColor Blue
New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
Set-Location $InstallPath

# Clone BUDDY repository
Write-Host "📥 Cloning BUDDY repository..." -ForegroundColor Blue
if (Test-Path "buddy") {
    Write-Host "📁 BUDDY directory exists, updating..." -ForegroundColor Yellow
    Set-Location "buddy"
    git pull origin main
} else {
    git clone https://github.com/your-repo/buddy.git
    Set-Location "buddy"
}

# Install Python dependencies
Write-Host "📦 Installing Python dependencies..." -ForegroundColor Blue
python -m pip install --upgrade pip
python -m pip install -r packages/core/requirements.txt
python -m pip install SpeechRecognition pydub pyaudio

# Install Node.js dependencies
Write-Host "📦 Installing Node.js dependencies..." -ForegroundColor Blue
Set-Location "apps/desktop"
npm install
npm run build
Set-Location "../.."

# Create startup scripts
Write-Host "🚀 Creating startup scripts..." -ForegroundColor Blue

# Core startup script
$coreScript = @"
@echo off
title BUDDY Core
cd /d "$InstallPath\buddy\packages\core"
echo 🚀 Starting BUDDY Core...
python start_buddy_simple.py
pause
"@
$coreScript | Out-File -Encoding ASCII "$InstallPath\buddy\start-buddy-core.bat"

# Desktop app startup script
$desktopScript = @"
@echo off
title BUDDY Desktop
cd /d "$InstallPath\buddy\apps\desktop"
echo 🚀 Starting BUDDY Desktop...
npm run dev
pause
"@
$desktopScript | Out-File -Encoding ASCII "$InstallPath\buddy\start-buddy-desktop.bat"

# Combined startup script
$combinedScript = @"
@echo off
title BUDDY AI Assistant
cd /d "$InstallPath\buddy"

echo 🤖 BUDDY AI Assistant
echo ====================
echo.

echo 🚀 Starting BUDDY Core...
start /min "BUDDY Core" cmd /c "start-buddy-core.bat"

echo ⏳ Waiting for core to initialize...
timeout /t 5 /nobreak >nul

echo 🖥️  Starting BUDDY Desktop...
start /min "BUDDY Desktop" cmd /c "start-buddy-desktop.bat"

echo.
echo ✅ BUDDY is starting up!
echo 🌐 Core API will be available at: http://localhost:8000
echo 🖥️  Desktop app will be available at: http://localhost:3000
echo.
echo Press any key to open BUDDY in your browser...
pause >nul

start http://localhost:8000

echo.
echo BUDDY is now running! 
echo - Core API: http://localhost:8000
echo - Desktop App: http://localhost:3000
echo.
echo To stop BUDDY, close this window or press Ctrl+C
echo.
pause
"@
$combinedScript | Out-File -Encoding ASCII "$InstallPath\buddy\start-buddy.bat"

# Create desktop shortcuts if requested
if ($CreateShortcuts) {
    Write-Host "🔗 Creating desktop shortcuts..." -ForegroundColor Blue
    
    $WshShell = New-Object -comObject WScript.Shell
    
    # BUDDY shortcut
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\BUDDY AI Assistant.lnk")
    $Shortcut.TargetPath = "$InstallPath\buddy\start-buddy.bat"
    $Shortcut.WorkingDirectory = "$InstallPath\buddy"
    $Shortcut.Description = "BUDDY AI Assistant"
    $Shortcut.Save()
    
    # Core only shortcut
    $CoreShortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\BUDDY Core.lnk")
    $CoreShortcut.TargetPath = "$InstallPath\buddy\start-buddy-core.bat"
    $CoreShortcut.WorkingDirectory = "$InstallPath\buddy\packages\core"
    $CoreShortcut.Description = "BUDDY Core Service"
    $CoreShortcut.Save()
}

# Configure Windows Firewall
Write-Host "🔥 Configuring Windows Firewall..." -ForegroundColor Blue
try {
    netsh advfirewall firewall add rule name="BUDDY Core API" dir=in action=allow protocol=TCP localport=8000
    netsh advfirewall firewall add rule name="BUDDY Desktop" dir=in action=allow protocol=TCP localport=3000
    netsh advfirewall firewall add rule name="BUDDY Sync" dir=in action=allow protocol=TCP localport=8001
    Write-Host "✅ Firewall rules added successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not configure firewall. You may need to allow BUDDY through Windows Firewall manually." -ForegroundColor Yellow
}

# Create uninstaller
Write-Host "🗑️  Creating uninstaller..." -ForegroundColor Blue
$uninstallScript = @"
@echo off
title BUDDY Uninstaller
echo 🗑️  BUDDY AI Assistant Uninstaller
echo ===================================
echo.

echo This will remove BUDDY from your system.
set /p confirm=Are you sure? (y/N): 

if /i "%confirm%" neq "y" goto :cancel

echo.
echo 🛑 Stopping BUDDY processes...
taskkill /f /im python.exe /fi "WINDOWTITLE eq BUDDY*" 2>nul
taskkill /f /im node.exe /fi "WINDOWTITLE eq BUDDY*" 2>nul

echo 🗑️  Removing BUDDY files...
cd /d "$env:USERPROFILE"
rmdir /s /q "$InstallPath\buddy" 2>nul

echo 🔥 Removing firewall rules...
netsh advfirewall firewall delete rule name="BUDDY Core API" 2>nul
netsh advfirewall firewall delete rule name="BUDDY Desktop" 2>nul
netsh advfirewall firewall delete rule name="BUDDY Sync" 2>nul

echo 🔗 Removing shortcuts...
del "$env:USERPROFILE\Desktop\BUDDY*.lnk" 2>nul

echo.
echo ✅ BUDDY has been uninstalled successfully!
goto :end

:cancel
echo Uninstall cancelled.

:end
pause
"@
$uninstallScript | Out-File -Encoding ASCII "$InstallPath\buddy\uninstall-buddy.bat"

Write-Host ""
Write-Host "🎉 BUDDY AI Assistant installation completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📍 Installation location: $InstallPath\buddy" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 To start BUDDY:" -ForegroundColor Yellow
Write-Host "   • Double-click: start-buddy.bat" -ForegroundColor White
Write-Host "   • Or run: $InstallPath\buddy\start-buddy.bat" -ForegroundColor White
Write-Host ""
Write-Host "🌐 BUDDY will be available at:" -ForegroundColor Yellow
Write-Host "   • Core API: http://localhost:8000" -ForegroundColor White
Write-Host "   • Desktop App: http://localhost:3000" -ForegroundColor White
Write-Host ""
Write-Host "🗑️  To uninstall BUDDY:" -ForegroundColor Yellow
Write-Host "   • Run: $InstallPath\buddy\uninstall-buddy.bat" -ForegroundColor White
Write-Host ""

# Ask if user wants to start BUDDY now
$startNow = Read-Host "Start BUDDY now? (y/N)"
if ($startNow -eq "y" -or $startNow -eq "Y") {
    Write-Host "🚀 Starting BUDDY..." -ForegroundColor Green
    Start-Process -FilePath "$InstallPath\buddy\start-buddy.bat"
}

Write-Host ""
Write-Host "✅ Setup complete! Enjoy your BUDDY AI Assistant! 🤖" -ForegroundColor Green