# Makefile for BUDDY - Cross-Device Personal AI Assistant

.PHONY: setup dev test build clean docker lint format

# Colors for output
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

## Show help
help:
	@echo "$(BLUE)BUDDY Development Commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  setup          Install all dependencies and setup development environment"
	@echo "  models         Download required AI models"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@echo "  dev            Start all development servers"
	@echo "  dev-backend    Start only Python backend"
	@echo "  dev-desktop    Start only Electron desktop app"
	@echo "  dev-mobile     Start Flutter mobile development"
	@echo ""
	@echo "$(GREEN)Testing:$(NC)"
	@echo "  test           Run all tests"
	@echo "  test-backend   Run Python backend tests"
	@echo "  test-desktop   Run Electron app tests"
	@echo "  test-mobile    Run Flutter tests"
	@echo ""
	@echo "$(GREEN)Build:$(NC)"
	@echo "  build          Build all applications"
	@echo "  build-backend  Package Python backend"
	@echo "  build-desktop  Build Electron app"
	@echo "  build-mobile   Build Flutter APK/IPA"
	@echo "  build-hub      Build Docker hub image"
	@echo ""
	@echo "$(GREEN)Quality:$(NC)"
	@echo "  lint           Run linters on all code"
	@echo "  format         Format all code"
	@echo "  clean          Clean build artifacts"

## Setup development environment
setup:
	@echo "$(BLUE)Setting up BUDDY development environment...$(NC)"
	@./tools/dev/setup.sh

## Download AI models
models:
	@echo "$(BLUE)Downloading AI models...$(NC)"
	@python tools/dev/download_models.py

## Start all development servers
dev:
	@echo "$(BLUE)Starting BUDDY development environment...$(NC)"
	@./tools/dev/start_dev.sh

## Start backend only
dev-backend:
	@echo "$(BLUE)Starting Python backend...$(NC)"
	@cd packages/core && python -m uvicorn buddy.main:app --reload --host 0.0.0.0 --port 8000

## Start desktop app only
dev-desktop:
	@echo "$(BLUE)Starting Electron desktop app...$(NC)"
	@cd apps/desktop && npm run dev

## Start mobile development
dev-mobile:
	@echo "$(BLUE)Starting Flutter mobile development...$(NC)"
	@cd apps/mobile && flutter run

## Run all tests
test:
	@echo "$(BLUE)Running all tests...$(NC)"
	@./tools/test/run_all_tests.sh

## Run backend tests
test-backend:
	@echo "$(BLUE)Running Python backend tests...$(NC)"
	@cd packages/core && python -m pytest tests/ -v

## Run desktop tests
test-desktop:
	@echo "$(BLUE)Running Electron tests...$(NC)"
	@cd apps/desktop && npm test

## Run mobile tests
test-mobile:
	@echo "$(BLUE)Running Flutter tests...$(NC)"
	@cd apps/mobile && flutter test

## Build all applications
build:
	@echo "$(BLUE)Building all applications...$(NC)"
	@./tools/build/build_all.sh

## Build backend
build-backend:
	@echo "$(BLUE)Building Python backend...$(NC)"
	@cd packages/core && python -m build

## Build desktop app
build-desktop:
	@echo "$(BLUE)Building Electron desktop app...$(NC)"
	@cd apps/desktop && npm run build

## Build mobile app
build-mobile:
	@echo "$(BLUE)Building Flutter mobile app...$(NC)"
	@cd apps/mobile && flutter build apk --release

## Build hub Docker image
build-hub:
	@echo "$(BLUE)Building Home Hub Docker image...$(NC)"
	@docker build -f apps/hub/Dockerfile -t buddy-hub:latest .

## Run linters
lint:
	@echo "$(BLUE)Running linters...$(NC)"
	@./tools/dev/lint.sh

## Format code
format:
	@echo "$(BLUE)Formatting code...$(NC)"
	@./tools/dev/format.sh

## Clean build artifacts
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@rm -rf dist/ build/ *.egg-info/
	@cd apps/desktop && rm -rf dist/ node_modules/.cache/
	@cd apps/mobile && flutter clean
	@docker system prune -f