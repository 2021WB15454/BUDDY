"""
Skills API Router

REST endpoints for skill management and execution:
- List available skills
- Execute skills with parameters
- Manage skill permissions
- View skill execution history
"""

import logging
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter()


class SkillExecuteRequest(BaseModel):
    """Request model for skill execution"""
    skill_name: str
    parameters: Dict[str, Any] = {}
    timeout_ms: Optional[int] = None
    require_confirmation: bool = False


class SkillSearchRequest(BaseModel):
    """Request model for skill search"""
    query: Optional[str] = None
    category: Optional[str] = None
    tags: List[str] = []
    limit: int = 20


@router.get("/")
async def list_skills(request: Request, category: Optional[str] = None):
    """Get list of all available skills"""
    try:
        skill_registry = request.app.state.skill_registry
        
        if category:
            skills = skill_registry.get_skills_by_category(category)
        else:
            skills = skill_registry.get_skill_list()
        
        return {
            "skills": [
                {
                    "name": skill.name,
                    "version": skill.version,
                    "description": skill.description,
                    "author": skill.author,
                    "category": skill.category,
                    "tags": skill.tags,
                    "permissions": skill.permissions,
                    "timeout_ms": skill.timeout_ms,
                    "requires_confirmation": skill.requires_confirmation
                }
                for skill in skills
            ],
            "total": len(skills)
        }
    
    except Exception as e:
        logger.error(f"Error listing skills: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/categories")
async def get_skill_categories(request: Request):
    """Get list of skill categories"""
    try:
        skill_registry = request.app.state.skill_registry
        skills = skill_registry.get_skill_list()
        
        categories = {}
        for skill in skills:
            if skill.category not in categories:
                categories[skill.category] = []
            categories[skill.category].append(skill.name)
        
        return {
            "categories": [
                {
                    "name": category,
                    "skills": skill_names,
                    "count": len(skill_names)
                }
                for category, skill_names in categories.items()
            ]
        }
    
    except Exception as e:
        logger.error(f"Error getting categories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{skill_name}")
async def get_skill_details(request: Request, skill_name: str):
    """Get detailed information about a specific skill"""
    try:
        skill_registry = request.app.state.skill_registry
        metadata = skill_registry.get_skill_metadata(skill_name)
        
        if not metadata:
            raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")
        
        return {
            "name": metadata.name,
            "version": metadata.version,
            "description": metadata.description,
            "author": metadata.author,
            "category": metadata.category,
            "tags": metadata.tags,
            "permissions": metadata.permissions,
            "timeout_ms": metadata.timeout_ms,
            "requires_confirmation": metadata.requires_confirmation,
            "input_schema": metadata.input_schema,
            "output_schema": metadata.output_schema
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting skill details: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{skill_name}/execute")
async def execute_skill(request: Request, skill_name: str, execute_request: SkillExecuteRequest):
    """Execute a skill with given parameters"""
    try:
        skill_registry = request.app.state.skill_registry
        
        # Validate skill exists
        if not skill_registry.get_skill_metadata(skill_name):
            raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")
        
        # Execute skill
        result = await skill_registry.execute_skill(
            skill_name, 
            execute_request.parameters
        )
        
        return {
            "success": result.success,
            "result": result.result,
            "error": result.error,
            "execution_time_ms": result.execution_time_ms,
            "metadata": result.metadata
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error executing skill {skill_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search")
async def search_skills(request: Request, search_request: SkillSearchRequest):
    """Search for skills by query, category, or tags"""
    try:
        skill_registry = request.app.state.skill_registry
        
        if search_request.query:
            skills = skill_registry.search_skills(search_request.query)
        elif search_request.category:
            skills = skill_registry.get_skills_by_category(search_request.category)
        else:
            skills = skill_registry.get_skill_list()
        
        # Filter by tags if provided
        if search_request.tags:
            skills = [
                skill for skill in skills
                if any(tag in skill.tags for tag in search_request.tags)
            ]
        
        # Apply limit
        skills = skills[:search_request.limit]
        
        return {
            "skills": [
                {
                    "name": skill.name,
                    "version": skill.version,
                    "description": skill.description,
                    "category": skill.category,
                    "tags": skill.tags,
                    "permissions": skill.permissions
                }
                for skill in skills
            ],
            "total": len(skills),
            "query": search_request.query,
            "category": search_request.category,
            "tags": search_request.tags
        }
    
    except Exception as e:
        logger.error(f"Error searching skills: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats/execution")
async def get_execution_stats(request: Request):
    """Get skill execution statistics"""
    try:
        skill_registry = request.app.state.skill_registry
        stats = skill_registry.get_execution_stats()
        
        return stats
    
    except Exception as e:
        logger.error(f"Error getting execution stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{skill_name}/validate")
async def validate_skill_input(request: Request, skill_name: str, input_data: Dict[str, Any]):
    """Validate input parameters for a skill"""
    try:
        skill_registry = request.app.state.skill_registry
        
        # Get skill
        if skill_name not in skill_registry._skills:
            raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")
        
        skill = skill_registry._skills[skill_name]
        
        # Validate input
        is_valid = await skill.validate_input(input_data)
        
        return {
            "valid": is_valid,
            "skill_name": skill_name,
            "input_data": input_data
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error validating skill input: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{skill_name}/schema")
async def get_skill_schema(request: Request, skill_name: str):
    """Get input and output schemas for a skill"""
    try:
        skill_registry = request.app.state.skill_registry
        metadata = skill_registry.get_skill_metadata(skill_name)
        
        if not metadata:
            raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")
        
        return {
            "skill_name": skill_name,
            "input_schema": metadata.input_schema,
            "output_schema": metadata.output_schema
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting skill schema: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{skill_name}/permissions")
async def get_skill_permissions(request: Request, skill_name: str):
    """Get required permissions for a skill"""
    try:
        skill_registry = request.app.state.skill_registry
        metadata = skill_registry.get_skill_metadata(skill_name)
        
        if not metadata:
            raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")
        
        return {
            "skill_name": skill_name,
            "permissions": metadata.permissions,
            "description": metadata.description
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting skill permissions: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/batch-execute")
async def batch_execute_skills(request: Request, requests: List[SkillExecuteRequest]):
    """Execute multiple skills in sequence"""
    try:
        skill_registry = request.app.state.skill_registry
        results = []
        
        for req in requests:
            try:
                result = await skill_registry.execute_skill(req.skill_name, req.parameters)
                results.append({
                    "skill_name": req.skill_name,
                    "success": result.success,
                    "result": result.result,
                    "error": result.error,
                    "execution_time_ms": result.execution_time_ms
                })
            except Exception as e:
                results.append({
                    "skill_name": req.skill_name,
                    "success": False,
                    "result": None,
                    "error": str(e),
                    "execution_time_ms": 0
                })
        
        return {
            "results": results,
            "total_executed": len(results),
            "successful": sum(1 for r in results if r["success"]),
            "failed": sum(1 for r in results if not r["success"])
        }
    
    except Exception as e:
        logger.error(f"Error in batch execution: {e}")
        raise HTTPException(status_code=500, detail=str(e))