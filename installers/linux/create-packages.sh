#!/bin/bash
# BUDDY AI Assistant - Linux Package Creator
# Creates .deb, .rpm, and AppImage packages

set -e

APP_NAME="BUDDY AI Assistant"
APP_VERSION="1.0.0"
MAINTAINER="BUDDY Team <support@buddy-ai.com>"
DESCRIPTION="Your intelligent personal AI assistant"
HOMEPAGE="https://github.com/2021WB15454/BUDDY"

echo "🤖 BUDDY Linux Package Builder"
echo "=============================="

# Create build directories
BUILD_DIR="build"
DEB_DIR="$BUILD_DIR/deb"
RPM_DIR="$BUILD_DIR/rpm"
APPIMAGE_DIR="$BUILD_DIR/appimage"

mkdir -p "$DEB_DIR" "$RPM_DIR" "$APPIMAGE_DIR"

# Function to create .deb package
create_deb_package() {
    echo "📦 Creating .deb package..."
    
    DEB_PKG_DIR="$DEB_DIR/buddy-ai_${APP_VERSION}_amd64"
    mkdir -p "$DEB_PKG_DIR/DEBIAN"
    mkdir -p "$DEB_PKG_DIR/opt/buddy"
    mkdir -p "$DEB_PKG_DIR/usr/bin"
    mkdir -p "$DEB_PKG_DIR/usr/share/applications"
    mkdir -p "$DEB_PKG_DIR/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$DEB_PKG_DIR/etc/systemd/system"
    
    # Create control file
    cat > "$DEB_PKG_DIR/DEBIAN/control" << EOF
Package: buddy-ai
Version: $APP_VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: python3 (>= 3.11), python3-pip, nodejs (>= 18), npm, portaudio19-dev, python3-pyaudio, curl, wget
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 BUDDY is an intelligent personal AI assistant that works across
 all your devices with advanced voice recognition, natural language
 processing, and cross-device synchronization capabilities.
Homepage: $HOMEPAGE
EOF

    # Create preinst script
    cat > "$DEB_PKG_DIR/DEBIAN/preinst" << 'EOF'
#!/bin/bash
# Stop existing BUDDY processes
systemctl stop buddy-ai || true
pkill -f "start_buddy_simple.py" || true
exit 0
EOF

    # Create postinst script
    cat > "$DEB_PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Create buddy user if it doesn't exist
if ! id "buddy" &>/dev/null; then
    useradd -r -s /bin/false -d /opt/buddy buddy
fi

# Set ownership and permissions
chown -R buddy:buddy /opt/buddy
chmod +x /opt/buddy/bin/buddy
chmod +x /opt/buddy/scripts/install-dependencies.sh

# Install Python dependencies
sudo -u buddy /opt/buddy/scripts/install-dependencies.sh

# Enable and start systemd service
systemctl daemon-reload
systemctl enable buddy-ai
systemctl start buddy-ai

# Configure firewall if ufw is available
if command -v ufw > /dev/null; then
    ufw allow 8000/tcp || true
fi

echo "✅ BUDDY AI Assistant installed successfully!"
echo "🌐 Access BUDDY at: http://localhost:8000"
echo "🔧 Manage service: sudo systemctl [start|stop|restart] buddy-ai"
EOF

    # Create prerm script
    cat > "$DEB_PKG_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/bash
# Stop and disable service
systemctl stop buddy-ai || true
systemctl disable buddy-ai || true
exit 0
EOF

    chmod +x "$DEB_PKG_DIR/DEBIAN/preinst"
    chmod +x "$DEB_PKG_DIR/DEBIAN/postinst"
    chmod +x "$DEB_PKG_DIR/DEBIAN/prerm"
    
    # Copy BUDDY files
    cp -r ../../* "$DEB_PKG_DIR/opt/buddy/" 2>/dev/null || true
    rm -rf "$DEB_PKG_DIR/opt/buddy/.git"
    rm -rf "$DEB_PKG_DIR/opt/buddy/installers"
    rm -rf "$DEB_PKG_DIR/opt/buddy/BUDDY"
    
    # Create startup script
    cat > "$DEB_PKG_DIR/opt/buddy/bin/buddy" << 'EOF'
#!/bin/bash
# BUDDY AI Assistant Launcher

BUDDY_HOME="/opt/buddy"
BUDDY_USER="buddy"

if [ "$EUID" -eq 0 ]; then
    # Running as root, switch to buddy user
    exec sudo -u "$BUDDY_USER" "$0" "$@"
fi

cd "$BUDDY_HOME"

case "$1" in
    start)
        echo "🚀 Starting BUDDY AI Assistant..."
        cd packages/core
        python3 start_buddy_simple.py &
        echo $! > /tmp/buddy.pid
        echo "✅ BUDDY started (PID: $(cat /tmp/buddy.pid))"
        echo "🌐 Access BUDDY at: http://localhost:8000"
        ;;
    stop)
        echo "🛑 Stopping BUDDY AI Assistant..."
        if [ -f /tmp/buddy.pid ]; then
            kill $(cat /tmp/buddy.pid) 2>/dev/null || true
            rm -f /tmp/buddy.pid
        fi
        pkill -f "start_buddy_simple.py" || true
        echo "✅ BUDDY stopped"
        ;;
    restart)
        "$0" stop
        sleep 2
        "$0" start
        ;;
    status)
        if pgrep -f "start_buddy_simple.py" > /dev/null; then
            echo "✅ BUDDY is running"
            echo "🌐 Access BUDDY at: http://localhost:8000"
        else
            echo "❌ BUDDY is not running"
        fi
        ;;
    install-deps)
        echo "📦 Installing BUDDY dependencies..."
        ./scripts/install-dependencies.sh
        ;;
    *)
        echo "Usage: buddy {start|stop|restart|status|install-deps}"
        echo ""
        echo "🤖 BUDDY AI Assistant Control Script"
        echo "=================================="
        echo ""
        echo "Commands:"
        echo "  start        Start BUDDY service"
        echo "  stop         Stop BUDDY service"
        echo "  restart      Restart BUDDY service"
        echo "  status       Check BUDDY status"
        echo "  install-deps Install/update dependencies"
        echo ""
        echo "🌐 Web Interface: http://localhost:8000"
        echo "📖 Documentation: https://github.com/2021WB15454/BUDDY"
        ;;
esac
EOF

    chmod +x "$DEB_PKG_DIR/opt/buddy/bin/buddy"
    
    # Create symlink in /usr/bin
    ln -sf "/opt/buddy/bin/buddy" "$DEB_PKG_DIR/usr/bin/buddy"
    
    # Create desktop file
    cat > "$DEB_PKG_DIR/usr/share/applications/buddy-ai.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=$DESCRIPTION
Exec=buddy start
Icon=buddy-ai
Terminal=false
Type=Application
Categories=Utility;Development;AudioVideo;
StartupNotify=true
MimeType=text/plain;
EOF

    # Create systemd service
    cat > "$DEB_PKG_DIR/etc/systemd/system/buddy-ai.service" << EOF
[Unit]
Description=$APP_NAME
After=network.target sound.target
Wants=network.target

[Service]
Type=forking
User=buddy
Group=buddy
WorkingDirectory=/opt/buddy
Environment=PYTHONPATH=/opt/buddy/packages/core
ExecStart=/opt/buddy/bin/buddy start
ExecStop=/opt/buddy/bin/buddy stop
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create dependency installation script
    mkdir -p "$DEB_PKG_DIR/opt/buddy/scripts"
    cat > "$DEB_PKG_DIR/opt/buddy/scripts/install-dependencies.sh" << 'EOF'
#!/bin/bash
# BUDDY Dependencies Installer

set -e

echo "📦 Installing BUDDY AI Assistant dependencies..."

# Create virtual environment
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install Python dependencies
if [ -f "packages/core/requirements.txt" ]; then
    pip install -r packages/core/requirements.txt
fi

# Install additional audio dependencies
pip install SpeechRecognition pydub pyaudio || {
    echo "⚠️ Some audio dependencies failed to install. Audio features may be limited."
}

# Install Node.js dependencies for desktop app
if [ -d "apps/desktop" ] && command -v npm > /dev/null; then
    echo "📦 Installing desktop app dependencies..."
    cd apps/desktop
    npm install --production
    npm run build || echo "⚠️ Desktop app build failed"
    cd ../..
fi

echo "✅ Dependencies installed successfully!"
EOF

    chmod +x "$DEB_PKG_DIR/opt/buddy/scripts/install-dependencies.sh"
    
    # Copy icon if available
    if [ -f "../../assets/icon.png" ]; then
        cp "../../assets/icon.png" "$DEB_PKG_DIR/usr/share/icons/hicolor/256x256/apps/buddy-ai.png"
    fi
    
    # Build .deb package
    dpkg-deb --build "$DEB_PKG_DIR"
    mv "$DEB_PKG_DIR.deb" "$BUILD_DIR/buddy-ai_${APP_VERSION}_amd64.deb"
    
    echo "✅ .deb package created: $BUILD_DIR/buddy-ai_${APP_VERSION}_amd64.deb"
}

# Function to create .rpm package
create_rpm_package() {
    echo "📦 Creating .rpm package..."
    
    # Create RPM build directories
    mkdir -p "$RPM_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Create spec file
    cat > "$RPM_DIR/SPECS/buddy-ai.spec" << EOF
Name:           buddy-ai
Version:        $APP_VERSION
Release:        1%{?dist}
Summary:        $DESCRIPTION
License:        MIT
URL:            $HOMEPAGE
Source0:        %{name}-%{version}.tar.gz
BuildArch:      x86_64

BuildRequires:  python3 >= 3.11, nodejs >= 18, npm
Requires:       python3 >= 3.11, python3-pip, nodejs >= 18, npm, portaudio-devel, curl, wget

%description
BUDDY is an intelligent personal AI assistant that works across
all your devices with advanced voice recognition, natural language
processing, and cross-device synchronization capabilities.

%prep
%setup -q

%build
# No build needed for Python/Node.js app

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/buddy
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
mkdir -p %{buildroot}/etc/systemd/system

# Copy BUDDY files
cp -r * %{buildroot}/opt/buddy/

# Create startup script
cat > %{buildroot}/opt/buddy/bin/buddy << 'EOFSCRIPT'
#!/bin/bash
# BUDDY AI Assistant Launcher - RPM Version

BUDDY_HOME="/opt/buddy"
BUDDY_USER="buddy"

if [ "\$EUID" -eq 0 ]; then
    exec sudo -u "\$BUDDY_USER" "\$0" "\$@"
fi

cd "\$BUDDY_HOME"

case "\$1" in
    start)
        echo "🚀 Starting BUDDY AI Assistant..."
        cd packages/core
        python3 start_buddy_simple.py &
        echo \$! > /tmp/buddy.pid
        echo "✅ BUDDY started"
        ;;
    stop)
        echo "🛑 Stopping BUDDY AI Assistant..."
        if [ -f /tmp/buddy.pid ]; then
            kill \$(cat /tmp/buddy.pid) 2>/dev/null || true
            rm -f /tmp/buddy.pid
        fi
        pkill -f "start_buddy_simple.py" || true
        ;;
    *)
        echo "Usage: buddy {start|stop|restart|status}"
        ;;
esac
EOFSCRIPT

chmod +x %{buildroot}/opt/buddy/bin/buddy

# Create symlink
ln -sf /opt/buddy/bin/buddy %{buildroot}/usr/bin/buddy

# Create desktop file
cat > %{buildroot}/usr/share/applications/buddy-ai.desktop << 'EOFDESKTOP'
[Desktop Entry]
Name=BUDDY AI Assistant
Comment=Your intelligent personal AI assistant
Exec=buddy start
Icon=buddy-ai
Terminal=false
Type=Application
Categories=Utility;Development;
EOFDESKTOP

# Create systemd service
cat > %{buildroot}/etc/systemd/system/buddy-ai.service << 'EOFSERVICE'
[Unit]
Description=BUDDY AI Assistant
After=network.target

[Service]
Type=forking
User=buddy
Group=buddy
WorkingDirectory=/opt/buddy
ExecStart=/opt/buddy/bin/buddy start
ExecStop=/opt/buddy/bin/buddy stop
Restart=always

[Install]
WantedBy=multi-user.target
EOFSERVICE

%files
/opt/buddy
/usr/bin/buddy
/usr/share/applications/buddy-ai.desktop
/etc/systemd/system/buddy-ai.service

%pre
# Create buddy user
if ! id "buddy" &>/dev/null; then
    useradd -r -s /bin/false -d /opt/buddy buddy
fi

%post
# Set permissions
chown -R buddy:buddy /opt/buddy
chmod +x /opt/buddy/bin/buddy

# Install dependencies
sudo -u buddy /opt/buddy/scripts/install-dependencies.sh || true

# Enable service
systemctl daemon-reload
systemctl enable buddy-ai

%preun
systemctl stop buddy-ai || true
systemctl disable buddy-ai || true

%changelog
* $(date +'%a %b %d %Y') BUDDY Team <support@buddy-ai.com> - $APP_VERSION-1
- Initial RPM package
EOF

    # Create source tarball
    tar -czf "$RPM_DIR/SOURCES/buddy-ai-$APP_VERSION.tar.gz" -C ../.. --exclude='.git' --exclude='installers' --exclude='BUDDY' .
    
    # Build RPM
    rpmbuild --define "_topdir $(pwd)/$RPM_DIR" -ba "$RPM_DIR/SPECS/buddy-ai.spec"
    
    # Copy built RPM
    cp "$RPM_DIR/RPMS/x86_64/buddy-ai-$APP_VERSION-1."*.rpm "$BUILD_DIR/"
    
    echo "✅ .rpm package created in $BUILD_DIR/"
}

# Function to create AppImage
create_appimage() {
    echo "📦 Creating AppImage..."
    
    APPDIR="$APPIMAGE_DIR/BUDDY.AppDir"
    mkdir -p "$APPDIR"
    
    # Create AppImage structure
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/lib"
    mkdir -p "$APPDIR/usr/share/buddy"
    
    # Copy BUDDY files
    cp -r ../../* "$APPDIR/usr/share/buddy/" 2>/dev/null || true
    rm -rf "$APPDIR/usr/share/buddy/.git"
    rm -rf "$APPDIR/usr/share/buddy/installers"
    rm -rf "$APPDIR/usr/share/buddy/BUDDY"
    
    # Create AppRun script
    cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
# BUDDY AI Assistant AppImage Launcher

HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"

cd "${HERE}/usr/share/buddy"

# Check for Python
if ! command -v python3 > /dev/null; then
    zenity --error --text="Python 3.11+ is required to run BUDDY. Please install it first."
    exit 1
fi

# Check for Node.js
if ! command -v node > /dev/null; then
    zenity --error --text="Node.js 18+ is required to run BUDDY. Please install it first."
    exit 1
fi

# Create virtual environment if needed
if [ ! -d "venv" ]; then
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r packages/core/requirements.txt
    pip install SpeechRecognition pydub pyaudio || true
else
    source venv/bin/activate
fi

# Install Node.js dependencies if needed
if [ ! -d "apps/desktop/node_modules" ]; then
    cd apps/desktop
    npm install --production
    npm run build || true
    cd ../..
fi

# Start BUDDY
cd packages/core
python3 start_buddy_simple.py &
BUDDY_PID=$!

# Wait and open browser
sleep 3
xdg-open http://localhost:8000 || true

# Show notification
notify-send "BUDDY AI Assistant" "BUDDY is now running at http://localhost:8000" || true

# Keep running
wait $BUDDY_PID
EOF

    chmod +x "$APPDIR/AppRun"
    
    # Create .desktop file
    cat > "$APPDIR/buddy-ai.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=$DESCRIPTION
Exec=AppRun
Icon=buddy-ai
Type=Application
Categories=Utility;Development;
Terminal=false
EOF

    # Copy icon
    if [ -f "../../assets/icon.png" ]; then
        cp "../../assets/icon.png" "$APPDIR/buddy-ai.png"
    else
        # Create a simple icon
        echo "Creating placeholder icon..."
        convert -size 256x256 xc:blue -fill white -gravity center -pointsize 72 -annotate 0 "🤖" "$APPDIR/buddy-ai.png" 2>/dev/null || {
            # Fallback: create a simple text file as icon
            echo "BUDDY" > "$APPDIR/buddy-ai.png"
        }
    fi
    
    # Download and use appimagetool
    if [ ! -f "appimagetool-x86_64.AppImage" ]; then
        echo "📥 Downloading appimagetool..."
        wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x appimagetool-x86_64.AppImage
    fi
    
    # Build AppImage
    ./appimagetool-x86_64.AppImage "$APPDIR" "$BUILD_DIR/BUDDY-$APP_VERSION-x86_64.AppImage"
    
    echo "✅ AppImage created: $BUILD_DIR/BUDDY-$APP_VERSION-x86_64.AppImage"
}

# Main execution
echo "Select package type to build:"
echo "1) .deb (Debian/Ubuntu)"
echo "2) .rpm (RedHat/CentOS/Fedora)"
echo "3) AppImage (Universal Linux)"
echo "4) All packages"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        create_deb_package
        ;;
    2)
        create_rpm_package
        ;;
    3)
        create_appimage
        ;;
    4)
        create_deb_package
        create_rpm_package
        create_appimage
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Linux package creation complete!"
echo "📁 Output directory: $BUILD_DIR/"
echo ""
echo "📋 Installation instructions:"
echo "  .deb: sudo dpkg -i buddy-ai_${APP_VERSION}_amd64.deb"
echo "  .rpm: sudo rpm -i buddy-ai-${APP_VERSION}-1.*.rpm"
echo "  AppImage: chmod +x BUDDY-${APP_VERSION}-x86_64.AppImage && ./BUDDY-${APP_VERSION}-x86_64.AppImage"