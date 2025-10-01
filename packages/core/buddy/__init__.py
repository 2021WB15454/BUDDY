"""
BUDDY Core Runtime Package

This package contains the core orchestrator and runtime for the BUDDY personal AI assistant.
It provides the central event bus, voice pipeline coordination, skill management, and
cross-device synchronization capabilities.

Key Components:
- Event Bus: Central pub/sub system for component coordination
- Voice Pipeline: Orchestrates wake word → ASR → NLU → dialogue → TTS
- Skill Registry: Manages available capabilities and their execution
- Memory Layer: Short-term and long-term storage with semantic search
- Sync Engine: CRDT-based state synchronization across devices
- Security: E2E encryption, permissions, and capability management
"""

__version__ = "0.1.0"
__author__ = "BUDDY Team"
__email__ = "team@buddy-ai.dev"

from .main import create_app
from .events import EventBus
from .voice import VoicePipeline
from .skills import SkillRegistry
from .memory import MemoryManager
from .sync import SyncEngine

__all__ = [
    "create_app",
    "EventBus", 
    "VoicePipeline",
    "SkillRegistry",
    "MemoryManager",
    "SyncEngine"
]