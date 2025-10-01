"""
Synchronization Engine for BUDDY Core Runtime

This module handles secure, conflict-free synchronization of data across devices
using CRDT (Conflict-free Replicated Data Types) and end-to-end encryption.

Key Features:
- CRDT-based state replication for conflict-free merging
- End-to-end encryption with device key pairs
- P2P discovery via mDNS and WebRTC
- Delta sync for efficient bandwidth usage
- Automatic conflict resolution
- Device authentication and authorization
"""

import asyncio
import json
import logging
import hashlib
import time
from typing import Dict, List, Any, Optional, Set
from dataclasses import dataclass, asdict
from datetime import datetime
from enum import Enum

from .events import EventBus, EventType
from .config import settings

logger = logging.getLogger(__name__)


class SyncState(Enum):
    """Sync engine states"""
    STOPPED = "stopped"
    STARTING = "starting"
    DISCOVERING = "discovering"
    CONNECTED = "connected"
    SYNCING = "syncing"
    ERROR = "error"


@dataclass
class DeviceInfo:
    """Information about a connected device"""
    device_id: str
    device_name: str
    device_type: str  # mobile, desktop, hub, tv, car, watch
    address: str
    port: int
    public_key: bytes
    last_seen: datetime
    is_trusted: bool = False
    capabilities: List[str] = None
    
    def __post_init__(self):
        if self.capabilities is None:
            self.capabilities = []


@dataclass
class SyncOperation:
    """Single sync operation"""
    operation_id: str
    device_id: str
    document_id: str
    operation_type: str  # create, update, delete
    data: Dict[str, Any]
    timestamp: float
    vector_clock: Dict[str, int]
    signature: Optional[bytes] = None


@dataclass
class CRDTDocument:
    """CRDT document for conflict-free synchronization"""
    document_id: str
    document_type: str  # note, reminder, preference, etc.
    content: Dict[str, Any]
    vector_clock: Dict[str, int]  # Logical clocks per device
    last_modified: datetime
    created_by: str


class SyncEngine:
    """
    CRDT-based synchronization engine for BUDDY
    
    Handles secure, conflict-free data synchronization across all BUDDY devices:
    - Automatic device discovery (mDNS/Bonjour)
    - Encrypted P2P connections (WebRTC/TCP)
    - CRDT operations for conflict resolution
    - Delta synchronization for efficiency
    - Device trust and capability management
    """
    
    def __init__(self, event_bus: EventBus, memory_manager, security_manager):
        self.event_bus = event_bus
        self.memory_manager = memory_manager
        self.security_manager = security_manager
        
        # Configuration
        self.device_id = settings.DEVICE_NAME
        self.sync_port = settings.SYNC_PORT
        self.enabled = settings.ENABLE_SYNC
        
        # State
        self.state = SyncState.STOPPED
        self.connected_devices: Dict[str, DeviceInfo] = {}
        self.pending_operations: List[SyncOperation] = []
        self.vector_clock: Dict[str, int] = {self.device_id: 0}
        
        # CRDT documents
        self.documents: Dict[str, CRDTDocument] = {}
        self.document_subscriptions: Dict[str, Set[str]] = {}  # doc_id -> device_ids
        
        # Network components
        self.discovery_service = None
        self.sync_server = None
        self.connections: Dict[str, Any] = {}  # device_id -> connection
        
        # Metrics
        self.metrics = {
            "devices_discovered": 0,
            "devices_connected": 0,
            "operations_sent": 0,
            "operations_received": 0,
            "conflicts_resolved": 0,
            "sync_errors": 0
        }
        
        logger.info(f"SyncEngine initialized for device: {self.device_id}")
    
    async def start(self):
        """Start the sync engine"""
        if not self.enabled:
            logger.info("Sync disabled in configuration")
            return
        
        logger.info("Starting sync engine...")
        self.state = SyncState.STARTING
        
        try:
            # Initialize CRDT documents from memory
            await self._load_documents()
            
            # Start device discovery
            await self._start_discovery()
            
            # Start sync server
            await self._start_sync_server()
            
            # Setup event handlers
            self._setup_event_handlers()
            
            self.state = SyncState.DISCOVERING
            logger.info("✅ Sync engine started successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to start sync engine: {e}")
            self.state = SyncState.ERROR
            raise
    
    async def stop(self):
        """Stop the sync engine"""
        logger.info("Stopping sync engine...")
        self.state = SyncState.STOPPED
        
        # Close connections
        for device_id, connection in self.connections.items():
            try:
                await self._close_connection(device_id)
            except Exception as e:
                logger.error(f"Error closing connection to {device_id}: {e}")
        
        # Stop network services
        if self.sync_server:
            await self._stop_sync_server()
        
        if self.discovery_service:
            await self._stop_discovery()
        
        logger.info("Sync engine stopped")
    
    async def _load_documents(self):
        """Load CRDT documents from memory manager"""
        # Load preferences as CRDT documents
        try:
            # TODO: Load actual documents from memory manager
            # For now, create sample documents
            
            # User preferences document
            prefs_doc = CRDTDocument(
                document_id="preferences_user",
                document_type="preferences",
                content={"theme": "dark", "language": "en"},
                vector_clock={self.device_id: 1},
                last_modified=datetime.utcnow(),
                created_by=self.device_id
            )
            self.documents[prefs_doc.document_id] = prefs_doc
            
            logger.info(f"Loaded {len(self.documents)} CRDT documents")
            
        except Exception as e:
            logger.error(f"Failed to load documents: {e}")
    
    async def _start_discovery(self):
        """Start device discovery service"""
        try:
            # TODO: Implement mDNS/Bonjour discovery
            # For now, create a mock discovery service
            
            class MockDiscoveryService:
                def __init__(self, sync_engine):
                    self.sync_engine = sync_engine
                    self.running = True
                
                async def start(self):
                    # Mock: periodically "discover" devices
                    asyncio.create_task(self._discovery_loop())
                
                async def _discovery_loop(self):
                    while self.running:
                        # Mock discovery - in real implementation, this would
                        # use mDNS to discover other BUDDY devices
                        await asyncio.sleep(30)  # Check every 30 seconds
                
                async def stop(self):
                    self.running = False
            
            self.discovery_service = MockDiscoveryService(self)
            await self.discovery_service.start()
            
            logger.info("Device discovery started")
            
        except Exception as e:
            logger.error(f"Failed to start discovery: {e}")
            raise
    
    async def _stop_discovery(self):
        """Stop device discovery service"""
        if self.discovery_service:
            await self.discovery_service.stop()
            logger.info("Device discovery stopped")
    
    async def _start_sync_server(self):
        """Start sync server for incoming connections"""
        try:
            # TODO: Implement actual sync server (WebSocket or TCP)
            # For now, create a mock server
            
            class MockSyncServer:
                def __init__(self, sync_engine, port):
                    self.sync_engine = sync_engine
                    self.port = port
                    self.running = False
                
                async def start(self):
                    self.running = True
                    logger.info(f"Mock sync server started on port {self.port}")
                
                async def stop(self):
                    self.running = False
                    logger.info("Mock sync server stopped")
            
            self.sync_server = MockSyncServer(self, self.sync_port)
            await self.sync_server.start()
            
        except Exception as e:
            logger.error(f"Failed to start sync server: {e}")
            raise
    
    async def _stop_sync_server(self):
        """Stop sync server"""
        if self.sync_server:
            await self.sync_server.stop()
    
    def _setup_event_handlers(self):
        """Setup event bus handlers"""
        self.event_bus.subscribe_async(EventType.SYNC_DELTA.value, self._handle_sync_delta)
        self.event_bus.subscribe_async(EventType.MEMORY_WRITE.value, self._handle_memory_write)
    
    async def _handle_sync_delta(self, event):
        """Handle incoming sync delta"""
        delta_data = event.payload
        await self._apply_sync_operation(delta_data)
    
    async def _handle_memory_write(self, event):
        """Handle memory write events for sync"""
        # When data is written to memory, create a CRDT operation
        data = event.payload
        if data.get("sync", True):  # Only sync if explicitly enabled
            await self._create_sync_operation("update", data)
    
    async def add_device(self, device_info: DeviceInfo):
        """Add a discovered device"""
        device_id = device_info.device_id
        
        if device_id == self.device_id:
            return  # Don't add ourselves
        
        self.connected_devices[device_id] = device_info
        self.metrics["devices_discovered"] += 1
        
        # Initialize vector clock entry
        if device_id not in self.vector_clock:
            self.vector_clock[device_id] = 0
        
        # Attempt connection if device is trusted
        if device_info.is_trusted:
            await self._connect_to_device(device_info)
        
        # Publish device connected event
        await self.event_bus.publish(
            EventType.SYNC_DEVICE_CONNECTED.value,
            {
                "device_id": device_id,
                "device_name": device_info.device_name,
                "device_type": device_info.device_type
            }
        )
        
        logger.info(f"Added device: {device_info.device_name} ({device_id})")
    
    async def remove_device(self, device_id: str):
        """Remove a device"""
        if device_id in self.connected_devices:
            device_info = self.connected_devices[device_id]
            del self.connected_devices[device_id]
            
            # Close connection
            await self._close_connection(device_id)
            
            # Publish device disconnected event
            await self.event_bus.publish(
                EventType.SYNC_DEVICE_DISCONNECTED.value,
                {
                    "device_id": device_id,
                    "device_name": device_info.device_name
                }
            )
            
            logger.info(f"Removed device: {device_info.device_name} ({device_id})")
    
    async def _connect_to_device(self, device_info: DeviceInfo):
        """Establish connection to a device"""
        device_id = device_info.device_id
        
        try:
            # TODO: Implement actual connection (WebRTC, TCP, etc.)
            # For now, create a mock connection
            
            class MockConnection:
                def __init__(self, device_info):
                    self.device_info = device_info
                    self.connected = True
                
                async def send(self, data):
                    # Mock sending data
                    pass
                
                async def close(self):
                    self.connected = False
            
            connection = MockConnection(device_info)
            self.connections[device_id] = connection
            self.metrics["devices_connected"] += 1
            
            # Start initial sync
            await self._initial_sync(device_id)
            
            logger.info(f"Connected to device: {device_info.device_name}")
            
        except Exception as e:
            logger.error(f"Failed to connect to {device_id}: {e}")
            self.metrics["sync_errors"] += 1
    
    async def _close_connection(self, device_id: str):
        """Close connection to a device"""
        if device_id in self.connections:
            connection = self.connections[device_id]
            await connection.close()
            del self.connections[device_id]
            logger.debug(f"Closed connection to {device_id}")
    
    async def _initial_sync(self, device_id: str):
        """Perform initial sync with a device"""
        try:
            # Send our vector clock and document list
            sync_message = {
                "type": "initial_sync",
                "vector_clock": self.vector_clock,
                "documents": [
                    {
                        "id": doc.document_id,
                        "type": doc.document_type,
                        "vector_clock": doc.vector_clock,
                        "last_modified": doc.last_modified.isoformat()
                    }
                    for doc in self.documents.values()
                ]
            }
            
            await self._send_message(device_id, sync_message)
            logger.debug(f"Sent initial sync to {device_id}")
            
        except Exception as e:
            logger.error(f"Initial sync failed with {device_id}: {e}")
    
    async def _send_message(self, device_id: str, message: Dict[str, Any]):
        """Send message to a connected device"""
        if device_id not in self.connections:
            raise ValueError(f"No connection to device {device_id}")
        
        connection = self.connections[device_id]
        
        # Encrypt message
        encrypted_message = await self.security_manager.encrypt_for_device(
            json.dumps(message).encode(), device_id
        )
        
        # Send via connection
        await connection.send(encrypted_message)
        self.metrics["operations_sent"] += 1
    
    async def _create_sync_operation(self, operation_type: str, data: Dict[str, Any]):
        """Create a sync operation for changes"""
        # Increment our vector clock
        self.vector_clock[self.device_id] += 1
        
        operation = SyncOperation(
            operation_id=f"{self.device_id}_{self.vector_clock[self.device_id]}",
            device_id=self.device_id,
            document_id=data.get("document_id", "unknown"),
            operation_type=operation_type,
            data=data,
            timestamp=time.time(),
            vector_clock=self.vector_clock.copy()
        )
        
        # Sign operation
        operation.signature = await self.security_manager.sign_data(
            json.dumps(asdict(operation)).encode()
        )
        
        # Apply locally
        await self._apply_operation(operation)
        
        # Broadcast to connected devices
        await self._broadcast_operation(operation)
        
        logger.debug(f"Created sync operation: {operation.operation_id}")
    
    async def _apply_operation(self, operation: SyncOperation):
        """Apply a sync operation to local state"""
        try:
            # Update vector clock
            for device_id, clock in operation.vector_clock.items():
                self.vector_clock[device_id] = max(
                    self.vector_clock.get(device_id, 0), clock
                )
            
            # Apply to document
            doc_id = operation.document_id
            
            if operation.operation_type == "create":
                if doc_id not in self.documents:
                    self.documents[doc_id] = CRDTDocument(
                        document_id=doc_id,
                        document_type=operation.data.get("type", "unknown"),
                        content=operation.data.get("content", {}),
                        vector_clock=operation.vector_clock.copy(),
                        last_modified=datetime.fromtimestamp(operation.timestamp),
                        created_by=operation.device_id
                    )
            
            elif operation.operation_type == "update":
                if doc_id in self.documents:
                    doc = self.documents[doc_id]
                    
                    # Check if operation is newer
                    if self._is_operation_newer(operation, doc):
                        # Merge content (simple last-writer-wins for now)
                        # TODO: Implement proper CRDT merge logic
                        doc.content.update(operation.data.get("content", {}))
                        doc.vector_clock = operation.vector_clock.copy()
                        doc.last_modified = datetime.fromtimestamp(operation.timestamp)
            
            elif operation.operation_type == "delete":
                if doc_id in self.documents:
                    del self.documents[doc_id]
            
            # Persist to memory manager
            await self._persist_document(doc_id)
            
        except Exception as e:
            logger.error(f"Failed to apply operation {operation.operation_id}: {e}")
            self.metrics["sync_errors"] += 1
    
    def _is_operation_newer(self, operation: SyncOperation, document: CRDTDocument) -> bool:
        """Check if operation is newer than document using vector clocks"""
        op_clock = operation.vector_clock
        doc_clock = document.vector_clock
        
        # Check if operation clock dominates document clock
        is_newer = False
        for device_id, op_time in op_clock.items():
            doc_time = doc_clock.get(device_id, 0)
            if op_time > doc_time:
                is_newer = True
            elif op_time < doc_time:
                return False  # Operation is older
        
        return is_newer
    
    async def _broadcast_operation(self, operation: SyncOperation):
        """Broadcast operation to all connected devices"""
        message = {
            "type": "sync_operation",
            "operation": asdict(operation)
        }
        
        for device_id in self.connections:
            try:
                await self._send_message(device_id, message)
            except Exception as e:
                logger.error(f"Failed to broadcast to {device_id}: {e}")
    
    async def _persist_document(self, document_id: str):
        """Persist document to memory manager"""
        if document_id in self.documents:
            doc = self.documents[document_id]
            
            # Store in memory manager
            await self.memory_manager.store_memory_item(
                f"crdt_{doc.document_type}",
                {
                    "document_id": doc.document_id,
                    "content": doc.content,
                    "vector_clock": doc.vector_clock,
                    "created_by": doc.created_by
                },
                {"sync": False}  # Don't sync this storage operation
            )
    
    async def _apply_sync_operation(self, operation_data: Dict[str, Any]):
        """Apply incoming sync operation"""
        try:
            operation = SyncOperation(**operation_data)
            
            # Verify signature
            if not await self.security_manager.verify_signature(
                json.dumps(asdict(operation)).encode(),
                operation.signature,
                operation.device_id
            ):
                logger.warning(f"Invalid signature for operation {operation.operation_id}")
                return
            
            # Apply operation
            await self._apply_operation(operation)
            self.metrics["operations_received"] += 1
            
        except Exception as e:
            logger.error(f"Failed to apply sync operation: {e}")
            self.metrics["sync_errors"] += 1
    
    async def sync_document(self, document_id: str, document_type: str,
                          content: Dict[str, Any]):
        """Manually sync a document"""
        await self._create_sync_operation("update", {
            "document_id": document_id,
            "type": document_type,
            "content": content
        })
    
    def get_connected_devices(self) -> List[DeviceInfo]:
        """Get list of connected devices"""
        return [
            device for device in self.connected_devices.values()
            if device.device_id in self.connections
        ]
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get sync engine metrics"""
        return {
            **self.metrics,
            "state": self.state.value,
            "connected_devices": len(self.connections),
            "discovered_devices": len(self.connected_devices),
            "documents": len(self.documents),
            "vector_clock": self.vector_clock
        }
    
    def is_running(self) -> bool:
        """Check if sync engine is running"""
        return self.state not in [SyncState.STOPPED, SyncState.ERROR]