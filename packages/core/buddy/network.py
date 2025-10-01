#!/usr/bin/env python3
"""
BUDDY Network Discovery and Cross-Device Connection Service
Enables BUDDY to be discoverable and connectable across WiFi networks
"""

import asyncio
import json
import socket
import time
from typing import Dict, List, Optional
import logging
from datetime import datetime

# Network discovery imports
try:
    import zeroconf
    from zeroconf import ServiceBrowser, ServiceListener, Zeroconf, ServiceInfo
except ImportError:
    print("Installing zeroconf for network discovery...")
    import subprocess
    subprocess.check_call(["pip", "install", "zeroconf"])
    import zeroconf
    from zeroconf import ServiceBrowser, ServiceListener, Zeroconf, ServiceInfo

from buddy.config import settings
from buddy.events import EventBus, Event, EventType

logger = logging.getLogger(__name__)

class BuddyNetworkService:
    """
    BUDDY Network Service for cross-device discovery and communication
    """
    
    def __init__(self, host: str = "0.0.0.0", port: int = 8000):
        self.host = host
        self.port = port
        self.device_id = settings.DEVICE_ID
        self.device_name = f"BUDDY-{socket.gethostname()}"
        self.zeroconf: Optional[Zeroconf] = None
        self.service_info: Optional[ServiceInfo] = None
        self.discovered_devices: Dict[str, Dict] = {}
        self.event_bus = EventBus()
        
    async def start_network_service(self):
        """Start the network discovery and announcement service"""
        try:
            logger.info(f"🌐 Starting BUDDY Network Service on {self.host}:{self.port}")
            
            # Start Zeroconf service
            self.zeroconf = Zeroconf()
            
            # Register BUDDY service
            await self._register_service()
            
            # Start discovering other BUDDY devices
            await self._start_discovery()
            
            # Start network monitoring
            asyncio.create_task(self._monitor_network())
            
            logger.info("✅ BUDDY Network Service started successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to start network service: {e}")
            raise
    
    async def _register_service(self):
        """Register this BUDDY instance as a discoverable service"""
        try:
            # Get local IP address
            local_ip = self._get_local_ip()
            
            # Service properties
            properties = {
                'device_id': self.device_id.encode('utf-8'),
                'device_name': self.device_name.encode('utf-8'),
                'version': '0.1.0'.encode('utf-8'),
                'capabilities': json.dumps(['voice', 'sync', 'skills']).encode('utf-8'),
                'platform': socket.platform.encode('utf-8') if hasattr(socket, 'platform') else b'unknown',
                'timestamp': str(int(time.time())).encode('utf-8')
            }
            
            # Create service info
            self.service_info = ServiceInfo(
                "_buddy._tcp.local.",
                f"{self.device_name}._buddy._tcp.local.",
                addresses=[socket.inet_aton(local_ip)],
                port=self.port,
                properties=properties,
                server=f"{self.device_name}.local."
            )
            
            # Register service
            self.zeroconf.register_service(self.service_info)
            
            logger.info(f"📡 BUDDY service registered: {self.device_name} at {local_ip}:{self.port}")
            
        except Exception as e:
            logger.error(f"❌ Failed to register service: {e}")
            raise
    
    async def _start_discovery(self):
        """Start discovering other BUDDY devices on the network"""
        try:
            listener = BuddyServiceListener(self)
            browser = ServiceBrowser(self.zeroconf, "_buddy._tcp.local.", listener)
            
            logger.info("🔍 Started discovering BUDDY devices on network")
            
        except Exception as e:
            logger.error(f"❌ Failed to start discovery: {e}")
            raise
    
    def _get_local_ip(self) -> str:
        """Get the local IP address"""
        try:
            # Connect to a remote address to determine local IP
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                local_ip = s.getsockname()[0]
            return local_ip
        except Exception:
            return "127.0.0.1"
    
    async def _monitor_network(self):
        """Monitor network connectivity and device status"""
        while True:
            try:
                await asyncio.sleep(30)  # Check every 30 seconds
                
                # Check if we're still connected
                local_ip = self._get_local_ip()
                if local_ip == "127.0.0.1":
                    logger.warning("⚠️  Network connectivity lost")
                    await self.event_bus.publish(Event(
                        type=EventType.NETWORK_DISCONNECTED,
                        data={"timestamp": datetime.utcnow().isoformat()}
                    ))
                else:
                    # Ping discovered devices to check connectivity
                    await self._ping_discovered_devices()
                
            except Exception as e:
                logger.error(f"❌ Network monitoring error: {e}")
    
    async def _ping_discovered_devices(self):
        """Ping discovered devices to check if they're still available"""
        for device_id, device_info in list(self.discovered_devices.items()):
            try:
                # Simple connectivity check
                host = device_info.get('address')
                port = device_info.get('port')
                
                if host and port:
                    reader, writer = await asyncio.wait_for(
                        asyncio.open_connection(host, port),
                        timeout=5.0
                    )
                    writer.close()
                    await writer.wait_closed()
                    
                    # Device is still reachable
                    device_info['last_seen'] = time.time()
                    
            except (asyncio.TimeoutError, ConnectionRefusedError, OSError):
                # Device is no longer reachable
                logger.info(f"📱 Device {device_id} is no longer reachable")
                await self._remove_device(device_id)
    
    async def add_discovered_device(self, device_id: str, device_info: Dict):
        """Add a newly discovered device"""
        self.discovered_devices[device_id] = device_info
        
        logger.info(f"📱 Discovered BUDDY device: {device_info.get('name', device_id)}")
        
        # Publish discovery event
        await self.event_bus.publish(Event(
            type=EventType.DEVICE_DISCOVERED,
            data={
                "device_id": device_id,
                "device_info": device_info,
                "timestamp": datetime.utcnow().isoformat()
            }
        ))
    
    async def _remove_device(self, device_id: str):
        """Remove a device that's no longer available"""
        if device_id in self.discovered_devices:
            device_info = self.discovered_devices.pop(device_id)
            
            # Publish removal event
            await self.event_bus.publish(Event(
                type=EventType.DEVICE_DISCONNECTED,
                data={
                    "device_id": device_id,
                    "device_info": device_info,
                    "timestamp": datetime.utcnow().isoformat()
                }
            ))
    
    def get_discovered_devices(self) -> Dict[str, Dict]:
        """Get all currently discovered devices"""
        return self.discovered_devices.copy()
    
    async def stop(self):
        """Stop the network service"""
        try:
            if self.zeroconf and self.service_info:
                self.zeroconf.unregister_service(self.service_info)
                self.zeroconf.close()
            
            logger.info("🛑 BUDDY Network Service stopped")
            
        except Exception as e:
            logger.error(f"❌ Error stopping network service: {e}")


class BuddyServiceListener(ServiceListener):
    """Listener for BUDDY service discovery"""
    
    def __init__(self, network_service: BuddyNetworkService):
        self.network_service = network_service
    
    def add_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        """Called when a BUDDY service is discovered"""
        asyncio.create_task(self._handle_service_added(zc, type_, name))
    
    async def _handle_service_added(self, zc: Zeroconf, type_: str, name: str):
        """Handle a newly discovered service"""
        try:
            info = zc.get_service_info(type_, name)
            if info:
                # Extract device information
                properties = {}
                if info.properties:
                    for key, value in info.properties.items():
                        properties[key.decode('utf-8')] = value.decode('utf-8')
                
                device_id = properties.get('device_id', name)
                device_name = properties.get('device_name', name)
                
                # Skip our own service
                if device_id == self.network_service.device_id:
                    return
                
                device_info = {
                    'name': device_name,
                    'address': socket.inet_ntoa(info.addresses[0]) if info.addresses else None,
                    'port': info.port,
                    'properties': properties,
                    'discovered_at': time.time(),
                    'last_seen': time.time()
                }
                
                await self.network_service.add_discovered_device(device_id, device_info)
                
        except Exception as e:
            logger.error(f"❌ Error handling discovered service: {e}")
    
    def remove_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        """Called when a BUDDY service is removed"""
        logger.info(f"📱 BUDDY device removed: {name}")
    
    def update_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        """Called when a BUDDY service is updated"""
        logger.info(f"📱 BUDDY device updated: {name}")


# Network service instance
network_service = BuddyNetworkService()

async def start_buddy_network():
    """Start BUDDY network services for cross-device connectivity"""
    await network_service.start_network_service()
    return network_service

if __name__ == "__main__":
    import asyncio
    
    async def main():
        print("🤖 Starting BUDDY Network Service...")
        service = await start_buddy_network()
        
        try:
            # Keep service running
            while True:
                devices = service.get_discovered_devices()
                print(f"📱 Discovered devices: {len(devices)}")
                for device_id, info in devices.items():
                    print(f"  - {info['name']} at {info['address']}:{info['port']}")
                
                await asyncio.sleep(10)
                
        except KeyboardInterrupt:
            print("\n🛑 Stopping BUDDY Network Service...")
            await service.stop()
    
    asyncio.run(main())