# 🚀 BUDDY: AN ADAPTIVE MULTI-MODAL PERSONAL AI ASSISTANT WITH CONTEXT-AWARE LEARNING AND CROSS-PLATFORM INTEGRATION

A complete, privacy‑first, voice+text, multi‑device assistant that learns you, syncs across your ecosystem, and self‑optimizes.

## 🎯 Core Principles

- **Always‑available**: Works fully offline; graceful degradation for cloud‑only connectors
- **Personal & private**: Local‑first storage, transparent learning, user‑controlled data
- **Ambient & multimodal**: Hotword, push‑to‑talk, text, on‑device vision (optional), haptics
- **Cross‑device continuity**: Tasks and context roam securely via P2P sync
- **Composable skills**: Everything is a capability; add/remove like apps
- **Reliable & testable**: Deterministic pipelines; sandboxes; end‑to‑end, unit, smoke tests

## 🏗️ Architecture Overview

```
┌─ apps/
│  ├─ desktop/          # Electron + React desktop app
│  ├─ mobile/           # Flutter mobile app
│  ├─ hub/              # Home Hub (Docker/Pi)
│  ├─ tv/               # TV/Android TV app
│  └─ car/              # Android Auto/CarPlay
├─ packages/
│  ├─ core/             # Core runtime & orchestrator
│  ├─ voice/            # Voice pipeline (ASR, TTS, VAD)
│  ├─ nlu/              # NLU engine (intent, entities)
│  ├─ sync/             # CRDT sync layer
│  ├─ skills/           # Skill registry & base classes
│  ├─ memory/           # Memory & storage layers
│  └─ security/         # E2E crypto & permissions
├─ models/
│  ├─ whisper/          # ASR models (tiny, base)
│  ├─ tts/              # Piper/Coqui TTS voices
│  ├─ embeddings/       # Sentence transformers
│  └─ nlu/              # Intent classifiers
├─ tools/
│  ├─ build/            # Build scripts & CI
│  ├─ deploy/           # Deployment tools
│  ├─ test/             # Testing utilities
│  └─ dev/              # Development helpers
└─ docs/                # Documentation
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Node.js 18+
- Flutter 3.16+
- Docker (optional, for hub)

### Setup
```bash
# Clone and setup
git clone <repo-url>
cd buddy
make setup

# Start development
make dev
```

### Development Commands
```bash
make setup           # Initial setup & dependencies
make dev             # Start all development servers
make test            # Run all tests
make build           # Build all apps
make deploy          # Deploy to staging
```

## 📱 Supported Platforms

- ✅ Desktop (Windows, macOS, Linux)
- ✅ Mobile (Android, iOS)
- 🚧 Smart TV (Android TV, tvOS)
- 🚧 Car (Android Auto, CarPlay)
- 🚧 Smartwatch (Wear OS, watchOS)
- ✅ Home Hub (Raspberry Pi, Docker)

## 🎤 Voice Pipeline

1. **Wake Word** → Porcupine/Precise (local)
2. **VAD** → WebRTC VAD + auto-gain
3. **Streaming ASR** → Whisper (chunked)
4. **NLU** → Intent + entity extraction
5. **Dialogue** → State management + policy
6. **Skills** → Tool execution
7. **TTS** → Piper voices + audio output

**Target Latency**: Wake→NLU < 600ms, Full response < 1.5s

## 🔒 Privacy & Security

- **Local-first**: All processing on-device by default
- **E2E encryption**: Device-to-device sync with rotating keys
- **Transparent logs**: User can see why actions were taken
- **Capability permissions**: Granular, just-in-time access control
- **Zero knowledge**: Optional cloud connectors use user's own tokens

## 📚 Documentation

- [Architecture Guide](docs/architecture.md)
- [API Reference](docs/api.md)
- [Skill Development](docs/skills.md)
- [Deployment Guide](docs/deployment.md)

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.