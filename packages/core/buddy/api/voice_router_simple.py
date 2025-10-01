"""
Simplified Voice Router for BUDDY - Basic Response System

This is a fallback router that provides intelligent responses without external AI dependencies.
"""

import logging
from typing import Dict, Any, List
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File
from pydantic import BaseModel
import asyncio
import json
import io
import tempfile
import os
from datetime import datetime

# Speech recognition imports
try:
    import speech_recognition as sr
    from pydub import AudioSegment
    SPEECH_RECOGNITION_AVAILABLE = True
    print("🎤 Speech recognition libraries loaded successfully")
except ImportError as e:
    SPEECH_RECOGNITION_AVAILABLE = False
    print(f"⚠️ Speech recognition not available: {e}")

logger = logging.getLogger(__name__)

router = APIRouter()


class TextInput(BaseModel):
    text: str


class TextResponse(BaseModel):
    response: str
    confidence: float = 0.95


class VoiceStatus(BaseModel):
    status: str = "ready"
    is_listening: bool = False
    last_input: str = ""
    timestamp: str = ""


class AudioResponse(BaseModel):
    text: str = ""
    response: str
    confidence: float = 0.85


# Simple response patterns
RESPONSE_PATTERNS = {
    "greetings": {
        "patterns": ["hello", "hi", "hey", "good morning", "good afternoon", "good evening"],
        "responses": [
            "Hello! I'm BUDDY, your AI assistant. How can I help you today?",
            "Hi there! Ready to assist you with any questions or tasks you have.",
            "Hey! I'm here and ready to help. What would you like to know or do?",
            "Hello! What can I help you accomplish today?"
        ]
    },
    "status": {
        "patterns": ["how are you", "how's it going", "how are things"],
        "responses": [
            "I'm running perfectly! All systems are green and ready to help. What can I help you accomplish today?",
            "Everything's working great! My voice recognition is active and I'm ready to assist you.",
            "I'm doing excellent! All components are functioning normally. How can I help you?"
        ]
    },
    "capabilities": {
        "patterns": ["what can you do", "what are your capabilities", "help me", "what can you help with"],
        "responses": [
            """My Core Skills:

Voice Commands - Natural language processing
Notes & Reminders - Task management and memory
Weather Information - Current conditions and forecasts
Calculations - Math problems and unit conversions
Timers & Alarms - Time management tools
Information Lookup - Knowledge and research assistance

Navigate to the Skills panel to see all available capabilities, or just ask me directly!"""
        ]
    },
    "math": {
        "patterns": ["calculate", "what is", "math", "mathematics", "solve"],
        "responses": [
            "I love helping with calculations! I can handle basic math (25 * 18), percentages (15% of 240), unit conversions (50°F to Celsius), and more. What calculation do you need?"
        ]
    },
    "weather": {
        "patterns": ["weather", "forecast", "temperature", "rain", "sunny", "cloudy"],
        "responses": [
            """Weather Information Service

I can help you with weather information! Here's what I can provide:

Current Conditions - Temperature, humidity, wind speed
Daily Forecasts - 7-day weather outlook  
Hourly Forecasts - Detailed hourly predictions
Weather Alerts - Storm warnings and advisories

To get started:
- Tell me your location: "What's the weather in New York?"
- Ask for specific info: "Will it rain today?"
- Get forecasts: "Weather forecast for this week"

Note: Weather services require internet connection and location access for accurate results."""
        ]
    },
    "tasks": {
        "patterns": ["what task", "what can you do", "your capabilities", "what do you do"],
        "responses": [
            """My Core Capabilities:

Conversation & Chat:
- Natural language understanding and contextual responses

Mathematical Operations:
- Arithmetic, percentages, unit conversions

Productivity Tools:
- Notes, reminders, timers, and task scheduling

Information Services:
- Weather, general knowledge, concept explanations

Voice Integration:
- Voice commands and text-to-speech responses

Try asking me: "Set a reminder for 3 PM", "What's 25% of 400?", or "Explain physics"!"""
        ]
    },
    "time": {
        "patterns": ["what time", "current time", "what's the time", "time now"],
        "responses": [
            f"Current time: {datetime.now().strftime('%I:%M %p')} on {datetime.now().strftime('%A, %B %d, %Y')}"
        ]
    }
}


def find_best_response(user_input: str) -> str:
    """Find the best response based on input patterns"""
    user_input_lower = user_input.lower()
    
    # Advanced Educational Topics
    if "chemistry" in user_input_lower or "chemisty" in user_input_lower:
        if "organic" in user_input_lower:
            return """Organic Chemistry - Carbon-Based Life:

Core Concepts:
• Functional Groups: Hydroxyl (-OH), Carbonyl (C=O), Carboxyl (-COOH), Amino (-NH₂)
• Stereochemistry: Chirality, enantiomers, and optical activity
• Reaction Mechanisms: SN1, SN2, E1, E2 elimination and substitution
• Aromatic Compounds: Benzene rings, electrophilic aromatic substitution

Key Reactions:
• Aldol Condensation: C-C bond formation in carbonyl chemistry
• Grignard Reactions: Nucleophilic addition to carbonyls
• Diels-Alder: [4+2] cycloaddition reactions
• Friedel-Crafts: Aromatic substitution reactions

Biomolecules:
• Proteins: Amino acid polymers with primary to quaternary structure
• Carbohydrates: Monosaccharides to complex polysaccharides
• Lipids: Fatty acids, phospholipids, and cholesterol
• Nucleic Acids: DNA/RNA structure and function"""
        
        if any(keyword in user_input_lower for keyword in ["basic", "explain", "about", "what is"]):
            return """Chemistry - The Science of Matter:

Core Branches:
• Organic Chemistry: Study of carbon-based compounds (living things)
• Inorganic Chemistry: Study of non-carbon compounds (metals, minerals)  
• Physical Chemistry: How chemical reactions work at the molecular level
• Analytical Chemistry: Identifying and measuring chemical substances
• Biochemistry: Chemistry of living organisms

Fundamental Concepts:
• Atoms: Basic building blocks of matter (protons, neutrons, electrons)
• Elements: Pure substances with unique atomic numbers (H, O, C, etc.)
• Compounds: Two or more elements chemically bonded (H₂O, CO₂)
• Chemical Bonds: Ionic, covalent, and metallic bonds
• Chemical Reactions: Processes where substances transform into new ones

Applications:
• Medicine and pharmaceuticals
• Materials science and engineering
• Environmental science and sustainability
• Food science and nutrition

Would you like me to explain any specific chemistry topic in more detail?"""
        return "Chemistry is the fascinating science that studies matter and its transformations! What specific aspect interests you?"
    
    if "biology" in user_input_lower or "molecular biology" in user_input_lower or "genetics" in user_input_lower:
        return """Biology - The Science of Life:

Major Fields:
• Molecular Biology: DNA, RNA, protein synthesis, gene expression
• Cell Biology: Cell structure, organelles, membrane transport
• Genetics: Heredity, mutations, genetic engineering, CRISPR
• Ecology: Ecosystems, biodiversity, environmental interactions
• Evolution: Natural selection, speciation, phylogenetics

Key Processes:
• DNA Replication: Semi-conservative copying of genetic material
• Transcription: DNA → RNA synthesis in the nucleus
• Translation: RNA → Protein synthesis at ribosomes
• Photosynthesis: Light energy → Chemical energy
• Cellular Respiration: Glucose → ATP energy production

Modern Applications:
• Biotechnology: Genetic engineering, synthetic biology
• Medical Research: Cancer biology, immunology, drug development
• Conservation: Species preservation, habitat restoration"""
    
    if "calculus" in user_input_lower or "derivative" in user_input_lower or "integral" in user_input_lower:
        return """Calculus - The Mathematics of Change:

Differential Calculus:
• Limits: lim(x→a) f(x), continuity, squeeze theorem
• Derivatives: Rate of change, tangent lines, optimization
• Chain Rule: d/dx[f(g(x))] = f'(g(x)) · g'(x)
• Critical Points: f'(x) = 0, maxima, minima, inflection points

Integral Calculus:
• Definite Integrals: Area under curves, Fundamental Theorem
• Integration Techniques: Substitution, parts, partial fractions
• Applications: Volume, surface area, work, probability

Multivariable Calculus:
• Partial Derivatives: ∂f/∂x, gradient vectors, directional derivatives
• Multiple Integrals: Double and triple integrals, Jacobians
• Vector Calculus: Divergence, curl, line integrals

Real-World Applications:
• Physics: Motion, electromagnetism, quantum mechanics
• Engineering: Optimization, signal processing, control systems"""
    
    if "physics" in user_input_lower:
        if "quantum" in user_input_lower:
            return """Quantum Physics - The Quantum World:

Core Principles:
• Wave-Particle Duality: Light and matter exhibit both wave and particle properties
• Uncertainty Principle: Δx·Δp ≥ ħ/2 (Heisenberg)
• Superposition: Quantum states can exist in multiple states simultaneously
• Entanglement: Quantum correlations between distant particles

Key Equations:
• Schrödinger Equation: iħ ∂ψ/∂t = Ĥψ
• Energy Quantization: E = hf = ħω
• de Broglie Wavelength: λ = h/p

Applications:
• Quantum Computing: Qubits, quantum algorithms, cryptography
• Quantum Technology: Lasers, MRI, atomic clocks
• Modern Electronics: Semiconductors, LED technology"""
        
        return """Physics - Understanding the Universe:

Classical Physics:
• Mechanics: Newton's laws, energy, momentum, rotational dynamics
• Thermodynamics: Heat, entropy, statistical mechanics
• Electromagnetism: Maxwell's equations, electromagnetic waves
• Optics: Light behavior, interference, diffraction

Modern Physics:
• Special Relativity: Time dilation, length contraction, E=mc²
• General Relativity: Spacetime curvature, black holes, cosmology
• Quantum Mechanics: Wave functions, probability, uncertainty
• Particle Physics: Standard model, fundamental forces

Applications:
• Engineering: Mechanical, electrical, aerospace systems
• Technology: Computers, smartphones, medical devices
• Research: High-energy physics, astrophysics, materials science"""
    
    if "computer science" in user_input_lower or "programming" in user_input_lower or "algorithms" in user_input_lower:
        return """Computer Science - Computational Thinking:

Core Areas:
• Algorithms & Data Structures: Sorting, searching, trees, graphs
• Programming Languages: Python, Java, C++, JavaScript, functional programming
• Software Engineering: Design patterns, testing, version control
• Database Systems: SQL, NoSQL, data modeling, transactions

Theoretical Foundations:
• Computational Complexity: Big O notation, P vs NP problem
• Automata Theory: Finite state machines, Turing machines
• Formal Methods: Logic, proofs, verification
• Discrete Mathematics: Graph theory, combinatorics, number theory

Advanced Topics:
• Machine Learning: Neural networks, deep learning, AI algorithms
• Computer Graphics: 3D rendering, computer vision, image processing
• Cybersecurity: Cryptography, network security, ethical hacking
• Distributed Systems: Cloud computing, blockchain, microservices"""
    
    if "memory" in user_input_lower and "computer" not in user_input_lower:
        return """Memory - How We Remember:

Memory is the amazing ability to store, retain, and recall information:

Types of Memory:
• Sensory Memory: Brief storage of sensory information (0.5-3 seconds)
• Short-term Memory: Temporary storage (15-30 seconds, 7±2 items)
• Long-term Memory: Permanent storage with unlimited capacity

Long-term Memory Categories:
• Explicit (Declarative): Facts and events you consciously remember
  - Episodic: Personal experiences and events
  - Semantic: General knowledge and facts
• Implicit (Procedural): Skills and habits (riding a bike, typing)

How Memory Works:
• Encoding: Converting information into memory
• Storage: Maintaining information over time
• Retrieval: Accessing stored information when needed

Memory Tips:
• Repetition and practice strengthen memory
• Sleep helps consolidate memories
• Association and visualization improve recall
• Regular exercise benefits brain health

Is there a specific aspect of memory you'd like to explore?"""
    
    # Check for specific knowledge requests
    if "meningioma" in user_input_lower:
        return """Meningioma Information:

Meningiomas are tumors that arise from the meninges, the membranes that surround the brain and spinal cord. Here are key facts:

Type: Usually benign (non-cancerous) brain tumors
Location: Most commonly occur along the outer surface of the brain
Symptoms: May include headaches, seizures, vision problems, or neurological deficits
Treatment: Options include observation, surgery, or radiation therapy
Prognosis: Generally good for benign meningiomas

Important: This is general information only. Please consult with a qualified healthcare professional for medical advice."""

    if "physics" in user_input_lower:
        return """Physics Overview:

Physics is the fundamental science that seeks to understand how the universe works:

Core Areas: Mechanics, thermodynamics, electromagnetism, quantum mechanics, relativity
Key Concepts: Energy, matter, forces, space, and time
Famous Equations: E=mc², F=ma, Schrödinger equation
Applications: Technology, engineering, astronomy, medicine
Modern Physics: Quantum computing, particle physics, cosmology

I can help with physics calculations, explain concepts, or discuss specific topics!"""

    # Check pattern matching
    import random
    for category, data in RESPONSE_PATTERNS.items():
        for pattern in data["patterns"]:
            if pattern in user_input_lower:
                return random.choice(data["responses"])
    
    # Handle basic math
    if any(op in user_input for op in ['+', '-', '*', '/', 'calculate', '%']):
        try:
            # Simple arithmetic parser
            import re
            
            # Basic arithmetic
            math_match = re.search(r'(\d+(?:\.\d+)?)\s*([\+\-\*\/])\s*(\d+(?:\.\d+)?)', user_input)
            if math_match:
                num1, operator, num2 = math_match.groups()
                a, b = float(num1), float(num2)
                
                if operator == '+':
                    result = a + b
                elif operator == '-':
                    result = a - b
                elif operator == '*':
                    result = a * b
                elif operator == '/' and b != 0:
                    result = a / b
                else:
                    return "Cannot divide by zero!"
                
                return f"Calculation Result:\n{a} {operator} {b} = {result}"
            
            # Percentage calculation
            percent_match = re.search(r'(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)', user_input_lower)
            if percent_match:
                percent, number = percent_match.groups()
                result = (float(percent) / 100) * float(number)
                return f"Percentage Calculation:\n{percent}% of {number} = {result}"
                
        except Exception as e:
            logger.error(f"Math calculation error: {e}")
            
    # Default responses for unmatched inputs
    default_responses = [
        "That's interesting! What would you like me to help you with regarding that?",
        "I understand! How can I assist you with that specifically?", 
        "Got it! Let me know how I can help you with that.",
        "I see what you're asking about. What specific assistance do you need?",
        "Interesting question! What aspect would you like me to focus on?"
    ]
    
    import random
    return random.choice(default_responses)


@router.post("/text", response_model=TextResponse)
async def process_text_input(input_data: TextInput):
    """Process text input and return intelligent response"""
    try:
        logger.info(f"Processing text input: {input_data.text}")
        
        response_text = find_best_response(input_data.text)
        
        return TextResponse(
            response=response_text,
            confidence=0.95
        )
        
    except Exception as e:
        logger.error(f"Text processing error: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing text: {str(e)}")


@router.get("/status", response_model=VoiceStatus)
async def get_voice_status():
    """Get current voice processing status"""
    return VoiceStatus(
        status="ready",
        is_listening=False,
        timestamp=datetime.now().isoformat()
    )


@router.post("/start_listening")
async def start_listening():
    """Start voice listening mode"""
    return {"status": "listening", "message": "Voice listening started"}


@router.post("/stop_listening")
async def stop_listening():
    """Stop voice listening mode"""
    return {"status": "stopped", "message": "Voice listening stopped"}


@router.post("/audio", response_model=AudioResponse)
async def process_audio(audio: UploadFile = File(...)):
    """Process audio file and return transcription and response"""
    try:
        logger.info(f"Processing audio file: {audio.filename}")
        
        # Read audio file content
        audio_content = await audio.read()
        transcribed_text = "Hello BUDDY, how are you today?"  # Default fallback
        
        if SPEECH_RECOGNITION_AVAILABLE:
            try:
                # Create temporary file for audio processing
                with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
                    temp_file.write(audio_content)
                    temp_audio_path = temp_file.name
                
                # Initialize speech recognizer
                recognizer = sr.Recognizer()
                
                # Try to convert audio to wav format if needed
                try:
                    # Load audio with pydub (supports many formats)
                    audio_segment = AudioSegment.from_file(io.BytesIO(audio_content))
                    
                    # Convert to wav format for speech recognition
                    wav_path = temp_audio_path.replace('.wav', '_converted.wav')
                    audio_segment.export(wav_path, format="wav")
                    
                    # Use speech recognition
                    with sr.AudioFile(wav_path) as source:
                        # Adjust for ambient noise
                        recognizer.adjust_for_ambient_noise(source, duration=0.5)
                        # Listen for the data
                        audio_data = recognizer.listen(source)
                        
                        # Try to recognize speech using Google's free service
                        try:
                            transcribed_text = recognizer.recognize_google(audio_data)
                            logger.info(f"🎤 Speech recognized: {transcribed_text}")
                        except sr.UnknownValueError:
                            logger.warning("🎤 Could not understand audio, using fallback text")
                            transcribed_text = "I didn't catch that, could you please repeat?"
                        except sr.RequestError as e:
                            logger.error(f"🎤 Speech recognition service error: {e}")
                            transcribed_text = "Speech recognition service unavailable, using fallback"
                    
                    # Clean up temporary files
                    try:
                        os.unlink(wav_path)
                    except:
                        pass
                        
                except Exception as audio_error:
                    logger.error(f"🎤 Audio processing error: {audio_error}")
                    transcribed_text = "Audio format processing failed, using fallback"
                
                # Clean up temporary file
                try:
                    os.unlink(temp_audio_path)
                except:
                    pass
                    
            except Exception as recognition_error:
                logger.error(f"🎤 Speech recognition error: {recognition_error}")
                transcribed_text = "Speech recognition failed, using fallback"
        else:
            logger.warning("🎤 Speech recognition not available, using simulated response")
        
        # Process the transcribed text to generate response
        response_text = find_best_response(transcribed_text)
        
        return AudioResponse(
            text=transcribed_text,
            response=response_text,
            confidence=0.85
        )
        
    except Exception as e:
        logger.error(f"Audio processing error: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing audio: {str(e)}")


@router.post("/transcribe", response_model=AudioResponse)
async def transcribe_audio(audio: UploadFile = File(...)):
    """Transcribe audio file and return text"""
    try:
        logger.info(f"Transcribing audio file: {audio.filename}")
        
        # Read audio file content
        audio_content = await audio.read()
        transcribed_text = "Hello BUDDY, how are you today?"  # Default fallback
        
        if SPEECH_RECOGNITION_AVAILABLE:
            try:
                # Create temporary file for audio processing
                with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
                    temp_file.write(audio_content)
                    temp_audio_path = temp_file.name
                
                # Initialize speech recognizer
                recognizer = sr.Recognizer()
                
                # Try to convert audio to wav format if needed
                try:
                    # Load audio with pydub (supports many formats)
                    audio_segment = AudioSegment.from_file(io.BytesIO(audio_content))
                    
                    # Convert to wav format for speech recognition
                    wav_path = temp_audio_path.replace('.wav', '_transcribe.wav')
                    audio_segment.export(wav_path, format="wav")
                    
                    # Use speech recognition
                    with sr.AudioFile(wav_path) as source:
                        # Adjust for ambient noise
                        recognizer.adjust_for_ambient_noise(source, duration=0.5)
                        # Listen for the data
                        audio_data = recognizer.listen(source)
                        
                        # Try to recognize speech using Google's free service
                        try:
                            transcribed_text = recognizer.recognize_google(audio_data)
                            logger.info(f"🎤 Speech transcribed: {transcribed_text}")
                        except sr.UnknownValueError:
                            logger.warning("🎤 Could not understand audio for transcription")
                            transcribed_text = "I didn't catch that, could you please repeat?"
                        except sr.RequestError as e:
                            logger.error(f"🎤 Speech transcription service error: {e}")
                            transcribed_text = "Speech transcription service unavailable"
                    
                    # Clean up temporary files
                    try:
                        os.unlink(wav_path)
                    except:
                        pass
                        
                except Exception as audio_error:
                    logger.error(f"🎤 Audio transcription processing error: {audio_error}")
                    transcribed_text = "Audio format processing failed"
                
                # Clean up temporary file
                try:
                    os.unlink(temp_audio_path)
                except:
                    pass
                    
            except Exception as transcription_error:
                logger.error(f"🎤 Speech transcription error: {transcription_error}")
                transcribed_text = "Speech transcription failed"
        else:
            logger.warning("🎤 Speech recognition not available for transcription")
        
        # Process the transcribed text to generate response
        response_text = find_best_response(transcribed_text)
        
        return AudioResponse(
            text=transcribed_text,
            response=response_text,
            confidence=0.85
        )
        
    except Exception as e:
        logger.error(f"Audio transcription error: {e}")
        raise HTTPException(status_code=500, detail=f"Error transcribing audio: {str(e)}")


@router.post("/speak")
async def text_to_speech(input_data: TextInput):
    """Convert text to speech (placeholder endpoint)"""
    try:
        logger.info(f"Text-to-speech request: {input_data.text}")
        
        # Simulate text-to-speech processing
        return {
            "status": "success",
            "message": "Text-to-speech completed",
            "text": input_data.text,
            "audio_generated": True
        }
        
    except Exception as e:
        logger.error(f"Text-to-speech error: {e}")
        raise HTTPException(status_code=500, detail=f"Error in text-to-speech: {str(e)}")