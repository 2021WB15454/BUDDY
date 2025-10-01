"""
Voice API Router

REST endpoints for voice processing functionality:
- Audio input and processing
- Speech recognition results
- Text-to-speech synthesis
- Voice pipeline status and control
"""

import asyncio
import logging
import re
import random
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Request
from pydantic import BaseModel

# Enhanced AI capabilities
try:
    import google.generativeai as genai
    GOOGLE_AI_AVAILABLE = True
except ImportError:
    GOOGLE_AI_AVAILABLE = False

logger = logging.getLogger(__name__)

router = APIRouter()

# Global voice pipeline instance
_voice_pipeline = None


def get_voice_pipeline():
    """Get the global voice pipeline instance"""
    return _voice_pipeline


def set_voice_pipeline(pipeline):
    """Set the global voice pipeline instance"""
    global _voice_pipeline
    _voice_pipeline = pipeline


class VoiceProcessRequest(BaseModel):
    """Request model for voice processing"""
    text: Optional[str] = None
    audio_format: str = "wav"
    sample_rate: int = 16000
    enable_streaming: bool = True


class TTSRequest(BaseModel):
    """Request model for text-to-speech"""
    text: str
    voice: Optional[str] = None
    speed: float = 1.0
    output_format: str = "wav"


class VoiceConfigRequest(BaseModel):
    """Request model for voice configuration"""
    wake_word_enabled: bool = True
    wake_word_sensitivity: float = 0.5
    asr_model: str = "whisper-tiny"
    tts_voice: str = "en_US-lessac-medium"
    streaming_enabled: bool = True


class TextProcessRequest(BaseModel):
    """Request model for text processing through voice pipeline"""
    text: str


@router.post("/text")
async def process_text(request: Request, text_request: TextProcessRequest):
    """
    Process text input through BUDDY's voice pipeline
    
    This endpoint allows text-based interaction with BUDDY,
    simulating voice input for chat interfaces.
    """
    try:
        # Get components from app state
        voice_pipeline = request.app.state.voice_pipeline
        skill_registry = request.app.state.skill_registry
        memory_manager = request.app.state.memory_manager
        event_bus = request.app.state.event_bus
        
        # Process the text input
        user_input = text_request.text.strip()
        
        if not user_input:
            raise HTTPException(status_code=400, detail="Text input cannot be empty")
        
        logger.info(f"Processing text input: {user_input}")
        
        # Store conversation turn in memory
        session_id = "web_chat"  # Use a default session for web chat
        await memory_manager.store_conversation_turn(
            session_id=session_id,
            user_input=user_input,
            assistant_response="",  # Will be filled later
            intent="text_chat",
            confidence=1.0
        )
        
        # Process through NLU to understand intent
        # For now, provide intelligent responses based on keywords
        response = await generate_response(user_input, skill_registry, memory_manager)
        
        # Store assistant response in memory
        await memory_manager.store_conversation_turn(
            session_id=session_id,
            user_input=user_input,
            assistant_response=response,
            intent="text_chat",
            confidence=1.0
        )
        
        # Publish TTS event for audio output (optional)
        await event_bus.publish("tts.speak", {"text": response})
        
        return {
            "success": True,
            "text": user_input,
            "response": response,
            "timestamp": "2025-09-30T18:33:00Z"
        }
        
    except Exception as e:
        logger.error(f"Text processing error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to process text: {str(e)}")


async def generate_response(user_input: str, skill_registry, memory_manager) -> str:
    """
    Generate an intelligent response to user input using enhanced AI capabilities
    
    Features:
    - Context-aware responses using conversation history
    - Integration with Google AI for natural language understanding
    - Skill-aware responses that guide users to available capabilities
    - Personality and conversational flow
    - Fallback to rule-based responses when AI is unavailable
    """
    
    user_input_lower = user_input.lower().strip()
    
    # Get conversation context from memory
    conversation_context = await get_conversation_context(memory_manager)
    
    # Try Google AI enhanced response first (if available and configured)
    if GOOGLE_AI_AVAILABLE:
        try:
            enhanced_response = await generate_ai_response(
                user_input, conversation_context, skill_registry
            )
            if enhanced_response:
                return enhanced_response
        except Exception as e:
            logger.warning(f"Google AI response failed, falling back to rule-based: {e}")
    
    # Enhanced rule-based responses with personality
    return await generate_rule_based_response(user_input, user_input_lower, skill_registry, conversation_context)


async def get_conversation_context(memory_manager, max_turns: int = 5) -> List[Dict]:
    """Get recent conversation context for enhanced responses"""
    try:
        # Get recent conversation turns from memory
        recent_conversations = await memory_manager.get_recent_conversations(
            session_id="web_chat", 
            limit=max_turns
        )
        return recent_conversations or []
    except Exception as e:
        logger.warning(f"Failed to get conversation context: {e}")
        return []


async def generate_ai_response(user_input: str, context: List[Dict], skill_registry) -> Optional[str]:
    """Generate response using Google AI with context awareness"""
    try:
        from ..config import settings
        
        # Check both GOOGLE_API_KEY and BUDDY_GOOGLE_API_KEY
        api_key = settings.GOOGLE_API_KEY or getattr(settings, 'BUDDY_GOOGLE_API_KEY', None)
        if not api_key:
            logger.debug("No Google AI API key configured")
            return None
            
        # Configure Google AI
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-pro')
        
        # Build context-aware prompt
        prompt = build_ai_prompt(user_input, context, skill_registry)
        
        # Generate response with safety settings
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                temperature=0.7,
                max_output_tokens=300,
                top_p=0.8,
                top_k=40
            ),
            safety_settings={
                genai.types.HarmCategory.HARM_CATEGORY_HARASSMENT: genai.types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
                genai.types.HarmCategory.HARM_CATEGORY_HATE_SPEECH: genai.types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
                genai.types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: genai.types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
                genai.types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: genai.types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
            }
        )
        
        if response.text:
            return response.text.strip()
            
    except Exception as e:
        logger.error(f"Google AI response generation failed: {e}")
        
    return None


def build_ai_prompt(user_input: str, context: List[Dict], skill_registry) -> str:
    """Build a comprehensive prompt for Google AI"""
    
    # Get available skills
    available_skills = []
    if skill_registry and hasattr(skill_registry, '_skills'):
        for skill_name, skill in skill_registry._skills.items():
            if hasattr(skill, 'metadata'):
                metadata = skill.metadata
                available_skills.append({
                    'name': metadata.name,
                    'description': metadata.description,
                    'category': metadata.category
                })
    
    # Build context from recent conversations
    context_str = ""
    if context:
        context_str = "\n\nRecent conversation context:\n"
        for turn in context[-3:]:  # Last 3 turns
            if 'user_input' in turn and 'assistant_response' in turn:
                context_str += f"User: {turn['user_input']}\nBUDDY: {turn['assistant_response']}\n"
    
    # Build skills description
    skills_str = ""
    if available_skills:
        skills_str = f"\n\nMy available capabilities include:\n"
        for skill in available_skills[:8]:  # Top skills
            skills_str += f"• {skill['name']}: {skill['description']}\n"
    
    current_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    
    prompt = f"""You are BUDDY, a helpful personal AI assistant with a friendly, conversational personality. 
You're designed to be helpful, knowledgeable, and engaging while maintaining a natural conversational tone.

Current time: {current_time}

Your core traits:
- Friendly and approachable, but professional
- Proactive in offering help and suggestions
- Clear and concise in explanations
- Encouraging and positive
- Remember context from our conversation

{skills_str}

{context_str}

User's current message: "{user_input}"

Respond naturally and helpfully. If the user is asking about capabilities you have, mention the relevant features. 
If they're making small talk, engage conversationally. If they need help with a task, guide them clearly.
Keep responses under 200 words and maintain a warm, helpful tone.

Your response:"""

    return prompt


async def generate_rule_based_response(user_input: str, user_input_lower: str, skill_registry, context: List[Dict]) -> str:
    """Enhanced rule-based response generation with personality and context"""
    
    # Determine if this is a returning conversation
    is_returning = len(context) > 0
    
    # Time-aware greetings
    current_hour = datetime.now().hour
    if current_hour < 12:
        time_greeting = "Good morning"
    elif current_hour < 17:
        time_greeting = "Good afternoon"
    else:
        time_greeting = "Good evening"
    
    # Enhanced greeting responses
    if any(greeting in user_input_lower for greeting in ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening']):
        if is_returning:
            return f"{time_greeting}! Great to see you back. What can I help you with today?"
        else:
            return f"{time_greeting}! I'm BUDDY, your personal AI assistant. I'm here to help you with tasks like setting reminders, checking weather, managing notes, and much more. What would you like to do?"
    
    # Enhanced capability questions
    if any(phrase in user_input_lower for phrase in ['what can you do', 'help me', 'capabilities', 'features', 'what are you']):
        skills_count = len(skill_registry._skills) if skill_registry and hasattr(skill_registry, '_skills') else 5
        
        return f"""I'm BUDDY, your intelligent personal assistant! I have {skills_count} core capabilities:

🎤 **Voice & Chat** - Natural conversation through voice or text
📝 **Notes & Reminders** - Never forget important tasks or ideas
🌤️ **Weather** - Current conditions and forecasts anywhere
🧮 **Calculations** - Math, conversions, and quick computations  
⏱️ **Timers** - Multiple timers for cooking, work, breaks
🧠 **Memory** - I remember our conversations and your preferences
🔄 **Multi-Device** - Access me from any device on your network

I'm designed to be conversational and helpful! Try:
• "Set a reminder to call mom at 3 PM"
• "What's the weather forecast?"
• "Start a 25-minute focus timer"
• "Calculate 15% tip on $47.50"

What interests you most?"""

    # Enhanced skill-specific guidance
    if 'timer' in user_input_lower:
        return "I'd love to help with timers! I can set multiple timers simultaneously and give you clear notifications. Try: 'Set a 10-minute timer for pasta' or 'Start a 25-minute focus session'. What timer do you need?"
    
    if 'weather' in user_input_lower:
        return "I can give you detailed weather information! Ask me 'What's the weather like?', 'Will it rain today?', or 'Show me tomorrow's forecast'. I can check any location worldwide. Where would you like to check?"
    
    if any(word in user_input_lower for word in ['reminder', 'remind', 'remember']):
        return "Perfect! I excel at reminders. I can set one-time reminders like 'Remind me to call the dentist at 2 PM' or recurring ones like 'Remind me to take vitamins daily at 8 AM'. What reminder can I set for you?"
    
    if 'note' in user_input_lower:
        return "I'm great with notes! I can create organized notes, shopping lists, meeting summaries, or quick thoughts. Try 'Create a note about vacation planning' or 'Add milk to my shopping list'. What would you like to jot down?"
    
    if any(word in user_input_lower for word in ['calculate', 'math', 'convert']):
        return "I love helping with calculations! I can handle basic math (25 * 18), percentages (15% of 240), unit conversions (50°F to Celsius), and more. What calculation do you need?"
    
    # Enhanced math processing
    if any(op in user_input for op in ['+', '-', '*', '/', '=']):
        try:
            # Extract mathematical expression
            import re
            math_patterns = [
                r'(\d+(?:\.\d+)?)\s*([+\-*/])\s*(\d+(?:\.\d+)?)',
                r'(\d+)\s*\%\s*of\s*(\d+)',
                r'what.{0,10}(\d+(?:\.\d+)?)\s*([+\-*/])\s*(\d+(?:\.\d+)?)'
            ]
            
            for pattern in math_patterns:
                match = re.search(pattern, user_input, re.IGNORECASE)
                if match:
                    if '% of' in user_input.lower():
                        percent = float(match.group(1))
                        number = float(match.group(2))
                        result = (percent / 100) * number
                        return f"✨ {percent}% of {number} = **{result}**\n\nNeed another calculation?"
                    else:
                        num1, op, num2 = float(match.group(1)), match.group(2), float(match.group(3))
                        operations = {'+': num1 + num2, '-': num1 - num2, '*': num1 * num2, '/': num1 / num2}
                        if op in operations:
                            result = operations[op]
                            return f"✨ {num1} {op} {num2} = **{result}**\n\nAnything else you'd like me to calculate?"
        except:
            pass
        return "I can help with that calculation! Try asking me something like '25 + 17', '15% of 200', or 'what's 12 times 8?'"
    
    # Enhanced status responses
    if any(phrase in user_input_lower for phrase in ['how are you', 'status', 'running', 'working']):
        uptime_responses = [
            "I'm running perfectly! All systems are green and ready to help.",
            "Feeling great! My voice, memory, and skills are all operating smoothly.",
            "I'm doing wonderful! All my capabilities are online and ready for action."
        ]
        return f"{random.choice(uptime_responses)} What can I help you accomplish today?"
    
    # Enhanced thank you responses
    if any(phrase in user_input_lower for phrase in ['thank you', 'thanks', 'appreciate']):
        thanks_responses = [
            "You're very welcome! I'm always here when you need assistance.",
            "My pleasure! That's what I'm here for. Anything else I can help with?",
            "Happy to help! Feel free to ask me anything else you need."
        ]
        return random.choice(thanks_responses)
    
    # Enhanced goodbye responses
    if any(phrase in user_input_lower for phrase in ['bye', 'goodbye', 'see you', 'talk later']):
        goodbye_responses = [
            "Goodbye! I'll be here whenever you need me. Have a great day!",
            "See you later! Don't hesitate to come back if you need anything.",
            "Take care! I'm always here and ready to help when you return."
        ]
        return random.choice(goodbye_responses)
    
    # Context-aware generic responses
    if is_returning:
        generic_responses = [
            "I understand! Let me know specifically how I can help with that.",
            "That's interesting! What would you like me to do regarding that?",
            "Got it! How can I assist you with that specifically?",
            "I'm following along! What specific help do you need with that?"
        ]
    else:
        generic_responses = [
            "I'm here to help! I can assist with reminders, weather, calculations, timers, notes, and general questions. What would you like to try?",
            "I'd love to help you with that! I have capabilities for productivity, information, and organization. What specific task can I help with?",
            "That sounds interesting! I can help with various tasks including scheduling, weather, math, and note-taking. What would be most useful right now?"
        ]
    
    return random.choice(generic_responses)


@router.post("/process")
async def process_voice(
    request: Request,
    audio: UploadFile = File(None),
    config: VoiceProcessRequest = None
):
    """
    Process voice input through the complete pipeline
    
    Can accept either:
    - Audio file upload for batch processing
    - Configuration for streaming processing (use WebSocket)
    """
    try:
        voice_pipeline = request.app.state.voice_pipeline
        
        if audio:
            # Process uploaded audio file
            audio_data = await audio.read()
            
            # TODO: Convert audio format if needed
            # TODO: Process through voice pipeline
            
            result = {
                "success": True,
                "transcript": "Mock transcription of uploaded audio",
                "confidence": 0.95,
                "intent": {
                    "name": "general.chat",
                    "confidence": 0.8,
                    "entities": {}
                },
                "response": "I processed your audio input successfully!"
            }
            
            return result
        
        else:
            # Return streaming instructions
            return {
                "message": "For real-time voice processing, connect to /ws/voice WebSocket endpoint",
                "websocket_url": "/ws/voice",
                "supported_formats": ["audio/wav", "audio/webm"],
                "sample_rate": 16000
            }
    
    except Exception as e:
        logger.error(f"Voice processing error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/tts")
async def text_to_speech(request: Request, tts_request: TTSRequest):
    """
    Convert text to speech
    
    Returns audio data or stream URL
    """
    try:
        voice_pipeline = request.app.state.voice_pipeline
        
        # Generate speech
        # TODO: Use actual TTS from voice pipeline
        
        # For now, return mock response
        result = {
            "success": True,
            "text": tts_request.text,
            "voice": tts_request.voice or "default",
            "audio_url": f"/api/v1/voice/audio/{hash(tts_request.text)}",
            "duration_ms": len(tts_request.text) * 50,  # Mock duration
            "format": tts_request.output_format
        }
        
        # Trigger TTS through event bus
        event_bus = request.app.state.event_bus
        await event_bus.publish_tts_speak(tts_request.text, tts_request.voice)
        
        return result
    
    except Exception as e:
        logger.error(f"TTS error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status")
async def get_voice_status(request: Request):
    """Get voice pipeline status and configuration"""
    try:
        voice_pipeline = request.app.state.voice_pipeline
        
        return {
            "status": "ready" if voice_pipeline.is_ready() else "not_ready",
            "state": voice_pipeline.state.value,
            "config": {
                "wake_word_enabled": voice_pipeline.config.wake_word_enabled,
                "wake_word_model": voice_pipeline.config.wake_word_model,
                "asr_model": voice_pipeline.config.asr_model,
                "tts_voice": voice_pipeline.config.tts_voice,
                "streaming_enabled": voice_pipeline.config.streaming_enabled
            },
            "metrics": voice_pipeline.get_metrics()
        }
    
    except Exception as e:
        logger.error(f"Voice status error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/config")
async def update_voice_config(request: Request, config: VoiceConfigRequest):
    """Update voice pipeline configuration"""
    try:
        voice_pipeline = request.app.state.voice_pipeline
        
        # Update configuration
        voice_pipeline.config.wake_word_enabled = config.wake_word_enabled
        voice_pipeline.config.wake_word_sensitivity = config.wake_word_sensitivity
        voice_pipeline.config.asr_model = config.asr_model
        voice_pipeline.config.tts_voice = config.tts_voice
        voice_pipeline.config.streaming_enabled = config.streaming_enabled
        
        # TODO: Reinitialize components if needed
        
        return {
            "success": True,
            "message": "Voice configuration updated",
            "config": {
                "wake_word_enabled": config.wake_word_enabled,
                "wake_word_sensitivity": config.wake_word_sensitivity,
                "asr_model": config.asr_model,
                "tts_voice": config.tts_voice,
                "streaming_enabled": config.streaming_enabled
            }
        }
    
    except Exception as e:
        logger.error(f"Voice config update error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/wake")
async def trigger_wake_word(request: Request):
    """Manually trigger wake word detection (for testing)"""
    try:
        event_bus = request.app.state.event_bus
        await event_bus.publish_wake_word(confidence=1.0)
        
        return {
            "success": True,
            "message": "Wake word triggered"
        }
    
    except Exception as e:
        logger.error(f"Wake word trigger error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/models")
async def get_available_models():
    """Get list of available voice models"""
    return {
        "asr_models": [
            {"name": "whisper-tiny", "size": "39MB", "languages": ["en"], "accuracy": "good"},
            {"name": "whisper-base", "size": "74MB", "languages": ["en", "es", "fr", "de"], "accuracy": "better"},
            {"name": "vosk-small", "size": "50MB", "languages": ["en"], "accuracy": "good"}
        ],
        "tts_voices": [
            {"name": "en_US-lessac-medium", "language": "en-US", "gender": "female", "quality": "medium"},
            {"name": "en_US-ryan-medium", "language": "en-US", "gender": "male", "quality": "medium"},
            {"name": "en_GB-alan-medium", "language": "en-GB", "gender": "male", "quality": "medium"}
        ],
        "wake_word_models": [
            {"name": "porcupine", "keywords": ["hey-buddy", "buddy"], "accuracy": "high"},
            {"name": "precise", "keywords": ["hey-buddy"], "accuracy": "medium"}
        ]
    }


@router.post("/audio")
async def process_audio(
    request: Request,
    audio: UploadFile = File(...)
):
    """
    Process uploaded audio file for speech recognition
    
    This endpoint handles audio uploads from the frontend voice interface
    """
    try:
        # Get components from app state
        skill_registry = request.app.state.skill_registry
        memory_manager = request.app.state.memory_manager
        event_bus = request.app.state.event_bus
        
        # Read audio data
        audio_data = await audio.read()
        
        # For now, we'll simulate speech recognition
        # In a real implementation, this would use Whisper or another ASR model
        
        # Mock transcription based on audio length
        audio_length = len(audio_data)
        if audio_length < 10000:  # Very short audio
            transcription = "Hello BUDDY"
        elif audio_length < 50000:  # Medium audio
            transcription = "What can you do?"
        else:  # Longer audio
            transcription = "Tell me about your capabilities"
        
        logger.info(f"Processing audio upload: {audio.filename}, size: {audio_length} bytes")
        logger.info(f"Mock transcription: {transcription}")
        
        # Process the transcribed text through the same pipeline as text input
        session_id = "voice_chat"
        
        # Store conversation turn in memory
        await memory_manager.store_conversation_turn(
            session_id=session_id,
            user_input=transcription,
            assistant_response="",  # Will be filled later
            intent="voice_chat",
            confidence=0.9
        )
        
        # Generate response
        response = await generate_response(transcription, skill_registry, memory_manager)
        
        # Store assistant response in memory
        await memory_manager.store_conversation_turn(
            session_id=session_id,
            user_input=transcription,
            assistant_response=response,
            intent="voice_chat",
            confidence=0.9
        )
        
        # Publish TTS event for audio output
        await event_bus.publish("tts.speak", {"text": response})
        
        return {
            "success": True,
            "transcription": transcription,
            "confidence": 0.9,
            "response": response,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error(f"Audio processing error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to process audio: {str(e)}")


@router.get("/audio/{audio_id}")
async def get_audio_file(audio_id: str):
    """Get generated audio file"""
    # TODO: Implement audio file serving
    # For now, return placeholder
    raise HTTPException(status_code=404, detail="Audio file not found")


@router.delete("/audio/{audio_id}")
async def delete_audio_file(audio_id: str):
    """Delete generated audio file"""
    # TODO: Implement audio file deletion
    return {"success": True, "message": f"Audio file {audio_id} deleted"}


@router.get("/capabilities")
async def get_voice_capabilities():
    """Get voice processing capabilities of this device"""
    return {
        "wake_word": True,
        "streaming_asr": True,
        "offline_asr": True,
        "online_asr": False,
        "tts": True,
        "voice_activity_detection": True,
        "noise_suppression": True,
        "echo_cancellation": False,
        "supported_languages": ["en-US", "en-GB"],
        "supported_audio_formats": ["wav", "webm", "ogg"],
        "max_audio_duration": 300  # seconds
    }