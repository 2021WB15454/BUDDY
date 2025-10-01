#!/usr/bin/env python3
"""
Simple BUDDY Network Startup Script
Starts BUDDY with basic network connectivity for cross-device interaction
"""

import asyncio
import logging
import signal
import sys
from pathlib import Path

# Add the buddy package to the path
sys.path.insert(0, str(Path(__file__).parent))

from buddy.main_simple import app
from buddy.config import settings
import uvicorn

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SimpleBuddyServer:
    """
    Simple BUDDY Server for WiFi network interaction
    """
    
    def __init__(self):
        self.server = None
        self.running = False
    
    async def start(self):
        """Start BUDDY services"""
        try:
            logger.info("🤖 Starting BUDDY for WiFi network interaction...")
            
            # Start the FastAPI server for cross-device access
            config = uvicorn.Config(
                app,
                host="0.0.0.0",  # Listen on all interfaces for cross-device access
                port=8000,
                log_level="info",
                access_log=True
            )
            
            server = uvicorn.Server(config)
            self.server = server
            
            logger.info("🚀 Starting BUDDY API server on http://0.0.0.0:8000")
            logger.info("📱 BUDDY is now accessible on the WiFi network")
            logger.info("🔗 Cross-device connections enabled via HTTP API")
            logger.info("💡 Access from other devices: http://[this-device-ip]:8000")
            
            # Display network information
            await self._show_network_info()
            
            # Start server
            self.running = True
            await server.serve()
            
        except Exception as e:
            logger.error(f"❌ Failed to start BUDDY: {e}")
            await self.stop()
            raise
    
    async def _show_network_info(self):
        """Show network information for device discovery"""
        try:
            import socket
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
            
            logger.info(f"🖥️  Device: {hostname}")
            logger.info(f"🌐 Local IP: {local_ip}")
            logger.info(f"📡 API Endpoint: http://{local_ip}:8000")
            logger.info(f"📖 API Docs: http://{local_ip}:8000/docs")
            logger.info(f"❤️  Health Check: http://{local_ip}:8000/health")
            
        except Exception as e:
            logger.warning(f"⚠️  Could not determine network info: {e}")
    
    async def stop(self):
        """Stop all BUDDY services"""
        try:
            logger.info("🛑 Stopping BUDDY services...")
            self.running = False
            
            if self.server:
                self.server.should_exit = True
            
            logger.info("✅ BUDDY stopped successfully")
            
        except Exception as e:
            logger.error(f"❌ Error stopping BUDDY: {e}")

# Global server instance
buddy_server = SimpleBuddyServer()

async def main():
    """Main entry point"""
    def signal_handler(signum, frame):
        logger.info("🛑 Received shutdown signal")
        asyncio.create_task(buddy_server.stop())
    
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        await buddy_server.start()
    except KeyboardInterrupt:
        logger.info("🛑 Keyboard interrupt received")
    except Exception as e:
        logger.error(f"❌ BUDDY startup failed: {e}")
        sys.exit(1)
    finally:
        await buddy_server.stop()

if __name__ == "__main__":
    print("🤖 BUDDY - Personal AI Assistant")
    print("🌐 Starting with WiFi network connectivity...")
    print("📱 Cross-device HTTP API enabled")
    print("🔗 Other devices can connect via IP address")
    print("=" * 50)
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 BUDDY shutdown complete")
    except Exception as e:
        print(f"\n❌ BUDDY failed to start: {e}")
        sys.exit(1)