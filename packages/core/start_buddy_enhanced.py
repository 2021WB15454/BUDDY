#!/usr/bin/env python3
"""
BUDDY AI Assistant - Enhanced Startup Script
Simplified version without external AI dependencies
"""

import asyncio
import logging
import signal
import sys
import socket
import uvicorn
from pathlib import Path

# Add the buddy package to the Python path
buddy_path = Path(__file__).parent
sys.path.insert(0, str(buddy_path))

from buddy.main_simple import app
from buddy.config import settings

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def get_local_ip():
    """Get the local IP address"""
    try:
        # Connect to a remote server to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    logger.info("🛑 Received shutdown signal")
    sys.exit(0)


def main():
    """Main entry point for BUDDY"""
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print("🤖 BUDDY - Personal AI Assistant")
    print("🌐 Starting enhanced version with improved chat...")
    print("📱 Cross-device HTTP API enabled")
    print("🔗 Other devices can connect via IP address")
    print("=" * 50)
    
    logger.info("🤖 Starting BUDDY with enhanced chat capabilities...")
    
    # Get network information
    local_ip = get_local_ip()
    port = 8000
    
    # Display connection information
    logger.info(f"🖥️  Device: {socket.gethostname()}")
    logger.info(f"🌐 Local IP: {local_ip}")
    logger.info(f"📡 API Endpoint: http://{local_ip}:{port}")
    logger.info(f"📖 API Docs: http://{local_ip}:{port}/docs")
    logger.info(f"❤️  Health Check: http://{local_ip}:{port}/health")
    
    try:
        # Start the server
        logger.info(f"🚀 Starting BUDDY API server on http://0.0.0.0:{port}")
        logger.info("📱 BUDDY is now accessible with enhanced chat capabilities")
        logger.info("🔗 Cross-device connections enabled via HTTP API")
        logger.info(f"💡 Access from other devices: http://{local_ip}:{port}")
        
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=port,
            log_level="info",
            access_log=True
        )
        
    except KeyboardInterrupt:
        logger.info("🛑 Received keyboard interrupt")
    except Exception as e:
        logger.error(f"❌ Failed to start BUDDY server: {e}")
        sys.exit(1)
    finally:
        logger.info("✅ BUDDY stopped successfully")


if __name__ == "__main__":
    main()