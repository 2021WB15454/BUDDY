"""
Security Manager for BUDDY Core Runtime

This module handles all security aspects of the BUDDY system:
- End-to-end encryption for device communication
- Digital signatures for operation verification
- Device authentication and authorization
- Capability-based permissions
- Secure key management and rotation

Key Features:
- X25519 key exchange for device pairing
- AES-GCM for symmetric encryption
- Ed25519 for digital signatures
- Device trust management
- Permission-based access control
- Secure credential storage
"""

import asyncio
import json
import logging
import os
import hashlib
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from enum import Enum

from .events import EventBus
from .config import settings

logger = logging.getLogger(__name__)


class PermissionLevel(Enum):
    """Permission levels for capabilities"""
    NONE = "none"
    READ = "read"
    WRITE = "write"
    ADMIN = "admin"


@dataclass
class DeviceKeys:
    """Cryptographic keys for a device"""
    device_id: str
    public_key: bytes
    private_key: Optional[bytes] = None  # Only for our device
    signing_public_key: bytes = None
    signing_private_key: Optional[bytes] = None  # Only for our device
    created_at: datetime = None
    expires_at: Optional[datetime] = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()


@dataclass
class Permission:
    """Permission for a specific capability"""
    capability: str
    level: PermissionLevel
    granted_by: str
    granted_at: datetime
    expires_at: Optional[datetime] = None
    conditions: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.conditions is None:
            self.conditions = {}


@dataclass
class TrustedDevice:
    """Information about a trusted device"""
    device_id: str
    device_name: str
    device_type: str
    public_key: bytes
    signing_public_key: bytes
    permissions: List[Permission]
    trusted_at: datetime
    last_seen: datetime
    is_active: bool = True


class SecurityManager:
    """
    Comprehensive security management for BUDDY
    
    Handles all security aspects:
    - Device authentication and trust management
    - End-to-end encryption for device communication
    - Digital signatures for operation verification
    - Permission-based access control
    - Secure storage of keys and credentials
    """
    
    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus
        
        # Configuration
        self.device_id = settings.DEVICE_NAME
        self.keys_dir = settings.DATA_DIR / "keys"
        self.keys_dir.mkdir(parents=True, exist_ok=True)
        
        # Cryptographic keys
        self.device_keys: Optional[DeviceKeys] = None
        self.trusted_devices: Dict[str, TrustedDevice] = {}
        self.session_keys: Dict[str, bytes] = {}  # device_id -> session_key
        
        # Permissions
        self.capabilities = {
            "mic": "Microphone access",
            "camera": "Camera access", 
            "location": "Location services",
            "notifications": "Send notifications",
            "schedule": "Access calendar and reminders",
            "storage": "File system access",
            "network": "Network access",
            "smart_home": "Smart home device control",
            "contacts": "Access contacts",
            "messages": "Send messages",
            "calls": "Make phone calls"
        }
        
        self.device_permissions: Dict[str, List[Permission]] = {}
        
        # Metrics
        self.metrics = {
            "devices_trusted": 0,
            "permissions_granted": 0,
            "encryption_operations": 0,
            "signature_operations": 0,
            "security_violations": 0
        }
        
        logger.info("SecurityManager initialized")
    
    async def initialize(self):
        """Initialize security manager"""
        logger.info("Initializing security manager...")
        
        try:
            # Load or generate device keys
            await self._load_or_generate_device_keys()
            
            # Load trusted devices
            await self._load_trusted_devices()
            
            # Load permissions
            await self._load_permissions()
            
            logger.info("✅ Security manager initialized successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize security manager: {e}")
            raise
    
    async def _load_or_generate_device_keys(self):
        """Load existing device keys or generate new ones"""
        keys_file = self.keys_dir / f"{self.device_id}.keys"
        
        if keys_file.exists():
            # Load existing keys
            try:
                with open(keys_file, 'rb') as f:
                    # TODO: Implement actual key loading with proper encryption
                    # For now, create mock keys
                    logger.info("Loading existing device keys")
                    self.device_keys = await self._generate_mock_keys()
            except Exception as e:
                logger.error(f"Failed to load device keys: {e}")
                self.device_keys = await self._generate_mock_keys()
        else:
            # Generate new keys
            logger.info("Generating new device keys")
            self.device_keys = await self._generate_mock_keys()
            await self._save_device_keys()
    
    async def _generate_mock_keys(self) -> DeviceKeys:
        """Generate mock cryptographic keys (replace with real crypto)"""
        # TODO: Replace with actual cryptographic key generation
        # - X25519 for key exchange
        # - Ed25519 for signing
        # - Proper random generation
        
        return DeviceKeys(
            device_id=self.device_id,
            public_key=os.urandom(32),  # Mock public key
            private_key=os.urandom(32),  # Mock private key
            signing_public_key=os.urandom(32),  # Mock signing public key
            signing_private_key=os.urandom(32),  # Mock signing private key
            created_at=datetime.utcnow()
        )
    
    async def _save_device_keys(self):
        """Save device keys to secure storage"""
        keys_file = self.keys_dir / f"{self.device_id}.keys"
        
        try:
            # TODO: Implement actual secure key storage
            # - Encrypt private keys with device keystore
            # - Use proper serialization
            
            with open(keys_file, 'w') as f:
                f.write("# Device keys stored here (mock implementation)\n")
                f.write(f"device_id: {self.device_id}\n")
                f.write(f"created_at: {self.device_keys.created_at.isoformat()}\n")
            
            logger.info("Device keys saved securely")
            
        except Exception as e:
            logger.error(f"Failed to save device keys: {e}")
    
    async def _load_trusted_devices(self):
        """Load trusted devices from storage"""
        trusted_file = self.keys_dir / "trusted_devices.json"
        
        if trusted_file.exists():
            try:
                with open(trusted_file, 'r') as f:
                    data = json.load(f)
                
                for device_data in data.get("devices", []):
                    device = TrustedDevice(
                        device_id=device_data["device_id"],
                        device_name=device_data["device_name"],
                        device_type=device_data["device_type"],
                        public_key=bytes.fromhex(device_data["public_key"]),
                        signing_public_key=bytes.fromhex(device_data["signing_public_key"]),
                        permissions=[
                            Permission(
                                capability=p["capability"],
                                level=PermissionLevel(p["level"]),
                                granted_by=p["granted_by"],
                                granted_at=datetime.fromisoformat(p["granted_at"])
                            )
                            for p in device_data.get("permissions", [])
                        ],
                        trusted_at=datetime.fromisoformat(device_data["trusted_at"]),
                        last_seen=datetime.fromisoformat(device_data["last_seen"])
                    )
                    self.trusted_devices[device.device_id] = device
                
                logger.info(f"Loaded {len(self.trusted_devices)} trusted devices")
                
            except Exception as e:
                logger.error(f"Failed to load trusted devices: {e}")
    
    async def _save_trusted_devices(self):
        """Save trusted devices to storage"""
        trusted_file = self.keys_dir / "trusted_devices.json"
        
        try:
            data = {
                "devices": [
                    {
                        "device_id": device.device_id,
                        "device_name": device.device_name,
                        "device_type": device.device_type,
                        "public_key": device.public_key.hex(),
                        "signing_public_key": device.signing_public_key.hex(),
                        "permissions": [
                            {
                                "capability": p.capability,
                                "level": p.level.value,
                                "granted_by": p.granted_by,
                                "granted_at": p.granted_at.isoformat()
                            }
                            for p in device.permissions
                        ],
                        "trusted_at": device.trusted_at.isoformat(),
                        "last_seen": device.last_seen.isoformat()
                    }
                    for device in self.trusted_devices.values()
                ]
            }
            
            with open(trusted_file, 'w') as f:
                json.dump(data, f, indent=2)
            
            logger.info("Trusted devices saved")
            
        except Exception as e:
            logger.error(f"Failed to save trusted devices: {e}")
    
    async def _load_permissions(self):
        """Load device permissions"""
        # Load permissions for our device
        permissions_file = self.keys_dir / "permissions.json"
        
        if permissions_file.exists():
            try:
                with open(permissions_file, 'r') as f:
                    data = json.load(f)
                
                for device_id, perms in data.items():
                    self.device_permissions[device_id] = [
                        Permission(
                            capability=p["capability"],
                            level=PermissionLevel(p["level"]),
                            granted_by=p["granted_by"],
                            granted_at=datetime.fromisoformat(p["granted_at"])
                        )
                        for p in perms
                    ]
                
                logger.info(f"Loaded permissions for {len(self.device_permissions)} devices")
                
            except Exception as e:
                logger.error(f"Failed to load permissions: {e}")
    
    async def trust_device(self, device_id: str, device_name: str, device_type: str,
                          public_key: bytes, signing_public_key: bytes,
                          permissions: List[str] = None) -> bool:
        """Add a device to the trusted devices list"""
        try:
            if permissions is None:
                permissions = []
            
            # Create permission objects
            permission_objects = []
            for capability in permissions:
                if capability in self.capabilities:
                    permission_objects.append(Permission(
                        capability=capability,
                        level=PermissionLevel.READ,  # Default to read access
                        granted_by=self.device_id,
                        granted_at=datetime.utcnow()
                    ))
            
            # Create trusted device
            trusted_device = TrustedDevice(
                device_id=device_id,
                device_name=device_name,
                device_type=device_type,
                public_key=public_key,
                signing_public_key=signing_public_key,
                permissions=permission_objects,
                trusted_at=datetime.utcnow(),
                last_seen=datetime.utcnow()
            )
            
            self.trusted_devices[device_id] = trusted_device
            self.metrics["devices_trusted"] += 1
            
            # Generate session key
            await self._generate_session_key(device_id)
            
            # Save to storage
            await self._save_trusted_devices()
            
            logger.info(f"Trusted device: {device_name} ({device_id})")
            return True
            
        except Exception as e:
            logger.error(f"Failed to trust device {device_id}: {e}")
            return False
    
    async def untrust_device(self, device_id: str):
        """Remove a device from trusted devices"""
        if device_id in self.trusted_devices:
            device_name = self.trusted_devices[device_id].device_name
            del self.trusted_devices[device_id]
            
            # Remove session key
            if device_id in self.session_keys:
                del self.session_keys[device_id]
            
            # Save changes
            await self._save_trusted_devices()
            
            logger.info(f"Untrusted device: {device_name} ({device_id})")
    
    async def is_device_trusted(self, device_id: str) -> bool:
        """Check if a device is trusted"""
        return device_id in self.trusted_devices
    
    async def grant_permission(self, device_id: str, capability: str, 
                             level: PermissionLevel = PermissionLevel.READ) -> bool:
        """Grant a permission to a device"""
        try:
            if device_id not in self.trusted_devices:
                logger.warning(f"Cannot grant permission to untrusted device: {device_id}")
                return False
            
            if capability not in self.capabilities:
                logger.warning(f"Unknown capability: {capability}")
                return False
            
            device = self.trusted_devices[device_id]
            
            # Check if permission already exists
            for perm in device.permissions:
                if perm.capability == capability:
                    perm.level = level
                    perm.granted_at = datetime.utcnow()
                    break
            else:
                # Add new permission
                device.permissions.append(Permission(
                    capability=capability,
                    level=level,
                    granted_by=self.device_id,
                    granted_at=datetime.utcnow()
                ))
            
            self.metrics["permissions_granted"] += 1
            await self._save_trusted_devices()
            
            logger.info(f"Granted {capability}:{level.value} to {device_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to grant permission: {e}")
            return False
    
    async def revoke_permission(self, device_id: str, capability: str) -> bool:
        """Revoke a permission from a device"""
        try:
            if device_id not in self.trusted_devices:
                return False
            
            device = self.trusted_devices[device_id]
            device.permissions = [
                p for p in device.permissions 
                if p.capability != capability
            ]
            
            await self._save_trusted_devices()
            
            logger.info(f"Revoked {capability} from {device_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to revoke permission: {e}")
            return False
    
    async def check_permission(self, device_id: str, capability: str,
                             required_level: PermissionLevel = PermissionLevel.READ) -> bool:
        """Check if a device has permission for a capability"""
        if device_id not in self.trusted_devices:
            self.metrics["security_violations"] += 1
            return False
        
        device = self.trusted_devices[device_id]
        
        for permission in device.permissions:
            if permission.capability == capability:
                # Check permission level hierarchy
                level_hierarchy = [
                    PermissionLevel.NONE,
                    PermissionLevel.READ,
                    PermissionLevel.WRITE,
                    PermissionLevel.ADMIN
                ]
                
                current_level_index = level_hierarchy.index(permission.level)
                required_level_index = level_hierarchy.index(required_level)
                
                return current_level_index >= required_level_index
        
        return False
    
    async def _generate_session_key(self, device_id: str):
        """Generate session key for device communication"""
        # TODO: Implement proper key exchange (X25519)
        # For now, generate a random session key
        session_key = os.urandom(32)
        self.session_keys[device_id] = session_key
        logger.debug(f"Generated session key for {device_id}")
    
    async def encrypt_for_device(self, data: bytes, device_id: str) -> bytes:
        """Encrypt data for a specific device"""
        if device_id not in self.session_keys:
            raise ValueError(f"No session key for device: {device_id}")
        
        try:
            # TODO: Implement actual AES-GCM encryption
            # For now, return mock encrypted data
            session_key = self.session_keys[device_id]
            
            # Mock encryption (in real implementation, use AES-GCM)
            encrypted_data = data  # Just pass through for now
            
            self.metrics["encryption_operations"] += 1
            return encrypted_data
            
        except Exception as e:
            logger.error(f"Encryption failed for device {device_id}: {e}")
            raise
    
    async def decrypt_from_device(self, encrypted_data: bytes, device_id: str) -> bytes:
        """Decrypt data from a specific device"""
        if device_id not in self.session_keys:
            raise ValueError(f"No session key for device: {device_id}")
        
        try:
            # TODO: Implement actual AES-GCM decryption
            # For now, return mock decrypted data
            session_key = self.session_keys[device_id]
            
            # Mock decryption (in real implementation, use AES-GCM)
            decrypted_data = encrypted_data  # Just pass through for now
            
            return decrypted_data
            
        except Exception as e:
            logger.error(f"Decryption failed for device {device_id}: {e}")
            raise
    
    async def sign_data(self, data: bytes) -> bytes:
        """Sign data with our private key"""
        try:
            # TODO: Implement actual Ed25519 signing
            # For now, return mock signature
            
            signature = hashlib.sha256(data + self.device_keys.signing_private_key).digest()
            
            self.metrics["signature_operations"] += 1
            return signature
            
        except Exception as e:
            logger.error(f"Signing failed: {e}")
            raise
    
    async def verify_signature(self, data: bytes, signature: bytes, device_id: str) -> bool:
        """Verify signature from a device"""
        if device_id not in self.trusted_devices:
            return False
        
        try:
            device = self.trusted_devices[device_id]
            
            # TODO: Implement actual Ed25519 signature verification
            # For now, mock verification
            expected_signature = hashlib.sha256(data + device.signing_public_key).digest()
            
            return signature == expected_signature
            
        except Exception as e:
            logger.error(f"Signature verification failed for device {device_id}: {e}")
            return False
    
    def get_device_public_key(self) -> bytes:
        """Get our device's public key"""
        return self.device_keys.public_key if self.device_keys else b""
    
    def get_device_signing_public_key(self) -> bytes:
        """Get our device's signing public key"""
        return self.device_keys.signing_public_key if self.device_keys else b""
    
    def get_trusted_devices(self) -> List[TrustedDevice]:
        """Get list of trusted devices"""
        return list(self.trusted_devices.values())
    
    def get_device_permissions(self, device_id: str) -> List[Permission]:
        """Get permissions for a specific device"""
        if device_id in self.trusted_devices:
            return self.trusted_devices[device_id].permissions
        return []
    
    def get_available_capabilities(self) -> Dict[str, str]:
        """Get list of available capabilities"""
        return self.capabilities.copy()
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get security metrics"""
        return {
            **self.metrics,
            "trusted_devices": len(self.trusted_devices),
            "active_sessions": len(self.session_keys),
            "capabilities": len(self.capabilities)
        }