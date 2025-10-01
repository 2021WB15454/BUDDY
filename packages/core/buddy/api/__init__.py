"""
API Routers for BUDDY Core Runtime

This module contains all the REST API endpoints for the BUDDY backend,
organized into logical router groups for different functionality areas.
"""

from .voice_router_simple import router as voice_router
from .skills_router import router as skills_router  
from .memory_router import router as memory_router
from .sync_router import router as sync_router
from .admin_router import router as admin_router
from .jarvis_router import router as jarvis_router

__all__ = [
    "voice_router",
    "skills_router", 
    "memory_router",
    "sync_router",
    "admin_router",
    "jarvis_router"
]