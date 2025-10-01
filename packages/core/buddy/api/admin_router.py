"""
Admin API Router

REST endpoints for system administration:
- System status and health checks
- Configuration management
- Metrics and monitoring
- Log access and debugging
"""

import logging
import platform
import psutil
from datetime import datetime
from typing import Dict, Any, Optional
from fastapi import APIRouter, HTTPException, Request, Query
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter()


class ConfigUpdateRequest(BaseModel):
    """Request model for configuration updates"""
    key: str
    value: Any


@router.get("/health")
async def health_check(request: Request):
    """Comprehensive health check of all system components"""
    try:
        # Check all components
        event_bus = request.app.state.event_bus
        voice_pipeline = request.app.state.voice_pipeline
        skill_registry = request.app.state.skill_registry
        memory_manager = request.app.state.memory_manager
        sync_engine = request.app.state.sync_engine
        security_manager = request.app.state.security_manager
        
        health_status = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "components": {
                "event_bus": {
                    "status": "healthy" if event_bus and event_bus.is_running() else "unhealthy",
                    "running": event_bus.is_running() if event_bus else False
                },
                "voice_pipeline": {
                    "status": "healthy" if voice_pipeline and voice_pipeline.is_ready() else "unhealthy",
                    "ready": voice_pipeline.is_ready() if voice_pipeline else False,
                    "state": voice_pipeline.state.value if voice_pipeline else "unknown"
                },
                "skill_registry": {
                    "status": "healthy" if skill_registry else "unhealthy",
                    "skills_loaded": len(skill_registry._skills) if skill_registry else 0
                },
                "memory_manager": {
                    "status": "healthy" if memory_manager and memory_manager.is_ready() else "unhealthy",
                    "ready": memory_manager.is_ready() if memory_manager else False
                },
                "sync_engine": {
                    "status": "healthy" if sync_engine and sync_engine.is_running() else "disabled",
                    "running": sync_engine.is_running() if sync_engine else False,
                    "connected_devices": len(sync_engine.connections) if sync_engine else 0
                },
                "security_manager": {
                    "status": "healthy" if security_manager else "unhealthy",
                    "trusted_devices": len(security_manager.trusted_devices) if security_manager else 0
                }
            }
        }
        
        # Determine overall status
        unhealthy_components = [
            name for name, info in health_status["components"].items()
            if info["status"] == "unhealthy"
        ]
        
        if unhealthy_components:
            health_status["status"] = "degraded"
            health_status["issues"] = unhealthy_components
        
        return health_status
    
    except Exception as e:
        logger.error(f"Health check error: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


@router.get("/system")
async def get_system_info():
    """Get system information"""
    try:
        # Get system information
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return {
            "platform": {
                "system": platform.system(),
                "machine": platform.machine(),
                "processor": platform.processor(),
                "python_version": platform.python_version(),
                "hostname": platform.node()
            },
            "resources": {
                "cpu": {
                    "usage_percent": cpu_percent,
                    "cores": psutil.cpu_count(),
                    "cores_logical": psutil.cpu_count(logical=True)
                },
                "memory": {
                    "total_gb": round(memory.total / (1024**3), 2),
                    "available_gb": round(memory.available / (1024**3), 2),
                    "used_gb": round(memory.used / (1024**3), 2),
                    "percent": memory.percent
                },
                "disk": {
                    "total_gb": round(disk.total / (1024**3), 2),
                    "free_gb": round(disk.free / (1024**3), 2),
                    "used_gb": round(disk.used / (1024**3), 2),
                    "percent": round((disk.used / disk.total) * 100, 1)
                }
            }
        }
    
    except Exception as e:
        logger.error(f"System info error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics")
async def get_system_metrics(request: Request):
    """Get comprehensive system metrics"""
    try:
        metrics = {
            "timestamp": datetime.utcnow().isoformat(),
            "uptime_seconds": 0,  # TODO: Track application uptime
            "components": {}
        }
        
        # Collect metrics from all components
        if hasattr(request.app.state, 'event_bus') and request.app.state.event_bus:
            metrics["components"]["event_bus"] = request.app.state.event_bus.get_metrics()
        
        if hasattr(request.app.state, 'voice_pipeline') and request.app.state.voice_pipeline:
            metrics["components"]["voice_pipeline"] = request.app.state.voice_pipeline.get_metrics()
        
        if hasattr(request.app.state, 'skill_registry') and request.app.state.skill_registry:
            metrics["components"]["skill_registry"] = request.app.state.skill_registry.get_execution_stats()
        
        if hasattr(request.app.state, 'memory_manager') and request.app.state.memory_manager:
            metrics["components"]["memory_manager"] = await request.app.state.memory_manager.get_metrics()
        
        if hasattr(request.app.state, 'sync_engine') and request.app.state.sync_engine:
            metrics["components"]["sync_engine"] = request.app.state.sync_engine.get_metrics()
        
        if hasattr(request.app.state, 'security_manager') and request.app.state.security_manager:
            metrics["components"]["security_manager"] = request.app.state.security_manager.get_metrics()
        
        return metrics
    
    except Exception as e:
        logger.error(f"Metrics error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/config")
async def get_configuration():
    """Get current system configuration"""
    try:
        from buddy.config import settings
        
        # Return non-sensitive configuration
        config = {
            "debug": settings.DEBUG,
            "log_level": settings.LOG_LEVEL,
            "host": settings.HOST,
            "port": settings.PORT,
            "data_dir": str(settings.DATA_DIR),
            "models_dir": str(settings.MODELS_DIR),
            "voice": {
                "enable_wake_word": settings.ENABLE_WAKE_WORD,
                "wake_word_model": settings.WAKE_WORD_MODEL,
                "asr_model": settings.ASR_MODEL,
                "tts_model": settings.TTS_MODEL,
                "tts_voice": settings.TTS_VOICE
            },
            "memory": {
                "max_conversation_history": settings.MAX_CONVERSATION_HISTORY
            },
            "sync": {
                "enable_sync": settings.ENABLE_SYNC,
                "sync_port": settings.SYNC_PORT
            },
            "features": {
                "enable_web_ui": settings.ENABLE_WEB_UI,
                "enable_telemetry": settings.ENABLE_TELEMETRY,
                "enable_cloud_connectors": settings.ENABLE_CLOUD_CONNECTORS
            }
        }
        
        return config
    
    except Exception as e:
        logger.error(f"Config retrieval error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/config")
async def update_configuration(config_request: ConfigUpdateRequest):
    """Update system configuration"""
    try:
        # TODO: Implement configuration updates
        # This would need to validate the key/value and update settings
        # Some changes might require component restarts
        
        return {
            "success": True,
            "key": config_request.key,
            "value": config_request.value,
            "message": "Configuration update queued (restart may be required)"
        }
    
    except Exception as e:
        logger.error(f"Config update error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/logs")
async def get_logs(
    level: Optional[str] = Query("INFO", regex="^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$"),
    lines: int = Query(100, ge=1, le=10000),
    component: Optional[str] = None
):
    """Get recent log entries"""
    try:
        # TODO: Implement log retrieval
        # This would read from log files or in-memory log buffer
        
        return {
            "logs": [
                {
                    "timestamp": "2024-01-01T12:00:00Z",
                    "level": "INFO",
                    "component": "voice_pipeline",
                    "message": "Mock log entry - implement log retrieval"
                }
            ],
            "total": 1,
            "level": level,
            "lines": lines,
            "component": component
        }
    
    except Exception as e:
        logger.error(f"Log retrieval error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/restart")
async def restart_system():
    """Restart the BUDDY system"""
    try:
        # TODO: Implement graceful system restart
        return {
            "success": True,
            "message": "System restart initiated"
        }
    
    except Exception as e:
        logger.error(f"Restart error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/components/{component}/restart")
async def restart_component(component: str):
    """Restart a specific component"""
    try:
        # TODO: Implement component-specific restarts
        valid_components = ["voice_pipeline", "sync_engine", "memory_manager"]
        
        if component not in valid_components:
            raise HTTPException(status_code=400, detail=f"Invalid component: {component}")
        
        return {
            "success": True,
            "component": component,
            "message": f"Component {component} restart initiated"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Component restart error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/debug/events")
async def get_event_history(request: Request, limit: int = Query(50, ge=1, le=1000)):
    """Get recent event history for debugging"""
    try:
        event_bus = request.app.state.event_bus
        
        if not event_bus:
            return {"events": [], "message": "Event bus not available"}
        
        history = event_bus.get_history(limit=limit)
        
        return {
            "events": [
                {
                    "type": event.type,
                    "payload": event.payload,
                    "timestamp": event.timestamp.isoformat(),
                    "device_id": event.device_id,
                    "session_id": event.session_id,
                    "correlation_id": event.correlation_id
                }
                for event in history
            ],
            "total": len(history),
            "limit": limit
        }
    
    except Exception as e:
        logger.error(f"Event history error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/debug/events")
async def clear_event_history(request: Request):
    """Clear event history"""
    try:
        event_bus = request.app.state.event_bus
        
        if event_bus:
            event_bus.clear_history()
        
        return {
            "success": True,
            "message": "Event history cleared"
        }
    
    except Exception as e:
        logger.error(f"Clear event history error: {e}")
        raise HTTPException(status_code=500, detail=str(e))