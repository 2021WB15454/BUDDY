"""
Skills Registry for BUDDY Core Runtime

This module manages the skill system - the composable capabilities that BUDDY can execute.
Skills are like apps: they can be dynamically loaded, executed with proper permissions,
and provide specific functionality like reminders, weather, smart home control, etc.

Key Features:
- Dynamic skill loading and registration
- Schema validation for skill inputs/outputs
- Permission and capability management
- Sandboxed execution with timeouts
- Skill dependency resolution
- Hot-reloading for development
"""

import asyncio
import json
import logging
import inspect
from typing import Dict, Any, List, Optional, Type, Callable
from dataclasses import dataclass, asdict
from pathlib import Path
from importlib import import_module
from abc import ABC, abstractmethod

from .events import EventBus, EventType
from .config import settings

logger = logging.getLogger(__name__)


@dataclass
class SkillMetadata:
    """Skill metadata and configuration"""
    name: str
    version: str
    description: str
    author: str
    permissions: List[str]
    input_schema: Dict[str, Any]
    output_schema: Dict[str, Any]
    timeout_ms: int = 5000
    requires_confirmation: bool = False
    category: str = "general"
    tags: List[str] = None
    
    def __post_init__(self):
        if self.tags is None:
            self.tags = []


@dataclass
class SkillResult:
    """Result of skill execution"""
    success: bool
    result: Any = None
    error: Optional[str] = None
    execution_time_ms: float = 0
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class SkillError(Exception):
    """Base exception for skill-related errors"""
    pass


class SkillTimeoutError(SkillError):
    """Raised when skill execution times out"""
    pass


class SkillPermissionError(SkillError):
    """Raised when skill lacks required permissions"""
    pass


class SkillValidationError(SkillError):
    """Raised when skill input/output validation fails"""
    pass


class BaseSkill(ABC):
    """
    Base class for all BUDDY skills
    
    Skills must inherit from this class and implement the execute method.
    They should also define metadata and handle their own validation.
    """
    
    def __init__(self, event_bus: EventBus, memory_manager):
        self.event_bus = event_bus
        self.memory_manager = memory_manager
        self._metadata: Optional[SkillMetadata] = None
    
    @property
    @abstractmethod
    def metadata(self) -> SkillMetadata:
        """Return skill metadata"""
        pass
    
    @abstractmethod
    async def execute(self, **kwargs) -> Any:
        """
        Execute the skill with given parameters
        
        Args:
            **kwargs: Skill parameters (validated against input schema)
            
        Returns:
            Skill result (validated against output schema)
        """
        pass
    
    async def validate_input(self, input_data: Dict[str, Any]) -> bool:
        """Validate input against skill's input schema"""
        # TODO: Implement JSON schema validation
        return True
    
    async def validate_output(self, output_data: Any) -> bool:
        """Validate output against skill's output schema"""
        # TODO: Implement JSON schema validation
        return True
    
    async def check_permissions(self, required_permissions: List[str]) -> bool:
        """Check if skill has required permissions"""
        # TODO: Implement permission checking
        return True
    
    def log_info(self, message: str):
        """Log info message with skill context"""
        logger.info(f"[{self.metadata.name}] {message}")
    
    def log_error(self, message: str):
        """Log error message with skill context"""
        logger.error(f"[{self.metadata.name}] {message}")


class SkillRegistry:
    """
    Central registry for managing BUDDY skills
    
    Handles:
    - Skill discovery and loading
    - Execution with validation and sandboxing
    - Permission management
    - Performance monitoring
    - Hot-reloading for development
    """
    
    def __init__(self, event_bus: EventBus, memory_manager):
        self.event_bus = event_bus
        self.memory_manager = memory_manager
        
        # Registered skills
        self._skills: Dict[str, BaseSkill] = {}
        self._skill_metadata: Dict[str, SkillMetadata] = {}
        
        # Execution tracking
        self._execution_stats = {}
        self._active_executions = {}
        
        # Configuration
        self.skills_dir = Path(__file__).parent.parent.parent.parent / "packages" / "skills"
        self.max_concurrent_executions = 10
        
        # Subscribe to skill execution events
        self._setup_event_handlers()
        
        logger.info("SkillRegistry initialized")
    
    def _setup_event_handlers(self):
        """Setup event bus handlers"""
        self.event_bus.subscribe_async(
            EventType.SKILL_INVOKE.value,
            self._handle_skill_invoke
        )
    
    async def _handle_skill_invoke(self, event):
        """Handle skill invocation events"""
        skill_name = event.payload["skill_name"]
        args = event.payload["args"]
        correlation_id = event.correlation_id
        
        # Execute skill
        result = await self.execute_skill(skill_name, args)
        
        # Publish result
        await self.event_bus.publish_skill_result(
            skill_name, result, correlation_id
        )
    
    async def load_skills(self):
        """Load all available skills"""
        logger.info("Loading skills...")
        
        # Load built-in skills
        await self._load_builtin_skills()
        
        # Load external skills from skills directory
        if self.skills_dir.exists():
            await self._load_external_skills()
        
        logger.info(f"Loaded {len(self._skills)} skills")
    
    async def _load_builtin_skills(self):
        """Load built-in skills"""
        builtin_skills = [
            RemindersSkill,
            WeatherSkill,
            TimerSkill,
            NotesSkill,
            CalculatorSkill
        ]
        
        for skill_class in builtin_skills:
            try:
                skill = skill_class(self.event_bus, self.memory_manager)
                await self.register_skill(skill)
            except Exception as e:
                logger.error(f"Failed to load built-in skill {skill_class.__name__}: {e}")
    
    async def _load_external_skills(self):
        """Load external skills from skills directory"""
        for skill_file in self.skills_dir.glob("*.py"):
            if skill_file.name.startswith("_"):
                continue
            
            try:
                # Import module
                module_name = skill_file.stem
                spec = import_module(f"skills.{module_name}")
                
                # Find skill classes
                for name, obj in inspect.getmembers(spec):
                    if (inspect.isclass(obj) and 
                        issubclass(obj, BaseSkill) and 
                        obj != BaseSkill):
                        
                        skill = obj(self.event_bus, self.memory_manager)
                        await self.register_skill(skill)
                        
            except Exception as e:
                logger.error(f"Failed to load skill from {skill_file}: {e}")
    
    async def register_skill(self, skill: BaseSkill):
        """Register a skill instance"""
        metadata = skill.metadata
        
        # Validate metadata
        if not metadata.name:
            raise SkillError("Skill name cannot be empty")
        
        if metadata.name in self._skills:
            logger.warning(f"Skill {metadata.name} already registered, replacing")
        
        # Register skill
        self._skills[metadata.name] = skill
        self._skill_metadata[metadata.name] = metadata
        
        # Initialize execution stats
        self._execution_stats[metadata.name] = {
            "executions": 0,
            "successes": 0,
            "errors": 0,
            "avg_execution_time_ms": 0,
            "total_execution_time_ms": 0
        }
        
        logger.info(f"Registered skill: {metadata.name} v{metadata.version}")
    
    async def unregister_skill(self, skill_name: str):
        """Unregister a skill"""
        if skill_name in self._skills:
            del self._skills[skill_name]
            del self._skill_metadata[skill_name]
            del self._execution_stats[skill_name]
            logger.info(f"Unregistered skill: {skill_name}")
    
    async def execute_skill(self, skill_name: str, args: Dict[str, Any]) -> SkillResult:
        """
        Execute a skill with given arguments
        
        Args:
            skill_name: Name of skill to execute
            args: Arguments to pass to skill
            
        Returns:
            SkillResult with execution outcome
        """
        if skill_name not in self._skills:
            return SkillResult(
                success=False,
                error=f"Skill not found: {skill_name}"
            )
        
        skill = self._skills[skill_name]
        metadata = self._skill_metadata[skill_name]
        
        # Check concurrent execution limit
        if len(self._active_executions) >= self.max_concurrent_executions:
            return SkillResult(
                success=False,
                error="Too many concurrent skill executions"
            )
        
        execution_id = f"{skill_name}_{asyncio.get_event_loop().time()}"
        self._active_executions[execution_id] = skill_name
        
        start_time = asyncio.get_event_loop().time()
        
        try:
            # Validate input
            if not await skill.validate_input(args):
                raise SkillValidationError("Input validation failed")
            
            # Check permissions
            if not await skill.check_permissions(metadata.permissions):
                raise SkillPermissionError("Insufficient permissions")
            
            # Execute with timeout
            result = await asyncio.wait_for(
                skill.execute(**args),
                timeout=metadata.timeout_ms / 1000.0
            )
            
            # Validate output
            if not await skill.validate_output(result):
                raise SkillValidationError("Output validation failed")
            
            execution_time_ms = (asyncio.get_event_loop().time() - start_time) * 1000
            
            # Update stats
            stats = self._execution_stats[skill_name]
            stats["executions"] += 1
            stats["successes"] += 1
            stats["total_execution_time_ms"] += execution_time_ms
            stats["avg_execution_time_ms"] = (
                stats["total_execution_time_ms"] / stats["executions"]
            )
            
            logger.info(f"Skill {skill_name} executed successfully in {execution_time_ms:.1f}ms")
            
            return SkillResult(
                success=True,
                result=result,
                execution_time_ms=execution_time_ms,
                metadata={"skill_name": skill_name, "version": metadata.version}
            )
            
        except asyncio.TimeoutError:
            self._execution_stats[skill_name]["errors"] += 1
            return SkillResult(
                success=False,
                error=f"Skill execution timed out after {metadata.timeout_ms}ms"
            )
        
        except Exception as e:
            self._execution_stats[skill_name]["errors"] += 1
            logger.error(f"Skill {skill_name} execution failed: {e}")
            return SkillResult(
                success=False,
                error=str(e)
            )
        
        finally:
            # Remove from active executions
            if execution_id in self._active_executions:
                del self._active_executions[execution_id]
    
    def get_skill_list(self) -> List[SkillMetadata]:
        """Get list of all registered skills"""
        return list(self._skill_metadata.values())
    
    def get_skill_metadata(self, skill_name: str) -> Optional[SkillMetadata]:
        """Get metadata for a specific skill"""
        return self._skill_metadata.get(skill_name)
    
    def get_skills_by_category(self, category: str) -> List[SkillMetadata]:
        """Get skills filtered by category"""
        return [
            metadata for metadata in self._skill_metadata.values()
            if metadata.category == category
        ]
    
    def search_skills(self, query: str) -> List[SkillMetadata]:
        """Search skills by name, description, or tags"""
        query_lower = query.lower()
        results = []
        
        for metadata in self._skill_metadata.values():
            if (query_lower in metadata.name.lower() or
                query_lower in metadata.description.lower() or
                any(query_lower in tag.lower() for tag in metadata.tags)):
                results.append(metadata)
        
        return results
    
    def get_execution_stats(self) -> Dict[str, Any]:
        """Get execution statistics for all skills"""
        return {
            "skills": dict(self._execution_stats),
            "active_executions": len(self._active_executions),
            "total_skills": len(self._skills)
        }
    
    async def register_builtin_skills(self):
        """Register built-in skills (called from main app)"""
        # This is called after initialization to register core skills
        pass


# Built-in Skills

class RemindersSkill(BaseSkill):
    """Skill for creating and managing reminders"""
    
    @property
    def metadata(self) -> SkillMetadata:
        return SkillMetadata(
            name="reminders.create",
            version="1.0.0",
            description="Create reminders and alerts",
            author="BUDDY Team",
            permissions=["schedule"],
            input_schema={
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "when": {"type": "string", "format": "date-time"},
                    "recurrence": {"type": "string", "enum": ["none", "daily", "weekly", "monthly"]}
                },
                "required": ["title", "when"]
            },
            output_schema={
                "type": "object",
                "properties": {
                    "reminder_id": {"type": "string"},
                    "response": {"type": "string"}
                }
            },
            category="productivity",
            tags=["reminder", "schedule", "alert"]
        )
    
    async def execute(self, title: str, when: str, recurrence: str = "none") -> Dict[str, Any]:
        """Create a reminder"""
        self.log_info(f"Creating reminder: {title} at {when}")
        
        # TODO: Implement actual reminder creation in memory/storage
        reminder_id = f"reminder_{asyncio.get_event_loop().time()}"
        
        # Store in memory manager
        await self.memory_manager.store_reminder({
            "id": reminder_id,
            "title": title,
            "when": when,
            "recurrence": recurrence,
            "created_at": asyncio.get_event_loop().time()
        })
        
        return {
            "reminder_id": reminder_id,
            "response": f"I've set a reminder for '{title}' at {when}"
        }


class WeatherSkill(BaseSkill):
    """Skill for getting weather information"""
    
    @property
    def metadata(self) -> SkillMetadata:
        return SkillMetadata(
            name="weather.get_current",
            version="1.0.0",
            description="Get current weather conditions",
            author="BUDDY Team",
            permissions=["location"],
            input_schema={
                "type": "object",
                "properties": {
                    "location": {"type": "string"}
                },
                "required": ["location"]
            },
            output_schema={
                "type": "object",
                "properties": {
                    "temperature": {"type": "number"},
                    "condition": {"type": "string"},
                    "response": {"type": "string"}
                }
            },
            category="information",
            tags=["weather", "outdoor", "temperature"]
        )
    
    async def execute(self, location: str = "current") -> Dict[str, Any]:
        """Get current weather"""
        self.log_info(f"Getting weather for: {location}")
        
        # TODO: Implement actual weather API call or cached data
        # For now, return mock data
        return {
            "temperature": 72,
            "condition": "sunny",
            "response": f"The weather in {location} is sunny and 72°F"
        }


class TimerSkill(BaseSkill):
    """Skill for managing timers"""
    
    @property
    def metadata(self) -> SkillMetadata:
        return SkillMetadata(
            name="timer.create",
            version="1.0.0",
            description="Create and manage timers",
            author="BUDDY Team",
            permissions=["notifications"],
            input_schema={
                "type": "object",
                "properties": {
                    "duration": {"type": "integer", "minimum": 1},
                    "label": {"type": "string"}
                },
                "required": ["duration"]
            },
            output_schema={
                "type": "object",
                "properties": {
                    "timer_id": {"type": "string"},
                    "response": {"type": "string"}
                }
            },
            category="productivity",
            tags=["timer", "alarm", "countdown"]
        )
    
    async def execute(self, duration: int, label: str = "Timer") -> Dict[str, Any]:
        """Create a timer"""
        self.log_info(f"Creating timer: {label} for {duration} seconds")
        
        timer_id = f"timer_{asyncio.get_event_loop().time()}"
        
        # TODO: Implement actual timer logic
        return {
            "timer_id": timer_id,
            "response": f"Timer set for {duration} seconds"
        }


class NotesSkill(BaseSkill):
    """Skill for taking and managing notes"""
    
    @property
    def metadata(self) -> SkillMetadata:
        return SkillMetadata(
            name="notes.create",
            version="1.0.0",
            description="Create and manage notes",
            author="BUDDY Team",
            permissions=["storage"],
            input_schema={
                "type": "object",
                "properties": {
                    "content": {"type": "string"},
                    "title": {"type": "string"}
                },
                "required": ["content"]
            },
            output_schema={
                "type": "object",
                "properties": {
                    "note_id": {"type": "string"},
                    "response": {"type": "string"}
                }
            },
            category="productivity",
            tags=["note", "memo", "text"]
        )
    
    async def execute(self, content: str, title: str = None) -> Dict[str, Any]:
        """Create a note"""
        if title is None:
            title = content[:50] + "..." if len(content) > 50 else content
        
        self.log_info(f"Creating note: {title}")
        
        note_id = f"note_{asyncio.get_event_loop().time()}"
        
        # TODO: Store in memory manager
        return {
            "note_id": note_id,
            "response": f"Note saved: {title}"
        }


class CalculatorSkill(BaseSkill):
    """Skill for mathematical calculations"""
    
    @property
    def metadata(self) -> SkillMetadata:
        return SkillMetadata(
            name="calculator.evaluate",
            version="1.0.0",
            description="Perform mathematical calculations",
            author="BUDDY Team",
            permissions=[],
            input_schema={
                "type": "object",
                "properties": {
                    "expression": {"type": "string"}
                },
                "required": ["expression"]
            },
            output_schema={
                "type": "object",
                "properties": {
                    "result": {"type": "number"},
                    "response": {"type": "string"}
                }
            },
            category="utility",
            tags=["math", "calculator", "arithmetic"]
        )
    
    async def execute(self, expression: str) -> Dict[str, Any]:
        """Evaluate mathematical expression"""
        self.log_info(f"Calculating: {expression}")
        
        try:
            # Safe evaluation of mathematical expressions
            # TODO: Implement proper math expression parser
            result = eval(expression)  # WARNING: In production, use a safe math parser
            
            return {
                "result": result,
                "response": f"{expression} equals {result}"
            }
        except Exception as e:
            raise SkillError(f"Invalid mathematical expression: {e}")