#!/bin/bash
# BUDDY Linux/macOS Installer Script
# Save as: setup-buddy-unix.sh
# Run: chmod +x setup-buddy-unix.sh && ./setup-buddy-unix.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default installation path
INSTALL_PATH="$HOME/BUDDY"
SKIP_DEPS=false
CREATE_SHORTCUTS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --skip-dependencies)
            SKIP_DEPS=true
            shift
            ;;
        --create-shortcuts)
            CREATE_SHORTCUTS=true
            shift
            ;;
        -h|--help)
            echo "BUDDY AI Assistant Installer"
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --install-path PATH       Installation directory (default: $HOME/BUDDY)"
            echo "  --skip-dependencies       Skip dependency installation"
            echo "  --create-shortcuts         Create desktop shortcuts"
            echo "  -h, --help                Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}🤖 BUDDY AI Assistant - Unix Installer${NC}"
echo -e "${CYAN}=======================================${NC}"

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    DISTRO="macOS"
else
    echo -e "${RED}❌ Unsupported operating system: $OSTYPE${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Detected OS: $DISTRO${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install dependencies on Linux
install_linux_deps() {
    echo -e "${BLUE}📦 Installing Linux dependencies...${NC}"
    
    if command_exists apt-get; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y python3.11 python3.11-pip python3.11-venv nodejs npm git curl wget \
                               portaudio19-dev python3-pyaudio build-essential libssl-dev libffi-dev
    elif command_exists yum; then
        # RHEL/CentOS
        sudo yum install -y python3.11 python3.11-pip nodejs npm git curl wget \
                           portaudio-devel gcc gcc-c++ openssl-devel libffi-devel
    elif command_exists dnf; then
        # Fedora
        sudo dnf install -y python3.11 python3.11-pip nodejs npm git curl wget \
                           portaudio-devel gcc gcc-c++ openssl-devel libffi-devel
    elif command_exists pacman; then
        # Arch Linux
        sudo pacman -S --noconfirm python python-pip nodejs npm git curl wget \
                                  portaudio gcc openssl libffi
    else
        echo -e "${YELLOW}⚠️  Unknown package manager. Please install dependencies manually:${NC}"
        echo "  - Python 3.11+"
        echo "  - Node.js 18+"
        echo "  - Git"
        echo "  - portaudio development headers"
        read -p "Press Enter to continue or Ctrl+C to exit..."
    fi
}

# Function to install dependencies on macOS
install_macos_deps() {
    echo -e "${BLUE}📦 Installing macOS dependencies...${NC}"
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
        echo -e "${YELLOW}📥 Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    
    # Install dependencies
    brew install python@3.11 node@18 git portaudio
    
    # Create symlinks if needed
    if ! command_exists python3.11; then
        ln -sf "$(brew --prefix python@3.11)/bin/python3.11" /usr/local/bin/python3.11
    fi
}

# Install dependencies
if [ "$SKIP_DEPS" = false ]; then
    echo -e "${BLUE}🔍 Checking and installing dependencies...${NC}"
    
    if [ "$OS" = "linux" ]; then
        install_linux_deps
    elif [ "$OS" = "macos" ]; then
        install_macos_deps
    fi
else
    echo -e "${YELLOW}⚠️  Skipping dependency installation${NC}"
fi

# Verify Python installation
echo -e "${BLUE}🔍 Verifying Python installation...${NC}"
if command_exists python3.11; then
    PYTHON_CMD="python3.11"
elif command_exists python3; then
    PYTHON_CMD="python3"
elif command_exists python; then
    PYTHON_CMD="python"
else
    echo -e "${RED}❌ Python not found. Please install Python 3.11+${NC}"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
echo -e "${GREEN}✅ Found Python $PYTHON_VERSION${NC}"

# Verify Node.js installation
echo -e "${BLUE}🔍 Verifying Node.js installation...${NC}"
if ! command_exists node; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js 18+${NC}"
    exit 1
fi

NODE_VERSION=$(node --version)
echo -e "${GREEN}✅ Found Node.js $NODE_VERSION${NC}"

# Verify Git installation
echo -e "${BLUE}🔍 Verifying Git installation...${NC}"
if ! command_exists git; then
    echo -e "${RED}❌ Git not found. Please install Git${NC}"
    exit 1
fi

GIT_VERSION=$(git --version | cut -d' ' -f3)
echo -e "${GREEN}✅ Found Git $GIT_VERSION${NC}"

# Create installation directory
echo -e "${BLUE}📁 Creating installation directory: $INSTALL_PATH${NC}"
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

# Clone BUDDY repository
echo -e "${BLUE}📥 Cloning BUDDY repository...${NC}"
if [ -d "buddy" ]; then
    echo -e "${YELLOW}📁 BUDDY directory exists, updating...${NC}"
    cd buddy
    git pull origin main
else
    git clone https://github.com/your-repo/buddy.git
    cd buddy
fi

# Create Python virtual environment
echo -e "${BLUE}🐍 Creating Python virtual environment...${NC}"
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Install Python dependencies
echo -e "${BLUE}📦 Installing Python dependencies...${NC}"
pip install --upgrade pip
pip install -r packages/core/requirements.txt
pip install SpeechRecognition pydub

# Install PyAudio with error handling
echo -e "${BLUE}🎤 Installing PyAudio...${NC}"
if ! pip install pyaudio; then
    echo -e "${YELLOW}⚠️  PyAudio installation failed. Trying alternative method...${NC}"
    if [ "$OS" = "macos" ]; then
        pip install --global-option='build_ext' --global-option='-I/opt/homebrew/include' --global-option='-L/opt/homebrew/lib' pyaudio
    else
        echo -e "${RED}❌ PyAudio installation failed. Audio features may not work.${NC}"
    fi
fi

# Install Node.js dependencies
echo -e "${BLUE}📦 Installing Node.js dependencies...${NC}"
cd apps/desktop
npm install
npm run build
cd ../..

# Create startup scripts
echo -e "${BLUE}🚀 Creating startup scripts...${NC}"

# Core startup script
cat > start-buddy-core.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting BUDDY Core..."
source venv/bin/activate
cd packages/core
python start_buddy_simple.py
EOF
chmod +x start-buddy-core.sh

# Desktop startup script
cat > start-buddy-desktop.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting BUDDY Desktop..."
cd apps/desktop
npm run dev
EOF
chmod +x start-buddy-desktop.sh

# Combined startup script
cat > start-buddy.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

echo "🤖 BUDDY AI Assistant"
echo "===================="
echo ""

echo "🚀 Starting BUDDY Core..."
./start-buddy-core.sh &
CORE_PID=$!

echo "⏳ Waiting for core to initialize..."
sleep 5

echo "🖥️  Starting BUDDY Desktop..."
./start-buddy-desktop.sh &
DESKTOP_PID=$!

echo ""
echo "✅ BUDDY is starting up!"
echo "🌐 Core API will be available at: http://localhost:8000"
echo "🖥️  Desktop app will be available at: http://localhost:3000"
echo ""
echo "Opening BUDDY in your browser..."
sleep 3

# Open browser
if command -v xdg-open > /dev/null; then
    xdg-open http://localhost:8000
elif command -v open > /dev/null; then
    open http://localhost:8000
fi

echo ""
echo "BUDDY is now running!"
echo "- Core API: http://localhost:8000"
echo "- Desktop App: http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop BUDDY"
echo ""

# Wait for user interrupt
trap 'echo ""; echo "🛑 Stopping BUDDY..."; kill $CORE_PID $DESKTOP_PID 2>/dev/null; exit 0' INT TERM
wait
EOF
chmod +x start-buddy.sh

# Create systemd service (Linux only)
if [ "$OS" = "linux" ] && command_exists systemctl; then
    echo -e "${BLUE}🔧 Creating systemd service...${NC}"
    
    cat > buddy.service << EOF
[Unit]
Description=BUDDY AI Assistant
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$INSTALL_PATH/buddy
ExecStart=$INSTALL_PATH/buddy/start-buddy-core.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${YELLOW}📋 To install as system service:${NC}"
    echo "  sudo cp $INSTALL_PATH/buddy/buddy.service /etc/systemd/system/"
    echo "  sudo systemctl enable buddy"
    echo "  sudo systemctl start buddy"
fi

# Create desktop shortcuts
if [ "$CREATE_SHORTCUTS" = true ]; then
    echo -e "${BLUE}🔗 Creating desktop shortcuts...${NC}"
    
    DESKTOP_DIR="$HOME/Desktop"
    if [ ! -d "$DESKTOP_DIR" ]; then
        DESKTOP_DIR="$HOME/Escritorio"  # Spanish
    fi
    
    if [ -d "$DESKTOP_DIR" ]; then
        # BUDDY shortcut
        cat > "$DESKTOP_DIR/BUDDY AI Assistant.desktop" << EOF
[Desktop Entry]
Name=BUDDY AI Assistant
Comment=Your Personal AI Assistant
Exec=$INSTALL_PATH/buddy/start-buddy.sh
Icon=$INSTALL_PATH/buddy/assets/icon.png
Terminal=true
Type=Application
Categories=Utility;Development;
EOF
        chmod +x "$DESKTOP_DIR/BUDDY AI Assistant.desktop"
        
        # Core only shortcut
        cat > "$DESKTOP_DIR/BUDDY Core.desktop" << EOF
[Desktop Entry]
Name=BUDDY Core
Comment=BUDDY Core Service
Exec=$INSTALL_PATH/buddy/start-buddy-core.sh
Icon=$INSTALL_PATH/buddy/assets/icon.png
Terminal=true
Type=Application
Categories=Utility;Development;
EOF
        chmod +x "$DESKTOP_DIR/BUDDY Core.desktop"
    fi
fi

# Create uninstaller
echo -e "${BLUE}🗑️  Creating uninstaller...${NC}"
cat > uninstall-buddy.sh << 'EOF'
#!/bin/bash
echo "🗑️  BUDDY AI Assistant Uninstaller"
echo "=================================="
echo ""

read -p "This will remove BUDDY from your system. Are you sure? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo "🛑 Stopping BUDDY processes..."
pkill -f "start_buddy_simple.py" 2>/dev/null || true
pkill -f "npm run dev" 2>/dev/null || true

echo "🗑️  Removing BUDDY files..."
cd "$HOME"
rm -rf "$INSTALL_PATH/buddy"

echo "🔗 Removing shortcuts..."
rm -f "$HOME/Desktop/BUDDY"*.desktop 2>/dev/null || true
rm -f "$HOME/Escritorio/BUDDY"*.desktop 2>/dev/null || true

echo "🔧 Removing systemd service..."
sudo systemctl stop buddy 2>/dev/null || true
sudo systemctl disable buddy 2>/dev/null || true
sudo rm -f /etc/systemd/system/buddy.service 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

echo ""
echo "✅ BUDDY has been uninstalled successfully!"
EOF
chmod +x uninstall-buddy.sh

echo ""
echo -e "${GREEN}🎉 BUDDY AI Assistant installation completed!${NC}"
echo ""
echo -e "${CYAN}📍 Installation location: $INSTALL_PATH/buddy${NC}"
echo ""
echo -e "${YELLOW}🚀 To start BUDDY:${NC}"
echo -e "   ${NC}• Run: ./start-buddy.sh${NC}"
echo -e "   ${NC}• Or: $INSTALL_PATH/buddy/start-buddy.sh${NC}"
echo ""
echo -e "${YELLOW}🌐 BUDDY will be available at:${NC}"
echo -e "   ${NC}• Core API: http://localhost:8000${NC}"
echo -e "   ${NC}• Desktop App: http://localhost:3000${NC}"
echo ""
echo -e "${YELLOW}🗑️  To uninstall BUDDY:${NC}"
echo -e "   ${NC}• Run: ./uninstall-buddy.sh${NC}"
echo ""

# Ask if user wants to start BUDDY now
read -p "Start BUDDY now? (y/N): " start_now
if [[ "$start_now" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 Starting BUDDY...${NC}"
    ./start-buddy.sh
fi

echo ""
echo -e "${GREEN}✅ Setup complete! Enjoy your BUDDY AI Assistant! 🤖${NC}"