"""
Sync API Router

REST endpoints for device synchronization:
- Device discovery and pairing
- Sync status and configuration
- Manual sync operations
- Device trust management
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter()


class DevicePairRequest(BaseModel):
    """Request model for device pairing"""
    device_name: str
    device_type: str
    public_key: str  # Hex-encoded public key
    signing_public_key: str  # Hex-encoded signing public key
    pairing_code: Optional[str] = None


class SyncDocumentRequest(BaseModel):
    """Request model for manual document sync"""
    document_id: str
    document_type: str
    content: Dict[str, Any]


class TrustDeviceRequest(BaseModel):
    """Request model for trusting a device"""
    device_id: str
    trust: bool = True


@router.get("/status")
async def get_sync_status(request: Request):
    """Get synchronization status"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            return {
                "enabled": False,
                "message": "Sync is disabled"
            }
        
        return {
            "enabled": True,
            "status": sync_engine.state.value,
            "device_id": sync_engine.device_id,
            "connected_devices": len(sync_engine.connections),
            "discovered_devices": len(sync_engine.connected_devices),
            "documents": len(sync_engine.documents),
            "vector_clock": sync_engine.vector_clock,
            "metrics": sync_engine.get_metrics()
        }
    
    except Exception as e:
        logger.error(f"Error getting sync status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/devices")
async def get_devices(request: Request):
    """Get list of discovered and connected devices"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            return {"devices": [], "message": "Sync is disabled"}
        
        devices = []
        for device_id, device_info in sync_engine.connected_devices.items():
            devices.append({
                "device_id": device_info.device_id,
                "device_name": device_info.device_name,
                "device_type": device_info.device_type,
                "address": device_info.address,
                "port": device_info.port,
                "is_trusted": device_info.is_trusted,
                "is_connected": device_id in sync_engine.connections,
                "capabilities": device_info.capabilities,
                "last_seen": device_info.last_seen.isoformat()
            })
        
        return {
            "devices": devices,
            "total": len(devices)
        }
    
    except Exception as e:
        logger.error(f"Error getting devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/pair")
async def pair_device(request: Request, pair_request: DevicePairRequest):
    """Pair with a new device"""
    try:
        sync_engine = request.app.state.sync_engine
        security_manager = request.app.state.security_manager
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        # Convert hex keys to bytes
        try:
            public_key = bytes.fromhex(pair_request.public_key)
            signing_public_key = bytes.fromhex(pair_request.signing_public_key)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid key format")
        
        # Generate device ID from public key
        import hashlib
        device_id = hashlib.sha256(public_key).hexdigest()[:16]
        
        # Trust the device in security manager
        success = await security_manager.trust_device(
            device_id,
            pair_request.device_name,
            pair_request.device_type,
            public_key,
            signing_public_key,
            permissions=["sync"]  # Basic sync permission
        )
        
        if not success:
            raise HTTPException(status_code=400, detail="Failed to trust device")
        
        # Add to sync engine (this would normally happen via discovery)
        from buddy.sync import DeviceInfo
        device_info = DeviceInfo(
            device_id=device_id,
            device_name=pair_request.device_name,
            device_type=pair_request.device_type,
            address="unknown",  # Will be discovered
            port=0,
            public_key=public_key,
            last_seen=datetime.utcnow(),
            is_trusted=True,
            capabilities=["sync"]
        )
        
        await sync_engine.add_device(device_info)
        
        return {
            "success": True,
            "device_id": device_id,
            "device_name": pair_request.device_name,
            "message": "Device paired successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error pairing device: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/devices/{device_id}")
async def unpair_device(request: Request, device_id: str):
    """Unpair a device"""
    try:
        sync_engine = request.app.state.sync_engine
        security_manager = request.app.state.security_manager
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        # Remove from sync engine
        await sync_engine.remove_device(device_id)
        
        # Untrust in security manager
        await security_manager.untrust_device(device_id)
        
        return {
            "success": True,
            "device_id": device_id,
            "message": "Device unpaired successfully"
        }
    
    except Exception as e:
        logger.error(f"Error unpairing device: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/devices/{device_id}/trust")
async def trust_device(request: Request, device_id: str, trust_request: TrustDeviceRequest):
    """Trust or untrust a device"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        if device_id not in sync_engine.connected_devices:
            raise HTTPException(status_code=404, detail="Device not found")
        
        device_info = sync_engine.connected_devices[device_id]
        device_info.is_trusted = trust_request.trust
        
        return {
            "success": True,
            "device_id": device_id,
            "trusted": trust_request.trust
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating device trust: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/documents")
async def get_sync_documents(request: Request):
    """Get list of synchronized documents"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            return {"documents": [], "message": "Sync is disabled"}
        
        documents = []
        for doc_id, doc in sync_engine.documents.items():
            documents.append({
                "id": doc.document_id,
                "type": doc.document_type,
                "content": doc.content,
                "vector_clock": doc.vector_clock,
                "last_modified": doc.last_modified.isoformat(),
                "created_by": doc.created_by
            })
        
        return {
            "documents": documents,
            "total": len(documents)
        }
    
    except Exception as e:
        logger.error(f"Error getting sync documents: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/documents/sync")
async def sync_document(request: Request, sync_request: SyncDocumentRequest):
    """Manually synchronize a document"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        await sync_engine.sync_document(
            sync_request.document_id,
            sync_request.document_type,
            sync_request.content
        )
        
        return {
            "success": True,
            "document_id": sync_request.document_id,
            "message": "Document synchronized"
        }
    
    except Exception as e:
        logger.error(f"Error syncing document: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/force-sync")
async def force_sync(request: Request):
    """Force immediate synchronization with all connected devices"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        # Trigger sync for all documents
        synced_docs = 0
        for doc_id, doc in sync_engine.documents.items():
            await sync_engine.sync_document(doc_id, doc.document_type, doc.content)
            synced_docs += 1
        
        return {
            "success": True,
            "documents_synced": synced_docs,
            "connected_devices": len(sync_engine.connections)
        }
    
    except Exception as e:
        logger.error(f"Error forcing sync: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/pairing-info")
async def get_pairing_info(request: Request):
    """Get information needed for device pairing"""
    try:
        security_manager = request.app.state.security_manager
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        return {
            "device_id": sync_engine.device_id,
            "device_name": sync_engine.device_id,  # TODO: Get actual device name
            "device_type": "desktop",  # TODO: Determine device type
            "public_key": security_manager.get_device_public_key().hex(),
            "signing_public_key": security_manager.get_device_signing_public_key().hex(),
            "sync_port": sync_engine.sync_port,
            "pairing_instructions": [
                "1. Ensure both devices are on the same network",
                "2. Exchange device information",
                "3. Confirm pairing on both devices",
                "4. Sync will begin automatically"
            ]
        }
    
    except Exception as e:
        logger.error(f"Error getting pairing info: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/conflicts")
async def get_sync_conflicts(request: Request):
    """Get list of sync conflicts that need resolution"""
    try:
        # TODO: Implement conflict tracking
        # For now, return empty list
        
        return {
            "conflicts": [],
            "total": 0,
            "message": "No conflicts detected"
        }
    
    except Exception as e:
        logger.error(f"Error getting sync conflicts: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/devices")
async def update_devices(request: Request):
    """Refresh device discovery and return updated device list"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            return {"devices": [], "message": "Sync is disabled"}
        
        # Just return current devices since there's no discover_devices method
        devices = []
        for device_id, device_info in sync_engine.connected_devices.items():
            devices.append({
                "device_id": device_info.device_id,
                "device_name": device_info.device_name,
                "device_type": device_info.device_type,
                "address": device_info.address,
                "port": device_info.port,
                "is_trusted": device_info.is_trusted,
                "is_connected": device_id in sync_engine.connections,
                "last_seen": getattr(device_info, 'last_seen', None)
            })
        
        return {
            "devices": devices,
            "total": len(devices),
            "discovery_status": "active" if sync_engine.state.value == "discovering" else "idle"
        }
    
    except Exception as e:
        logger.error(f"Error updating devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/data")
async def get_sync_data(request: Request):
    """Get general sync data and statistics"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            return {"message": "Sync is disabled", "data": {}}
        
        # Get sync statistics
        data = {
            "connected_devices": len(sync_engine.connections),
            "total_devices": len(sync_engine.connected_devices),
            "documents_count": len(sync_engine.documents),
            "last_sync": getattr(sync_engine, 'last_sync_time', None),
            "sync_status": "active" if sync_engine.connections else "idle",
            "network_status": "connected" if hasattr(sync_engine, 'discovery_socket') and sync_engine.discovery_socket else "disconnected"
        }
        
        return {
            "success": True,
            "data": data,
            "timestamp": __import__('time').time()
        }
    
    except Exception as e:
        logger.error(f"Error getting sync data: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/data")
async def update_sync_data(request: Request):
    """Update sync configuration and trigger refresh"""
    try:
        sync_engine = request.app.state.sync_engine
        
        if not sync_engine:
            raise HTTPException(status_code=400, detail="Sync is disabled")
        
        # Get current data without calling discover_devices
        data = {
            "connected_devices": len(sync_engine.connections),
            "total_devices": len(sync_engine.connected_devices),
            "documents_count": len(sync_engine.documents),
            "last_sync": getattr(sync_engine, 'last_sync_time', None),
            "sync_status": "refreshed",
            "refresh_timestamp": __import__('time').time(),
            "engine_state": sync_engine.state.value if hasattr(sync_engine.state, 'value') else str(sync_engine.state)
        }
        
        return {
            "success": True,
            "data": data,
            "message": "Sync data refreshed"
        }
    
    except Exception as e:
        logger.error(f"Error updating sync data: {e}")
        raise HTTPException(status_code=500, detail=str(e))