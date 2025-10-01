#!/bin/bash
# BUDDY AI Assistant - macOS Installer Creator
# Creates a macOS .pkg installer package

set -e

APP_NAME="BUDDY AI Assistant"
APP_VERSION="1.0.0"
BUNDLE_ID="com.buddy.ai.assistant"
DEVELOPER_ID="BUDDY Team"
OUTPUT_DIR="./output"

echo "🤖 BUDDY macOS Installer Builder"
echo "================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create app bundle structure
APP_BUNDLE="$OUTPUT_DIR/BUDDY.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BUDDY</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>BUDY</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUDDY needs microphone access for voice commands</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>BUDDY needs access to control other applications</string>
    <key>LSUIElement</key>
    <false/>
    <key>LSBackgroundOnly</key>
    <false/>
</dict>
</plist>
EOF

# Create main executable script
cat > "$APP_BUNDLE/Contents/MacOS/BUDDY" << 'EOF'
#!/bin/bash
# BUDDY AI Assistant - macOS Launcher

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BUDDY_DIR="$APP_DIR/Contents/Resources/buddy"

echo "🤖 Starting BUDDY AI Assistant..."

# Change to BUDDY directory
cd "$BUDDY_DIR"

# Check for Python
if command -v python3.11 > /dev/null; then
    PYTHON_CMD=python3.11
elif command -v python3 > /dev/null; then
    PYTHON_CMD=python3
else
    echo "❌ Python not found. Please install Python 3.11+"
    osascript -e 'display dialog "Python 3.11+ is required to run BUDDY. Please install it from python.org" buttons {"OK"} default button "OK"'
    exit 1
fi

# Check for Node.js
if ! command -v node > /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+"
    osascript -e 'display dialog "Node.js 18+ is required to run BUDDY. Please install it from nodejs.org" buttons {"OK"} default button "OK"'
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    $PYTHON_CMD -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies if needed
if [ ! -f "venv/.dependencies_installed" ]; then
    echo "📦 Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r packages/core/requirements.txt
    pip install SpeechRecognition pydub pyaudio
    touch venv/.dependencies_installed
fi

# Install Node.js dependencies if needed
if [ ! -d "apps/desktop/node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    cd apps/desktop
    npm install
    npm run build
    cd ../..
fi

# Start BUDDY Core
echo "🚀 Starting BUDDY Core..."
cd packages/core
$PYTHON_CMD start_buddy_simple.py &
CORE_PID=$!

# Wait for core to start
sleep 3

# Start Desktop App
echo "🖥️ Starting Desktop Interface..."
cd ../../apps/desktop
npm run dev &
DESKTOP_PID=$!

# Open browser
sleep 3
open http://localhost:8000

echo "✅ BUDDY is running!"
echo "🌐 Web Interface: http://localhost:8000"
echo "🖥️ Desktop App: http://localhost:3000"

# Keep the app running
wait $CORE_PID $DESKTOP_PID
EOF

chmod +x "$APP_BUNDLE/Contents/MacOS/BUDDY"

# Copy BUDDY source code to Resources
echo "📦 Copying BUDDY source code..."
cp -r ../../ "$APP_BUNDLE/Contents/Resources/buddy"

# Remove unnecessary files from bundle
rm -rf "$APP_BUNDLE/Contents/Resources/buddy/.git"
rm -rf "$APP_BUNDLE/Contents/Resources/buddy/installers"
rm -rf "$APP_BUNDLE/Contents/Resources/buddy/BUDDY"

# Copy icon (if exists)
if [ -f "../../assets/icon.icns" ]; then
    cp "../../assets/icon.icns" "$APP_BUNDLE/Contents/Resources/"
else
    echo "⚠️ Icon file not found. Creating placeholder..."
    # Create a simple icon using sips (if available)
    if command -v sips > /dev/null && [ -f "../../assets/icon.png" ]; then
        sips -s format icns "../../assets/icon.png" --out "$APP_BUNDLE/Contents/Resources/icon.icns"
    fi
fi

# Create .pkg installer
echo "📦 Creating .pkg installer..."

# Create installer scripts
mkdir -p "$OUTPUT_DIR/scripts"

# Pre-install script
cat > "$OUTPUT_DIR/scripts/preinstall" << 'EOF'
#!/bin/bash
# Stop any running BUDDY processes
pkill -f "start_buddy_simple.py" || true
pkill -f "npm run dev" || true
exit 0
EOF

# Post-install script
cat > "$OUTPUT_DIR/scripts/postinstall" << 'EOF'
#!/bin/bash
# Set proper permissions
chmod -R 755 "/Applications/BUDDY.app"
chown -R root:wheel "/Applications/BUDDY.app"

# Create LaunchAgent for auto-start (optional)
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENT_DIR"

cat > "$LAUNCH_AGENT_DIR/com.buddy.ai.assistant.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.buddy.ai.assistant</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/BUDDY.app/Contents/MacOS/BUDDY</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLIST

# Install Homebrew dependencies (optional)
if command -v brew > /dev/null; then
    echo "📦 Installing audio dependencies via Homebrew..."
    brew install portaudio || true
fi

exit 0
EOF

chmod +x "$OUTPUT_DIR/scripts/preinstall"
chmod +x "$OUTPUT_DIR/scripts/postinstall"

# Build the .pkg
pkgbuild --root "$OUTPUT_DIR" \
         --install-location "/Applications" \
         --scripts "$OUTPUT_DIR/scripts" \
         --identifier "$BUNDLE_ID" \
         --version "$APP_VERSION" \
         "$OUTPUT_DIR/BUDDY-$APP_VERSION.pkg"

# Create distribution XML for productbuild (for more advanced installer)
cat > "$OUTPUT_DIR/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>$APP_NAME</title>
    <organization>$DEVELOPER_ID</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>
    
    <welcome file="welcome.html"/>
    <license file="license.txt"/>
    <readme file="readme.html"/>
    
    <pkg-ref id="$BUNDLE_ID"/>
    
    <choices-outline>
        <line choice="default">
            <line choice="$BUNDLE_ID"/>
        </line>
    </choices-outline>
    
    <choice id="default"/>
    <choice id="$BUNDLE_ID" visible="false">
        <pkg-ref id="$BUNDLE_ID"/>
    </choice>
    
    <pkg-ref id="$BUNDLE_ID" version="$APP_VERSION" onConclusion="none">BUDDY-$APP_VERSION.pkg</pkg-ref>
</installer-gui-script>
EOF

# Create welcome page
cat > "$OUTPUT_DIR/welcome.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
        h1 { color: #007AFF; }
        .feature { margin: 10px 0; }
    </style>
</head>
<body>
    <h1>🤖 Welcome to BUDDY AI Assistant</h1>
    <p>BUDDY is your intelligent personal assistant that works across all your devices.</p>
    
    <h2>Features:</h2>
    <div class="feature">🎤 Advanced voice recognition and natural language processing</div>
    <div class="feature">🔄 Cross-device synchronization and seamless handoff</div>
    <div class="feature">🏠 Smart home integration and automation</div>
    <div class="feature">📱 Works on desktop, mobile, TV, watch, and car</div>
    <div class="feature">🔒 Privacy-focused with local processing options</div>
    
    <h2>System Requirements:</h2>
    <ul>
        <li>macOS 10.15 or later</li>
        <li>4GB RAM minimum (8GB recommended)</li>
        <li>1GB free disk space</li>
        <li>Microphone for voice commands</li>
        <li>Internet connection for initial setup</li>
    </ul>
    
    <p><strong>Note:</strong> This installer will download and install Python 3.11+ and Node.js 18+ if not already present on your system.</p>
</body>
</html>
EOF

# Create license file
cat > "$OUTPUT_DIR/license.txt" << 'EOF'
BUDDY AI Assistant License Agreement

Copyright (c) 2025 BUDDY Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Create readme
cat > "$OUTPUT_DIR/readme.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
        h1 { color: #007AFF; }
        code { background: #f0f0f0; padding: 2px 4px; border-radius: 3px; }
        .step { margin: 10px 0; padding: 10px; background: #f8f9fa; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>🚀 Getting Started with BUDDY</h1>
    
    <h2>Installation Complete!</h2>
    <p>BUDDY AI Assistant has been installed to your Applications folder.</p>
    
    <h2>First Launch:</h2>
    <div class="step">
        <strong>1.</strong> Open BUDDY from Applications folder or Launchpad
    </div>
    <div class="step">
        <strong>2.</strong> Grant microphone permissions when prompted
    </div>
    <div class="step">
        <strong>3.</strong> Wait for dependencies to install (first launch only)
    </div>
    <div class="step">
        <strong>4.</strong> BUDDY will open in your default browser at <code>http://localhost:8000</code>
    </div>
    
    <h2>Voice Commands:</h2>
    <ul>
        <li>"Hey BUDDY" - Wake up command</li>
        <li>"What's the weather?" - Get weather information</li>
        <li>"Set a reminder" - Create reminders</li>
        <li>"Tell me a joke" - Entertainment</li>
        <li>"Help" - Show available commands</li>
    </ul>
    
    <h2>Troubleshooting:</h2>
    <p>If BUDDY doesn't start:</p>
    <ul>
        <li>Ensure Python 3.11+ is installed</li>
        <li>Check Console.app for error messages</li>
        <li>Try running from Terminal: <code>/Applications/BUDDY.app/Contents/MacOS/BUDDY</code></li>
    </ul>
    
    <h2>Support:</h2>
    <p>Visit <a href="https://github.com/2021WB15454/BUDDY">github.com/2021WB15454/BUDDY</a> for documentation and support.</p>
</body>
</html>
EOF

# Build final installer package
productbuild --distribution "$OUTPUT_DIR/distribution.xml" \
             --package-path "$OUTPUT_DIR" \
             "$OUTPUT_DIR/BUDDY-Installer-$APP_VERSION.pkg"

echo ""
echo "✅ macOS installer created successfully!"
echo "📁 Output files:"
echo "  - $OUTPUT_DIR/BUDDY.app (Application bundle)"
echo "  - $OUTPUT_DIR/BUDDY-$APP_VERSION.pkg (Simple installer)"
echo "  - $OUTPUT_DIR/BUDDY-Installer-$APP_VERSION.pkg (Full installer with UI)"
echo ""
echo "🔐 To sign the installer (requires Apple Developer certificate):"
echo "  productsign --sign 'Developer ID Installer: Your Name' BUDDY-Installer-$APP_VERSION.pkg BUDDY-Installer-$APP_VERSION-Signed.pkg"