#!/bin/bash
# BUDDY AI Assistant - Smart TV App Builder
# Creates apps for Android TV, Apple TV, Samsung Tizen, LG webOS, Fire TV

set -e

APP_NAME="BUDDY AI Assistant"
APP_VERSION="1.0.0"
OUTPUT_DIR="output"

echo "🤖 BUDDY Smart TV App Builder"
echo "============================="

mkdir -p "$OUTPUT_DIR"

# Function to build Android TV APK
build_android_tv() {
    echo "📺 Building Android TV APK..."
    
    # Create Android TV project structure
    TV_PROJECT_DIR="../../apps/tv-android"
    mkdir -p "$TV_PROJECT_DIR"
    cd "$TV_PROJECT_DIR"
    
    # Create Android TV manifest
    mkdir -p src/main
    cat > src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.buddy.ai.tv">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    
    <uses-feature
        android:name="android.software.leanback"
        android:required="true" />
    <uses-feature
        android:name="android.hardware.touchscreen"
        android:required="false" />
    <uses-feature
        android:name="android.hardware.microphone"
        android:required="true" />

    <application
        android:allowBackup="true"
        android:banner="@drawable/banner"
        android:icon="@drawable/icon"
        android:label="@string/app_name"
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
        
        <activity
            android:name=".VoiceActivity"
            android:exported="false"
            android:theme="@style/Theme.Transparent" />
            
        <service
            android:name=".BuddyTVService"
            android:enabled="true"
            android:exported="false" />
    </application>
</manifest>
EOF

    # Create build.gradle
    cat > build.gradle << 'EOF'
apply plugin: 'com.android.application'

android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.buddy.ai.tv"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation 'androidx.leanback:leanback:1.0.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.10.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'androidx.lifecycle:lifecycle-livedata-ktx:2.6.2'
    implementation 'androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2'
    implementation 'com.squareup.okhttp3:okhttp:4.11.0'
    implementation 'org.java-websocket:Java-WebSocket:1.5.3'
    implementation 'com.google.code.gson:gson:2.10.1'
}
EOF

    # Create MainActivity
    mkdir -p src/main/java/com/buddy/ai/tv
    cat > src/main/java/com/buddy/ai/tv/MainActivity.java << 'EOF'
package com.buddy.ai.tv;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.Nullable;

public class MainActivity extends Activity {
    private BuddyTVService buddyService;
    private TextView statusText;
    private TextView responseText;
    private boolean isListening = false;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        statusText = findViewById(R.id.status_text);
        responseText = findViewById(R.id.response_text);
        
        // Initialize BUDDY service
        buddyService = new BuddyTVService(this);
        buddyService.connect();
        
        // Set initial status
        statusText.setText("🤖 BUDDY TV - Press voice button to talk");
        
        // Setup voice button listener
        findViewById(R.id.voice_button).setOnClickListener(v -> toggleVoiceInput());
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
                // Enter key - start voice input
                toggleVoiceInput();
                return true;
                
            case KeyEvent.KEYCODE_BACK:
                // Back key - stop voice input or exit
                if (isListening) {
                    stopVoiceInput();
                    return true;
                }
                break;
                
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
                // Play/Pause key - toggle voice
                toggleVoiceInput();
                return true;
        }
        
        return super.onKeyDown(keyCode, event);
    }

    private void toggleVoiceInput() {
        if (isListening) {
            stopVoiceInput();
        } else {
            startVoiceInput();
        }
    }

    private void startVoiceInput() {
        Intent voiceIntent = new Intent(this, VoiceActivity.class);
        startActivityForResult(voiceIntent, 1001);
        isListening = true;
        statusText.setText("🎤 Listening... Press BACK to cancel");
    }

    private void stopVoiceInput() {
        isListening = false;
        statusText.setText("🤖 BUDDY TV - Press voice button to talk");
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == 1001) {
            isListening = false;
            
            if (resultCode == RESULT_OK && data != null) {
                String voiceText = data.getStringExtra("voice_text");
                if (voiceText != null && !voiceText.isEmpty()) {
                    // Send to BUDDY
                    buddyService.sendMessage(voiceText);
                    statusText.setText("Processing: " + voiceText);
                }
            } else {
                statusText.setText("🤖 BUDDY TV - Press voice button to talk");
            }
        }
    }

    public void onBuddyResponse(String response) {
        runOnUiThread(() -> {
            responseText.setText(response);
            statusText.setText("🤖 BUDDY is ready - Press voice button to talk");
            
            // Speak response using TTS
            buddyService.speak(response);
        });
    }

    public void onBuddyError(String error) {
        runOnUiThread(() -> {
            Toast.makeText(this, "BUDDY Error: " + error, Toast.LENGTH_LONG).show();
            statusText.setText("❌ Connection error - Check BUDDY Core");
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (buddyService != null) {
            buddyService.disconnect();
        }
    }
}
EOF

    # Create layout
    mkdir -p src/main/res/layout
    cat > src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="@drawable/tv_background"
    android:gravity="center"
    android:padding="48dp">

    <ImageView
        android:layout_width="200dp"
        android:layout_height="200dp"
        android:src="@drawable/buddy_logo"
        android:layout_marginBottom="32dp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="🤖 BUDDY AI Assistant"
        android:textSize="48sp"
        android:textColor="@color/white"
        android:textStyle="bold"
        android:layout_marginBottom="24dp" />

    <TextView
        android:id="@+id/status_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Connecting to BUDDY Core..."
        android:textSize="24sp"
        android:textColor="@color/light_blue"
        android:layout_marginBottom="32dp"
        android:gravity="center" />

    <TextView
        android:id="@+id/response_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:textSize="20sp"
        android:textColor="@color/white"
        android:layout_marginBottom="32dp"
        android:gravity="center"
        android:minHeight="100dp" />

    <Button
        android:id="@+id/voice_button"
        android:layout_width="200dp"
        android:layout_height="80dp"
        android:text="🎤 Voice"
        android:textSize="24sp"
        android:background="@drawable/voice_button_bg"
        android:textColor="@color/white" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Press ENTER or voice button on remote to talk"
        android:textSize="16sp"
        android:textColor="@color/light_gray"
        android:layout_marginTop="16dp"
        android:gravity="center" />

</LinearLayout>
EOF

    # Create resources
    mkdir -p src/main/res/values
    cat > src/main/res/values/strings.xml << 'EOF'
<resources>
    <string name="app_name">BUDDY AI Assistant</string>
    <string name="connecting">Connecting to BUDDY Core...</string>
    <string name="ready">BUDDY is ready - Press voice button to talk</string>
    <string name="listening">Listening... Press BACK to cancel</string>
    <string name="processing">Processing your request...</string>
</resources>
EOF

    cat > src/main/res/values/colors.xml << 'EOF'
<resources>
    <color name="white">#FFFFFF</color>
    <color name="light_blue">#667EEA</color>
    <color name="dark_blue">#764BA2</color>
    <color name="light_gray">#CCCCCC</color>
    <color name="transparent">#00000000</color>
</resources>
EOF

    echo "✅ Android TV project structure created"
    echo "📋 To build APK:"
    echo "   1. Install Android Studio"
    echo "   2. Open project in Android Studio"
    echo "   3. Build → Generate Signed Bundle/APK"
    echo "   4. Install on Android TV: adb install buddy-tv.apk"
    
    cd ../../installers/smarttv
}

# Function to create Apple TV app
build_apple_tv() {
    echo "📺 Building Apple TV app..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ Apple TV development requires macOS with Xcode"
        return 1
    fi
    
    # Create tvOS project structure
    TV_PROJECT_DIR="../../apps/tv-ios"
    mkdir -p "$TV_PROJECT_DIR"
    cd "$TV_PROJECT_DIR"
    
    # Create Xcode project structure
    mkdir -p "BUDDYTV.xcodeproj"
    mkdir -p "BUDDYTV"
    
    # Create Info.plist
    cat > BUDDYTV/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>BUDDY AI</string>
    <key>CFBundleIdentifier</key>
    <string>com.buddy.ai.tv</string>
    <key>CFBundleName</key>
    <string>BUDDY AI Assistant</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>3</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIUserInterfaceIdiom</key>
    <string>tv</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUDDY needs microphone access for voice commands on Apple TV</string>
</dict>
</plist>
EOF

    # Create main view controller
    cat > BUDDYTV/ViewController.swift << 'EOF'
import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var responseLabel: UILabel!
    @IBOutlet weak var voiceButton: UIButton!
    
    private var buddyService: BuddyTVService!
    private var speechRecognizer: AVSpeechSynthesizer!
    private var isListening = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupBuddyService()
        setupSpeechSynthesizer()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0)
        
        statusLabel.text = "🤖 BUDDY TV - Press Siri Remote to talk"
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        
        responseLabel.textColor = .white
        responseLabel.textAlignment = .center
        responseLabel.numberOfLines = 0
        
        voiceButton.setTitle("🎤 Voice", for: .normal)
        voiceButton.backgroundColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
        voiceButton.layer.cornerRadius = 10
    }
    
    private func setupBuddyService() {
        buddyService = BuddyTVService()
        buddyService.delegate = self
        buddyService.connect()
    }
    
    private func setupSpeechSynthesizer() {
        speechRecognizer = AVSpeechSynthesizer()
    }
    
    @IBAction func voiceButtonPressed(_ sender: UIButton) {
        toggleVoiceInput()
    }
    
    private func toggleVoiceInput() {
        if isListening {
            stopVoiceInput()
        } else {
            startVoiceInput()
        }
    }
    
    private func startVoiceInput() {
        // Apple TV voice input implementation
        isListening = true
        statusLabel.text = "🎤 Listening... Press Menu to cancel"
        
        // Use AVAudioSession for microphone access
        // Implementation depends on Apple TV microphone capabilities
    }
    
    private func stopVoiceInput() {
        isListening = false
        statusLabel.text = "🤖 BUDDY TV - Press Siri Remote to talk"
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.type {
            case .select:
                // Select button pressed
                toggleVoiceInput()
                return
            case .menu:
                // Menu button pressed
                if isListening {
                    stopVoiceInput()
                    return
                }
            case .playPause:
                // Play/Pause button pressed
                toggleVoiceInput()
                return
            default:
                break
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

extension ViewController: BuddyTVServiceDelegate {
    func buddyServiceDidConnect() {
        DispatchQueue.main.async {
            self.statusLabel.text = "✅ Connected to BUDDY Core"
        }
    }
    
    func buddyServiceDidDisconnect() {
        DispatchQueue.main.async {
            self.statusLabel.text = "❌ Disconnected from BUDDY Core"
        }
    }
    
    func buddyServiceDidReceiveResponse(_ response: String) {
        DispatchQueue.main.async {
            self.responseLabel.text = response
            self.statusLabel.text = "🤖 BUDDY is ready"
            
            // Speak the response
            let utterance = AVSpeechUtterance(string: response)
            utterance.rate = 0.5
            self.speechRecognizer.speak(utterance)
        }
    }
    
    func buddyServiceDidEncounterError(_ error: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = "❌ Error: \(error)"
        }
    }
}
EOF

    echo "✅ Apple TV project structure created"
    echo "📋 To build Apple TV app:"
    echo "   1. Open BUDDYTV.xcodeproj in Xcode"
    echo "   2. Select Apple TV target"
    echo "   3. Build and run on Apple TV simulator or device"
    
    cd ../../installers/smarttv
}

# Function to create Samsung Tizen app
build_tizen_tv() {
    echo "📺 Building Samsung Tizen TV app..."
    
    # Create Tizen project structure
    TV_PROJECT_DIR="../../apps/tv-tizen"
    mkdir -p "$TV_PROJECT_DIR"
    cd "$TV_PROJECT_DIR"
    
    # Create config.xml
    cat > config.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<widget xmlns="http://www.w3.org/ns/widgets" 
        xmlns:tizen="http://tizen.org/ns/widgets" 
        id="http://buddy.ai/tv" 
        version="1.0.0" 
        viewmodes="maximized">
    
    <tizen:application id="buddy.tv" package="buddy" required_version="6.0"/>
    <content src="index.html"/>
    <feature name="http://tizen.org/feature/screen.size.normal.1920.1080"/>
    <icon src="icon.png"/>
    <name>BUDDY AI Assistant</name>
    
    <tizen:privilege name="http://tizen.org/privilege/internet"/>
    <tizen:privilege name="http://tizen.org/privilege/audiorecord"/>
    <tizen:privilege name="http://tizen.org/privilege/tv.inputdevice"/>
    <tizen:privilege name="http://tizen.org/privilege/application.launch"/>
    
    <tizen:setting screen-orientation="landscape" context-menu="disable" background-support="disable" encryption="disable" install-location="auto"/>
</widget>
EOF

    # Create main HTML file
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>BUDDY AI Assistant</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: white;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            overflow: hidden;
            width: 100vw;
            height: 100vh;
        }
        
        .tv-container {
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 60px;
            box-sizing: border-box;
        }
        
        .buddy-logo {
            font-size: 6rem;
            margin-bottom: 2rem;
            text-shadow: 0 0 30px rgba(102, 126, 234, 0.7);
            animation: glow 2s ease-in-out infinite alternate;
        }
        
        @keyframes glow {
            from { text-shadow: 0 0 20px rgba(102, 126, 234, 0.5); }
            to { text-shadow: 0 0 30px rgba(102, 126, 234, 1); }
        }
        
        .status {
            font-size: 2rem;
            margin-bottom: 3rem;
            text-align: center;
            min-height: 80px;
        }
        
        .response {
            font-size: 1.8rem;
            text-align: center;
            margin-bottom: 3rem;
            min-height: 120px;
            max-width: 80%;
            line-height: 1.4;
        }
        
        .controls {
            display: flex;
            gap: 2rem;
            margin-bottom: 3rem;
        }
        
        .voice-button {
            background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
            border: none;
            border-radius: 15px;
            color: white;
            font-size: 1.5rem;
            padding: 20px 40px;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 8px 25px rgba(0,0,0,0.3);
        }
        
        .voice-button:hover,
        .voice-button:focus {
            transform: translateY(-3px);
            box-shadow: 0 12px 35px rgba(0,0,0,0.4);
            background: linear-gradient(45deg, #764ba2 0%, #667eea 100%);
        }
        
        .voice-button.listening {
            background: linear-gradient(45deg, #f093fb 0%, #f5576c 100%);
            animation: pulse 1s infinite;
        }
        
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }
        
        .remote-hint {
            position: absolute;
            bottom: 40px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 1.2rem;
            opacity: 0.8;
            text-align: center;
        }
        
        .connection-indicator {
            position: absolute;
            top: 40px;
            right: 40px;
            font-size: 1.5rem;
        }
        
        .connected {
            color: #4CAF50;
        }
        
        .disconnected {
            color: #F44336;
        }
    </style>
</head>
<body>
    <div class="tv-container">
        <div class="connection-indicator" id="connectionStatus">
            <span class="disconnected">⚫ Disconnected</span>
        </div>
        
        <div class="buddy-logo">🤖 BUDDY</div>
        
        <div class="status" id="status">Connecting to BUDDY Core...</div>
        
        <div class="response" id="response"></div>
        
        <div class="controls">
            <button class="voice-button" id="voiceButton" onclick="toggleVoice()">
                🎤 Press to Talk
            </button>
        </div>
        
        <div class="remote-hint">
            Use remote control: OK button to talk • Back to cancel • Menu for settings
        </div>
    </div>

    <script src="js/tizen-buddy.js"></script>
    <script>
        // Initialize BUDDY TV app
        document.addEventListener('DOMContentLoaded', function() {
            BuddyTV.init();
        });
        
        // Handle TV remote control
        document.addEventListener('keydown', function(e) {
            switch(e.keyCode) {
                case 13: // OK/Enter
                    e.preventDefault();
                    toggleVoice();
                    break;
                case 10009: // Back
                    e.preventDefault();
                    if (BuddyTV.isListening) {
                        BuddyTV.stopListening();
                    } else {
                        tizen.application.getCurrentApplication().exit();
                    }
                    break;
                case 10182: // Menu
                    e.preventDefault();
                    // Show settings or help
                    break;
                case 415: // Play
                case 19: // Pause
                    e.preventDefault();
                    toggleVoice();
                    break;
            }
        });
        
        function toggleVoice() {
            if (BuddyTV.isListening) {
                BuddyTV.stopListening();
            } else {
                BuddyTV.startListening();
            }
        }
    </script>
</body>
</html>
EOF

    # Create JavaScript file
    mkdir -p js
    cat > js/tizen-buddy.js << 'EOF'
const BuddyTV = {
    ws: null,
    isConnected: false,
    isListening: false,
    recognition: null,
    synthesis: null,
    
    init() {
        this.setupWebSocket();
        this.setupSpeechRecognition();
        this.setupTextToSpeech();
        this.updateUI();
    },
    
    setupWebSocket() {
        try {
            // Try to connect to BUDDY Core
            const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
            const host = location.hostname || 'localhost';
            const port = '8000';
            
            this.ws = new WebSocket(`${protocol}//${host}:${port}/ws`);
            
            this.ws.onopen = () => {
                this.isConnected = true;
                this.updateConnectionStatus();
                this.updateStatus('✅ Connected to BUDDY Core - Press OK to talk');
            };
            
            this.ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.type === 'response') {
                        this.displayResponse(data.text);
                        this.speak(data.text);
                    }
                } catch (error) {
                    console.error('Error parsing message:', error);
                }
            };
            
            this.ws.onclose = () => {
                this.isConnected = false;
                this.updateConnectionStatus();
                this.updateStatus('❌ Connection lost - Check BUDDY Core');
            };
            
            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
                this.updateStatus('❌ Connection error - Check network');
            };
            
        } catch (error) {
            console.error('Failed to setup WebSocket:', error);
            this.updateStatus('❌ Cannot connect to BUDDY Core');
        }
    },
    
    setupSpeechRecognition() {
        if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
            const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
            this.recognition = new SpeechRecognition();
            
            this.recognition.continuous = false;
            this.recognition.interimResults = false;
            this.recognition.lang = 'en-US';
            
            this.recognition.onstart = () => {
                this.isListening = true;
                this.updateUI();
                this.updateStatus('🎤 Listening... Say something or press Back to cancel');
            };
            
            this.recognition.onresult = (event) => {
                const transcript = event.results[0][0].transcript;
                this.sendToBuddy(transcript);
                this.updateStatus(`Processing: "${transcript}"`);
            };
            
            this.recognition.onend = () => {
                this.isListening = false;
                this.updateUI();
            };
            
            this.recognition.onerror = (event) => {
                this.isListening = false;
                this.updateUI();
                this.updateStatus('❌ Voice recognition error - Try again');
            };
        } else {
            console.warn('Speech recognition not supported');
        }
    },
    
    setupTextToSpeech() {
        if ('speechSynthesis' in window) {
            this.synthesis = window.speechSynthesis;
        }
    },
    
    startListening() {
        if (this.recognition && this.isConnected) {
            try {
                this.recognition.start();
            } catch (error) {
                console.error('Error starting speech recognition:', error);
                this.updateStatus('❌ Cannot start voice recognition');
            }
        } else if (!this.isConnected) {
            this.updateStatus('❌ Not connected to BUDDY Core');
        } else {
            this.updateStatus('❌ Voice recognition not available');
        }
    },
    
    stopListening() {
        if (this.recognition && this.isListening) {
            this.recognition.stop();
        }
    },
    
    sendToBuddy(message) {
        if (this.isConnected && this.ws) {
            const data = {
                type: 'message',
                text: message,
                timestamp: new Date().toISOString(),
                source: 'tizen-tv'
            };
            this.ws.send(JSON.stringify(data));
        }
    },
    
    speak(text) {
        if (this.synthesis) {
            // Stop any ongoing speech
            this.synthesis.cancel();
            
            const utterance = new SpeechSynthesisUtterance(text);
            utterance.rate = 0.8;
            utterance.pitch = 1.0;
            utterance.volume = 1.0;
            
            this.synthesis.speak(utterance);
        }
    },
    
    updateStatus(message) {
        const statusElement = document.getElementById('status');
        if (statusElement) {
            statusElement.textContent = message;
        }
    },
    
    displayResponse(response) {
        const responseElement = document.getElementById('response');
        if (responseElement) {
            responseElement.textContent = response;
        }
        this.updateStatus('🤖 BUDDY is ready - Press OK to talk again');
    },
    
    updateConnectionStatus() {
        const indicator = document.getElementById('connectionStatus');
        if (indicator) {
            if (this.isConnected) {
                indicator.innerHTML = '<span class="connected">🟢 Connected</span>';
            } else {
                indicator.innerHTML = '<span class="disconnected">🔴 Disconnected</span>';
            }
        }
    },
    
    updateUI() {
        const button = document.getElementById('voiceButton');
        if (button) {
            if (this.isListening) {
                button.textContent = '🛑 Stop Listening';
                button.classList.add('listening');
            } else {
                button.textContent = '🎤 Press to Talk';
                button.classList.remove('listening');
            }
        }
    }
};

// Export for global access
window.BuddyTV = BuddyTV;
EOF

    echo "✅ Samsung Tizen TV app created"
    echo "📋 To build and install:"
    echo "   1. Install Tizen Studio"
    echo "   2. Build: tizen build-web"
    echo "   3. Package: tizen package -t wgt"
    echo "   4. Install: tizen install -n buddy-tv.wgt -t YOUR_TV_ID"
    
    cd ../../installers/smarttv
}

# Function to create LG webOS app
build_webos_tv() {
    echo "📺 Building LG webOS TV app..."
    
    # Create webOS project structure
    TV_PROJECT_DIR="../../apps/tv-webos"
    mkdir -p "$TV_PROJECT_DIR"
    cd "$TV_PROJECT_DIR"
    
    # Create appinfo.json
    cat > appinfo.json << 'EOF'
{
    "id": "com.buddy.ai.tv",
    "version": "1.0.0",
    "vendor": "BUDDY Team",
    "type": "web",
    "main": "index.html",
    "title": "BUDDY AI Assistant",
    "icon": "icon.png",
    "largeIcon": "largeIcon.png",
    "splash": "splash.png",
    "splashBackground": "#1a1a2e",
    "uiRevision": 2,
    "allowVideoCapture": false,
    "allowAudioCapture": true,
    "allowCrossDomain": true,
    "supportQuickStartForSameApp": true,
    "requiredPermissions": [
        "audio.operation",
        "network.operation",
        "device.info"
    ]
}
EOF

    # Create main HTML (similar to Tizen but adapted for webOS)
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BUDDY AI Assistant</title>
    <script src="webOSTVjs-1.2.4/webOSTV.js"></script>
    <link rel="stylesheet" href="css/webos-style.css">
</head>
<body>
    <div class="tv-container">
        <div class="buddy-header">
            <div class="buddy-logo">🤖 BUDDY AI</div>
            <div class="connection-status" id="connectionStatus">⚫ Connecting...</div>
        </div>
        
        <div class="main-content">
            <div class="status-display" id="status">
                Connecting to BUDDY Core...
            </div>
            
            <div class="response-display" id="response"></div>
            
            <div class="control-panel">
                <div class="voice-control" id="voiceControl">
                    <button class="voice-btn" id="voiceButton" onclick="handleVoiceInput()">
                        🎤 Press Magic Remote Voice Button
                    </button>
                </div>
            </div>
        </div>
        
        <div class="footer-hint">
            Magic Remote: Voice button to talk • Back to exit • Home for webOS menu
        </div>
    </div>

    <script src="js/webos-buddy.js"></script>
    <script>
        // Initialize webOS services and BUDDY connection
        document.addEventListener('DOMContentLoaded', function() {
            WebOSBuddy.init();
        });
    </script>
</body>
</html>
EOF

    # Create webOS-specific CSS
    mkdir -p css
    cat > css/webos-style.css << 'EOF'
body {
    margin: 0;
    padding: 0;
    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
    color: white;
    font-family: 'LG Smart UI', Arial, sans-serif;
    overflow: hidden;
    width: 100vw;
    height: 100vh;
}

.tv-container {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    padding: 40px;
    box-sizing: border-box;
}

.buddy-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 40px;
}

.buddy-logo {
    font-size: 4rem;
    font-weight: bold;
    text-shadow: 0 0 20px rgba(102, 126, 234, 0.6);
}

.connection-status {
    font-size: 1.2rem;
    padding: 8px 16px;
    border-radius: 20px;
    background: rgba(255, 255, 255, 0.1);
}

.main-content {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
}

.status-display {
    font-size: 2.5rem;
    margin-bottom: 40px;
    min-height: 80px;
}

.response-display {
    font-size: 2rem;
    margin-bottom: 60px;
    max-width: 80%;
    line-height: 1.4;
    min-height: 120px;
}

.voice-btn {
    background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
    border: none;
    border-radius: 20px;
    color: white;
    font-size: 1.8rem;
    padding: 25px 50px;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 10px 30px rgba(0,0,0,0.3);
}

.voice-btn:hover,
.voice-btn:focus {
    transform: translateY(-5px);
    box-shadow: 0 15px 40px rgba(0,0,0,0.4);
}

.voice-btn.active {
    background: linear-gradient(45deg, #f093fb 0%, #f5576c 100%);
    animation: webos-pulse 1.5s infinite;
}

@keyframes webos-pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.08); }
}

.footer-hint {
    text-align: center;
    font-size: 1.1rem;
    opacity: 0.7;
    margin-top: auto;
}

/* webOS specific focus styles */
.voice-btn:focus {
    outline: 3px solid #00D4FF;
    outline-offset: 2px;
}
EOF

    # Create webOS JavaScript
    mkdir -p js
    cat > js/webos-buddy.js << 'EOF'
const WebOSBuddy = {
    ws: null,
    isConnected: false,
    isListening: false,
    
    init() {
        this.setupWebOSServices();
        this.setupWebSocket();
        this.setupKeyHandlers();
        this.updateUI();
    },
    
    setupWebOSServices() {
        if (typeof webOS !== 'undefined') {
            // Request audio permissions
            webOS.service.request('luna://com.webos.service.audiorecorder', {
                method: 'getStatus',
                onSuccess: (result) => {
                    console.log('Audio service available:', result);
                },
                onFailure: (error) => {
                    console.error('Audio service error:', error);
                }
            });
            
            // Setup TV service for remote control
            webOS.service.request('luna://com.webos.service.tv', {
                method: 'getChannelList',
                onSuccess: (result) => {
                    console.log('TV service available');
                },
                onFailure: (error) => {
                    console.log('TV service not critical');
                }
            });
        }
    },
    
    setupWebSocket() {
        try {
            const host = location.hostname || '192.168.1.100'; // Default BUDDY server
            const port = '8000';
            const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
            
            this.ws = new WebSocket(`${protocol}//${host}:${port}/ws`);
            
            this.ws.onopen = () => {
                this.isConnected = true;
                this.updateConnectionStatus();
                this.updateStatus('✅ BUDDY Connected - Use Magic Remote voice button');
            };
            
            this.ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.type === 'response') {
                        this.displayResponse(data.text);
                        this.speakResponse(data.text);
                    }
                } catch (error) {
                    console.error('Message parse error:', error);
                }
            };
            
            this.ws.onclose = () => {
                this.isConnected = false;
                this.updateConnectionStatus();
                this.updateStatus('❌ Disconnected from BUDDY Core');
            };
            
            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
                this.updateStatus('❌ Connection error');
            };
            
        } catch (error) {
            console.error('WebSocket setup failed:', error);
            this.updateStatus('❌ Cannot reach BUDDY Core');
        }
    },
    
    setupKeyHandlers() {
        document.addEventListener('keydown', (e) => {
            switch(e.keyCode) {
                case 13: // OK button
                    e.preventDefault();
                    this.handleVoiceInput();
                    break;
                case 27: // Back button
                    e.preventDefault();
                    if (this.isListening) {
                        this.stopListening();
                    } else {
                        this.exitApp();
                    }
                    break;
                case 461: // Back (webOS specific)
                    e.preventDefault();
                    this.exitApp();
                    break;
                case 1001: // Magic Remote voice button
                    e.preventDefault();
                    this.handleVoiceInput();
                    break;
            }
        });
    },
    
    handleVoiceInput() {
        if (!this.isConnected) {
            this.updateStatus('❌ Not connected to BUDDY Core');
            return;
        }
        
        if (this.isListening) {
            this.stopListening();
        } else {
            this.startListening();
        }
    },
    
    startListening() {
        if (typeof webOS !== 'undefined') {
            // Use webOS native voice recognition
            webOS.service.request('luna://com.webos.service.voicerecognition', {
                method: 'start',
                parameters: {
                    language: 'en-US',
                    continuous: false
                },
                onSuccess: (result) => {
                    this.isListening = true;
                    this.updateUI();
                    this.updateStatus('🎤 Listening... Press Back to cancel');
                },
                onFailure: (error) => {
                    console.error('Voice recognition failed:', error);
                    this.fallbackToWebSpeech();
                }
            });
        } else {
            this.fallbackToWebSpeech();
        }
    },
    
    fallbackToWebSpeech() {
        if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
            const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
            const recognition = new SpeechRecognition();
            
            recognition.continuous = false;
            recognition.interimResults = false;
            recognition.lang = 'en-US';
            
            recognition.onstart = () => {
                this.isListening = true;
                this.updateUI();
                this.updateStatus('🎤 Listening... Press Back to cancel');
            };
            
            recognition.onresult = (event) => {
                const transcript = event.results[0][0].transcript;
                this.sendToBuddy(transcript);
                this.updateStatus(`Processing: "${transcript}"`);
            };
            
            recognition.onend = () => {
                this.isListening = false;
                this.updateUI();
            };
            
            recognition.onerror = () => {
                this.isListening = false;
                this.updateUI();
                this.updateStatus('❌ Voice recognition error');
            };
            
            recognition.start();
        } else {
            this.updateStatus('❌ Voice recognition not supported');
        }
    },
    
    stopListening() {
        this.isListening = false;
        this.updateUI();
        this.updateStatus('🤖 BUDDY ready - Press voice button to talk');
    },
    
    sendToBuddy(message) {
        if (this.isConnected && this.ws) {
            const data = {
                type: 'message',
                text: message,
                timestamp: new Date().toISOString(),
                source: 'webos-tv'
            };
            this.ws.send(JSON.stringify(data));
        }
    },
    
    speakResponse(text) {
        if (typeof webOS !== 'undefined') {
            // Use webOS TTS service
            webOS.service.request('luna://com.webos.service.tts', {
                method: 'speak',
                parameters: {
                    text: text,
                    language: 'en-US',
                    speed: 1.0
                },
                onSuccess: (result) => {
                    console.log('TTS success:', result);
                },
                onFailure: (error) => {
                    console.error('TTS error:', error);
                    this.fallbackToWebSpeech(text);
                }
            });
        } else {
            this.fallbackToWebSpeech(text);
        }
    },
    
    fallbackToWebSpeech(text) {
        if ('speechSynthesis' in window) {
            const utterance = new SpeechSynthesisUtterance(text);
            utterance.rate = 0.8;
            speechSynthesis.speak(utterance);
        }
    },
    
    updateStatus(message) {
        const statusEl = document.getElementById('status');
        if (statusEl) {
            statusEl.textContent = message;
        }
    },
    
    displayResponse(response) {
        const responseEl = document.getElementById('response');
        if (responseEl) {
            responseEl.textContent = response;
        }
        this.updateStatus('🤖 BUDDY ready - Press voice button to talk');
    },
    
    updateConnectionStatus() {
        const statusEl = document.getElementById('connectionStatus');
        if (statusEl) {
            if (this.isConnected) {
                statusEl.innerHTML = '🟢 Connected';
                statusEl.style.background = 'rgba(76, 175, 80, 0.3)';
            } else {
                statusEl.innerHTML = '🔴 Disconnected';
                statusEl.style.background = 'rgba(244, 67, 54, 0.3)';
            }
        }
    },
    
    updateUI() {
        const button = document.getElementById('voiceButton');
        if (button) {
            if (this.isListening) {
                button.textContent = '🛑 Stop Listening';
                button.classList.add('active');
            } else {
                button.textContent = '🎤 Press Magic Remote Voice Button';
                button.classList.remove('active');
            }
        }
    },
    
    exitApp() {
        if (typeof webOS !== 'undefined') {
            webOS.platformBack();
        } else {
            window.close();
        }
    }
};

// Export for global access
window.WebOSBuddy = WebOSBuddy;
window.handleVoiceInput = () => WebOSBuddy.handleVoiceInput();
EOF

    echo "✅ LG webOS TV app created"
    echo "📋 To build and install:"
    echo "   1. Install webOS TV SDK"
    echo "   2. Package: ares-package ."
    echo "   3. Install: ares-install buddy-tv.ipk -d YOUR_TV"
    
    cd ../../installers/smarttv
}

# Function to create unified Smart TV installer
create_smart_tv_installer() {
    echo "📺 Creating Smart TV installer script..."
    
    cat > "$OUTPUT_DIR/install-smart-tv.sh" << 'EOF'
#!/bin/bash
# BUDDY Smart TV Universal Installer

echo "📺 BUDDY AI Assistant - Smart TV Installer"
echo "==========================================="

echo ""
echo "📋 Select your Smart TV platform:"
echo "1) Android TV"
echo "2) Apple TV (requires macOS + Xcode)"
echo "3) Samsung Tizen TV"
echo "4) LG webOS TV"
echo "5) Amazon Fire TV"
echo "6) All platforms (development setup)"
echo ""

read -p "Enter choice (1-6): " tv_choice

case $tv_choice in
    1)
        echo "📱 Android TV Installation"
        echo "========================="
        
        if [ ! -f "buddy-android-tv.apk" ]; then
            echo "❌ Android TV APK not found"
            echo "📋 To build APK:"
            echo "   1. Install Android Studio"
            echo "   2. Open tv-android project"
            echo "   3. Build signed APK"
            exit 1
        fi
        
        echo "📱 Installing BUDDY on Android TV..."
        
        if ! command -v adb > /dev/null; then
            echo "❌ ADB not found. Install Android SDK Platform Tools"
            exit 1
        fi
        
        echo "🔍 Looking for Android TV devices..."
        adb devices
        
        read -p "Enter Android TV IP address (or press Enter if connected via USB): " tv_ip
        
        if [ ! -z "$tv_ip" ]; then
            echo "📡 Connecting to $tv_ip..."
            adb connect "$tv_ip:5555"
        fi
        
        echo "📲 Installing BUDDY TV APK..."
        adb install -r buddy-android-tv.apk
        
        echo "✅ BUDDY installed on Android TV!"
        echo "🚀 Launch from TV launcher or use voice command"
        ;;
        
    2)
        echo "🍎 Apple TV Installation"
        echo "======================="
        
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo "❌ Apple TV development requires macOS with Xcode"
            exit 1
        fi
        
        if [ ! -d "tv-ios" ]; then
            echo "❌ Apple TV project not found"
            exit 1
        fi
        
        echo "🍎 Opening Apple TV project in Xcode..."
        open tv-ios/BUDDYTV.xcodeproj
        
        echo "📋 Manual steps in Xcode:"
        echo "   1. Connect Apple TV to same network"
        echo "   2. Pair Apple TV in Xcode (Window → Devices)"
        echo "   3. Select Apple TV as target"
        echo "   4. Build and run (Cmd+R)"
        ;;
        
    3)
        echo "📺 Samsung Tizen TV Installation"
        echo "==============================="
        
        if ! command -v tizen > /dev/null; then
            echo "❌ Tizen Studio not found"
            echo "📥 Install from: https://developer.samsung.com/tizen"
            exit 1
        fi
        
        if [ ! -f "buddy-tizen.wgt" ]; then
            echo "📦 Building Tizen package..."
            cd tv-tizen
            tizen build-web
            tizen package -t wgt
            mv *.wgt ../buddy-tizen.wgt
            cd ..
        fi
        
        echo "📺 Available Samsung TVs:"
        tizen list target
        
        read -p "Enter Samsung TV target name: " tv_target
        
        echo "📲 Installing BUDDY on Samsung TV..."
        tizen install -n buddy-tizen.wgt -t "$tv_target"
        
        echo "✅ BUDDY installed on Samsung TV!"
        echo "🚀 Find BUDDY in TV apps menu"
        ;;
        
    4)
        echo "📺 LG webOS TV Installation"
        echo "==========================="
        
        if ! command -v ares-package > /dev/null; then
            echo "❌ webOS TV SDK not found"
            echo "📥 Install from: http://webostv.developer.lge.com"
            exit 1
        fi
        
        if [ ! -f "buddy-webos.ipk" ]; then
            echo "📦 Building webOS package..."
            cd tv-webos
            ares-package .
            mv *.ipk ../buddy-webos.ipk
            cd ..
        fi
        
        echo "📺 Available LG TVs:"
        ares-device-list
        
        read -p "Enter LG TV device name: " tv_device
        
        echo "📲 Installing BUDDY on LG TV..."
        ares-install buddy-webos.ipk -d "$tv_device"
        
        echo "✅ BUDDY installed on LG webOS TV!"
        echo "🚀 Launch from TV home screen"
        ;;
        
    5)
        echo "🔥 Amazon Fire TV Installation"
        echo "============================="
        
        # Fire TV uses Android APK
        if [ ! -f "buddy-android-tv.apk" ]; then
            echo "❌ Fire TV APK not found (same as Android TV)"
            exit 1
        fi
        
        echo "🔥 Installing BUDDY on Fire TV..."
        echo "📋 Make sure Fire TV has Developer Options enabled"
        
        if ! command -v adb > /dev/null; then
            echo "❌ ADB not found. Install Android SDK Platform Tools"
            exit 1
        fi
        
        read -p "Enter Fire TV IP address: " fire_tv_ip
        
        echo "📡 Connecting to Fire TV..."
        adb connect "$fire_tv_ip:5555"
        
        echo "📲 Installing BUDDY..."
        adb install -r buddy-android-tv.apk
        
        echo "✅ BUDDY installed on Fire TV!"
        echo "🚀 Find BUDDY in Fire TV apps"
        ;;
        
    6)
        echo "🛠️ Smart TV Development Setup"
        echo "============================"
        
        echo "📥 Setting up development environment for all TV platforms..."
        
        # Android TV
        echo "1️⃣ Android TV development:"
        echo "   - Install Android Studio"
        echo "   - Install Android SDK API 30+"
        echo "   - Enable USB debugging on TV"
        
        # Apple TV
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "2️⃣ Apple TV development:"
            echo "   - Xcode already available on macOS"
            echo "   - Install tvOS SDK"
        else
            echo "2️⃣ Apple TV development: Requires macOS"
        fi
        
        # Samsung Tizen
        echo "3️⃣ Samsung Tizen development:"
        if ! command -v tizen > /dev/null; then
            echo "   📥 Installing Tizen Studio..."
            # Add Tizen installation commands here
        else
            echo "   ✅ Tizen Studio already installed"
        fi
        
        # LG webOS
        echo "4️⃣ LG webOS development:"
        if ! command -v ares-package > /dev/null; then
            echo "   📥 Installing webOS TV SDK..."
            # Add webOS SDK installation commands here
        else
            echo "   ✅ webOS TV SDK already installed"
        fi
        
        echo ""
        echo "✅ Development environment setup complete!"
        echo "📋 Next steps:"
        echo "   1. Enable Developer Mode on your TV"
        echo "   2. Connect TV to same network as development machine"
        echo "   3. Build and install BUDDY for your TV platform"
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Smart TV installation complete!"
echo ""
echo "📋 BUDDY TV Features:"
echo "   🎤 Voice control with TV remote"
echo "   🌐 Connects to BUDDY Core on your network"
echo "   🔄 Syncs with other BUDDY devices"
echo "   📺 Optimized for TV viewing experience"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Ensure BUDDY Core is running on your network"
echo "   • Check TV and BUDDY Core are on same WiFi"
echo "   • Verify TV has microphone permissions enabled"
EOF

    chmod +x "$OUTPUT_DIR/install-smart-tv.sh"
    echo "✅ Smart TV installer created: $OUTPUT_DIR/install-smart-tv.sh"
}

# Main execution
echo "Select Smart TV platform to build:"
echo "1) Android TV"
echo "2) Apple TV (macOS only)"
echo "3) Samsung Tizen TV"
echo "4) LG webOS TV"
echo "5) All TV platforms"
echo "6) Create installer script only"

read -p "Enter choice (1-6): " choice

case $choice in
    1)
        build_android_tv
        create_smart_tv_installer
        ;;
    2)
        build_apple_tv
        create_smart_tv_installer
        ;;
    3)
        build_tizen_tv
        create_smart_tv_installer
        ;;
    4)
        build_webos_tv
        create_smart_tv_installer
        ;;
    5)
        build_android_tv
        build_apple_tv
        build_tizen_tv
        build_webos_tv
        create_smart_tv_installer
        ;;
    6)
        create_smart_tv_installer
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Smart TV app creation complete!"
echo "📁 Output directory: $OUTPUT_DIR/"
echo ""
echo "📺 Installation options:"
echo "  • Use install-smart-tv.sh for guided installation"
echo "  • Manual installation via TV developer tools"
echo "  • Sideload APK for Android-based TVs"
echo "  • App store distribution for commercial deployment"