# BUDDY Personal AI Assistant
# Multi-stage Docker build for production deployment

# ================================
# Stage 1: Python Dependencies
# ================================
FROM python:3.11-slim as python-base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libffi-dev \
    libssl-dev \
    portaudio19-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --create-home --shell /bin/bash buddy

# ================================
# Stage 2: Model Downloads
# ================================
FROM python-base as model-stage

# Install Python dependencies for model downloads
COPY packages/core/pyproject.toml /tmp/
RUN pip install --upgrade pip setuptools wheel && \
    pip install toml requests huggingface_hub

# Create models directory
RUN mkdir -p /models/{whisper,piper,embeddings,wake_word}

# Download Whisper models
RUN python -c "\
    import whisper; \
    import os; \
    models = ['tiny', 'base']; \
    [whisper.load_model(model, download_root='/models/whisper') for model in models]; \
    print('✅ Whisper models downloaded')"

# Download sentence-transformers model
RUN python -c "\
    from sentence_transformers import SentenceTransformer; \
    import os; \
    model = SentenceTransformer('all-MiniLM-L6-v2'); \
    model.save('/models/embeddings/all-MiniLM-L6-v2'); \
    print('✅ Sentence transformer model downloaded')"

# ================================
# Stage 3: Production Image
# ================================
FROM python-base as production

# Install production dependencies
COPY packages/core/pyproject.toml packages/core/README.md /app/
WORKDIR /app

RUN pip install --upgrade pip setuptools wheel && \
    pip install . && \
    pip cache purge

# Copy models from model stage
COPY --from=model-stage /models /app/models

# Copy application code
COPY packages/core/buddy /app/buddy
COPY docker/entrypoint.sh /app/entrypoint.sh
COPY docker/healthcheck.py /app/healthcheck.py

# Set permissions
RUN chmod +x /app/entrypoint.sh && \
    chown -R buddy:buddy /app

# Switch to app user
USER buddy

# Create data directories
RUN mkdir -p /app/data/{db,logs,audio,sync}

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python /app/healthcheck.py

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["uvicorn", "buddy.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ================================
# Development Image
# ================================
FROM production as development

# Switch back to root for development tools
USER root

# Install development dependencies
RUN pip install \
    pytest \
    pytest-asyncio \
    pytest-cov \
    black \
    mypy \
    flake8 \
    isort \
    pre-commit

# Install Node.js for development tools
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Switch back to buddy user
USER buddy

# Override CMD for development
CMD ["uvicorn", "buddy.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# ================================
# Raspberry Pi ARM64 Image
# ================================
FROM arm64v8/python:3.11-slim as raspberry-pi

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    BUDDY_PLATFORM=raspberry-pi

# Install ARM-specific dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libatlas-base-dev \
    libhdf5-dev \
    libhdf5-serial-dev \
    libhdf5-103 \
    libqtgui4 \
    libqtwebkit4 \
    libqt4-test \
    python3-pyqt5 \
    libportaudio2 \
    libportaudiocpp0 \
    portaudio19-dev \
    ffmpeg \
    alsa-utils \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --create-home --shell /bin/bash buddy

# Install Python dependencies
COPY packages/core/pyproject.toml packages/core/README.md /app/
WORKDIR /app

# Install with ARM optimizations
RUN pip install --upgrade pip setuptools wheel && \
    pip install . --find-links https://www.piwheels.org/simple && \
    pip cache purge

# Copy application
COPY packages/core/buddy /app/buddy
COPY docker/entrypoint-rpi.sh /app/entrypoint.sh
COPY docker/healthcheck.py /app/healthcheck.py

# Set permissions
RUN chmod +x /app/entrypoint.sh && \
    chown -R buddy:buddy /app

# Switch to app user
USER buddy

# Create data directories
RUN mkdir -p /app/data/{db,logs,audio,sync}

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python /app/healthcheck.py

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["uvicorn", "buddy.main:app", "--host", "0.0.0.0", "--port", "8000"]