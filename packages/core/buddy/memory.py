"""
Memory Management System for BUDDY Core Runtime

This module provides multi-layered memory capabilities:
- Episodic: Recent conversations and interactions
- Semantic: Vector-based knowledge storage and retrieval
- Procedural: Learned patterns and automation scripts
- Preferences: User settings and personalization data

Key Features:
- SQLite for structured data storage
- Vector database for semantic search
- CRDT documents for conflict-free sync
- Automatic summarization and compaction
- Privacy-preserving local storage
"""

import asyncio
import json
import logging
import sqlite3
import numpy as np
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path

from .events import EventBus, EventType
from .config import settings

logger = logging.getLogger(__name__)


@dataclass
class MemoryItem:
    """Base class for memory items"""
    id: str
    type: str
    content: Dict[str, Any]
    timestamp: datetime
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class ConversationTurn:
    """Single conversation turn"""
    id: str
    session_id: str
    user_input: str
    assistant_response: str
    intent: str
    entities: Dict[str, Any]
    timestamp: datetime
    confidence: float = 1.0


@dataclass
class UserPreference:
    """User preference item"""
    key: str
    value: Any
    weight: float = 1.0
    updated_at: datetime = None
    
    def __post_init__(self):
        if self.updated_at is None:
            self.updated_at = datetime.utcnow()


class MemoryManager:
    """
    Comprehensive memory management for BUDDY
    
    Handles all aspects of memory storage, retrieval, and management:
    - Structured data in SQLite
    - Vector embeddings for semantic search
    - User preferences and personalization
    - Conversation history and context
    - Automatic cleanup and optimization
    """
    
    def __init__(self, event_bus: EventBus, data_dir: Path):
        self.event_bus = event_bus
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        # Database connections
        self.db_path = self.data_dir / "memory.db"
        self.vector_db_path = self.data_dir / "vectors"
        self.db_connection = None
        self.vector_store = None
        
        # In-memory caches
        self.conversation_cache = []
        self.preferences_cache = {}
        self.recent_embeddings = {}
        
        # Configuration
        self.max_conversation_history = settings.MAX_CONVERSATION_HISTORY
        self.embedding_model = None  # Will be initialized
        
        # Metrics
        self.metrics = {
            "memory_items": 0,
            "conversations": 0,
            "preferences": 0,
            "searches_performed": 0,
            "cache_hits": 0
        }
        
        logger.info(f"MemoryManager initialized with data dir: {self.data_dir}")
    
    async def initialize(self):
        """Initialize memory management system"""
        logger.info("Initializing memory management...")
        
        try:
            # Initialize SQLite database
            await self._init_database()
            
            # Initialize vector store
            await self._init_vector_store()
            
            # Initialize embedding model
            await self._init_embedding_model()
            
            # Load caches
            await self._load_caches()
            
            # Setup event handlers
            self._setup_event_handlers()
            
            logger.info("✅ Memory management initialized successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize memory management: {e}")
            raise
    
    async def _init_database(self):
        """Initialize SQLite database with schema"""
        self.db_connection = sqlite3.connect(
            self.db_path, 
            check_same_thread=False,
            timeout=30.0
        )
        self.db_connection.row_factory = sqlite3.Row
        
        # Create tables
        cursor = self.db_connection.cursor()
        
        # Memory items table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS memory_items (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp REAL NOT NULL,
                metadata TEXT,
                embedding BLOB,
                created_at REAL DEFAULT (julianday('now'))
            )
        """)
        
        # Conversations table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                user_input TEXT NOT NULL,
                assistant_response TEXT NOT NULL,
                intent TEXT,
                entities TEXT,
                confidence REAL DEFAULT 1.0,
                timestamp REAL NOT NULL,
                created_at REAL DEFAULT (julianday('now'))
            )
        """)
        
        # Preferences table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS preferences (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                weight REAL DEFAULT 1.0,
                updated_at REAL NOT NULL
            )
        """)
        
        # Reminders table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS reminders (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT,
                when_time REAL NOT NULL,
                recurrence TEXT DEFAULT 'none',
                status TEXT DEFAULT 'active',
                created_at REAL DEFAULT (julianday('now'))
            )
        """)
        
        # Notes table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                title TEXT,
                content TEXT NOT NULL,
                tags TEXT,
                created_at REAL DEFAULT (julianday('now')),
                updated_at REAL DEFAULT (julianday('now'))
            )
        """)
        
        # Create indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_memory_type ON memory_items(type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_memory_timestamp ON memory_items(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_conv_session ON conversations(session_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_conv_timestamp ON conversations(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_reminders_when ON reminders(when_time)")
        
        self.db_connection.commit()
        logger.info("Database schema initialized")
    
    async def _init_vector_store(self):
        """Initialize vector database for semantic search"""
        try:
            # TODO: Initialize actual vector store (Chroma, FAISS, etc.)
            # For now, use a simple in-memory store
            self.vector_store = {
                "embeddings": {},
                "metadata": {},
                "index": None
            }
            
            logger.info("Vector store initialized")
            
        except Exception as e:
            logger.error(f"Failed to initialize vector store: {e}")
            # Fallback to no vector search
            self.vector_store = None
    
    async def _init_embedding_model(self):
        """Initialize embedding model for semantic search"""
        try:
            # TODO: Initialize actual embedding model (sentence-transformers, etc.)
            # For now, create a mock embedding function
            logger.info(f"Loading embedding model: {settings.EMBEDDING_MODEL}")
            
            class MockEmbeddingModel:
                def encode(self, texts):
                    # Return random embeddings for testing
                    if isinstance(texts, str):
                        texts = [texts]
                    return np.random.random((len(texts), 384))
            
            self.embedding_model = MockEmbeddingModel()
            logger.info("Embedding model loaded")
            
        except Exception as e:
            logger.error(f"Failed to load embedding model: {e}")
            self.embedding_model = None
    
    async def _load_caches(self):
        """Load frequently accessed data into memory caches"""
        cursor = self.db_connection.cursor()
        
        # Load recent conversations
        cursor.execute("""
            SELECT * FROM conversations 
            ORDER BY timestamp DESC 
            LIMIT ?
        """, (self.max_conversation_history,))
        
        for row in cursor.fetchall():
            turn = ConversationTurn(
                id=row["id"],
                session_id=row["session_id"],
                user_input=row["user_input"],
                assistant_response=row["assistant_response"],
                intent=row["intent"] or "",
                entities=json.loads(row["entities"]) if row["entities"] else {},
                timestamp=datetime.fromtimestamp(row["timestamp"]),
                confidence=row["confidence"]
            )
            self.conversation_cache.append(turn)
        
        # Load preferences
        cursor.execute("SELECT * FROM preferences")
        for row in cursor.fetchall():
            self.preferences_cache[row["key"]] = UserPreference(
                key=row["key"],
                value=json.loads(row["value"]),
                weight=row["weight"],
                updated_at=datetime.fromtimestamp(row["updated_at"])
            )
        
        logger.info(f"Loaded {len(self.conversation_cache)} conversations, {len(self.preferences_cache)} preferences")
    
    def _setup_event_handlers(self):
        """Setup event bus handlers"""
        self.event_bus.subscribe_async(EventType.MEMORY_WRITE.value, self._handle_memory_write)
        self.event_bus.subscribe_async(EventType.MEMORY_READ.value, self._handle_memory_read)
        self.event_bus.subscribe_async(EventType.MEMORY_SEARCH.value, self._handle_memory_search)
    
    async def _handle_memory_write(self, event):
        """Handle memory write events"""
        data = event.payload
        await self.store_memory_item(data["type"], data["content"], data.get("metadata", {}))
    
    async def _handle_memory_read(self, event):
        """Handle memory read events"""
        query = event.payload
        results = await self.search_memory(**query)
        # TODO: Send results back via event bus
    
    async def _handle_memory_search(self, event):
        """Handle memory search events"""
        query = event.payload["query"]
        results = await self.semantic_search(query)
        # TODO: Send results back via event bus
    
    async def store_memory_item(self, item_type: str, content: Dict[str, Any], 
                              metadata: Dict[str, Any] = None) -> str:
        """Store a memory item"""
        item_id = f"{item_type}_{asyncio.get_event_loop().time()}"
        timestamp = datetime.utcnow().timestamp()
        
        if metadata is None:
            metadata = {}
        
        # Generate embedding if possible
        embedding = None
        if self.embedding_model and isinstance(content, dict):
            text_content = self._extract_text_content(content)
            if text_content:
                embedding_vector = self.embedding_model.encode([text_content])[0]
                embedding = embedding_vector.tobytes()
        
        # Store in database
        cursor = self.db_connection.cursor()
        cursor.execute("""
            INSERT INTO memory_items (id, type, content, timestamp, metadata, embedding)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            item_id,
            item_type,
            json.dumps(content),
            timestamp,
            json.dumps(metadata),
            embedding
        ))
        self.db_connection.commit()
        
        # Update vector store
        if self.vector_store and embedding:
            self.vector_store["embeddings"][item_id] = embedding_vector
            self.vector_store["metadata"][item_id] = {
                "type": item_type,
                "content": content,
                "metadata": metadata,
                "timestamp": timestamp
            }
        
        self.metrics["memory_items"] += 1
        logger.debug(f"Stored memory item: {item_id}")
        
        return item_id
    
    async def store_conversation_turn(self, session_id: str, user_input: str,
                                    assistant_response: str, intent: str = "",
                                    entities: Dict[str, Any] = None,
                                    confidence: float = 1.0) -> str:
        """Store a conversation turn"""
        turn_id = f"conv_{asyncio.get_event_loop().time()}"
        timestamp = datetime.utcnow().timestamp()
        
        if entities is None:
            entities = {}
        
        # Store in database
        cursor = self.db_connection.cursor()
        cursor.execute("""
            INSERT INTO conversations 
            (id, session_id, user_input, assistant_response, intent, entities, confidence, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            turn_id, session_id, user_input, assistant_response,
            intent, json.dumps(entities), confidence, timestamp
        ))
        self.db_connection.commit()
        
        # Add to cache
        turn = ConversationTurn(
            id=turn_id,
            session_id=session_id,
            user_input=user_input,
            assistant_response=assistant_response,
            intent=intent,
            entities=entities,
            timestamp=datetime.fromtimestamp(timestamp),
            confidence=confidence
        )
        
        self.conversation_cache.append(turn)
        
        # Maintain cache size
        if len(self.conversation_cache) > self.max_conversation_history:
            self.conversation_cache.pop(0)
        
        self.metrics["conversations"] += 1
        logger.debug(f"Stored conversation turn: {turn_id}")
        
        return turn_id
    
    async def store_preference(self, key: str, value: Any, weight: float = 1.0):
        """Store or update a user preference"""
        timestamp = datetime.utcnow().timestamp()
        
        # Store in database
        cursor = self.db_connection.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO preferences (key, value, weight, updated_at)
            VALUES (?, ?, ?, ?)
        """, (key, json.dumps(value), weight, timestamp))
        self.db_connection.commit()
        
        # Update cache
        self.preferences_cache[key] = UserPreference(
            key=key,
            value=value,
            weight=weight,
            updated_at=datetime.fromtimestamp(timestamp)
        )
        
        self.metrics["preferences"] += 1
        logger.debug(f"Stored preference: {key}")
    
    async def store_reminder(self, reminder_data: Dict[str, Any]) -> str:
        """Store a reminder"""
        reminder_id = reminder_data.get("id", f"reminder_{asyncio.get_event_loop().time()}")
        
        cursor = self.db_connection.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO reminders 
            (id, title, content, when_time, recurrence, status)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            reminder_id,
            reminder_data["title"],
            reminder_data.get("content", ""),
            reminder_data["when"],
            reminder_data.get("recurrence", "none"),
            reminder_data.get("status", "active")
        ))
        self.db_connection.commit()
        
        logger.debug(f"Stored reminder: {reminder_id}")
        return reminder_id
    
    async def get_preference(self, key: str, default: Any = None) -> Any:
        """Get a user preference"""
        if key in self.preferences_cache:
            self.metrics["cache_hits"] += 1
            return self.preferences_cache[key].value
        
        # Check database
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT value FROM preferences WHERE key = ?", (key,))
        row = cursor.fetchone()
        
        if row:
            return json.loads(row["value"])
        
        return default
    
    async def get_conversation_history(self, session_id: Optional[str] = None,
                                     limit: int = 50) -> List[ConversationTurn]:
        """Get conversation history"""
        if session_id:
            # Filter by session
            history = [turn for turn in self.conversation_cache if turn.session_id == session_id]
        else:
            history = self.conversation_cache
        
        return history[-limit:] if limit else history
    
    async def get_recent_conversations(self, session_id: str = None, limit: int = 5) -> List[Dict[str, Any]]:
        """Get recent conversations formatted for AI context"""
        try:
            # Get from cache first
            if session_id:
                history = [turn for turn in self.conversation_cache if turn.session_id == session_id]
            else:
                history = self.conversation_cache
            
            # If cache doesn't have enough, query database
            if len(history) < limit:
                cursor = self.db_connection.cursor()
                if session_id:
                    cursor.execute("""
                        SELECT user_input, assistant_response, intent, confidence, timestamp
                        FROM conversations 
                        WHERE session_id = ?
                        ORDER BY timestamp DESC 
                        LIMIT ?
                    """, (session_id, limit))
                else:
                    cursor.execute("""
                        SELECT user_input, assistant_response, intent, confidence, timestamp
                        FROM conversations 
                        ORDER BY timestamp DESC 
                        LIMIT ?
                    """, (limit,))
                
                rows = cursor.fetchall()
                return [{
                    'user_input': row['user_input'],
                    'assistant_response': row['assistant_response'],
                    'intent': row['intent'],
                    'confidence': row['confidence'],
                    'timestamp': row['timestamp']
                } for row in rows]
            
            # Convert cache to format expected by AI
            recent = history[-limit:] if limit else history
            return [{
                'user_input': turn.user_input,
                'assistant_response': turn.assistant_response,
                'intent': turn.intent,
                'confidence': turn.confidence,
                'timestamp': turn.timestamp.isoformat() if hasattr(turn.timestamp, 'isoformat') else str(turn.timestamp)
            } for turn in recent]
            
        except Exception as e:
            logger.error(f"Failed to get recent conversations: {e}")
            return []
    
    async def semantic_search(self, query: str, limit: int = 10,
                            item_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """Perform semantic search across memory"""
        if not self.embedding_model or not self.vector_store:
            logger.warning("Semantic search not available - no embedding model or vector store")
            return []
        
        try:
            # Generate query embedding
            query_embedding = self.embedding_model.encode([query])[0]
            
            # Search similar embeddings
            results = []
            for item_id, item_embedding in self.vector_store["embeddings"].items():
                # Calculate similarity (cosine similarity)
                similarity = np.dot(query_embedding, item_embedding) / (
                    np.linalg.norm(query_embedding) * np.linalg.norm(item_embedding)
                )
                
                metadata = self.vector_store["metadata"][item_id]
                
                # Filter by type if specified
                if item_type and metadata["type"] != item_type:
                    continue
                
                results.append({
                    "id": item_id,
                    "similarity": float(similarity),
                    "content": metadata["content"],
                    "type": metadata["type"],
                    "timestamp": metadata["timestamp"]
                })
            
            # Sort by similarity and return top results
            results.sort(key=lambda x: x["similarity"], reverse=True)
            
            self.metrics["searches_performed"] += 1
            
            return results[:limit]
            
        except Exception as e:
            logger.error(f"Semantic search failed: {e}")
            return []
    
    async def search_memory(self, query: str = None, item_type: str = None,
                          since: datetime = None, limit: int = 50) -> List[Dict[str, Any]]:
        """Search memory with filters"""
        cursor = self.db_connection.cursor()
        
        sql = "SELECT * FROM memory_items WHERE 1=1"
        params = []
        
        if item_type:
            sql += " AND type = ?"
            params.append(item_type)
        
        if since:
            sql += " AND timestamp >= ?"
            params.append(since.timestamp())
        
        if query:
            sql += " AND (content LIKE ? OR metadata LIKE ?)"
            params.extend([f"%{query}%", f"%{query}%"])
        
        sql += " ORDER BY timestamp DESC LIMIT ?"
        params.append(limit)
        
        cursor.execute(sql, params)
        results = []
        
        for row in cursor.fetchall():
            results.append({
                "id": row["id"],
                "type": row["type"],
                "content": json.loads(row["content"]),
                "metadata": json.loads(row["metadata"]) if row["metadata"] else {},
                "timestamp": row["timestamp"]
            })
        
        return results
    
    def _extract_text_content(self, content: Dict[str, Any]) -> str:
        """Extract searchable text from content"""
        text_parts = []
        
        for key, value in content.items():
            if isinstance(value, str):
                text_parts.append(value)
            elif isinstance(value, (list, dict)):
                text_parts.append(str(value))
        
        return " ".join(text_parts)
    
    async def cleanup_old_data(self, days_to_keep: int = 30):
        """Clean up old memory data"""
        cutoff_time = (datetime.utcnow() - timedelta(days=days_to_keep)).timestamp()
        
        cursor = self.db_connection.cursor()
        
        # Clean old memory items
        cursor.execute("DELETE FROM memory_items WHERE timestamp < ?", (cutoff_time,))
        
        # Clean old conversations (but keep more recent ones)
        cursor.execute("""
            DELETE FROM conversations 
            WHERE timestamp < ? 
            AND id NOT IN (
                SELECT id FROM conversations 
                ORDER BY timestamp DESC 
                LIMIT ?
            )
        """, (cutoff_time, self.max_conversation_history))
        
        self.db_connection.commit()
        
        # Rebuild caches
        await self._load_caches()
        
        logger.info(f"Cleaned up memory data older than {days_to_keep} days")
    
    async def get_metrics(self) -> Dict[str, Any]:
        """Get memory management metrics"""
        cursor = self.db_connection.cursor()
        
        # Count items in database
        cursor.execute("SELECT COUNT(*) as count FROM memory_items")
        memory_items_count = cursor.fetchone()["count"]
        
        cursor.execute("SELECT COUNT(*) as count FROM conversations")
        conversations_count = cursor.fetchone()["count"]
        
        cursor.execute("SELECT COUNT(*) as count FROM preferences")
        preferences_count = cursor.fetchone()["count"]
        
        return {
            **self.metrics,
            "db_memory_items": memory_items_count,
            "db_conversations": conversations_count,
            "db_preferences": preferences_count,
            "cache_size": {
                "conversations": len(self.conversation_cache),
                "preferences": len(self.preferences_cache)
            },
            "vector_store_size": len(self.vector_store["embeddings"]) if self.vector_store else 0
        }
    
    async def close(self):
        """Close memory management resources"""
        logger.info("Closing memory management...")
        
        if self.db_connection:
            self.db_connection.close()
        
        # Clear caches
        self.conversation_cache.clear()
        self.preferences_cache.clear()
        
        logger.info("Memory management closed")
    
    def is_ready(self) -> bool:
        """Check if memory manager is ready"""
        return (self.db_connection is not None and 
                self.embedding_model is not None)