# BUDDY Mobile Deployment Guide
# For Android and iOS devices

# ===========================================
# ANDROID DEPLOYMENT
# ===========================================

## Option 1: Web App (Recommended for quick deployment)
# The BUDDY core runs on your network, mobile accesses via browser

### Setup Steps:
1. **Start BUDDY Core on your main device**
   ```bash
   # On Windows
   .\scripts\deployment\setup-buddy-windows.ps1
   
   # On Linux/macOS
   chmod +x scripts/deployment/setup-buddy-unix.sh
   ./scripts/deployment/setup-buddy-unix.sh
   ```

2. **Configure network access**
   # Find your local IP address
   # Windows: ipconfig
   # Linux/macOS: ip addr show or ifconfig
   
3. **Access from mobile browser**
   # Navigate to: http://YOUR_LOCAL_IP:8000
   # Example: http://192.168.1.100:8000

4. **Add to home screen (Android)**
   - Open Chrome/Firefox
   - Navigate to BUDDY URL
   - Menu → "Add to Home screen"
   - Icon will appear on home screen

## Option 2: Native Android App (Flutter)

### Prerequisites:
- Flutter SDK 3.10+
- Android Studio
- Android SDK 33+
- Java 17+

### Build Steps:
```bash
# Navigate to mobile app directory
cd apps/mobile

# Get Flutter dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK (for distribution)
flutter build apk --release

# Install on connected device
flutter install
```

### APK Distribution:
```bash
# Copy APK for sideloading
cp build/app/outputs/flutter-apk/app-release.apk ~/buddy-mobile.apk

# Share via:
# - Email attachment
# - Cloud storage (Google Drive, Dropbox)
# - USB transfer
# - QR code generator for download link
```

### Sideloading Instructions for Users:
1. **Enable Developer Options**
   - Settings → About Phone → Tap "Build Number" 7 times
   
2. **Enable Unknown Sources**
   - Settings → Security → Enable "Unknown Sources" or "Install Unknown Apps"
   
3. **Install APK**
   - Download buddy-mobile.apk
   - Tap file → Install
   - Grant permissions when prompted

## Option 3: Google Play Store (Production)

### Preparation:
```bash
# Build signed release bundle
flutter build appbundle --release

# Generate upload key
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Sign the bundle
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore ~/upload-keystore.jks build/app/outputs/bundle/release/app-release.aab upload
```

### Play Store Submission:
1. Create Google Play Developer Account ($25 fee)
2. Upload app bundle
3. Complete store listing
4. Set pricing (free/paid)
5. Submit for review

# ===========================================
# iOS DEPLOYMENT
# ===========================================

## Option 1: Web App (Recommended)
# Same as Android Option 1 - use Safari browser

### Add to Home Screen (iOS):
1. Open Safari
2. Navigate to BUDDY URL (http://YOUR_LOCAL_IP:8000)
3. Tap Share button
4. Select "Add to Home Screen"
5. Icon appears on home screen

## Option 2: Native iOS App (Flutter)

### Prerequisites:
- macOS with Xcode 15+
- iOS SDK 16+
- Apple Developer Account
- Flutter configured for iOS

### Build Steps:
```bash
# Navigate to mobile app directory
cd apps/mobile

# Get Flutter dependencies
flutter pub get

# Build iOS app
flutter build ios --release

# Open in Xcode for signing/deployment
open ios/Runner.xcworkspace
```

### TestFlight Distribution (Beta Testing):
1. **Build Archive in Xcode**
   - Product → Archive
   - Upload to App Store Connect
   
2. **Configure TestFlight**
   - Add internal testers (up to 100)
   - Add external testers (up to 10,000)
   - Send invitations
   
3. **Testers Install**
   - Install TestFlight app
   - Accept invitation
   - Install BUDDY beta

### App Store Distribution:
1. Complete app review guidelines compliance
2. Submit for App Store review
3. Apple review process (1-7 days)
4. Release to App Store

## Option 3: Enterprise Distribution
# For organizations with Apple Developer Enterprise Program

```bash
# Build enterprise distribution
flutter build ipa --export-method enterprise

# Distribute via:
# - Internal app catalog
# - Mobile Device Management (MDM)
# - Direct download links
```

# ===========================================
# PROGRESSIVE WEB APP (PWA) SETUP
# ===========================================

## Enhanced Web App Features:

### Update BUDDY static files:
```javascript
// apps/static/manifest.json
{
  "name": "BUDDY AI Assistant",
  "short_name": "BUDDY",
  "description": "Your Personal AI Assistant",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#16213e",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png"
    },
    {
      "src": "icons/icon-144x144.png",
      "sizes": "144x144",
      "type": "image/png"
    },
    {
      "src": "icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ],
  "categories": ["productivity", "utilities"],
  "shortcuts": [
    {
      "name": "Voice Chat",
      "short_name": "Voice",
      "description": "Start voice conversation",
      "url": "/voice",
      "icons": [{"src": "icons/voice-icon.png", "sizes": "96x96"}]
    }
  ]
}
```

### Service Worker for Offline Support:
```javascript
// apps/static/sw.js
const CACHE_NAME = 'buddy-v1';
const urlsToCache = [
  '/',
  '/static/css/mobile.css',
  '/static/js/enhanced-gui.js',
  '/static/icons/icon-192x192.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});
```

# ===========================================
# MOBILE-SPECIFIC OPTIMIZATIONS
# ===========================================

## Voice Input Optimization:
```javascript
// Enhanced mobile voice interface
class MobileVoiceInterface {
  constructor() {
    this.recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
    this.setupMobileOptimizations();
  }
  
  setupMobileOptimizations() {
    // Continuous listening for mobile
    this.recognition.continuous = true;
    this.recognition.interimResults = true;
    
    // Handle mobile-specific events
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.pauseRecognition();
      } else {
        this.resumeRecognition();
      }
    });
    
    // Touch-friendly voice activation
    this.addTouchVoiceButton();
  }
  
  addTouchVoiceButton() {
    const voiceBtn = document.createElement('button');
    voiceBtn.className = 'mobile-voice-btn';
    voiceBtn.innerHTML = '🎤';
    voiceBtn.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      width: 60px;
      height: 60px;
      border-radius: 50%;
      border: none;
      background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
      color: white;
      font-size: 24px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.2);
      z-index: 1000;
    `;
    
    voiceBtn.addEventListener('touchstart', (e) => {
      e.preventDefault();
      this.startRecognition();
      voiceBtn.style.background = 'linear-gradient(45deg, #f093fb 0%, #f5576c 100%)';
    });
    
    voiceBtn.addEventListener('touchend', (e) => {
      e.preventDefault();
      this.stopRecognition();
      voiceBtn.style.background = 'linear-gradient(45deg, #667eea 0%, #764ba2 100%)';
    });
    
    document.body.appendChild(voiceBtn);
  }
}
```

## Mobile UI Optimizations:
```css
/* Enhanced mobile CSS */
@media (max-width: 768px) {
  .chat-container {
    height: calc(100vh - 120px);
    padding: 10px;
  }
  
  .message-input {
    font-size: 16px; /* Prevent zoom on iOS */
    padding: 15px;
    border-radius: 25px;
  }
  
  .voice-button {
    width: 60px;
    height: 60px;
    border-radius: 50%;
    position: fixed;
    bottom: 20px;
    right: 20px;
    background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
    border: none;
    color: white;
    font-size: 24px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.2);
    z-index: 1000;
  }
  
  /* Handle safe areas for newer phones */
  @supports (padding: max(0px)) {
    .app-container {
      padding-bottom: max(20px, env(safe-area-inset-bottom));
    }
  }
}
```

# ===========================================
# DEPLOYMENT AUTOMATION SCRIPTS
# ===========================================

## Android Deployment Script:
```bash
#!/bin/bash
# deploy-android.sh

echo "🤖 BUDDY Android Deployment"
echo "=========================="

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Build APK
echo "📱 Building Android APK..."
cd apps/mobile
flutter clean
flutter pub get
flutter build apk --release

# Create deployment package
echo "📦 Creating deployment package..."
mkdir -p ../../dist/android
cp build/app/outputs/flutter-apk/app-release.apk ../../dist/android/buddy-mobile.apk

# Generate QR code for easy download
echo "📱 Generating QR code for download..."
python3 -c "
import qrcode
import os

# Assuming you'll host the APK file
download_url = 'https://your-domain.com/buddy-mobile.apk'
qr = qrcode.QRCode(version=1, box_size=10, border=5)
qr.add_data(download_url)
qr.make(fit=True)

img = qr.make_image(fill_color='black', back_color='white')
img.save('../../dist/android/download-qr.png')
print(f'QR code saved: {os.path.abspath(\"../../dist/android/download-qr.png\")}')
"

echo "✅ Android deployment complete!"
echo "📁 Files available in: dist/android/"
echo "🔗 Share buddy-mobile.apk for sideloading"
echo "📱 Share download-qr.png for easy mobile access"
```

## iOS Deployment Script:
```bash
#!/bin/bash
# deploy-ios.sh

echo "🍎 BUDDY iOS Deployment"
echo "======================"

# Check prerequisites
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ iOS builds require macOS with Xcode."
    exit 1
fi

# Build iOS app
echo "📱 Building iOS app..."
cd apps/mobile
flutter clean
flutter pub get
flutter build ios --release

echo "🔧 Opening Xcode for signing and deployment..."
open ios/Runner.xcworkspace

echo "📋 Next steps:"
echo "1. In Xcode, select your development team"
echo "2. Archive the project (Product → Archive)"
echo "3. Distribute to TestFlight or App Store"
echo "4. Or export IPA for enterprise distribution"
```

# ===========================================
# MOBILE DEVICE CONFIGURATION
# ===========================================

## Network Configuration:
```javascript
// Mobile-optimized network detection
class MobileNetworkManager {
  constructor() {
    this.detectNetworkType();
    this.setupConnectionHandling();
  }
  
  detectNetworkType() {
    const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
    
    if (connection) {
      console.log('Network type:', connection.effectiveType);
      console.log('Downlink:', connection.downlink);
      
      // Adjust features based on connection
      if (connection.effectiveType === 'slow-2g' || connection.effectiveType === '2g') {
        this.enableLowBandwidthMode();
      }
    }
  }
  
  enableLowBandwidthMode() {
    // Reduce audio quality for slower connections
    this.audioQuality = 'low';
    // Increase timeout values
    this.requestTimeout = 30000;
    // Show connection status to user
    this.showConnectionWarning();
  }
  
  setupConnectionHandling() {
    window.addEventListener('online', () => {
      console.log('Connection restored');
      this.showConnectionStatus('online');
    });
    
    window.addEventListener('offline', () => {
      console.log('Connection lost');
      this.showConnectionStatus('offline');
    });
  }
}
```

# ===========================================
# TROUBLESHOOTING
# ===========================================

## Common Mobile Issues:

### 1. Voice Recognition Not Working:
- **iOS Safari**: Requires HTTPS or localhost
- **Android Chrome**: Check microphone permissions
- **Solution**: Use PWA with HTTPS certificate

### 2. App Not Installing (Android):
- Enable "Unknown Sources" in security settings
- Check storage space (need 100MB+ free)
- Verify APK is not corrupted

### 3. Connection Issues:
- Verify BUDDY core is running on main device
- Check firewall settings (port 8000)
- Ensure devices are on same network
- Try IP address instead of hostname

### 4. Performance Issues:
- Close other apps to free memory
- Check network connection quality
- Reduce audio quality in settings

### 5. iOS Web App Limitations:
- No background processing
- Limited offline storage
- No push notifications
- Solution: Use native app for full features

## Mobile Device Testing:
```bash
# Test on multiple devices
flutter test integration_test/app_test.dart

# Test on specific device
flutter run -d <device-id>

# Check performance
flutter run --profile
```

This comprehensive mobile deployment guide covers all major platforms and deployment methods for BUDDY on mobile devices! 📱🤖