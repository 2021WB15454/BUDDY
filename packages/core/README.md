# BUDDY Core Runtime

The core runtime package for the BUDDY personal AI assistant.

## Features

- **Voice Pipeline**: Complete voice processing from wake word to response
- **Skills System**: Extensible capability framework with dynamic loading
- **Memory Management**: Multi-layered storage with semantic search
- **Sync Engine**: CRDT-based cross-device synchronization
- **Security**: End-to-end encryption and permission management
- **Event System**: High-performance async pub/sub coordination

## Installation

```bash
# Basic installation
pip install buddy-core

# With voice processing
pip install buddy-core[voice]

# With ML capabilities
pip install buddy-core[ml]

# Development installation
pip install buddy-core[dev]
```

## Quick Start

```python
from buddy import create_app
import uvicorn

# Create and run the BUDDY core
app = create_app()
uvicorn.run(app, host="0.0.0.0", port=8000)
```

## Configuration

Configuration is handled via environment variables with the `BUDDY_` prefix:

```bash
export BUDDY_DEBUG=true
export BUDDY_ASR_MODEL=whisper-base
export BUDDY_TTS_VOICE=en_US-lessac-medium
export BUDDY_ENABLE_SYNC=true
```

## API Endpoints

- `/health` - System health check
- `/api/v1/voice/*` - Voice processing endpoints
- `/api/v1/skills/*` - Skill management endpoints
- `/api/v1/memory/*` - Memory and storage endpoints
- `/api/v1/sync/*` - Device synchronization endpoints
- `/ws/voice` - WebSocket for real-time voice processing

## Development

```bash
# Install development dependencies
pip install -e .[dev]

# Run tests
pytest

# Format code
black buddy/
isort buddy/

# Type checking
mypy buddy/
```

## Architecture

```
┌─ buddy/
│  ├─ main.py          # FastAPI application
│  ├─ config.py        # Configuration management
│  ├─ events.py        # Event bus system
│  ├─ voice.py         # Voice pipeline
│  ├─ skills.py        # Skills registry
│  ├─ memory.py        # Memory management
│  ├─ sync.py          # Synchronization engine
│  ├─ security.py      # Security and encryption
│  └─ api/             # REST API routers
```

## License

MIT License - see LICENSE file for details.