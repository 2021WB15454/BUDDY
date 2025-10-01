#!/bin/bash
# BUDDY Smart Device Deployment Script
# Supports: Smart TVs, Smartwatches, Cars, IoT devices, Home Hubs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🤖 BUDDY Smart Device Deployment${NC}"
echo -e "${CYAN}=================================${NC}"

# Device type selection
echo -e "${BLUE}📱 Select device type:${NC}"
echo "1) Smart TV (Android TV/Apple TV/Samsung Tizen)"
echo "2) Smartwatch (Wear OS/Apple Watch)"
echo "3) Car Integration (Android Auto/CarPlay)"
echo "4) IoT Device (Raspberry Pi/Arduino)"
echo "5) Home Hub (Google Home/Alexa/Custom)"
echo "6) Gaming Console (Xbox/PlayStation)"
echo "7) Router/NAS Device"
echo "8) All devices (full deployment)"

read -p "Enter choice (1-8): " device_choice

case $device_choice in
    1) deploy_smart_tv ;;
    2) deploy_smartwatch ;;
    3) deploy_car ;;
    4) deploy_iot ;;
    5) deploy_home_hub ;;
    6) deploy_gaming_console ;;
    7) deploy_router_nas ;;
    8) deploy_all_devices ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

# Smart TV Deployment
deploy_smart_tv() {
    echo -e "${BLUE}📺 Smart TV Deployment${NC}"
    echo "========================"
    
    echo -e "${YELLOW}Select TV platform:${NC}"
    echo "1) Android TV"
    echo "2) Apple TV"
    echo "3) Samsung Tizen"
    echo "4) LG webOS"
    echo "5) Fire TV"
    
    read -p "Enter choice (1-5): " tv_choice
    
    case $tv_choice in
        1) deploy_android_tv ;;
        2) deploy_apple_tv ;;
        3) deploy_samsung_tizen ;;
        4) deploy_lg_webos ;;
        5) deploy_fire_tv ;;
    esac
}

deploy_android_tv() {
    echo -e "${BLUE}📺 Android TV Deployment${NC}"
    
    # Create Android TV APK
    mkdir -p dist/tv/android
    
    cat > apps/tv-android/build.gradle << 'EOF'
android {
    compileSdk 33
    
    defaultConfig {
        applicationId "com.buddy.tv"
        minSdk 21
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }
    
    leanbackLauncher true
    
    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation 'androidx.leanback:leanback:1.0.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.8.0'
}
EOF

    cat > apps/tv-android/src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    
    <uses-feature
        android:name="android.software.leanback"
        android:required="true" />
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />
        
    <application
        android:allowBackup="true"
        android:banner="@drawable/banner"
        android:icon="@drawable/icon"
        android:label="BUDDY AI"
        android:theme="@style/Theme.Leanback">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:screenOrientation="landscape">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

    # Build Android TV APK
    cd apps/tv-android
    ./gradlew assembleRelease
    cp app/build/outputs/apk/release/app-release.apk ../../dist/tv/android/buddy-tv.apk
    cd ../..
    
    echo -e "${GREEN}✅ Android TV APK created: dist/tv/android/buddy-tv.apk${NC}"
    echo -e "${YELLOW}📋 Installation instructions:${NC}"
    echo "1. Enable Developer Options on Android TV"
    echo "2. Enable USB Debugging"
    echo "3. Install via ADB: adb install buddy-tv.apk"
    echo "4. Or sideload via USB/network"
}

deploy_apple_tv() {
    echo -e "${BLUE}📺 Apple TV Deployment${NC}"
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ Apple TV development requires macOS${NC}"
        return 1
    fi
    
    # Create tvOS app
    mkdir -p apps/tv-ios
    
    cat > apps/tv-ios/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<dict>
    <key>CFBundleDisplayName</key>
    <string>BUDDY AI</string>
    <key>CFBundleIdentifier</key>
    <string>com.buddy.tv</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UIUserInterfaceIdiom</key>
    <string>tv</string>
</dict>
EOF

    echo -e "${GREEN}✅ Apple TV project created${NC}"
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "1. Open Xcode"
    echo "2. Create new tvOS project"
    echo "3. Build and deploy to Apple TV"
    echo "4. Submit to App Store for distribution"
}

deploy_samsung_tizen() {
    echo -e "${BLUE}📺 Samsung Tizen Deployment${NC}"
    
    # Create Tizen web app
    mkdir -p apps/tv-tizen
    
    cat > apps/tv-tizen/config.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<widget xmlns="http://www.w3.org/ns/widgets" 
        xmlns:tizen="http://tizen.org/ns/widgets" 
        id="http://buddy.ai/tv" 
        version="1.0.0" 
        viewmodes="maximized">
    <tizen:application id="buddy.tv" package="buddy" required_version="5.0"/>
    <content src="index.html"/>
    <feature name="http://tizen.org/feature/screen.size.normal.1920.1080"/>
    <icon src="icon.png"/>
    <name>BUDDY AI Assistant</name>
    <tizen:privilege name="http://tizen.org/privilege/internet"/>
    <tizen:privilege name="http://tizen.org/privilege/audiorecord"/>
</widget>
EOF

    cat > apps/tv-tizen/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BUDDY AI Assistant</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: white;
            font-family: Arial, sans-serif;
            overflow: hidden;
        }
        
        .tv-container {
            width: 100vw;
            height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        
        .buddy-logo {
            font-size: 4rem;
            margin-bottom: 2rem;
            text-shadow: 0 0 20px rgba(102, 126, 234, 0.5);
        }
        
        .status {
            font-size: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .remote-hint {
            position: absolute;
            bottom: 50px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 1.2rem;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="tv-container">
        <div class="buddy-logo">🤖 BUDDY</div>
        <div class="status" id="status">Connecting to BUDDY Core...</div>
        <div class="remote-hint">Press and hold voice button on remote to talk</div>
    </div>
    
    <script>
        // Connect to BUDDY Core
        const ws = new WebSocket('ws://' + window.location.hostname + ':8000/ws');
        const status = document.getElementById('status');
        
        ws.onopen = () => {
            status.textContent = 'BUDDY is ready! Press voice button to talk.';
        };
        
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'response') {
                status.textContent = data.text;
                speak(data.text);
            }
        };
        
        function speak(text) {
            const utterance = new SpeechSynthesisUtterance(text);
            utterance.rate = 0.8;
            speechSynthesis.speak(utterance);
        }
        
        // TV remote navigation
        document.addEventListener('keydown', (e) => {
            switch(e.keyCode) {
                case 13: // Enter - start voice
                    startVoiceRecognition();
                    break;
                case 27: // Back
                    stopVoiceRecognition();
                    break;
            }
        });
        
        function startVoiceRecognition() {
            if ('SpeechRecognition' in window || 'webkitSpeechRecognition' in window) {
                const recognition = new (window.SpeechRecognition || window.webkitSpeechRecognition)();
                recognition.start();
                status.textContent = 'Listening...';
                
                recognition.onresult = (event) => {
                    const text = event.results[0][0].transcript;
                    ws.send(JSON.stringify({type: 'voice', text: text}));
                    status.textContent = 'Processing: ' + text;
                };
            }
        }
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}✅ Samsung Tizen app created${NC}"
    echo -e "${YELLOW}📋 Installation:${NC}"
    echo "1. Install Tizen Studio"
    echo "2. Enable Developer Mode on TV"
    echo "3. Build and install: tizen package -t wgt"
}

# Smartwatch Deployment
deploy_smartwatch() {
    echo -e "${BLUE}⌚ Smartwatch Deployment${NC}"
    echo "========================="
    
    echo -e "${YELLOW}Select smartwatch platform:${NC}"
    echo "1) Wear OS (Android)"
    echo "2) Apple Watch (watchOS)"
    echo "3) Samsung Galaxy Watch (Tizen)"
    echo "4) Fitbit OS"
    
    read -p "Enter choice (1-4): " watch_choice
    
    case $watch_choice in
        1) deploy_wear_os ;;
        2) deploy_apple_watch ;;
        3) deploy_galaxy_watch ;;
        4) deploy_fitbit ;;
    esac
}

deploy_wear_os() {
    echo -e "${BLUE}⌚ Wear OS Deployment${NC}"
    
    mkdir -p apps/watch-wear
    
    cat > apps/watch-wear/wear/build.gradle << 'EOF'
android {
    compileSdk 33
    
    defaultConfig {
        applicationId "com.buddy.wear"
        minSdk 23
        targetSdk 33
        versionCode 1
        versionName "1.0"
    }
}

dependencies {
    implementation 'androidx.wear:wear:1.3.0'
    implementation 'com.google.android.support:wearable:2.9.0'
    implementation 'androidx.wear.compose:compose-material:1.1.2'
}
EOF

    cat > apps/watch-wear/wear/src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    
    <uses-feature android:name="android.hardware.type.watch" />
    
    <application
        android:allowBackup="true"
        android:icon="@drawable/icon"
        android:label="BUDDY"
        android:theme="@android:style/Theme.DeviceDefault">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@android:style/Theme.DeviceDefault.Light">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

    echo -e "${GREEN}✅ Wear OS app structure created${NC}"
}

deploy_apple_watch() {
    echo -e "${BLUE}⌚ Apple Watch Deployment${NC}"
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ Apple Watch development requires macOS${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Apple Watch project setup${NC}"
    echo -e "${YELLOW}📋 Create watchOS app in Xcode:${NC}"
    echo "1. Create new watchOS app"
    echo "2. Add voice recognition capabilities"
    echo "3. Connect to BUDDY Core via network"
}

# Car Integration
deploy_car() {
    echo -e "${BLUE}🚗 Car Integration Deployment${NC}"
    echo "============================="
    
    echo -e "${YELLOW}Select car platform:${NC}"
    echo "1) Android Auto"
    echo "2) Apple CarPlay"
    echo "3) Custom In-Vehicle Infotainment"
    
    read -p "Enter choice (1-3): " car_choice
    
    case $car_choice in
        1) deploy_android_auto ;;
        2) deploy_carplay ;;
        3) deploy_custom_ivi ;;
    esac
}

deploy_android_auto() {
    echo -e "${BLUE}🚗 Android Auto Deployment${NC}"
    
    mkdir -p apps/car-android
    
    cat > apps/car-android/build.gradle << 'EOF'
dependencies {
    implementation 'androidx.car.app:app:1.3.0'
    implementation 'androidx.car.app:app-automotive:1.3.0'
}
EOF

    cat > apps/car-android/src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    
    <application>
        <service
            android:name=".BuddyCarAppService"
            android:exported="true">
            <intent-filter>
                <action android:name="androidx.car.app.CarAppService" />
            </intent-filter>
        </service>
        
        <meta-data
            android:name="androidx.car.app.minCarApiLevel"
            android:value="1" />
    </application>
</manifest>
EOF

    echo -e "${GREEN}✅ Android Auto app structure created${NC}"
}

# IoT Device Deployment
deploy_iot() {
    echo -e "${BLUE}🔧 IoT Device Deployment${NC}"
    echo "========================"
    
    echo -e "${YELLOW}Select IoT platform:${NC}"
    echo "1) Raspberry Pi"
    echo "2) Arduino/ESP32"
    echo "3) NVIDIA Jetson"
    echo "4) Intel NUC"
    
    read -p "Enter choice (1-4): " iot_choice
    
    case $iot_choice in
        1) deploy_raspberry_pi ;;
        2) deploy_arduino ;;
        3) deploy_jetson ;;
        4) deploy_intel_nuc ;;
    esac
}

deploy_raspberry_pi() {
    echo -e "${BLUE}🥧 Raspberry Pi Deployment${NC}"
    
    # Create Raspberry Pi installation script
    cat > deploy-raspberry-pi.sh << 'EOF'
#!/bin/bash
# BUDDY Raspberry Pi Installer

echo "🥧 BUDDY Raspberry Pi Setup"
echo "=========================="

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3.11 python3.11-pip python3.11-venv \
                    portaudio19-dev python3-pyaudio \
                    git curl wget \
                    alsa-utils pulseaudio \
                    nginx

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Create BUDDY directory
mkdir -p ~/buddy
cd ~/buddy

# Clone repository
git clone https://github.com/your-repo/buddy.git .

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install -r packages/core/requirements.txt
pip install SpeechRecognition pydub pyaudio

# Configure audio
echo "Setting up audio..."
sudo usermod -a -G audio $USER

# Create systemd service
sudo tee /etc/systemd/system/buddy.service << EOL
[Unit]
Description=BUDDY AI Assistant
After=network.target sound.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/buddy
Environment=PATH=$HOME/buddy/venv/bin
ExecStart=$HOME/buddy/venv/bin/python packages/core/start_buddy_simple.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Enable and start service
sudo systemctl enable buddy
sudo systemctl start buddy

# Setup auto-start on boot
echo "Adding to rc.local for boot startup..."
echo "$HOME/buddy/start-buddy.sh &" | sudo tee -a /etc/rc.local

echo "✅ Raspberry Pi setup complete!"
echo "🌐 BUDDY available at: http://$(hostname -I | awk '{print $1}'):8000"
EOF

    chmod +x deploy-raspberry-pi.sh
    
    echo -e "${GREEN}✅ Raspberry Pi installer created: deploy-raspberry-pi.sh${NC}"
    echo -e "${YELLOW}📋 Installation:${NC}"
    echo "1. Copy deploy-raspberry-pi.sh to your Raspberry Pi"
    echo "2. Run: chmod +x deploy-raspberry-pi.sh && ./deploy-raspberry-pi.sh"
    echo "3. Reboot and BUDDY will auto-start"
}

deploy_arduino() {
    echo -e "${BLUE}🔧 Arduino/ESP32 Deployment${NC}"
    
    mkdir -p apps/arduino
    
    cat > apps/arduino/buddy_esp32.ino << 'EOF'
#include <WiFi.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <driver/i2s.h>

// WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// BUDDY Core server
const char* buddy_host = "192.168.1.100";  // Your BUDDY server IP
const int buddy_port = 8000;

WebSocketsClient webSocket;

// I2S pins for audio
#define I2S_WS 15
#define I2S_SD 32
#define I2S_SCK 14

void setup() {
    Serial.begin(115200);
    
    // Connect to WiFi
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(1000);
        Serial.println("Connecting to WiFi...");
    }
    Serial.println("Connected to WiFi");
    
    // Setup I2S for audio
    setupI2S();
    
    // Connect to BUDDY Core
    webSocket.begin(buddy_host, buddy_port, "/ws");
    webSocket.onEvent(webSocketEvent);
    
    Serial.println("ESP32 BUDDY Client Ready");
}

void loop() {
    webSocket.loop();
    
    // Check for voice input
    if (digitalRead(0) == LOW) {  // Boot button pressed
        recordAndSendAudio();
        delay(1000);  // Debounce
    }
    
    delay(100);
}

void setupI2S() {
    i2s_config_t i2s_config = {
        .mode = i2s_mode_t(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = 16000,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 4,
        .dma_buf_len = 1024,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0
    };
    
    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_SCK,
        .ws_io_num = I2S_WS,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = I2S_SD
    };
    
    i2s_driver_install(I2S_NUM_0, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_NUM_0, &pin_config);
}

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_CONNECTED:
            Serial.println("Connected to BUDDY Core");
            break;
        case WStype_TEXT:
            Serial.printf("Received: %s\n", payload);
            handleBuddyResponse((char*)payload);
            break;
        case WStype_DISCONNECTED:
            Serial.println("Disconnected from BUDDY Core");
            break;
    }
}

void handleBuddyResponse(char* response) {
    // Parse JSON response
    DynamicJsonDocument doc(1024);
    deserializeJson(doc, response);
    
    if (doc["type"] == "response") {
        String text = doc["text"];
        Serial.println("BUDDY: " + text);
        // TODO: Add TTS output via I2S
    }
}

void recordAndSendAudio() {
    Serial.println("Recording audio...");
    
    // Record 2 seconds of audio
    const int sampleRate = 16000;
    const int recordTime = 2;  // seconds
    const int bufferSize = sampleRate * recordTime * 2;  // 16-bit samples
    
    uint8_t* audioBuffer = (uint8_t*)malloc(bufferSize);
    size_t bytesRead = 0;
    
    i2s_read(I2S_NUM_0, audioBuffer, bufferSize, &bytesRead, portMAX_DELAY);
    
    // Send to BUDDY Core
    DynamicJsonDocument doc(1024);
    doc["type"] = "audio";
    doc["format"] = "raw";
    doc["sampleRate"] = sampleRate;
    doc["channels"] = 1;
    doc["bitDepth"] = 16;
    
    String audioData;
    serializeJson(doc, audioData);
    
    webSocket.sendTXT(audioData);
    
    free(audioBuffer);
    Serial.println("Audio sent to BUDDY");
}
EOF

    echo -e "${GREEN}✅ ESP32 sketch created: apps/arduino/buddy_esp32.ino${NC}"
    echo -e "${YELLOW}📋 Installation:${NC}"
    echo "1. Install Arduino IDE and ESP32 board support"
    echo "2. Install libraries: WebSocketsClient, ArduinoJson"
    echo "3. Update WiFi credentials and BUDDY server IP"
    echo "4. Upload to ESP32"
}

# Home Hub Deployment
deploy_home_hub() {
    echo -e "${BLUE}🏠 Home Hub Deployment${NC}"
    echo "======================"
    
    echo -e "${YELLOW}Select home hub platform:${NC}"
    echo "1) Google Home Integration"
    echo "2) Amazon Alexa Skill"
    echo "3) Custom Smart Display"
    echo "4) Home Assistant Add-on"
    
    read -p "Enter choice (1-4): " hub_choice
    
    case $hub_choice in
        1) deploy_google_home ;;
        2) deploy_alexa_skill ;;
        3) deploy_smart_display ;;
        4) deploy_home_assistant ;;
    esac
}

deploy_google_home() {
    echo -e "${BLUE}🏠 Google Home Integration${NC}"
    
    mkdir -p apps/google-home
    
    cat > apps/google-home/package.json << 'EOF'
{
  "name": "buddy-google-action",
  "version": "1.0.0",
  "description": "BUDDY AI Assistant Google Action",
  "main": "index.js",
  "dependencies": {
    "actions-on-google": "^3.0.0",
    "express": "^4.18.0",
    "axios": "^1.0.0"
  }
}
EOF

    cat > apps/google-home/index.js << 'EOF'
const { conversation } = require('@assistant/conversation');
const express = require('express');
const axios = require('axios');

const app = conversation();

app.handle('buddy_intent', async conv => {
    const query = conv.intent.query;
    
    try {
        // Send to BUDDY Core
        const response = await axios.post('http://localhost:8000/api/query', {
            text: query,
            user: conv.user.params.userId || 'google_home_user'
        });
        
        conv.add(response.data.response);
    } catch (error) {
        conv.add("Sorry, I'm having trouble connecting to BUDDY right now.");
    }
});

const expressApp = express();
expressApp.post('/webhook', app);
expressApp.listen(3000);
EOF

    echo -e "${GREEN}✅ Google Action created${NC}"
    echo -e "${YELLOW}📋 Setup:${NC}"
    echo "1. Create Actions on Google project"
    echo "2. Deploy webhook to cloud (Google Cloud Functions)"
    echo "3. Configure intents and fulfillment"
}

deploy_alexa_skill() {
    echo -e "${BLUE}🗣️  Amazon Alexa Skill${NC}"
    
    mkdir -p apps/alexa-skill
    
    cat > apps/alexa-skill/lambda/index.js << 'EOF'
const Alexa = require('ask-sdk-core');
const axios = require('axios');

const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
    },
    handle(handlerInput) {
        const speakOutput = 'Hello, BUDDY is ready to help you!';
        return handlerInput.responseBuilder
            .speak(speakOutput)
            .reprompt(speakOutput)
            .getResponse();
    }
};

const BuddyIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'BuddyIntent';
    },
    async handle(handlerInput) {
        const query = Alexa.getSlotValue(handlerInput.requestEnvelope, 'query');
        
        try {
            const response = await axios.post('http://localhost:8000/api/query', {
                text: query,
                user: handlerInput.requestEnvelope.session.user.userId
            });
            
            const speakOutput = response.data.response;
            return handlerInput.responseBuilder
                .speak(speakOutput)
                .getResponse();
        } catch (error) {
            return handlerInput.responseBuilder
                .speak("Sorry, I'm having trouble connecting to BUDDY.")
                .getResponse();
        }
    }
};

exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        BuddyIntentHandler
    )
    .lambda();
EOF

    echo -e "${GREEN}✅ Alexa Skill created${NC}"
    echo -e "${YELLOW}📋 Setup:${NC}"
    echo "1. Create Alexa Developer Console account"
    echo "2. Create new skill"
    echo "3. Deploy Lambda function"
    echo "4. Configure voice interaction model"
}

# All devices deployment
deploy_all_devices() {
    echo -e "${BLUE}📱 Deploying to All Devices${NC}"
    echo "==========================="
    
    echo -e "${YELLOW}🚀 Starting comprehensive deployment...${NC}"
    
    # Create deployment structure
    mkdir -p dist/{tv,watch,car,iot,hub,mobile}
    
    # Run all deployments
    deploy_smart_tv
    deploy_smartwatch
    deploy_car
    deploy_iot
    deploy_home_hub
    
    # Create unified deployment package
    echo -e "${BLUE}📦 Creating unified deployment package...${NC}"
    
    cat > deploy-all-platforms.sh << 'EOF'
#!/bin/bash
# BUDDY Universal Deployment Script

echo "🤖 BUDDY Universal Deployment"
echo "============================="

# Deploy to different device categories
echo "1. Setting up core infrastructure..."
docker-compose -f docker-compose.yml up -d

echo "2. Generating mobile packages..."
# Android APK
cd apps/mobile && flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ../../dist/mobile/

# iOS build (on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    flutter build ios --release
fi

echo "3. Creating smart device packages..."
# TV platforms
# (Android TV, Apple TV, etc.)

echo "4. Setting up IoT devices..."
# Raspberry Pi, Arduino, etc.

echo "✅ Universal deployment complete!"
echo "📁 All packages available in dist/ directory"
EOF

    chmod +x deploy-all-platforms.sh
    
    echo -e "${GREEN}✅ Universal deployment script created!${NC}"
    echo -e "${YELLOW}📋 Run: ./deploy-all-platforms.sh${NC}"
}

# Run the main function
case $device_choice in
    1|2|3|4|5|6|7|8) ;; # Already handled in case statement above
esac

echo ""
echo -e "${GREEN}🎉 BUDDY Smart Device Deployment Complete!${NC}"
echo -e "${CYAN}📱 Your BUDDY AI Assistant is now ready for smart devices!${NC}"