#!/usr/bin/env python3
"""
BUDDY Network Startup Script
Starts BUDDY with network discovery for cross-device connectivity
"""

import asyncio
import logging
import signal
import sys
from pathlib import Path

# Add the buddy package to the path
sys.path.insert(0, str(Path(__file__).parent))

from buddy.main import app, BuddyCore
from buddy.network import start_buddy_network
from buddy.config import settings
import uvicorn

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class BuddyNetworkServer:
    """
    BUDDY Network Server - Coordinates all BUDDY services for cross-device interaction
    """
    
    def __init__(self):
        self.buddy_core = None
        self.network_service = None
        self.server = None
        self.running = False
    
    async def start(self):
        """Start all BUDDY services"""
        try:
            logger.info("🤖 Starting BUDDY for WiFi network interaction...")
            
            # Initialize BUDDY core
            self.buddy_core = BuddyCore()
            await self.buddy_core.initialize()
            
            # Start network discovery service
            logger.info("🌐 Starting network discovery service...")
            self.network_service = await start_buddy_network()
            
            # Start the FastAPI server
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
            logger.info("📱 BUDDY is now discoverable on the WiFi network")
            logger.info("🔗 Cross-device connections enabled")
            
            # Start server in background
            server_task = asyncio.create_task(server.serve())
            
            # Monitor for discovered devices
            discovery_task = asyncio.create_task(self._monitor_devices())
            
            self.running = True
            
            # Wait for both tasks
            await asyncio.gather(server_task, discovery_task)
            
        except Exception as e:
            logger.error(f"❌ Failed to start BUDDY: {e}")
            await self.stop()
            raise
    
    async def _monitor_devices(self):
        """Monitor and report discovered devices"""
        logger.info("🔍 Monitoring for BUDDY devices on network...")
        
        last_device_count = 0
        
        while self.running:
            try:
                if self.network_service:
                    devices = self.network_service.get_discovered_devices()
                    device_count = len(devices)
                    
                    if device_count != last_device_count:
                        if device_count > 0:
                            logger.info(f"📱 {device_count} BUDDY device(s) discovered:")
                            for device_id, info in devices.items():
                                logger.info(f"  ├─ {info['name']} at {info['address']}:{info['port']}")
                                logger.info(f"  └─ Capabilities: {info['properties'].get('capabilities', 'unknown')}")
                        else:
                            logger.info("📱 No other BUDDY devices found on network")
                        
                        last_device_count = device_count
                
                await asyncio.sleep(5)  # Check every 5 seconds
                
            except Exception as e:
                logger.error(f"❌ Device monitoring error: {e}")
                await asyncio.sleep(10)
    
    async def stop(self):
        """Stop all BUDDY services"""
        try:
            logger.info("🛑 Stopping BUDDY services...")
            self.running = False
            
            if self.network_service:
                await self.network_service.stop()
            
            if self.server:
                self.server.should_exit = True
            
            if self.buddy_core:
                await self.buddy_core.cleanup()
            
            logger.info("✅ BUDDY stopped successfully")
            
        except Exception as e:
            logger.error(f"❌ Error stopping BUDDY: {e}")

# Global server instance
buddy_server = BuddyNetworkServer()

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
    print("🌐 Starting with WiFi network discovery...")
    print("📱 Cross-device connectivity enabled")
    print("🔗 Other BUDDY devices will auto-connect")
    print("=" * 50)
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 BUDDY shutdown complete")
    except Exception as e:
        print(f"\n❌ BUDDY failed to start: {e}")
        sys.exit(1)