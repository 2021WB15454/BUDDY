"""
Main FastAPI application for BUDDY Core Runtime

This module creates and configures the main FastAPI application that serves as
backend for all BUDDY client applications. It provides REST and WebSocket APIs
for voice processing, skill execution, memory management, and device synchronization.
"""

import logging
import asyncio
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
from .voice import VoicePipeline
from .skills import SkillRegistry
from .memory import MemoryManager
from .sync import SyncEngine
from .security import SecurityManager
from .api import skills_router, memory_router, sync_router, admin_router, jarvis_router
from .api.voice_router_simple import router as voice_router
# from .api.jarvis_router import router as jarvis_router  # Disabled for simple mode

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Global components (initialized in lifespan)
event_bus: EventBus = None
voice_pipeline: VoicePipeline = None
skill_registry: SkillRegistry = None
memory_manager: MemoryManager = None
sync_engine: SyncEngine = None
security_manager: SecurityManager = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager - startup and shutdown logic"""
    
    # Startup
    logger.info("🚀 Starting BUDDY Core Runtime...")
    
    global event_bus, voice_pipeline, skill_registry, memory_manager, sync_engine, security_manager
    
    try:
        # Initialize core components
        event_bus = EventBus()
        await event_bus.start()
        
        security_manager = SecurityManager(event_bus)
        await security_manager.initialize()
        
        memory_manager = MemoryManager(event_bus, settings.DATA_DIR)
        await memory_manager.initialize()
        
        skill_registry = SkillRegistry(event_bus, memory_manager)
        await skill_registry.load_skills()
        
        voice_pipeline = VoicePipeline(event_bus, skill_registry, memory_manager)
        await voice_pipeline.initialize()
        
        sync_engine = SyncEngine(event_bus, memory_manager, security_manager)
        await sync_engine.start()
        
        # Register built-in skills
        await skill_registry.register_builtin_skills()
        
        logger.info("✅ BUDDY Core Runtime started successfully")
        
        # Store components in app state for API access
        app.state.event_bus = event_bus
        app.state.voice_pipeline = voice_pipeline
        app.state.skill_registry = skill_registry
        app.state.memory_manager = memory_manager
        app.state.sync_engine = sync_engine
        app.state.security_manager = security_manager
        
    except Exception as e:
        logger.error(f"❌ Failed to start BUDDY Core Runtime: {e}")
        raise
    
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down BUDDY Core Runtime...")
    
    try:
        if sync_engine:
            await sync_engine.stop()
        if voice_pipeline:
            await voice_pipeline.cleanup()
        if memory_manager:
            await memory_manager.close()
        if event_bus:
            await event_bus.stop()
        
        logger.info("✅ BUDDY Core Runtime shutdown complete")
        
    except Exception as e:
        logger.error(f"❌ Error during shutdown: {e}")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application"""
    
    app = FastAPI(
        title="BUDDY Core Runtime",
        description="Privacy-first, offline-capable personal AI assistant runtime",
        version="0.1.0",
        lifespan=lifespan,
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None
    )
    
    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.ALLOWED_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"]
    )
    
    # Include API routers
    app.include_router(voice_router, prefix="/api/v1/voice", tags=["voice"])
    app.include_router(skills_router, prefix="/api/v1/skills", tags=["skills"])
    app.include_router(memory_router, prefix="/api/v1/memory", tags=["memory"])
    app.include_router(sync_router, prefix="/api/v1/sync", tags=["sync"])
    app.include_router(admin_router, prefix="/api/v1/admin", tags=["admin"])
    app.include_router(jarvis_router, prefix="/api/v1/jarvis", tags=["jarvis"])
    
    # Serve static files for web UI (if enabled)
    if settings.ENABLE_WEB_UI:
        static_path = Path(__file__).parent / "static"
        if static_path.exists():
            app.mount("/static", StaticFiles(directory=static_path), name="static")
    
    # WebSocket endpoint for real-time voice processing
    @app.websocket("/ws/voice")
    async def voice_websocket(websocket: WebSocket):
        """WebSocket endpoint for real-time voice interaction"""
        await websocket.accept()
        
        try:
            # Get voice pipeline from app state
            voice_pipeline = app.state.voice_pipeline
            
            # Handle voice stream
            await voice_pipeline.handle_websocket(websocket)
            
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            await websocket.close()
    
    # Health check endpoint
    @app.get("/health")
    async def health_check():
        """Health check endpoint"""
        return {
            "status": "healthy",
            "version": "0.1.0",
            "components": {
                "event_bus": event_bus.is_running() if event_bus else False,
                "voice_pipeline": voice_pipeline.is_ready() if voice_pipeline else False,
                "memory_manager": memory_manager.is_ready() if memory_manager else False,
                "sync_engine": sync_engine.is_running() if sync_engine else False
            }
        }
    
    # Root endpoint - serve the BUDDY GUI
    @app.get("/", response_class=HTMLResponse)
    async def root():
        """Root endpoint serving the BUDDY GUI"""
        static_path = Path(__file__).parent / "static"
        index_path = static_path / "index.html"
        
        if settings.ENABLE_WEB_UI and index_path.exists():
            # Serve the BUDDY GUI
            with open(index_path, "r", encoding="utf-8") as f:
                return f.read()
        else:
            # Fallback to basic info page
            return """
            <html>
                <head><title>BUDDY Core Runtime</title></head>
                <body>
                    <h1>🤖 BUDDY Core Runtime</h1>
                    <p>Your privacy-first personal AI assistant is running!</p>
                    <ul>
                        <li><a href="/health">Health Check</a></li>
                        <li><a href="/docs">API Documentation</a></li>
                    </ul>
                </body>
            </html>
            """
    
    return app


class BuddyCore:
    """
    BUDDY Core manager for coordinating all system components
    """
    
    def __init__(self):
        self.event_bus = None
        self.voice_pipeline = None
        self.skill_registry = None
        self.memory_manager = None
        self.sync_engine = None
        self.security_manager = None
        self.initialized = False
    
    async def initialize(self):
        """Initialize all BUDDY core components"""
        if self.initialized:
            return
        
        logger.info("🚀 Initializing BUDDY Core components...")
        
        try:
            # Initialize core components
            self.event_bus = EventBus()
            await self.event_bus.start()
            
            self.security_manager = SecurityManager(self.event_bus)
            await self.security_manager.initialize()
            
            self.memory_manager = MemoryManager(self.event_bus, settings.DATA_DIR)
            await self.memory_manager.initialize()
            
            self.skill_registry = SkillRegistry(self.event_bus, self.memory_manager)
            await self.skill_registry.load_skills()
            
            self.voice_pipeline = VoicePipeline(self.event_bus, self.skill_registry, self.memory_manager)
            await self.voice_pipeline.initialize()
            
            self.sync_engine = SyncEngine(self.event_bus, self.memory_manager, self.security_manager)
            await self.sync_engine.start()
            
            # Register built-in skills
            await self.skill_registry.register_builtin_skills()
            
            self.initialized = True
            logger.info("✅ BUDDY Core components initialized successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize BUDDY Core: {e}")
            raise
    
    async def cleanup(self):
        """Cleanup all BUDDY core components"""
        logger.info("🛑 Cleaning up BUDDY Core components...")
        
        try:
            if self.sync_engine:
                await self.sync_engine.stop()
            if self.voice_pipeline:
                await self.voice_pipeline.cleanup()
            if self.memory_manager:
                await self.memory_manager.close()
            if self.event_bus:
                await self.event_bus.stop()
            
            self.initialized = False
            logger.info("✅ BUDDY Core cleanup complete")
            
        except Exception as e:
            logger.error(f"❌ Error during cleanup: {e}")
    
    def is_ready(self) -> bool:
        """Check if all components are ready"""
        return (
            self.initialized and
            self.event_bus and self.event_bus.is_running() and
            self.voice_pipeline and self.voice_pipeline.is_ready() and
            self.memory_manager and self.memory_manager.is_ready() and
            self.sync_engine and self.sync_engine.is_running()
        )


# Global app instance
app = create_app()


if __name__ == "__main__":
    uvicorn.run(
        "buddy.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower()
    )