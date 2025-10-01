# 🚀 BUDDY Cross-Platform Deployment Guide

Deploy your BUDDY AI assistant across all your devices with this comprehensive installation guide.

## 📋 Table of Contents

1. [System Requirements](#system-requirements)
2. [Desktop Installation](#desktop-installation)
3. [Mobile Installation](#mobile-installation)
4. [Smart TV Installation](#smart-tv-installation)
5. [Smartwatch Installation](#smartwatch-installation)
6. [Car Integration](#car-integration)
7. [Home Hub Setup](#home-hub-setup)
8. [Network Configuration](#network-configuration)
9. [Cross-Device Sync](#cross-device-sync)
10. [Troubleshooting](#troubleshooting)

---

## 🖥️ System Requirements

### Minimum Hardware Requirements
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 1GB free space for base installation
- **Network**: WiFi or Ethernet connection
- **Audio**: Microphone and speakers/headphones

### Software Requirements
- **Python**: 3.11 or higher
- **Node.js**: 18+ (for desktop app)
- **Flutter**: 3.16+ (for mobile)
- **Docker**: Latest (for containerized deployment)

---

## 💻 Desktop Installation

### Windows 10/11

```powershell
# 1. Install Python 3.11+
# Download from https://python.org or use Microsoft Store

# 2. Install Node.js 18+
# Download from https://nodejs.org

# 3. Clone BUDDY repository
git clone https://github.com/your-repo/buddy.git
cd buddy

# 4. Install dependencies
pip install -r packages/core/requirements.txt
pip install SpeechRecognition pydub

# 5. Build desktop app
cd apps/desktop
npm install
npm run build

# 6. Start BUDDY Core
cd ../../packages/core
python start_buddy_simple.py

# 7. Launch Desktop App
cd ../../apps/desktop
npm run dev
```

### macOS

```bash
# 1. Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install dependencies
brew install python@3.11 node@18 git

# 3. Clone and setup BUDDY
git clone https://github.com/your-repo/buddy.git
cd buddy

# 4. Install Python dependencies
python3.11 -m pip install -r packages/core/requirements.txt
python3.11 -m pip install SpeechRecognition pydub

# 5. Install audio dependencies
brew install portaudio
pip install pyaudio

# 6. Build and run
cd apps/desktop && npm install && npm run build
cd ../../packages/core && python3.11 start_buddy_simple.py
```

### Linux (Ubuntu/Debian)

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install dependencies
sudo apt install python3.11 python3.11-pip nodejs npm git portaudio19-dev python3-pyaudio

# 3. Clone BUDDY
git clone https://github.com/your-repo/buddy.git
cd buddy

# 4. Install Python dependencies
pip3.11 install -r packages/core/requirements.txt
pip3.11 install SpeechRecognition pydub pyaudio

# 5. Build desktop app
cd apps/desktop
npm install && npm run build

# 6. Start BUDDY
cd ../../packages/core
python3.11 start_buddy_simple.py

# 7. Create desktop shortcut
cat > ~/.local/share/applications/buddy.desktop << EOF
[Desktop Entry]
Name=BUDDY AI Assistant
Comment=Your Personal AI Assistant
Exec=/path/to/buddy/start_buddy.sh
Icon=/path/to/buddy/assets/icon.png
Terminal=false
Type=Application
Categories=Utility;
EOF
```

---

## 📱 Mobile Installation

### Android

#### Option 1: Build from Source
```bash
# 1. Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# 2. Install Android Studio and SDK
# Download from https://developer.android.com/studio

# 3. Build BUDDY mobile app
cd buddy/apps/mobile
flutter doctor  # Check setup
flutter build apk --release

# 4. Install APK
flutter install
```

#### Option 2: Direct APK Installation
```bash
# 1. Download BUDDY APK from releases
wget https://github.com/your-repo/buddy/releases/latest/buddy-android.apk

# 2. Enable "Unknown Sources" in Android Settings
# Settings → Security → Unknown Sources

# 3. Install APK
adb install buddy-android.apk
# OR transfer to device and tap to install
```

### iOS

#### Prerequisites
- macOS with Xcode 14+
- Apple Developer Account (for device installation)

```bash
# 1. Install Flutter for iOS
flutter doctor --android-licenses
flutter doctor

# 2. Build iOS app
cd buddy/apps/mobile
flutter build ios --release

# 3. Open in Xcode and deploy
open ios/Runner.xcworkspace
# Build and run to device through Xcode
```

---

## 📺 Smart TV Installation

### Android TV

```bash
# 1. Enable Developer Options on Android TV
# Settings → About → Build Number (click 7 times)

# 2. Enable ADB Debugging
# Settings → Developer Options → USB Debugging

# 3. Connect via ADB
adb connect YOUR_TV_IP:5555

# 4. Install BUDDY TV APK
adb install buddy-tv.apk

# 5. Configure TV-specific settings
adb shell am start -n com.buddy.tv/.MainActivity
```

### Apple TV (tvOS)

```bash
# 1. Build tvOS app (requires macOS + Xcode)
cd buddy/apps/tv
xcodebuild -workspace BuddyTV.xcworkspace -scheme BuddyTV -destination 'platform=tvOS,name=Apple TV'

# 2. Install via Xcode or TestFlight
# Use Apple Configurator or Xcode for installation
```

### Samsung Tizen TV

```bash
# 1. Install Tizen Studio
# Download from https://developer.samsung.com/tizen

# 2. Build Tizen app
cd buddy/apps/tv/tizen
tizen build-web

# 3. Install on TV
tizen install -n buddy-tv.wgt -t YOUR_TV_ID
```

---

## ⌚ Smartwatch Installation

### Wear OS (Android Watches)

```bash
# 1. Enable Developer Options on watch
# Settings → About → Build Number (tap 7 times)

# 2. Enable ADB Debugging
# Settings → Developer Options → ADB Debugging

# 3. Connect watch via Bluetooth debugging
adb forward tcp:4444 localabstract:/adb-hub
adb connect 127.0.0.1:4444

# 4. Install BUDDY watch app
adb install buddy-wear.apk
```

### Apple Watch (watchOS)

```bash
# 1. Build watchOS app (requires Xcode)
cd buddy/apps/watch
xcodebuild -workspace BuddyWatch.xcworkspace -scheme BuddyWatch

# 2. Install via iPhone (paired watch required)
# App automatically installs when iPhone app is installed
```

---

## 🚗 Car Integration

### Android Auto

```bash
# 1. Install BUDDY mobile app with Android Auto support
# (Built into main Android app)

# 2. Enable Developer Mode in Android Auto
# Settings → About → Tap version 10 times

# 3. Enable Unknown Sources
# Developer Settings → Unknown Sources

# 4. Connect phone to car via USB or wireless
# BUDDY will appear in Android Auto interface
```

### Apple CarPlay

```bash
# 1. Install BUDDY iOS app with CarPlay support
# (Built into main iOS app)

# 2. Connect iPhone to car
# Via USB or wireless CarPlay

# 3. BUDDY appears in CarPlay interface
# Voice commands available through car's microphone
```

---

## 🏠 Home Hub Setup

### Raspberry Pi Hub

```bash
# 1. Install Raspberry Pi OS Lite
# Flash to SD card with Raspberry Pi Imager

# 2. SSH into Pi
ssh pi@raspberrypi.local

# 3. Update system
sudo apt update && sudo apt upgrade -y

# 4. Install dependencies
sudo apt install python3.11 python3.11-pip git docker.io portaudio19-dev

# 5. Clone BUDDY
git clone https://github.com/your-repo/buddy.git
cd buddy

# 6. Install BUDDY
pip3.11 install -r packages/core/requirements.txt
pip3.11 install SpeechRecognition pydub pyaudio

# 7. Configure as hub
sudo systemctl enable docker
sudo usermod -aG docker pi

# 8. Start BUDDY hub service
sudo cp scripts/buddy-hub.service /etc/systemd/system/
sudo systemctl enable buddy-hub
sudo systemctl start buddy-hub
```

### Docker Deployment

```bash
# 1. Create Docker Compose file
cat > docker-compose.yml << EOF
version: '3.8'
services:
  buddy-core:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - buddy-data:/app/data
      - /dev/snd:/dev/snd  # Audio devices
    devices:
      - /dev/snd  # Audio access
    environment:
      - BUDDY_HOST=0.0.0.0
      - BUDDY_PORT=8000
    restart: unless-stopped

volumes:
  buddy-data:
EOF

# 2. Build and start
docker-compose up -d

# 3. Check status
docker-compose logs -f buddy-core
```

---

## 🌐 Network Configuration

### Local Network Setup

```bash
# 1. Configure BUDDY Core as central hub
# Edit packages/core/buddy/config.py

BUDDY_CONFIG = {
    'host': '0.0.0.0',  # Listen on all interfaces
    'port': 8000,
    'enable_discovery': True,
    'sync_enabled': True,
    'cross_device_sync': True
}

# 2. Configure firewall (if needed)
# Windows
netsh advfirewall firewall add rule name="BUDDY" dir=in action=allow protocol=TCP localport=8000

# macOS
sudo pfctl -f /etc/pf.conf

# Linux
sudo ufw allow 8000/tcp
```

### Device Discovery

```python
# BUDDY automatically discovers devices on local network
# Configure discovery settings in config.py

DISCOVERY_CONFIG = {
    'enabled': True,
    'broadcast_interval': 30,  # seconds
    'discovery_port': 8001,
    'encryption': True
}
```

---

## 🔄 Cross-Device Sync

### Initial Setup

```bash
# 1. Start BUDDY on primary device (usually desktop/hub)
python start_buddy_simple.py

# 2. Note the sync credentials shown in logs
# Example: Device ID: ABC123, Sync Key: XYZ789

# 3. On secondary devices, enter sync credentials
# Mobile app: Settings → Sync → Add Device
# Desktop app: Settings → Devices → Pair Device
```

### Sync Configuration

```python
# Configure sync in packages/core/buddy/sync.py

SYNC_CONFIG = {
    'enabled': True,
    'encryption': 'AES-256',
    'sync_interval': 60,  # seconds
    'conflict_resolution': 'timestamp',  # or 'user_prompt'
    'sync_data': [
        'conversations',
        'preferences', 
        'skills',
        'reminders'
    ]
}
```

---

## 🎯 Quick Setup Scripts

### All-in-One Desktop Setup (Windows)

```powershell
# Save as setup-buddy-windows.ps1
# Run: powershell -ExecutionPolicy Bypass -File setup-buddy-windows.ps1

Write-Host "🤖 Setting up BUDDY on Windows..." -ForegroundColor Green

# Check Python
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python not found. Please install Python 3.11+ from python.org" -ForegroundColor Red
    exit 1
}

# Clone repository
Write-Host "📥 Cloning BUDDY repository..." -ForegroundColor Blue
git clone https://github.com/your-repo/buddy.git
cd buddy

# Install dependencies
Write-Host "📦 Installing Python dependencies..." -ForegroundColor Blue
pip install -r packages/core/requirements.txt
pip install SpeechRecognition pydub

# Install Node.js dependencies
Write-Host "📦 Installing Node.js dependencies..." -ForegroundColor Blue
cd apps/desktop
npm install
npm run build

# Create startup script
Write-Host "🚀 Creating startup script..." -ForegroundColor Blue
$startScript = @"
@echo off
cd /d "%~dp0"
start /min cmd /c "cd packages\core && python start_buddy_simple.py"
timeout /t 3
start /min cmd /c "cd apps\desktop && npm run dev"
echo BUDDY is starting... Check http://localhost:8000
pause
"@

$startScript | Out-File -Encoding ASCII "start-buddy.bat"

Write-Host "✅ BUDDY setup complete!" -ForegroundColor Green
Write-Host "🚀 Run start-buddy.bat to launch BUDDY" -ForegroundColor Yellow
```

### All-in-One Linux Setup

```bash
#!/bin/bash
# Save as setup-buddy-linux.sh
# Run: chmod +x setup-buddy-linux.sh && ./setup-buddy-linux.sh

echo "🤖 Setting up BUDDY on Linux..."

# Install dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y python3.11 python3.11-pip nodejs npm git portaudio19-dev python3-pyaudio

# Clone repository
echo "📥 Cloning BUDDY repository..."
git clone https://github.com/your-repo/buddy.git
cd buddy

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3.11 install -r packages/core/requirements.txt
pip3.11 install SpeechRecognition pydub pyaudio

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
cd apps/desktop
npm install && npm run build
cd ../..

# Create startup script
echo "🚀 Creating startup script..."
cat > start-buddy.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting BUDDY Core..."
cd packages/core
python3.11 start_buddy_simple.py &
CORE_PID=$!

sleep 3
echo "🚀 Starting BUDDY Desktop..."
cd ../../apps/desktop
npm run dev &
DESKTOP_PID=$!

echo "✅ BUDDY is running!"
echo "🌐 Core API: http://localhost:8000"
echo "🖥️  Desktop App: http://localhost:3000"
echo "Press Ctrl+C to stop"

trap 'kill $CORE_PID $DESKTOP_PID' EXIT
wait
EOF

chmod +x start-buddy.sh

echo "✅ BUDDY setup complete!"
echo "🚀 Run ./start-buddy.sh to launch BUDDY"
```

---

## 🔧 Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Kill process on port 8000
# Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Linux/macOS
lsof -ti:8000 | xargs kill -9
```

#### Audio Issues
```bash
# Install audio dependencies
# Windows: Install Microsoft Visual C++ Redistributable
# macOS: brew install portaudio
# Linux: sudo apt install portaudio19-dev python3-pyaudio
```

#### Permission Errors
```bash
# Run with appropriate permissions
# Windows: Run as Administrator
# Linux/macOS: Check file permissions
chmod +x scripts/*
```

### Device-Specific Issues

#### Android TV: App Not Installing
```bash
# Enable ADB debugging
adb shell pm list packages | grep buddy
adb uninstall com.buddy.tv  # Remove old version
adb install -r buddy-tv.apk  # Force reinstall
```

#### iOS: Developer Certificate Issues
```bash
# Update certificates in Xcode
# Product → Archive → Distribute App → App Store Connect
```

#### Raspberry Pi: Audio Not Working
```bash
# Configure audio output
sudo raspi-config
# Advanced Options → Audio → Force 3.5mm jack

# Test audio
speaker-test -t wav -c 2
```

---

## 📞 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-repo/buddy/issues)
- **Community**: [Discord Server](https://discord.gg/buddy)
- **Email**: support@buddy-ai.com

---

## 🔄 Auto-Update

BUDDY includes automatic update capabilities:

```python
# Enable auto-updates in config.py
AUTO_UPDATE_CONFIG = {
    'enabled': True,
    'check_interval': 86400,  # 24 hours
    'auto_install': False,    # Prompt user
    'beta_channel': False
}
```

---

*Happy deploying! 🚀 Your BUDDY AI assistant will be available across all your devices.*