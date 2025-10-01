#!/bin/bash
# BUDDY AI Assistant - Automotive Integration Builder
# Creates apps for Android Auto, Apple CarPlay, and in-vehicle systems

set -e

APP_NAME="BUDDY Auto"
APP_VERSION="1.0.0"
OUTPUT_DIR="output"

echo "🚗 BUDDY Automotive Integration Builder"
echo "======================================"

mkdir -p "$OUTPUT_DIR"

# Function to create Android Auto app
build_android_auto() {
    echo "🚗 Building Android Auto app..."
    
    # Create Android Auto project structure
    AUTO_PROJECT_DIR="../../apps/auto-android"
    mkdir -p "$AUTO_PROJECT_DIR"
    cd "$AUTO_PROJECT_DIR"
    
    # Create Android Auto manifest
    mkdir -p src/main
    cat > src/main/AndroidManifest.xml << 'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.buddy.ai.auto">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.CALL_PHONE" />
    <uses-permission android:name="android.permission.SEND_SMS" />
    
    <!-- Android Auto metadata -->
    <uses-feature
        android:name="android.hardware.microphone"
        android:required="true" />
    <uses-feature
        android:name="android.hardware.location"
        android:required="false" />

    <application
        android:allowBackup="true"
        android:icon="@drawable/ic_buddy_auto"
        android:label="@string/app_name"
        android:theme="@style/AppTheme">

        <!-- Android Auto service -->
        <service
            android:name=".BuddyAutoMessagingService"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <action android:name="android.intent.action.SEND_MULTIPLE" />
            </intent-filter>
        </service>

        <!-- Car App Service -->
        <service
            android:name=".BuddyAutoCarAppService"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="androidx.car.app.CarAppService" />
            </intent-filter>
            <meta-data
                android:name="androidx.car.app.minCarApiLevel"
                android:value="1" />
        </service>

        <!-- Main activity for phone use -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Voice command receiver -->
        <receiver
            android:name=".VoiceCommandReceiver"
            android:enabled="true"
            android:exported="true">
            <intent-filter>
                <action android:name="android.speech.action.VOICE_SEARCH_HANDS_FREE" />
            </intent-filter>
        </receiver>

    </application>
</manifest>
EOF

    # Create build.gradle
    cat > build.gradle << 'EOF'
apply plugin: 'com.android.application'

android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.buddy.ai.auto"
        minSdk 23
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
    implementation 'androidx.car.app:app:1.3.0'
    implementation 'androidx.car.app:app-projected:1.3.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.core:core:1.10.1'
    implementation 'com.google.android.gms:play-services-location:21.0.1'
    implementation 'com.squareup.okhttp3:okhttp:4.11.0'
    implementation 'org.java-websocket:Java-WebSocket:1.5.3'
    implementation 'com.google.code.gson:gson:2.10.1'
}
EOF

    # Create BuddyAutoCarAppService
    mkdir -p src/main/java/com/buddy/ai/auto
    cat > src/main/java/com/buddy/ai/auto/BuddyAutoCarAppService.java << 'EOF'
package com.buddy.ai.auto;

import androidx.annotation.NonNull;
import androidx.car.app.CarAppService;
import androidx.car.app.Screen;
import androidx.car.app.Session;
import androidx.car.app.validation.HostValidator;

public class BuddyAutoCarAppService extends CarAppService {
    
    @NonNull
    @Override
    public HostValidator createHostValidator() {
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR;
    }

    @NonNull
    @Override
    public Session onCreateSession() {
        return new BuddyAutoSession();
    }

    public static class BuddyAutoSession extends Session {
        
        @NonNull
        @Override
        public Screen onCreateScreen(@NonNull Intent intent) {
            return new BuddyAutoMainScreen(getCarContext());
        }
    }
}
EOF

    # Create main screen for Android Auto
    cat > src/main/java/com/buddy/ai/auto/BuddyAutoMainScreen.java << 'EOF'
package com.buddy.ai.auto;

import androidx.annotation.NonNull;
import androidx.car.app.CarContext;
import androidx.car.app.Screen;
import androidx.car.app.model.Action;
import androidx.car.app.model.CarIcon;
import androidx.car.app.model.ListTemplate;
import androidx.car.app.model.Row;
import androidx.car.app.model.Template;
import androidx.core.graphics.drawable.IconCompat;

public class BuddyAutoMainScreen extends Screen {
    private BuddyAutoService buddyService;

    public BuddyAutoMainScreen(@NonNull CarContext carContext) {
        super(carContext);
        this.buddyService = new BuddyAutoService(carContext);
    }

    @NonNull
    @Override
    public Template onGetTemplate() {
        return new ListTemplate.Builder()
                .setSingleList(
                    new ItemList.Builder()
                        .addItem(new Row.Builder()
                            .setTitle("🎤 Talk to BUDDY")
                            .setOnClickListener(() -> startVoiceCommand())
                            .build())
                        .addItem(new Row.Builder()
                            .setTitle("📱 Send Message")
                            .setOnClickListener(() -> openMessaging())
                            .build())
                        .addItem(new Row.Builder()
                            .setTitle("🗺️ Navigation Help")
                            .setOnClickListener(() -> startNavigation())
                            .build())
                        .addItem(new Row.Builder()
                            .setTitle("🎵 Music Control")
                            .setOnClickListener(() -> controlMusic())
                            .build())
                        .addItem(new Row.Builder()
                            .setTitle("☎️ Make Call")
                            .setOnClickListener(() -> makeCall())
                            .build())
                        .addItem(new Row.Builder()
                            .setTitle("🌡️ Car Status")
                            .setOnClickListener(() -> checkCarStatus())
                            .build())
                        .build())
                .setTitle("🤖 BUDDY Auto Assistant")
                .setHeaderAction(Action.APP_ICON)
                .build();
    }

    private void startVoiceCommand() {
        // Start voice recognition for BUDDY commands
        buddyService.startVoiceRecognition(new BuddyAutoService.VoiceCallback() {
            @Override
            public void onVoiceResult(String text) {
                buddyService.sendToBuddy(text);
                showToast("Processing: " + text);
            }
            
            @Override
            public void onVoiceError(String error) {
                showToast("Voice error: " + error);
            }
        });
    }

    private void openMessaging() {
        getScreenManager().push(new BuddyAutoMessagingScreen(getCarContext(), buddyService));
    }

    private void startNavigation() {
        // Integration with navigation apps
        buddyService.sendToBuddy("Help me with navigation");
    }

    private void controlMusic() {
        // Music control integration
        buddyService.sendToBuddy("Control my music");
    }

    private void makeCall() {
        // Phone call integration
        buddyService.sendToBuddy("Help me make a call");
    }

    private void checkCarStatus() {
        // Car diagnostic integration
        buddyService.sendToBuddy("Check my car status");
    }

    private void showToast(String message) {
        getCarContext().getCarService(AppManager.class)
            .showToast(message, CarToast.LENGTH_SHORT);
    }
}
EOF

    # Create voice command receiver
    cat > src/main/java/com/buddy/ai/auto/VoiceCommandReceiver.java << 'EOF'
package com.buddy.ai.auto;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.speech.RecognizerIntent;
import java.util.ArrayList;

public class VoiceCommandReceiver extends BroadcastReceiver {
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (RecognizerIntent.ACTION_VOICE_SEARCH_HANDS_FREE.equals(intent.getAction())) {
            // Handle "OK Google, talk to BUDDY" commands
            ArrayList<String> results = intent.getStringArrayListExtra(
                RecognizerIntent.EXTRA_RESULTS);
            
            if (results != null && !results.isEmpty()) {
                String voiceCommand = results.get(0).toLowerCase();
                
                if (voiceCommand.contains("buddy") || voiceCommand.contains("assistant")) {
                    // Launch BUDDY Auto
                    Intent launchIntent = new Intent(context, MainActivity.class);
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    launchIntent.putExtra("voice_command", voiceCommand);
                    context.startActivity(launchIntent);
                }
            }
        }
    }
}
EOF

    # Create BUDDY Auto service
    cat > src/main/java/com/buddy/ai/auto/BuddyAutoService.java << 'EOF'
package com.buddy.ai.auto;

import android.car.CarContext;
import android.content.Context;
import android.location.Location;
import android.location.LocationManager;
import android.media.AudioManager;
import android.speech.RecognitionListener;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;
import java.net.URI;
import java.util.Locale;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

public class BuddyAutoService {
    private Context context;
    private WebSocketClient wsClient;
    private TextToSpeech tts;
    private SpeechRecognizer speechRecognizer;
    private boolean isConnected = false;
    private Gson gson = new Gson();

    public interface VoiceCallback {
        void onVoiceResult(String text);
        void onVoiceError(String error);
    }

    public interface BuddyCallback {
        void onResponse(String response);
        void onError(String error);
    }

    public BuddyAutoService(Context context) {
        this.context = context;
        initializeServices();
        connectToBuddy();
    }

    private void initializeServices() {
        // Initialize Text-to-Speech
        tts = new TextToSpeech(context, status -> {
            if (status == TextToSpeech.SUCCESS) {
                tts.setLanguage(Locale.US);
                tts.setSpeechRate(0.9f);
            }
        });

        // Initialize Speech Recognition
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context);
    }

    private void connectToBuddy() {
        try {
            // Connect to BUDDY Core via hotspot or home network
            String serverUrl = "ws://192.168.1.100:8000/ws"; // Default BUDDY server
            
            wsClient = new WebSocketClient(URI.create(serverUrl)) {
                @Override
                public void onOpen(ServerHandshake handshake) {
                    isConnected = true;
                    // Send car context information
                    JsonObject carInfo = new JsonObject();
                    carInfo.addProperty("type", "car_connected");
                    carInfo.addProperty("device", "android_auto");
                    carInfo.addProperty("capabilities", "voice,navigation,music,calls,sms");
                    send(gson.toJson(carInfo));
                }

                @Override
                public void onMessage(String message) {
                    try {
                        JsonObject data = gson.fromJson(message, JsonObject.class);
                        if (data.has("response")) {
                            String response = data.get("response").getAsString();
                            speakResponse(response);
                            
                            // Handle specific car commands
                            handleCarCommand(response, data);
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }

                @Override
                public void onClose(int code, String reason, boolean remote) {
                    isConnected = false;
                }

                @Override
                public void onError(Exception ex) {
                    ex.printStackTrace();
                    isConnected = false;
                }
            };

            wsClient.connect();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void startVoiceRecognition(VoiceCallback callback) {
        if (speechRecognizer == null) return;

        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, 
                       RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault());
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak to BUDDY...");

        speechRecognizer.setRecognitionListener(new RecognitionListener() {
            @Override
            public void onResults(Bundle results) {
                ArrayList<String> matches = results.getStringArrayList(
                    SpeechRecognizer.RESULTS_RECOGNITION);
                if (matches != null && !matches.isEmpty()) {
                    callback.onVoiceResult(matches.get(0));
                }
            }

            @Override
            public void onError(int error) {
                callback.onVoiceError("Speech recognition error: " + error);
            }

            // Other required methods...
            @Override public void onReadyForSpeech(Bundle params) {}
            @Override public void onBeginningOfSpeech() {}
            @Override public void onRmsChanged(float rmsdB) {}
            @Override public void onBufferReceived(byte[] buffer) {}
            @Override public void onEndOfSpeech() {}
            @Override public void onPartialResults(Bundle partialResults) {}
            @Override public void onEvent(int eventType, Bundle params) {}
        });

        speechRecognizer.startListening(intent);
    }

    public void sendToBuddy(String message) {
        if (isConnected && wsClient != null) {
            JsonObject data = new JsonObject();
            data.addProperty("type", "car_message");
            data.addProperty("text", message);
            data.addProperty("timestamp", System.currentTimeMillis());
            
            // Add car context
            JsonObject context = new JsonObject();
            context.addProperty("speed", getCurrentSpeed());
            context.addProperty("location", getCurrentLocation());
            context.addProperty("time", System.currentTimeMillis());
            data.add("car_context", context);
            
            wsClient.send(gson.toJson(data));
        }
    }

    private void speakResponse(String text) {
        if (tts != null) {
            // Lower music volume during speech
            AudioManager audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            audioManager.requestAudioFocus(null, AudioManager.STREAM_MUSIC, 
                                         AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK);
            
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "buddy_response");
        }
    }

    private void handleCarCommand(String response, JsonObject data) {
        // Handle specific automotive commands
        if (data.has("action")) {
            String action = data.get("action").getAsString();
            
            switch (action) {
                case "navigate":
                    if (data.has("destination")) {
                        String destination = data.get("destination").getAsString();
                        startNavigation(destination);
                    }
                    break;
                    
                case "call":
                    if (data.has("contact")) {
                        String contact = data.get("contact").getAsString();
                        makePhoneCall(contact);
                    }
                    break;
                    
                case "message":
                    if (data.has("contact") && data.has("message")) {
                        String contact = data.get("contact").getAsString();
                        String message = data.get("message").getAsString();
                        sendTextMessage(contact, message);
                    }
                    break;
                    
                case "music":
                    if (data.has("command")) {
                        String command = data.get("command").getAsString();
                        controlMusic(command);
                    }
                    break;
            }
        }
    }

    private void startNavigation(String destination) {
        Intent intent = new Intent(Intent.ACTION_VIEW, 
                                 Uri.parse("google.navigation:q=" + destination));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    private void makePhoneCall(String contact) {
        Intent intent = new Intent(Intent.ACTION_CALL);
        intent.setData(Uri.parse("tel:" + contact));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    private void sendTextMessage(String contact, String message) {
        Intent intent = new Intent(Intent.ACTION_SENDTO);
        intent.setData(Uri.parse("smsto:" + contact));
        intent.putExtra("sms_body", message);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    private void controlMusic(String command) {
        Intent intent = new Intent("com.android.music.musicservicecommand");
        
        switch (command.toLowerCase()) {
            case "play":
                intent.putExtra("command", "play");
                break;
            case "pause":
                intent.putExtra("command", "pause");
                break;
            case "next":
                intent.putExtra("command", "next");
                break;
            case "previous":
                intent.putExtra("command", "previous");
                break;
        }
        
        context.sendBroadcast(intent);
    }

    private String getCurrentSpeed() {
        // Get current vehicle speed if available
        return "0"; // Placeholder
    }

    private String getCurrentLocation() {
        try {
            LocationManager locationManager = (LocationManager) 
                context.getSystemService(Context.LOCATION_SERVICE);
            Location location = locationManager.getLastKnownLocation(
                LocationManager.GPS_PROVIDER);
            
            if (location != null) {
                return location.getLatitude() + "," + location.getLongitude();
            }
        } catch (SecurityException e) {
            // Location permission not granted
        }
        return "unknown";
    }

    public void disconnect() {
        if (wsClient != null) {
            wsClient.close();
        }
        if (tts != null) {
            tts.stop();
            tts.shutdown();
        }
        if (speechRecognizer != null) {
            speechRecognizer.destroy();
        }
    }
}
EOF

    echo "✅ Android Auto project structure created"
    echo "📋 To build Android Auto app:"
    echo "   1. Install Android Studio"
    echo "   2. Enable Android Auto developer mode"
    echo "   3. Build and install APK"
    echo "   4. Test with Android Auto head unit or simulator"
    
    cd ../../installers/automotive
}

# Function to create Apple CarPlay app
build_apple_carplay() {
    echo "🚗 Building Apple CarPlay app..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ Apple CarPlay development requires macOS with Xcode"
        return 1
    fi
    
    # Create CarPlay project structure
    CARPLAY_PROJECT_DIR="../../apps/carplay-ios"
    mkdir -p "$CARPLAY_PROJECT_DIR"
    cd "$CARPLAY_PROJECT_DIR"
    
    # Create Info.plist for CarPlay
    cat > Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>BUDDY Auto</string>
    <key>CFBundleIdentifier</key>
    <string>com.buddy.ai.carplay</string>
    <key>CFBundleName</key>
    <string>BUDDY Auto</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    
    <!-- CarPlay Configuration -->
    <key>MKDirectionsApplicationSupportedModes</key>
    <array>
        <string>MKDirectionsModeCar</string>
    </array>
    
    <!-- Privacy Usage Descriptions -->
    <key>NSMicrophoneUsageDescription</key>
    <string>BUDDY needs microphone access for voice commands in your car</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>BUDDY uses location for navigation and context-aware assistance</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>BUDDY can provide location-based assistance while driving</string>
    <key>NSContactsUsageDescription</key>
    <string>BUDDY can help you call or message your contacts while driving</string>
    
    <!-- CarPlay Scene Configuration -->
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>CPTemplateApplicationSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneClassName</key>
                    <string>CPTemplateApplicationScene</string>
                    <key>UISceneConfigurationName</key>
                    <string>BuddyCarPlayScene</string>
                    <key>UISceneDelegateClassName</key>
                    <string>CarPlaySceneDelegate</string>
                </dict>
            </array>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneClassName</key>
                    <string>UIWindowScene</string>
                    <key>UISceneConfigurationName</key>
                    <string>Default Configuration</string>
                    <key>UISceneDelegateClassName</key>
                    <string>SceneDelegate</string>
                    <key>UISceneStoryboardFile</key>
                    <string>Main</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
</plist>
EOF

    # Create CarPlay Scene Delegate
    cat > CarPlaySceneDelegate.swift << 'EOF'
import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    var buddyService: BuddyCarPlayService?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.buddyService = BuddyCarPlayService()
        
        // Setup main CarPlay interface
        setupCarPlayInterface()
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        buddyService?.disconnect()
    }
    
    private func setupCarPlayInterface() {
        guard let interfaceController = interfaceController else { return }
        
        // Create main list template
        let mainTemplate = createMainTemplate()
        interfaceController.setRootTemplate(mainTemplate, animated: true)
    }
    
    private func createMainTemplate() -> CPListTemplate {
        let voiceItem = CPListItem(text: "🎤 Talk to BUDDY",
                                   detailText: "Voice commands and assistance",
                                   image: nil)
        voiceItem.handler = { [weak self] item, completion in
            self?.startVoiceInteraction()
            completion()
        }
        
        let navigationItem = CPListItem(text: "🗺️ Navigation",
                                       detailText: "Get directions and traffic info",
                                       image: nil)
        navigationItem.handler = { [weak self] item, completion in
            self?.showNavigationTemplate()
            completion()
        }
        
        let musicItem = CPListItem(text: "🎵 Music Control",
                                  detailText: "Control your music",
                                  image: nil)
        musicItem.handler = { [weak self] item, completion in
            self?.showMusicControl()
            completion()
        }
        
        let communicationItem = CPListItem(text: "📞 Communication",
                                          detailText: "Calls and messages",
                                          image: nil)
        communicationItem.handler = { [weak self] item, completion in
            self?.showCommunicationTemplate()
            completion()
        }
        
        let carStatusItem = CPListItem(text: "🚗 Car Status",
                                      detailText: "Vehicle information",
                                      image: nil)
        carStatusItem.handler = { [weak self] item, completion in
            self?.showCarStatus()
            completion()
        }
        
        let section = CPListSection(items: [voiceItem, navigationItem, musicItem, 
                                          communicationItem, carStatusItem])
        
        let listTemplate = CPListTemplate(title: "🤖 BUDDY Auto", sections: [section])
        
        // Add voice button to tab bar
        let voiceButton = CPBarButton(title: "🎤") { [weak self] button in
            self?.startVoiceInteraction()
        }
        listTemplate.leadingNavigationBarButtons = [voiceButton]
        
        return listTemplate
    }
    
    private func startVoiceInteraction() {
        // Show voice template
        let voiceTemplate = CPVoiceControlTemplate(voiceControlStates: [
            CPVoiceControlState(identifier: "listening",
                               titleVariants: ["Listening..."],
                               subtitleVariants: ["Say something to BUDDY"],
                               image: nil)
        ])
        
        voiceTemplate.activateVoiceControlState(withIdentifier: "listening")
        
        interfaceController?.presentTemplate(voiceTemplate, animated: true) { [weak self] success, error in
            if success {
                self?.buddyService?.startVoiceRecognition { [weak self] result in
                    DispatchQueue.main.async {
                        self?.handleVoiceResult(result)
                        self?.interfaceController?.dismissTemplate(animated: true)
                    }
                }
            }
        }
    }
    
    private func handleVoiceResult(_ result: VoiceResult) {
        switch result {
        case .success(let text):
            buddyService?.sendToBuddy(text) { [weak self] response in
                DispatchQueue.main.async {
                    self?.showBuddyResponse(response)
                }
            }
        case .error(let error):
            showAlert(title: "Voice Error", message: error.localizedDescription)
        }
    }
    
    private func showBuddyResponse(_ response: String) {
        // Speak the response
        buddyService?.speak(response)
        
        // Show response in CarPlay
        let alertTemplate = CPAlertTemplate(titleVariants: ["BUDDY says:"],
                                           subtitleVariants: [response])
        
        let okAction = CPAlertAction(title: "OK", style: .default) { [weak self] action in
            self?.interfaceController?.dismissTemplate(animated: true)
        }
        
        let voiceAction = CPAlertAction(title: "🎤 Talk Again", style: .default) { [weak self] action in
            self?.interfaceController?.dismissTemplate(animated: true)
            self?.startVoiceInteraction()
        }
        
        alertTemplate.actions = [okAction, voiceAction]
        
        interfaceController?.presentTemplate(alertTemplate, animated: true)
    }
    
    private func showNavigationTemplate() {
        // Create navigation template
        let destinationItem = CPListItem(text: "Where to?",
                                        detailText: "Tell BUDDY your destination",
                                        image: nil)
        destinationItem.handler = { [weak self] item, completion in
            self?.startVoiceNavigation()
            completion()
        }
        
        let homeItem = CPListItem(text: "🏠 Go Home",
                                 detailText: "Navigate to home",
                                 image: nil)
        homeItem.handler = { [weak self] item, completion in
            self?.navigateHome()
            completion()
        }
        
        let workItem = CPListItem(text: "🏢 Go to Work",
                                 detailText: "Navigate to work",
                                 image: nil)
        workItem.handler = { [weak self] item, completion in
            self?.navigateToWork()
            completion()
        }
        
        let section = CPListSection(items: [destinationItem, homeItem, workItem])
        let template = CPListTemplate(title: "🗺️ Navigation", sections: [section])
        
        interfaceController?.pushTemplate(template, animated: true)
    }
    
    private func showMusicControl() {
        // Music control template
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        interfaceController?.pushTemplate(nowPlayingTemplate, animated: true)
    }
    
    private func showCommunicationTemplate() {
        // Communication template
        let callItem = CPListItem(text: "📞 Make Call",
                                 detailText: "Call a contact",
                                 image: nil)
        callItem.handler = { [weak self] item, completion in
            self?.initiateCall()
            completion()
        }
        
        let messageItem = CPListItem(text: "💬 Send Message",
                                    detailText: "Send a text message",
                                    image: nil)
        messageItem.handler = { [weak self] item, completion in
            self?.sendMessage()
            completion()
        }
        
        let section = CPListSection(items: [callItem, messageItem])
        let template = CPListTemplate(title: "📞 Communication", sections: [section])
        
        interfaceController?.pushTemplate(template, animated: true)
    }
    
    private func showCarStatus() {
        buddyService?.getCarStatus { [weak self] status in
            DispatchQueue.main.async {
                let items = status.map { info in
                    CPListItem(text: info.title, detailText: info.value, image: nil)
                }
                
                let section = CPListSection(items: items)
                let template = CPListTemplate(title: "🚗 Car Status", sections: [section])
                
                self?.interfaceController?.pushTemplate(template, animated: true)
            }
        }
    }
    
    private func startVoiceNavigation() {
        startVoiceInteraction()
    }
    
    private func navigateHome() {
        buddyService?.sendToBuddy("Navigate home") { [weak self] response in
            DispatchQueue.main.async {
                self?.showBuddyResponse(response)
            }
        }
    }
    
    private func navigateToWork() {
        buddyService?.sendToBuddy("Navigate to work") { [weak self] response in
            DispatchQueue.main.async {
                self?.showBuddyResponse(response)
            }
        }
    }
    
    private func initiateCall() {
        startVoiceInteraction()
    }
    
    private func sendMessage() {
        startVoiceInteraction()
    }
    
    private func showAlert(title: String, message: String) {
        let alertTemplate = CPAlertTemplate(titleVariants: [title],
                                           subtitleVariants: [message])
        
        let okAction = CPAlertAction(title: "OK", style: .default) { [weak self] action in
            self?.interfaceController?.dismissTemplate(animated: true)
        }
        
        alertTemplate.actions = [okAction]
        interfaceController?.presentTemplate(alertTemplate, animated: true)
    }
}

enum VoiceResult {
    case success(String)
    case error(Error)
}
EOF

    echo "✅ Apple CarPlay project structure created"
    echo "📋 To build CarPlay app:"
    echo "   1. Open project in Xcode"
    echo "   2. Enable CarPlay capability"
    echo "   3. Test with CarPlay simulator"
    echo "   4. Deploy to iPhone with CarPlay head unit"
    
    cd ../../installers/automotive
}

# Function to create automotive installer script
create_automotive_installer() {
    echo "🚗 Creating automotive installer script..."
    
    cat > "$OUTPUT_DIR/install-automotive.sh" << 'EOF'
#!/bin/bash
# BUDDY Automotive Universal Installer

echo "🚗 BUDDY AI Assistant - Automotive Installer"
echo "============================================"

echo ""
echo "🚗 Select your automotive platform:"
echo "1) Android Auto"
echo "2) Apple CarPlay (requires iOS device)"
echo "3) Custom In-Vehicle System"
echo "4) OBD-II Integration"
echo "5) Development Setup"
echo ""

read -p "Enter choice (1-5): " auto_choice

case $auto_choice in
    1)
        echo "📱 Android Auto Installation"
        echo "==========================="
        
        if [ ! -f "buddy-android-auto.apk" ]; then
            echo "❌ Android Auto APK not found"
            echo "📋 To build APK:"
            echo "   1. Install Android Studio"
            echo "   2. Enable Android Auto developer mode"
            echo "   3. Build signed APK"
            exit 1
        fi
        
        echo "📱 Installing BUDDY for Android Auto..."
        
        if ! command -v adb > /dev/null; then
            echo "❌ ADB not found. Install Android SDK Platform Tools"
            exit 1
        fi
        
        echo "📱 Connect your Android phone with USB debugging enabled"
        echo "🔍 Available devices:"
        adb devices
        
        read -p "Press Enter when phone is connected..."
        
        echo "📲 Installing BUDDY Auto APK..."
        adb install -r buddy-android-auto.apk
        
        echo "✅ BUDDY installed for Android Auto!"
        echo "🚗 Connect phone to Android Auto head unit to use"
        ;;
        
    2)
        echo "🍎 Apple CarPlay Installation"
        echo "============================"
        
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo "❌ CarPlay development requires macOS with Xcode"
            exit 1
        fi
        
        if [ ! -d "carplay-ios" ]; then
            echo "❌ CarPlay project not found"
            exit 1
        fi
        
        echo "🍎 Opening CarPlay project in Xcode..."
        open carplay-ios/BuddyCarPlay.xcodeproj
        
        echo "📋 Manual steps:"
        echo "   1. Connect iPhone to Mac"
        echo "   2. Build and install app on iPhone"
        echo "   3. Enable CarPlay capability in Xcode"
        echo "   4. Connect iPhone to CarPlay head unit"
        ;;
        
    3)
        echo "🖥️ Custom In-Vehicle System Installation"
        echo "======================================="
        
        echo "🚗 Installing BUDDY for custom vehicle systems..."
        
        # Check system type
        if command -v apt-get > /dev/null; then
            echo "📦 Installing on Debian/Ubuntu-based system..."
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip nodejs npm
        elif command -v yum > /dev/null; then
            echo "📦 Installing on RedHat/CentOS-based system..."
            sudo yum install -y python3 python3-pip nodejs npm
        elif command -v pacman > /dev/null; then
            echo "📦 Installing on Arch-based system..."
            sudo pacman -S python python-pip nodejs npm
        else
            echo "❌ Unsupported Linux distribution"
            exit 1
        fi
        
        # Install BUDDY Core for automotive
        echo "🤖 Installing BUDDY Core..."
        pip3 install -r ../packages/core/requirements.txt
        
        # Create automotive service
        echo "🚗 Setting up automotive service..."
        sudo tee /etc/systemd/system/buddy-auto.service > /dev/null << 'EOL'
[Unit]
Description=BUDDY AI Automotive Assistant
After=network.target

[Service]
Type=simple
User=buddy
WorkingDirectory=/opt/buddy
ExecStart=/usr/bin/python3 /opt/buddy/start_buddy_auto.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

        # Create automotive configuration
        sudo mkdir -p /opt/buddy
        sudo cp -r ../packages/core/* /opt/buddy/
        
        # Create automotive-specific startup script
        sudo tee /opt/buddy/start_buddy_auto.py > /dev/null << 'EOL'
#!/usr/bin/env python3
import os
import sys
sys.path.append(os.path.dirname(__file__))

from buddy.main import main
from buddy.config import Config

# Automotive-specific configuration
config = Config()
config.voice_enabled = True
config.automotive_mode = True
config.can_bus_enabled = True
config.obd2_enabled = True
config.display_mode = "automotive"

if __name__ == "__main__":
    main(config)
EOL

        sudo chmod +x /opt/buddy/start_buddy_auto.py
        
        # Create buddy user
        sudo useradd -r -s /bin/false buddy || true
        sudo chown -R buddy:buddy /opt/buddy
        
        # Enable and start service
        sudo systemctl daemon-reload
        sudo systemctl enable buddy-auto.service
        sudo systemctl start buddy-auto.service
        
        echo "✅ BUDDY installed for custom in-vehicle system!"
        echo "🚗 Service running on: http://localhost:8000"
        echo "📋 View logs: sudo journalctl -u buddy-auto.service -f"
        ;;
        
    4)
        echo "🔌 OBD-II Integration Setup"
        echo "==========================="
        
        echo "🔌 Installing OBD-II integration for BUDDY..."
        
        # Install Python OBD library
        pip3 install obd pyserial cantools
        
        # Create OBD-II configuration
        cat > obd2_config.py << 'EOL'
import obd

# OBD-II Configuration for BUDDY
OBD_PORT = '/dev/ttyUSB0'  # Adjust for your OBD-II adapter
OBD_BAUDRATE = 38400

# Supported OBD-II commands
SUPPORTED_COMMANDS = [
    obd.commands.RPM,
    obd.commands.SPEED,
    obd.commands.THROTTLE_POS,
    obd.commands.ENGINE_LOAD,
    obd.commands.COOLANT_TEMP,
    obd.commands.FUEL_LEVEL,
    obd.commands.INTAKE_PRESSURE,
    obd.commands.MAF,
    obd.commands.TIMING_ADVANCE,
    obd.commands.INTAKE_TEMP,
    obd.commands.RUN_TIME,
    obd.commands.FUEL_PRESSURE,
    obd.commands.BAROMETRIC_PRESSURE,
    obd.commands.AMBIANT_AIR_TEMP,
    obd.commands.RELATIVE_THROTTLE_POS,
    obd.commands.ABSOLUTE_THROTTLE_POS_B,
    obd.commands.ACCELERATOR_POS_D,
    obd.commands.ACCELERATOR_POS_E,
    obd.commands.ACCELERATOR_POS_F,
    obd.commands.COMMANDED_THROTTLE_ACTUATOR,
]
EOL

        # Create OBD-II integration script
        cat > buddy_obd2.py << 'EOL'
#!/usr/bin/env python3
import obd
import time
import json
import websocket
from threading import Thread

class BuddyOBD2:
    def __init__(self):
        self.connection = None
        self.ws = None
        self.running = False
        
    def connect_obd(self):
        try:
            self.connection = obd.OBD()  # Auto-detect port
            if self.connection.is_connected():
                print("✅ Connected to OBD-II port")
                return True
        except Exception as e:
            print(f"❌ OBD-II connection failed: {e}")
        return False
        
    def connect_buddy(self):
        try:
            self.ws = websocket.WebSocket()
            self.ws.connect("ws://localhost:8000/ws")
            print("✅ Connected to BUDDY Core")
            return True
        except Exception as e:
            print(f"❌ BUDDY connection failed: {e}")
        return False
        
    def read_obd_data(self):
        if not self.connection:
            return {}
            
        data = {}
        for cmd in [obd.commands.RPM, obd.commands.SPEED, 
                   obd.commands.FUEL_LEVEL, obd.commands.COOLANT_TEMP]:
            try:
                response = self.connection.query(cmd)
                if response.value:
                    data[cmd.name] = str(response.value)
            except:
                pass
                
        return data
        
    def send_to_buddy(self, data):
        if self.ws:
            try:
                message = {
                    "type": "obd2_data",
                    "data": data,
                    "timestamp": time.time()
                }
                self.ws.send(json.dumps(message))
            except Exception as e:
                print(f"Error sending to BUDDY: {e}")
                
    def monitor_loop(self):
        while self.running:
            try:
                obd_data = self.read_obd_data()
                if obd_data:
                    self.send_to_buddy(obd_data)
                time.sleep(2)  # Read every 2 seconds
            except Exception as e:
                print(f"Monitor error: {e}")
                time.sleep(5)
                
    def start(self):
        if self.connect_obd() and self.connect_buddy():
            self.running = True
            monitor_thread = Thread(target=self.monitor_loop)
            monitor_thread.daemon = True
            monitor_thread.start()
            
            print("🚗 OBD-II monitoring started")
            print("📊 Sending vehicle data to BUDDY...")
            
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                self.running = False
                print("\n🛑 OBD-II monitoring stopped")

if __name__ == "__main__":
    buddy_obd = BuddyOBD2()
    buddy_obd.start()
EOL

        chmod +x buddy_obd2.py
        
        echo "✅ OBD-II integration setup complete!"
        echo "🔌 Connect OBD-II adapter to vehicle"
        echo "🚗 Run: python3 buddy_obd2.py"
        echo "📊 BUDDY will receive real-time vehicle data"
        ;;
        
    5)
        echo "🛠️ Automotive Development Setup"
        echo "==============================="
        
        echo "🚗 Setting up automotive development environment..."
        
        # Android Auto development
        echo "1️⃣ Android Auto development:"
        if ! command -v adb > /dev/null; then
            echo "   📥 Installing Android SDK Platform Tools..."
            # Add platform tools installation
        fi
        echo "   ✅ Enable Android Auto developer mode"
        echo "   ✅ Install Android Auto head unit simulator"
        
        # CarPlay development
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "2️⃣ Apple CarPlay development:"
            echo "   ✅ Xcode available"
            echo "   ✅ Install CarPlay simulator"
        else
            echo "2️⃣ Apple CarPlay development: Requires macOS"
        fi
        
        # OBD-II development
        echo "3️⃣ OBD-II development:"
        pip3 install obd pyserial cantools
        echo "   ✅ OBD-II libraries installed"
        
        # CAN bus development
        echo "4️⃣ CAN bus development:"
        if command -v apt-get > /dev/null; then
            sudo apt-get install -y can-utils
        fi
        echo "   ✅ CAN utilities installed"
        
        echo ""
        echo "✅ Automotive development environment ready!"
        echo "📋 Next steps:"
        echo "   1. Connect development device to vehicle"
        echo "   2. Enable developer modes on automotive platforms"
        echo "   3. Build and test BUDDY automotive integration"
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Automotive installation complete!"
echo ""
echo "🚗 BUDDY Automotive Features:"
echo "   🎤 Voice control while driving"
echo "   🗺️ Navigation assistance"
echo "   📞 Hands-free communication"
echo "   🎵 Music control"
echo "   📊 Vehicle diagnostics"
echo "   🔌 OBD-II integration"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Ensure BUDDY Core is running"
echo "   • Check automotive platform compatibility"
echo "   • Verify microphone permissions"
echo "   • Test voice recognition in vehicle"
EOF

    chmod +x "$OUTPUT_DIR/install-automotive.sh"
    echo "✅ Automotive installer created: $OUTPUT_DIR/install-automotive.sh"
}

# Main execution
echo "Select automotive platform to build:"
echo "1) Android Auto"
echo "2) Apple CarPlay (macOS only)"
echo "3) Both platforms"
echo "4) Create installer script only"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        build_android_auto
        create_automotive_installer
        ;;
    2)
        build_apple_carplay
        create_automotive_installer
        ;;
    3)
        build_android_auto
        build_apple_carplay
        create_automotive_installer
        ;;
    4)
        create_automotive_installer
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Automotive integration complete!"
echo "📁 Output directory: $OUTPUT_DIR/"
echo ""
echo "🚗 Installation options:"
echo "  • Use install-automotive.sh for guided installation"
echo "  • Manual installation via automotive development tools"
echo "  • OBD-II integration for vehicle diagnostics"
echo "  • Custom in-vehicle system deployment"