"""
Event Bus System for BUDDY Core Runtime

This module provides a high-performance, async pub/sub event system that coordinates
all components in the BUDDY assistant. It handles voice pipeline events, skill
execution, memory updates, sync operations, and cross-device communication.
"""

import asyncio
import json
import logging
from typing import Dict, List, Callable, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime
from enum import Enum

logger = logging.getLogger(__name__)


class EventType(Enum):
    """Standard event types in the BUDDY system"""
    
    # Voice pipeline events
    AUDIO_WAKE = "audio.wake"
    AUDIO_VAD_START = "audio.vad.start"
    AUDIO_VAD_END = "audio.vad.end"
    AUDIO_PARTIAL_TEXT = "audio.partial_text"
    AUDIO_FINAL_TEXT = "audio.final_text"
    
    # NLU events
    NLU_INTENT = "nlu.intent"
    NLU_ENTITIES = "nlu.entities"
    
    # Dialogue events
    DIALOG_PLAN = "dialog.plan"
    DIALOG_STATE_UPDATE = "dialog.state_update"
    
    # Skill events
    SKILL_INVOKE = "skill.invoke"
    SKILL_RESULT = "skill.result"
    SKILL_ERROR = "skill.error"
    
    # TTS events
    TTS_SPEAK = "tts.speak"
    TTS_START = "tts.start"
    TTS_END = "tts.end"
    
    # Memory events
    MEMORY_WRITE = "memory.write"
    MEMORY_READ = "memory.read"
    MEMORY_SEARCH = "memory.search"
    
    # Sync events
    SYNC_DELTA = "sync.delta"
    SYNC_CONFLICT = "sync.conflict"
    SYNC_DEVICE_CONNECTED = "sync.device.connected"
    SYNC_DEVICE_DISCONNECTED = "sync.device.disconnected"
    
    # Network events
    NETWORK_CONNECTED = "network.connected"
    NETWORK_DISCONNECTED = "network.disconnected"
    DEVICE_DISCOVERED = "device.discovered"
    DEVICE_DISCONNECTED = "device.disconnected"
    
    # System events
    SYSTEM_STARTUP = "system.startup"
    SYSTEM_SHUTDOWN = "system.shutdown"
    SYSTEM_ERROR = "system.error"


@dataclass
class Event:
    """Event data structure"""
    type: str
    data: Dict[str, Any] = None
    payload: Dict[str, Any] = None
    timestamp: datetime = None
    device_id: str = None
    session_id: Optional[str] = None
    correlation_id: Optional[str] = None
    
    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.utcnow()
        if self.data is None:
            self.data = {}
        if self.payload is None:
            self.payload = self.data  # For backward compatibility
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert event to dictionary"""
        return {
            "type": self.type,
            "data": self.data,
            "payload": self.payload,
            "timestamp": self.timestamp.isoformat(),
            "device_id": self.device_id,
            "session_id": self.session_id,
            "correlation_id": self.correlation_id
        }
    
    def to_json(self) -> str:
        """Convert event to JSON string"""
        return json.dumps(self.to_dict())


EventHandler = Callable[[Event], None]
AsyncEventHandler = Callable[[Event], asyncio.Task]


class EventBus:
    """
    High-performance async event bus for BUDDY components
    
    Features:
    - Type-safe event handling
    - Async and sync handler support
    - Event filtering and routing
    - Error isolation between handlers
    - Event history and replay
    - Performance metrics
    """
    
    def __init__(self, max_history: int = 1000):
        self._handlers: Dict[str, List[Callable]] = {}
        self._async_handlers: Dict[str, List[Callable]] = {}
        self._event_history: List[Event] = []
        self._max_history = max_history
        self._running = False
        self._metrics = {
            "events_published": 0,
            "events_handled": 0,
            "handler_errors": 0
        }
        
        # Get device ID from config
        from .config import settings
        self._device_id = settings.DEVICE_NAME
        
        logger.info(f"EventBus initialized for device: {self._device_id}")
    
    async def start(self):
        """Start the event bus"""
        self._running = True
        logger.info("EventBus started")
    
    async def stop(self):
        """Stop the event bus"""
        self._running = False
        logger.info("EventBus stopped")
    
    def is_running(self) -> bool:
        """Check if event bus is running"""
        return self._running
    
    def subscribe(self, event_type: str, handler: Callable[[Event], None]):
        """Subscribe to events with a synchronous handler"""
        if event_type not in self._handlers:
            self._handlers[event_type] = []
        
        self._handlers[event_type].append(handler)
        logger.debug(f"Subscribed sync handler to {event_type}")
    
    def subscribe_async(self, event_type: str, handler: Callable[[Event], asyncio.Task]):
        """Subscribe to events with an asynchronous handler"""
        if event_type not in self._async_handlers:
            self._async_handlers[event_type] = []
        
        self._async_handlers[event_type].append(handler)
        logger.debug(f"Subscribed async handler to {event_type}")
    
    def unsubscribe(self, event_type: str, handler: Callable):
        """Unsubscribe a handler from an event type"""
        if event_type in self._handlers and handler in self._handlers[event_type]:
            self._handlers[event_type].remove(handler)
        
        if event_type in self._async_handlers and handler in self._async_handlers[event_type]:
            self._async_handlers[event_type].remove(handler)
        
        logger.debug(f"Unsubscribed handler from {event_type}")
    
    async def publish(self, event_type: str, payload: Dict[str, Any], 
                     session_id: Optional[str] = None,
                     correlation_id: Optional[str] = None):
        """Publish an event to all subscribers"""
        if not self._running:
            logger.warning("EventBus not running, dropping event")
            return
        
        # Create event
        event = Event(
            type=event_type,
            payload=payload,
            timestamp=datetime.utcnow(),
            device_id=self._device_id,
            session_id=session_id,
            correlation_id=correlation_id
        )
        
        # Add to history
        self._event_history.append(event)
        if len(self._event_history) > self._max_history:
            self._event_history.pop(0)
        
        # Update metrics
        self._metrics["events_published"] += 1
        
        # Handle synchronous handlers
        sync_handlers = self._handlers.get(event_type, [])
        for handler in sync_handlers:
            try:
                handler(event)
                self._metrics["events_handled"] += 1
            except Exception as e:
                self._metrics["handler_errors"] += 1
                logger.error(f"Error in sync handler for {event_type}: {e}")
        
        # Handle asynchronous handlers
        async_handlers = self._async_handlers.get(event_type, [])
        tasks = []
        for handler in async_handlers:
            try:
                task = asyncio.create_task(handler(event))
                tasks.append(task)
            except Exception as e:
                self._metrics["handler_errors"] += 1
                logger.error(f"Error creating async task for {event_type}: {e}")
        
        # Wait for async handlers (with timeout)
        if tasks:
            try:
                await asyncio.wait_for(
                    asyncio.gather(*tasks, return_exceptions=True),
                    timeout=5.0
                )
                self._metrics["events_handled"] += len(tasks)
            except asyncio.TimeoutError:
                logger.warning(f"Timeout waiting for async handlers for {event_type}")
                # Cancel remaining tasks
                for task in tasks:
                    if not task.done():
                        task.cancel()
        
        logger.debug(f"Published event: {event_type}")
    
    def get_history(self, event_type: Optional[str] = None, 
                   limit: Optional[int] = None) -> List[Event]:
        """Get event history, optionally filtered by type"""
        history = self._event_history
        
        if event_type:
            history = [e for e in history if e.type == event_type]
        
        if limit:
            history = history[-limit:]
        
        return history
    
    def get_metrics(self) -> Dict[str, Any]:
        """Get event bus performance metrics"""
        return {
            **self._metrics,
            "active_handlers": sum(len(handlers) for handlers in self._handlers.values()),
            "active_async_handlers": sum(len(handlers) for handlers in self._async_handlers.values()),
            "history_size": len(self._event_history)
        }
    
    def clear_history(self):
        """Clear event history"""
        self._event_history.clear()
        logger.info("Event history cleared")
    
    # Convenience methods for common events
    
    async def publish_wake_word(self, confidence: float = 1.0):
        """Publish wake word detected event"""
        await self.publish(EventType.AUDIO_WAKE.value, {"confidence": confidence})
    
    async def publish_partial_text(self, text: str, confidence: float = 1.0):
        """Publish partial ASR text"""
        await self.publish(EventType.AUDIO_PARTIAL_TEXT.value, {
            "text": text,
            "confidence": confidence
        })
    
    async def publish_final_text(self, text: str, confidence: float = 1.0):
        """Publish final ASR text"""
        await self.publish(EventType.AUDIO_FINAL_TEXT.value, {
            "text": text,
            "confidence": confidence
        })
    
    async def publish_intent(self, intent: str, entities: Dict[str, Any], 
                           confidence: float = 1.0):
        """Publish NLU intent"""
        await self.publish(EventType.NLU_INTENT.value, {
            "intent": intent,
            "entities": entities,
            "confidence": confidence
        })
    
    async def publish_skill_invoke(self, skill_name: str, args: Dict[str, Any],
                                 correlation_id: str):
        """Publish skill invocation"""
        await self.publish(EventType.SKILL_INVOKE.value, {
            "skill_name": skill_name,
            "args": args
        }, correlation_id=correlation_id)
    
    async def publish_skill_result(self, skill_name: str, result: Any,
                                 correlation_id: str):
        """Publish skill result"""
        await self.publish(EventType.SKILL_RESULT.value, {
            "skill_name": skill_name,
            "result": result
        }, correlation_id=correlation_id)
    
    async def publish_tts_speak(self, text: str, voice: Optional[str] = None):
        """Publish TTS speak request"""
        await self.publish(EventType.TTS_SPEAK.value, {
            "text": text,
            "voice": voice
        })