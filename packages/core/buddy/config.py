"""
Configuration management for BUDDY Core Runtime

This module handles all configuration settings, environment variables,
and runtime parameters for the BUDDY assistant.
"""

import os
from pathlib import Path
from typing import List, Optional
from pydantic_settings import BaseSettings
from pydantic import validator


class Settings(BaseSettings):
    """BUDDY Core Runtime Settings"""
    
    # Basic settings
    DEBUG: bool = True
    LOG_LEVEL: str = "INFO"
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # API Keys for external services
    GOOGLE_API_KEY: Optional[str] = None
    OPENWEATHER_API_KEY: Optional[str] = None
    GEOAPIFY_API_KEY: Optional[str] = None
    ALPHAVANTAGE_API_KEY: Optional[str] = None
    NEWSAPI_KEY: Optional[str] = None
    YOUTUBE_API_KEY: Optional[str] = None
    
    # Multi-Device Network Configuration
    MAX_DEVICES_PER_USER: int = 10
    SYNC_INTERVAL: int = 30
    DEVICE_TIMEOUT: int = 300
    
    # Voice Configuration
    VOICE_ENABLED: bool = True
    BACKGROUND_VOICE: bool = True
    VOICE_THRESHOLD: float = 0.5
    
    # Chat Configuration
    MAX_CHAT_HISTORY: int = 100
    RESPONSE_TIMEOUT: int = 30
    
    # Data directories
    DATA_DIR: Path = Path.home() / ".buddy"
    MODELS_DIR: Path = Path(__file__).parent.parent.parent.parent / "models"
    
    # Security
    SECRET_KEY: str = "buddy-secret-key-change-in-production"
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]
    
    # Voice settings
    ENABLE_WAKE_WORD: bool = True
    WAKE_WORD_MODEL: str = "porcupine"
    ASR_MODEL: str = "whisper-tiny"
    TTS_MODEL: str = "piper"
    TTS_VOICE: str = "en_US-lessac-medium"
    
    # NLU settings
    NLU_MODEL_PATH: Optional[str] = None
    EMBEDDING_MODEL: str = "all-MiniLM-L6-v2"
    
    # Memory settings
    MEMORY_DB_PATH: Optional[str] = None
    VECTOR_DB_PATH: Optional[str] = None
    MAX_CONVERSATION_HISTORY: int = 100
    
    # Sync settings
    ENABLE_SYNC: bool = True
    SYNC_PORT: int = 8001
    DEVICE_NAME: Optional[str] = None
    DEVICE_ID: Optional[str] = None
    
    # Feature flags
    ENABLE_WEB_UI: bool = True
    ENABLE_TELEMETRY: bool = False  # Local-only by default
    ENABLE_CLOUD_CONNECTORS: bool = False
    
    # Performance settings
    MAX_WORKERS: int = 4
    REQUEST_TIMEOUT: int = 30
    
    @validator('DATA_DIR', 'MODELS_DIR', pre=True)
    def resolve_paths(cls, v):
        """Resolve and create paths"""
        path = Path(v)
        if not path.is_absolute():
            path = Path.cwd() / path
        path.mkdir(parents=True, exist_ok=True)
        return path
    
    @validator('MEMORY_DB_PATH', pre=True)
    def resolve_memory_db_path(cls, v, values):
        """Set default memory DB path"""
        if v is None:
            return str(values['DATA_DIR'] / "memory.db")
        return v
    
    @validator('VECTOR_DB_PATH', pre=True)
    def resolve_vector_db_path(cls, v, values):
        """Set default vector DB path"""
        if v is None:
            return str(values['DATA_DIR'] / "vectors")
        return v
    
    @validator('DEVICE_NAME', pre=True)
    def set_default_device_name(cls, v):
        """Set default device name"""
        if v is None:
            import platform
            return f"{platform.node()}-{platform.system().lower()}"
        return v
    
    @validator('DEVICE_ID', pre=True)
    def set_default_device_id(cls, v):
        """Set default device ID"""
        if v is None:
            import uuid
            return str(uuid.uuid4())
        return v
    
    class Config:
        env_prefix = "BUDDY_"
        case_sensitive = True
        env_file = ".env"


# Global settings instance
settings = Settings()

# Ensure data directories exist
settings.DATA_DIR.mkdir(parents=True, exist_ok=True)
settings.MODELS_DIR.mkdir(parents=True, exist_ok=True)