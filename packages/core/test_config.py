#!/usr/bin/env python3
"""
Test script to verify BUDDY configuration is loading API keys correctly
"""

from buddy.config import settings

def test_configuration():
    """Test that configuration values are loaded properly"""
    
    print("🔧 BUDDY Configuration Test")
    print("=" * 50)
    
    # Basic settings
    print(f"🌐 Host: {settings.HOST}")
    print(f"🔌 Port: {settings.PORT}")
    print(f"🐛 Debug: {settings.DEBUG}")
    
    # API Keys (masked for security)
    print("\n🔑 API Keys:")
    print(f"   Google API: {'✅ Set' if settings.GOOGLE_API_KEY else '❌ Not set'}")
    print(f"   OpenWeather: {'✅ Set' if settings.OPENWEATHER_API_KEY else '❌ Not set'}")
    print(f"   Geoapify: {'✅ Set' if settings.GEOAPIFY_API_KEY else '❌ Not set'}")
    print(f"   AlphaVantage: {'✅ Set' if settings.ALPHAVANTAGE_API_KEY else '❌ Not set'}")
    print(f"   News API: {'✅ Set' if settings.NEWSAPI_KEY else '❌ Not set'}")
    print(f"   YouTube: {'✅ Set' if settings.YOUTUBE_API_KEY else '❌ Not set'}")
    
    # Voice Configuration
    print("\n🎤 Voice Configuration:")
    print(f"   Voice Enabled: {settings.VOICE_ENABLED}")
    print(f"   Background Voice: {settings.BACKGROUND_VOICE}")
    print(f"   Voice Threshold: {settings.VOICE_THRESHOLD}")
    
    # Network Configuration
    print("\n🌐 Network Configuration:")
    print(f"   Max Devices: {settings.MAX_DEVICES_PER_USER}")
    print(f"   Sync Interval: {settings.SYNC_INTERVAL}s")
    print(f"   Device Timeout: {settings.DEVICE_TIMEOUT}s")
    
    # Chat Configuration
    print("\n💬 Chat Configuration:")
    print(f"   Max Chat History: {settings.MAX_CHAT_HISTORY}")
    print(f"   Response Timeout: {settings.RESPONSE_TIMEOUT}s")
    
    print("\n✅ Configuration test completed!")

if __name__ == "__main__":
    test_configuration()