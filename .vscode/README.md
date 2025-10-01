# BUDDY Monorepo

This workspace contains all components for the BUDDY personal AI assistant.

## Development Setup

```bash
# Install dependencies
make setup

# Start development servers
make dev

# Run tests
make test
```

## Workspace Structure

- `apps/` - Application frontends
- `packages/` - Shared libraries and core runtime
- `models/` - AI models and weights
- `tools/` - Build and development tools
- `docs/` - Documentation

## VS Code Extensions

Recommended extensions are automatically suggested when opening this workspace.

## Scripts

All development scripts are in the `tools/` directory and orchestrated via the Makefile.