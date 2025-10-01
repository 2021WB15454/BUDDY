#!/bin/bash
set -e

# BUDDY Entrypoint Script
echo "🤖 Starting BUDDY Personal AI Assistant..."

# Environment setup
export BUDDY_DATA_DIR="${BUDDY_DATA_DIR:-/app/data}"
export BUDDY_LOG_LEVEL="${BUDDY_LOG_LEVEL:-INFO}"
export BUDDY_HOST="${BUDDY_HOST:-0.0.0.0}"
export BUDDY_PORT="${BUDDY_PORT:-8000}"

# Create necessary directories
mkdir -p "${BUDDY_DATA_DIR}"/{db,logs,audio,sync,models}

# Set up logging
LOG_FILE="${BUDDY_DATA_DIR}/logs/buddy.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🚀 BUDDY initialization starting..."

# Check if running as root (not recommended)
if [ "$(id -u)" -eq 0 ]; then
    log "⚠️  Warning: Running as root. Consider using a non-root user."
fi

# Check required environment variables
required_vars=("BUDDY_DATA_DIR")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        log "❌ Error: Required environment variable $var is not set"
        exit 1
    fi
done

# Initialize database if it doesn't exist
DB_PATH="${BUDDY_DATA_DIR}/db/buddy.db"
if [ ! -f "$DB_PATH" ]; then
    log "📊 Initializing database..."
    python -c "
from buddy.memory import MemoryManager
import asyncio

async def init_db():
    memory = MemoryManager()
    await memory.initialize()
    print('✅ Database initialized')

asyncio.run(init_db())
"
fi

# Check model availability
log "🧠 Checking AI models..."

# Check Whisper models
WHISPER_MODEL_DIR="${BUDDY_DATA_DIR}/models/whisper"
if [ ! -d "$WHISPER_MODEL_DIR" ] || [ -z "$(ls -A "$WHISPER_MODEL_DIR")" ]; then
    log "📥 Downloading Whisper models..."
    mkdir -p "$WHISPER_MODEL_DIR"
    python -c "
import whisper
import os
models = ['tiny', 'base']
for model in models:
    print(f'Downloading Whisper {model}...')
    whisper.load_model(model, download_root='$WHISPER_MODEL_DIR')
    print(f'✅ Whisper {model} downloaded')
"
else
    log "✅ Whisper models found"
fi

# Check sentence transformer models
EMBEDDINGS_MODEL_DIR="${BUDDY_DATA_DIR}/models/embeddings"
if [ ! -d "$EMBEDDINGS_MODEL_DIR" ] || [ -z "$(ls -A "$EMBEDDINGS_MODEL_DIR")" ]; then
    log "📥 Downloading embedding models..."
    mkdir -p "$EMBEDDINGS_MODEL_DIR"
    python -c "
from sentence_transformers import SentenceTransformer
model = SentenceTransformer('all-MiniLM-L6-v2')
model.save('$EMBEDDINGS_MODEL_DIR/all-MiniLM-L6-v2')
print('✅ Sentence transformer model downloaded')
"
else
    log "✅ Embedding models found"
fi

# Test backend connectivity
log "🌐 Testing backend connectivity..."
python -c "
import asyncio
from buddy.main import create_app

async def test_app():
    app = create_app()
    print('✅ Backend app created successfully')

try:
    asyncio.run(test_app())
except Exception as e:
    print(f'❌ Backend test failed: {e}')
    exit(1)
"

# Set up audio system
if command -v aplay >/dev/null 2>&1; then
    log "🔊 Audio system available"
else
    log "⚠️  Audio system not detected - voice features may be limited"
fi

# Start health monitoring in background
if [ "${BUDDY_ENABLE_HEALTH_MONITORING:-true}" = "true" ]; then
    python /app/healthcheck.py --monitor &
    HEALTH_PID=$!
    log "❤️  Health monitoring started (PID: $HEALTH_PID)"
fi

# Setup signal handlers for graceful shutdown
cleanup() {
    log "🛑 Shutting down BUDDY..."
    if [ ! -z "$HEALTH_PID" ]; then
        kill $HEALTH_PID 2>/dev/null || true
    fi
    log "👋 BUDDY shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Final checks
log "🔍 Final system checks..."

# Check available memory
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
log "💾 Available memory: ${AVAILABLE_MEM}GB"

if (( $(echo "$AVAILABLE_MEM < 0.5" | bc -l) )); then
    log "⚠️  Warning: Low memory available. BUDDY may perform poorly."
fi

# Check disk space
AVAILABLE_DISK=$(df -h "$BUDDY_DATA_DIR" | awk 'NR==2 {print $4}')
log "💿 Available disk space: $AVAILABLE_DISK"

log "✅ BUDDY initialization complete!"
log "🎯 Starting server on ${BUDDY_HOST}:${BUDDY_PORT}"

# Execute the command passed to the container
exec "$@"