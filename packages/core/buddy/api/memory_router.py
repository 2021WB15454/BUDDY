"""
Memory API Router

REST endpoints for memory management and retrieval:
- Store and retrieve memory items
- Search memories with semantic queries
- Manage conversation history
- User preferences and personalization
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Request, Query
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter()


class MemoryStoreRequest(BaseModel):
    """Request model for storing memory items"""
    type: str
    content: Dict[str, Any]
    metadata: Optional[Dict[str, Any]] = {}


class ConversationTurnRequest(BaseModel):
    """Request model for storing conversation turns"""
    session_id: str
    user_input: str
    assistant_response: str
    intent: Optional[str] = ""
    entities: Optional[Dict[str, Any]] = {}
    confidence: float = 1.0


class PreferenceRequest(BaseModel):
    """Request model for user preferences"""
    key: str
    value: Any
    weight: float = 1.0


class SearchRequest(BaseModel):
    """Request model for memory search"""
    query: Optional[str] = None
    type: Optional[str] = None
    since_days: Optional[int] = None
    limit: int = 50


class SemanticSearchRequest(BaseModel):
    """Request model for semantic search"""
    query: str
    limit: int = 10
    type: Optional[str] = None


@router.post("/store")
async def store_memory_item(request: Request, memory_request: MemoryStoreRequest):
    """Store a memory item"""
    try:
        memory_manager = request.app.state.memory_manager
        
        item_id = await memory_manager.store_memory_item(
            memory_request.type,
            memory_request.content,
            memory_request.metadata
        )
        
        return {
            "success": True,
            "item_id": item_id,
            "type": memory_request.type,
            "timestamp": datetime.utcnow().isoformat()
        }
    
    except Exception as e:
        logger.error(f"Error storing memory item: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/conversation")
async def store_conversation_turn(request: Request, turn_request: ConversationTurnRequest):
    """Store a conversation turn"""
    try:
        memory_manager = request.app.state.memory_manager
        
        turn_id = await memory_manager.store_conversation_turn(
            turn_request.session_id,
            turn_request.user_input,
            turn_request.assistant_response,
            turn_request.intent,
            turn_request.entities,
            turn_request.confidence
        )
        
        return {
            "success": True,
            "turn_id": turn_id,
            "session_id": turn_request.session_id
        }
    
    except Exception as e:
        logger.error(f"Error storing conversation turn: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/conversation")
async def get_conversation_history(
    request: Request,
    session_id: Optional[str] = None,
    limit: int = Query(50, ge=1, le=500)
):
    """Get conversation history"""
    try:
        memory_manager = request.app.state.memory_manager
        
        history = await memory_manager.get_conversation_history(session_id, limit)
        
        return {
            "conversations": [
                {
                    "id": turn.id,
                    "session_id": turn.session_id,
                    "user_input": turn.user_input,
                    "assistant_response": turn.assistant_response,
                    "intent": turn.intent,
                    "entities": turn.entities,
                    "confidence": turn.confidence,
                    "timestamp": turn.timestamp.isoformat()
                }
                for turn in history
            ],
            "total": len(history),
            "session_id": session_id,
            "limit": limit
        }
    
    except Exception as e:
        logger.error(f"Error getting conversation history: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/preferences")
async def set_preference(request: Request, pref_request: PreferenceRequest):
    """Set a user preference"""
    try:
        memory_manager = request.app.state.memory_manager
        
        await memory_manager.store_preference(
            pref_request.key,
            pref_request.value,
            pref_request.weight
        )
        
        return {
            "success": True,
            "key": pref_request.key,
            "value": pref_request.value,
            "weight": pref_request.weight
        }
    
    except Exception as e:
        logger.error(f"Error setting preference: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/preferences/{key}")
async def get_preference(request: Request, key: str):
    """Get a user preference"""
    try:
        memory_manager = request.app.state.memory_manager
        
        value = await memory_manager.get_preference(key)
        
        if value is None:
            raise HTTPException(status_code=404, detail=f"Preference '{key}' not found")
        
        return {
            "key": key,
            "value": value
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting preference: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/preferences")
async def list_preferences(request: Request):
    """List all user preferences"""
    try:
        memory_manager = request.app.state.memory_manager
        
        # Get all preferences from cache
        preferences = []
        for key, pref in memory_manager.preferences_cache.items():
            preferences.append({
                "key": key,
                "value": pref.value,
                "weight": pref.weight,
                "updated_at": pref.updated_at.isoformat()
            })
        
        return {
            "preferences": preferences,
            "total": len(preferences)
        }
    
    except Exception as e:
        logger.error(f"Error listing preferences: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search")
async def search_memory(request: Request, search_request: SearchRequest):
    """Search memory with filters"""
    try:
        memory_manager = request.app.state.memory_manager
        
        since = None
        if search_request.since_days:
            since = datetime.utcnow() - timedelta(days=search_request.since_days)
        
        results = await memory_manager.search_memory(
            query=search_request.query,
            item_type=search_request.type,
            since=since,
            limit=search_request.limit
        )
        
        return {
            "results": results,
            "total": len(results),
            "query": search_request.query,
            "type": search_request.type,
            "since_days": search_request.since_days
        }
    
    except Exception as e:
        logger.error(f"Error searching memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search/semantic")
async def semantic_search(request: Request, search_request: SemanticSearchRequest):
    """Perform semantic search across memory"""
    try:
        memory_manager = request.app.state.memory_manager
        
        results = await memory_manager.semantic_search(
            search_request.query,
            search_request.limit,
            search_request.type
        )
        
        return {
            "results": results,
            "total": len(results),
            "query": search_request.query,
            "type": search_request.type
        }
    
    except Exception as e:
        logger.error(f"Error in semantic search: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_memory_stats(request: Request):
    """Get memory system statistics"""
    try:
        memory_manager = request.app.state.memory_manager
        metrics = await memory_manager.get_metrics()
        
        return metrics
    
    except Exception as e:
        logger.error(f"Error getting memory stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/cleanup")
async def cleanup_old_data(request: Request, days_to_keep: int = Query(30, ge=1, le=365)):
    """Clean up old memory data"""
    try:
        memory_manager = request.app.state.memory_manager
        
        await memory_manager.cleanup_old_data(days_to_keep)
        
        return {
            "success": True,
            "message": f"Cleaned up data older than {days_to_keep} days"
        }
    
    except Exception as e:
        logger.error(f"Error cleaning up memory: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/reminders")
async def get_reminders(request: Request, active_only: bool = Query(True)):
    """Get reminders"""
    try:
        memory_manager = request.app.state.memory_manager
        
        # Query reminders from database
        cursor = memory_manager.db_connection.cursor()
        
        if active_only:
            cursor.execute("""
                SELECT * FROM reminders 
                WHERE status = 'active' AND when_time > ? 
                ORDER BY when_time ASC
            """, (datetime.utcnow().timestamp(),))
        else:
            cursor.execute("SELECT * FROM reminders ORDER BY when_time DESC")
        
        reminders = []
        for row in cursor.fetchall():
            reminders.append({
                "id": row["id"],
                "title": row["title"],
                "content": row["content"],
                "when": datetime.fromtimestamp(row["when_time"]).isoformat(),
                "recurrence": row["recurrence"],
                "status": row["status"],
                "created_at": datetime.fromtimestamp(row["created_at"]).isoformat()
            })
        
        return {
            "reminders": reminders,
            "total": len(reminders),
            "active_only": active_only
        }
    
    except Exception as e:
        logger.error(f"Error getting reminders: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/notes")
async def get_notes(request: Request, limit: int = Query(50, ge=1, le=500)):
    """Get notes"""
    try:
        memory_manager = request.app.state.memory_manager
        
        # Query notes from database
        cursor = memory_manager.db_connection.cursor()
        cursor.execute("""
            SELECT * FROM notes 
            ORDER BY updated_at DESC 
            LIMIT ?
        """, (limit,))
        
        notes = []
        for row in cursor.fetchall():
            notes.append({
                "id": row["id"],
                "title": row["title"],
                "content": row["content"],
                "tags": row["tags"].split(",") if row["tags"] else [],
                "created_at": datetime.fromtimestamp(row["created_at"]).isoformat(),
                "updated_at": datetime.fromtimestamp(row["updated_at"]).isoformat()
            })
        
        return {
            "notes": notes,
            "total": len(notes),
            "limit": limit
        }
    
    except Exception as e:
        logger.error(f"Error getting notes: {e}")
        raise HTTPException(status_code=500, detail=str(e))