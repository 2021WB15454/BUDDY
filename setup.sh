#!/bin/bash

# BUDDY Quick Setup Script
# This script sets up BUDDY for different deployment scenarios

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEPLOYMENT_TYPE=""
ENABLE_HOMEASSISTANT=false
ENABLE_WEB=false
ENABLE_MONITORING=false
ENABLE_CACHE=false
DATA_DIR="./data"
MODELS_DIR="./models"

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "🤖 =============================="
    echo "   BUDDY Personal AI Assistant"
    echo "   Quick Setup Script"
    echo "==============================${NC}"
    echo
}

show_help() {
    cat << EOF
BUDDY Quick Setup Script

Usage: $0 [OPTIONS] [DEPLOYMENT_TYPE]

Deployment Types:
  development    - Development setup with hot reload
  production     - Production setup with optimizations
  raspberry-pi   - Raspberry Pi optimized setup
  homeassistant  - Home Assistant integration
  cluster        - Multi-device cluster setup

Options:
  --web                Enable web interface
  --homeassistant     Enable Home Assistant integration
  --monitoring        Enable Prometheus/Grafana monitoring
  --cache             Enable Redis caching
  --data-dir DIR      Set data directory (default: ./data)
  --models-dir DIR    Set models directory (default: ./models)
  --help              Show this help message

Examples:
  $0 development --web
  $0 production --monitoring --cache
  $0 raspberry-pi --homeassistant
  $0 homeassistant --web --monitoring

EOF
}

check_requirements() {
    print_info "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check available memory
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        AVAILABLE_MEM=$(free -g | awk 'NR==2{print $7}')
        if [ "$AVAILABLE_MEM" -lt 1 ]; then
            print_warning "Less than 1GB RAM available. BUDDY may perform poorly."
        fi
    fi
    
    print_success "Requirements check passed"
}

setup_directories() {
    print_info "Setting up directories..."
    
    # Create data directories
    mkdir -p "$DATA_DIR"/{db,logs,audio,sync,config}
    mkdir -p "$MODELS_DIR"/{whisper,piper,embeddings,wake_word}
    
    # Set permissions
    chmod 755 "$DATA_DIR"
    chmod 755 "$MODELS_DIR"
    
    print_success "Directories created"
}

setup_environment() {
    print_info "Setting up environment..."
    
    # Create .env file
    cat > .env << EOF
# BUDDY Environment Configuration
BUDDY_DATA_DIR=$DATA_DIR
BUDDY_MODELS_DIR=$MODELS_DIR
BUDDY_LOG_LEVEL=INFO
BUDDY_DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE

# Backend Configuration
BUDDY_HOST=0.0.0.0
BUDDY_PORT=8000
BUDDY_WORKERS=1

# Feature Flags
BUDDY_ENABLE_VOICE=true
BUDDY_ENABLE_SYNC=true
BUDDY_ENABLE_SKILLS=true

# Security
BUDDY_SECRET_KEY=$(openssl rand -hex 32)
BUDDY_DEVICE_ID=$(uuidgen)

# Optional Services
ENABLE_HOMEASSISTANT=$ENABLE_HOMEASSISTANT
ENABLE_WEB=$ENABLE_WEB
ENABLE_MONITORING=$ENABLE_MONITORING
ENABLE_CACHE=$ENABLE_CACHE
EOF

    print_success "Environment configured"
}

download_models() {
    print_info "Downloading AI models (this may take a while)..."
    
    # Create model download script
    cat > download_models.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
from pathlib import Path

def download_whisper_models():
    try:
        import whisper
        models = ['tiny', 'base']
        models_dir = Path(os.environ.get('BUDDY_MODELS_DIR', './models')) / 'whisper'
        models_dir.mkdir(parents=True, exist_ok=True)
        
        for model in models:
            print(f"Downloading Whisper {model}...")
            whisper.load_model(model, download_root=str(models_dir))
            print(f"✅ Whisper {model} downloaded")
    except ImportError:
        print("⚠️  Whisper not available - will download during first run")
    except Exception as e:
        print(f"❌ Failed to download Whisper models: {e}")

def download_sentence_transformer():
    try:
        from sentence_transformers import SentenceTransformer
        models_dir = Path(os.environ.get('BUDDY_MODELS_DIR', './models')) / 'embeddings'
        models_dir.mkdir(parents=True, exist_ok=True)
        
        print("Downloading sentence transformer model...")
        model = SentenceTransformer('all-MiniLM-L6-v2')
        model.save(str(models_dir / 'all-MiniLM-L6-v2'))
        print("✅ Sentence transformer model downloaded")
    except ImportError:
        print("⚠️  Sentence transformers not available - will download during first run")
    except Exception as e:
        print(f"❌ Failed to download sentence transformer: {e}")

if __name__ == "__main__":
    download_whisper_models()
    download_sentence_transformer()
EOF

    # Make executable and run if Python is available
    chmod +x download_models.py
    if command -v python3 &> /dev/null; then
        python3 download_models.py || print_warning "Model download failed - will retry during container startup"
    else
        print_warning "Python3 not found - models will be downloaded during container startup"
    fi
    
    rm -f download_models.py
}

build_images() {
    print_info "Building Docker images..."
    
    # Determine build target
    case $DEPLOYMENT_TYPE in
        "development")
            BUILD_TARGET="development"
            ;;
        "raspberry-pi")
            BUILD_TARGET="raspberry-pi"
            ;;
        *)
            BUILD_TARGET="production"
            ;;
    esac
    
    # Build main image
    docker build \
        --target $BUILD_TARGET \
        -t buddy/backend:latest \
        -f docker/Dockerfile .
    
    print_success "Docker images built"
}

generate_docker_compose() {
    print_info "Generating Docker Compose configuration..."
    
    # Start with base services
    PROFILES="default"
    
    # Add optional services
    if [ "$ENABLE_WEB" = true ]; then
        PROFILES="$PROFILES,web"
    fi
    
    if [ "$ENABLE_HOMEASSISTANT" = true ]; then
        PROFILES="$PROFILES,homeassistant"
    fi
    
    if [ "$ENABLE_MONITORING" = true ]; then
        PROFILES="$PROFILES,monitoring"
    fi
    
    if [ "$ENABLE_CACHE" = true ]; then
        PROFILES="$PROFILES,cache"
    fi
    
    # Create override file
    cat > docker-compose.override.yml << EOF
version: '3.8'

services:
  buddy-backend:
    environment:
      - BUDDY_DEPLOYMENT_TYPE=$DEPLOYMENT_TYPE
    profiles:
      - default
EOF

    print_success "Docker Compose configuration generated"
}

start_services() {
    print_info "Starting BUDDY services..."
    
    # Use docker-compose or docker compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Start services
    PROFILES=$(echo $PROFILES | tr ',' ' ')
    for profile in $PROFILES; do
        $COMPOSE_CMD --profile $profile up -d
    done
    
    print_success "BUDDY services started"
}

show_status() {
    print_info "Checking service status..."
    
    # Wait a moment for services to start
    sleep 5
    
    # Check BUDDY backend
    if curl -s http://localhost:8000/health > /dev/null; then
        print_success "BUDDY backend is running at http://localhost:8000"
    else
        print_warning "BUDDY backend is starting up..."
    fi
    
    # Check optional services
    if [ "$ENABLE_WEB" = true ]; then
        if curl -s http://localhost:3000 > /dev/null; then
            print_success "Web interface is running at http://localhost:3000"
        else
            print_warning "Web interface is starting up..."
        fi
    fi
    
    if [ "$ENABLE_HOMEASSISTANT" = true ]; then
        if curl -s http://localhost:8123 > /dev/null; then
            print_success "Home Assistant is running at http://localhost:8123"
        else
            print_warning "Home Assistant is starting up..."
        fi
    fi
    
    if [ "$ENABLE_MONITORING" = true ]; then
        print_info "Monitoring available at:"
        print_info "  - Prometheus: http://localhost:9090"
        print_info "  - Grafana: http://localhost:3001 (admin/buddy_admin)"
    fi
}

show_next_steps() {
    print_success "BUDDY setup complete! 🎉"
    echo
    print_info "Next steps:"
    echo "  1. Wait for all services to fully start (check docker logs)"
    echo "  2. Visit http://localhost:8000/docs for API documentation"
    echo "  3. Use the BUDDY mobile app or desktop app to connect"
    echo "  4. Configure your preferences in the settings"
    echo
    print_info "Useful commands:"
    echo "  - View logs: docker-compose logs -f buddy-backend"
    echo "  - Stop services: docker-compose down"
    echo "  - Restart: docker-compose restart"
    echo "  - Update: git pull && ./setup.sh $DEPLOYMENT_TYPE"
    echo
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --web)
            ENABLE_WEB=true
            shift
            ;;
        --homeassistant)
            ENABLE_HOMEASSISTANT=true
            shift
            ;;
        --monitoring)
            ENABLE_MONITORING=true
            shift
            ;;
        --cache)
            ENABLE_CACHE=true
            shift
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --models-dir)
            MODELS_DIR="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            print_error "Unknown option $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$DEPLOYMENT_TYPE" ]; then
                DEPLOYMENT_TYPE="$1"
            else
                print_error "Multiple deployment types specified"
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default deployment type
if [ -z "$DEPLOYMENT_TYPE" ]; then
    DEPLOYMENT_TYPE="production"
fi

# Validate deployment type
case $DEPLOYMENT_TYPE in
    "development"|"production"|"raspberry-pi"|"homeassistant"|"cluster")
        ;;
    *)
        print_error "Invalid deployment type: $DEPLOYMENT_TYPE"
        show_help
        exit 1
        ;;
esac

# Main execution
print_header

print_info "Deployment type: $DEPLOYMENT_TYPE"
print_info "Optional services:"
print_info "  - Web interface: $ENABLE_WEB"
print_info "  - Home Assistant: $ENABLE_HOMEASSISTANT"
print_info "  - Monitoring: $ENABLE_MONITORING"
print_info "  - Cache: $ENABLE_CACHE"
echo

check_requirements
setup_directories
setup_environment
download_models
build_images
generate_docker_compose
start_services
show_status
show_next_steps