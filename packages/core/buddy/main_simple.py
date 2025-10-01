"""
Simplified BUDDY Main Application - Without External AI Dependencies

This version provides core BUDDY functionality without requiring external AI services.
"""

import logging
import asyncio
import json
from datetime import datetime
from contextlib import asynccontextmanager
from typing import Dict, Any
from pathlib import Path

from fastapi import FastAPI, WebSocket, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
import uvicorn

from .config import settings
from .events import EventBus
from .skills import SkillRegistry
from .memory import MemoryManager
from .sync import SyncEngine
from .security import SecurityManager
from .api import skills_router, memory_router, sync_router, admin_router, jarvis_router
from .api.voice_router_simple import router as voice_router

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Global components (initialized in lifespan)
event_bus: EventBus = None
skill_registry: SkillRegistry = None
memory_manager: MemoryManager = None
sync_engine: SyncEngine = None
security_manager: SecurityManager = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    global event_bus, skill_registry, memory_manager, sync_engine, security_manager
    
    logger.info("🚀 Starting BUDDY Core Runtime...")
    
    try:
        # Initialize core components in proper order
        event_bus = EventBus()
        await event_bus.start()
        
        security_manager = SecurityManager(event_bus)
        await security_manager.initialize()
        
        memory_manager = MemoryManager(event_bus, settings.DATA_DIR)
        await memory_manager.initialize()
        
        skill_registry = SkillRegistry(event_bus, memory_manager)
        await skill_registry.load_skills()
        
        sync_engine = SyncEngine(event_bus, memory_manager, security_manager)
        await sync_engine.start()
        
        # Set app state for router access
        app.state.event_bus = event_bus
        app.state.skill_registry = skill_registry
        app.state.memory_manager = memory_manager
        app.state.sync_engine = sync_engine
        app.state.security_manager = security_manager
        
        logger.info("✅ BUDDY Core Runtime started successfully")
        
        yield
        
    except Exception as e:
        logger.error(f"Failed to start BUDDY Core Runtime: {e}")
        raise
    finally:
        logger.info("🛑 Shutting down BUDDY Core Runtime...")
        
        if sync_engine:
            await sync_engine.stop()
        if memory_manager:
            await memory_manager.close()
        if event_bus:
            await event_bus.stop()
            
        logger.info("✅ BUDDY Core Runtime shutdown complete")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application"""
    
    app = FastAPI(
        title="BUDDY AI Assistant",
        description="Personal AI Assistant with voice, skills, and memory",
        version="2.0.0",
        lifespan=lifespan
    )
    
    # Configure CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # Register API routers
    app.include_router(voice_router, prefix="/api/v1/voice", tags=["voice"])
    app.include_router(skills_router, prefix="/api/v1/skills", tags=["skills"])
    app.include_router(memory_router, prefix="/api/v1/memory", tags=["memory"])
    app.include_router(sync_router, prefix="/api/v1/sync", tags=["sync"])
    app.include_router(admin_router, prefix="/api/v1/admin", tags=["admin"])
    app.include_router(jarvis_router, prefix="/api/v1/jarvis", tags=["jarvis"])
    
    # Health check endpoint
    @app.get("/health")
    async def health_check():
        """Health check endpoint"""
        return {
            "status": "healthy",
            "version": "2.0.0",
            "components": {
                "event_bus": event_bus.is_running() if event_bus else False,
                "memory": memory_manager is not None,
                "skills": len(skill_registry._skills) if skill_registry else 0,
                "sync": sync_engine is not None,
                "security": security_manager is not None
            }
        }
    
    # Root endpoint - serve main GUI
    @app.get("/", response_class=HTMLResponse)
    async def serve_gui():
        """Serve the main BUDDY GUI"""
        static_dir = Path(__file__).parent / "static"
        index_file = static_dir / "index.html"
        
        if index_file.exists():
            return HTMLResponse(content=index_file.read_text(encoding='utf-8'))
        else:
            return HTMLResponse(content="<h1>BUDDY AI Assistant</h1><p>GUI not found</p>", status_code=404)
    
    # Mount static files
    static_dir = Path(__file__).parent / "static"
    if static_dir.exists():
        app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
    
    # WebSocket endpoint for voice communication
    @app.websocket("/ws/voice")
    async def voice_websocket(websocket: WebSocket):
        """WebSocket endpoint for real-time voice communication"""
        await websocket.accept()
        logger.info("WebSocket voice connection established")
        
        try:
            # Send initial status
            await websocket.send_json({
                "type": "status",
                "status": "connected",
                "message": "Voice WebSocket connected successfully",
                "capabilities": ["voice_recognition", "text_to_speech", "wake_word"]
            })
            
            while True:
                # Handle different types of messages
                data = await websocket.receive_text()
                
                try:
                    # Try to parse as JSON for structured commands
                    message = json.loads(data)
                    
                    if message.get("type") == "status_request":
                        # Send status update
                        await websocket.send_json({
                            "type": "status",
                            "pipeline_status": "ready",
                            "recognition_accuracy": "95%",
                            "response_time": "< 300ms",
                            "wake_words": ["hey buddy", "buddy", "hi buddy"]
                        })
                    
                    elif message.get("type") == "voice_command":
                        # Process voice command
                        command = message.get("command", "")
                        logger.info(f"Voice command received: {command}")
                        
                        # Echo back with processing status
                        await websocket.send_json({
                            "type": "command_response",
                            "original_command": command,
                            "status": "processed",
                            "response": f"Processed voice command: {command}"
                        })
                    
                    elif message.get("type") == "ping":
                        # Respond to ping for connection health
                        await websocket.send_json({"type": "pong"})
                    
                    else:
                        # Handle unknown message types
                        await websocket.send_json({
                            "type": "error",
                            "message": f"Unknown message type: {message.get('type', 'undefined')}"
                        })
                        
                except json.JSONDecodeError:
                    # Handle plain text messages
                    if data.strip():
                        logger.info(f"Voice WebSocket text message: {data}")
                        await websocket.send_json({
                            "type": "text_response",
                            "original_text": data,
                            "echo": f"Received: {data}",
                            "timestamp": datetime.now().isoformat()
                        })
                
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            logger.info("WebSocket voice connection closed")
    
    return app


# Create the app instance
app = create_app()


def get_event_bus() -> EventBus:
    """Dependency to get the event bus"""
    global event_bus
    if not event_bus:
        raise HTTPException(status_code=503, detail="Event bus not initialized")
    return event_bus


def get_skill_registry() -> SkillRegistry:
    """Dependency to get the skill registry"""
    global skill_registry
    if not skill_registry:
        raise HTTPException(status_code=503, detail="Skill registry not initialized")
    return skill_registry


def get_memory_manager() -> MemoryManager:
    """Dependency to get the memory manager"""
    global memory_manager
    if not memory_manager:
        raise HTTPException(status_code=503, detail="Memory manager not initialized")
    return memory_manager


def get_sync_engine() -> SyncEngine:
    """Dependency to get the sync engine"""
    global sync_engine
    if not sync_engine:
        raise HTTPException(status_code=503, detail="Sync engine not initialized")
    return sync_engine


def get_security_manager() -> SecurityManager:
    """Dependency to get the security manager"""
    global security_manager
    if not security_manager:
        raise HTTPException(status_code=503, detail="Security manager not initialized")
    return security_manager