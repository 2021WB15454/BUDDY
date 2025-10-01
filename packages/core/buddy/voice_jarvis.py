"""
BUDDY Voice Pipeline - Enhanced with JARVIS-Style Recognition

This module provides advanced voice processing capabilities with JARVIS-like features.
The implementation has been enhanced to support:

- Continuous voice monitoring with ultra-low latency
- Advanced wake word detection with multiple phrases
- Real-time streaming speech recognition
- Context-aware natural language understanding
- Intelligent dialogue management with personality
- Emotional text-to-speech synthesis
- Voice biometrics and user recognition
- Adaptive learning and customization
- Advanced noise suppression and audio processing

For the full JARVIS-style implementation, see voice_advanced.py
"""

import logging
from .voice_advanced import JarvisVoicePipeline

logger = logging.getLogger(__name__)

# Use the advanced JARVIS-style voice pipeline as the main implementation
VoicePipeline = JarvisVoicePipeline

logger.info("🤖 BUDDY Voice Pipeline enhanced with JARVIS-style recognition capabilities")

# Export the main class and any additional components
__all__ = ['VoicePipeline', 'JarvisVoicePipeline']