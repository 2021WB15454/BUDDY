#!/bin/bash
# BUDDY AI Assistant - Mobile App Builder
# Creates Android APK and iOS IPA packages

set -e

APP_NAME="BUDDY AI Assistant"
APP_VERSION="1.0.0"
PACKAGE_NAME="com.buddy.ai.assistant"
OUTPUT_DIR="output"

echo "🤖 BUDDY Mobile App Builder"
echo "=========================="

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to build Android APK
build_android() {
    echo "📱 Building Android APK..."
    
    # Check Flutter installation
    if ! command -v flutter > /dev/null; then
        echo "❌ Flutter not found. Please install Flutter first."
        echo "📥 Download from: https://flutter.dev/docs/get-started/install"
        exit 1
    fi
    
    # Navigate to mobile app directory
    if [ ! -d "../../apps/mobile" ]; then
        echo "📁 Creating mobile app structure..."
        mkdir -p "../../apps/mobile"
        cd "../../apps/mobile"
        
        # Create new Flutter project
        flutter create --org com.buddy.ai --project-name buddy_mobile .
        
        # Update pubspec.yaml with BUDDY dependencies
        cat > pubspec.yaml << 'EOF'
name: buddy_mobile
description: BUDDY AI Assistant Mobile App
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.16.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  http: ^1.1.0
  web_socket_channel: ^2.4.0
  speech_to_text: ^6.6.0
  flutter_tts: ^3.8.3
  permission_handler: ^11.0.1
  shared_preferences: ^2.2.2
  connectivity_plus: ^5.0.2
  device_info_plus: ^9.1.1
  package_info_plus: ^4.2.0
  url_launcher: ^6.2.1
  flutter_local_notifications: ^16.3.0
  avatar_glow: ^3.0.1
  animated_text_kit: ^4.2.2
  lottie: ^2.7.0
  auto_size_text: ^3.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/icon.png"
  min_sdk_android: 21
  web:
    generate: true
    image_path: "assets/icon.png"
    background_color: "#hexcode"
    theme_color: "#hexcode"
  windows:
    generate: true
    image_path: "assets/icon.png"
    icon_size: 48

flutter:
  uses-material-design: true
  assets:
    - assets/
    - assets/animations/
    - assets/sounds/
EOF
        
        # Create main.dart
        mkdir -p lib
        cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/buddy_service.dart';
import 'utils/theme.dart';

void main() {
  runApp(BuddyApp());
}

class BuddyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: BuddyTheme.primaryColor,
      ),
    );
    
    return MaterialApp(
      title: 'BUDDY AI Assistant',
      theme: BuddyTheme.lightTheme,
      darkTheme: BuddyTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
EOF

        # Create home screen
        mkdir -p lib/screens
        cat > lib/screens/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../services/buddy_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_animation.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BuddyService _buddyService = BuddyService();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isConnected = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initializeBuddy();
  }

  Future<void> _initializeBuddy() async {
    await _speechToText.initialize();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.8);
    
    // Connect to BUDDY Core
    await _buddyService.connect();
    setState(() => _isConnected = _buddyService.isConnected);
    
    // Listen for responses
    _buddyService.messageStream.listen((message) {
      setState(() {
        _messages.add(ChatMessage(
          text: message,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      _speak(message);
    });
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            setState(() => _lastWords = result.recognizedWords);
            if (result.finalResult) {
              _sendMessage(_lastWords);
              _stopListening();
            }
          },
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    
    _textController.clear();
    _scrollToBottom();
    _buddyService.sendMessage(text);
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.white),
            SizedBox(width: 8),
            Text('BUDDY AI'),
            Spacer(),
            Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
          if (_isListening)
            Container(
              padding: EdgeInsets.all(16),
              child: VoiceAnimation(isListening: _isListening),
            ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Ask BUDDY anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                SizedBox(width: 8),
                AvatarGlow(
                  animate: _isListening,
                  glowColor: Theme.of(context).primaryColor,
                  endRadius: 30,
                  duration: Duration(milliseconds: 2000),
                  repeatPauseDuration: Duration(milliseconds: 100),
                  repeat: true,
                  child: FloatingActionButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    _buddyService.disconnect();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
EOF

        # Create BUDDY service
        mkdir -p lib/services
        cat > lib/services/buddy_service.dart << 'EOF'
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class BuddyService {
  static const String DEFAULT_HOST = 'localhost';
  static const int DEFAULT_PORT = 8000;
  
  WebSocketChannel? _channel;
  String _host = DEFAULT_HOST;
  int _port = DEFAULT_PORT;
  bool _isConnected = false;
  
  final StreamController<String> _messageController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect({String? host, int? port}) async {
    _host = host ?? DEFAULT_HOST;
    _port = port ?? DEFAULT_PORT;
    
    try {
      // First check if BUDDY Core is running
      final response = await http.get(
        Uri.parse('http://$_host:$_port/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        // Connect WebSocket
        _channel = WebSocketChannel.connect(
          Uri.parse('ws://$_host:$_port/ws'),
        );
        
        _channel!.stream.listen(
          (data) {
            final message = json.decode(data);
            if (message['type'] == 'response') {
              _messageController.add(message['text']);
            }
          },
          onError: (error) {
            _isConnected = false;
            _messageController.addError('Connection error: $error');
          },
          onDone: () {
            _isConnected = false;
          },
        );
        
        _isConnected = true;
        _messageController.add('Connected to BUDDY Core');
      }
    } catch (e) {
      _isConnected = false;
      _messageController.addError('Failed to connect to BUDDY Core: $e');
    }
  }

  void sendMessage(String message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode({
        'type': 'message',
        'text': message,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
EOF

        # Create theme
        mkdir -p lib/utils
        cat > lib/utils/theme.dart << 'EOF'
import 'package:flutter/material.dart';

class BuddyTheme {
  static const Color primaryColor = Color(0xFF667EEA);
  static const Color secondaryColor = Color(0xFF764BA2);
  static const Color accentColor = Color(0xFF6C63FF);
  
  static ThemeData lightTheme = ThemeData(
    primarySwatch: MaterialColor(0xFF667EEA, {
      50: Color(0xFFE8EFFE),
      100: Color(0xFFC6D7FD),
      200: Color(0xFFA1BCFB),
      300: Color(0xFF7BA1F9),
      400: Color(0xFF5F8CF8),
      500: Color(0xFF667EEA),
      600: Color(0xFF5A70E8),
      700: Color(0xFF4C5FE5),
      800: Color(0xFF3F4FE3),
      900: Color(0xFF2B32DF),
    }),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: 'Roboto',
  );
  
  static ThemeData darkTheme = ThemeData.dark().copyWith(
    primaryColor: primaryColor,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
EOF

        # Create widgets
        mkdir -p lib/widgets
        cat > lib/widgets/chat_bubble.dart << 'EOF'
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, color: Colors.grey[600], size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
EOF

        cat > lib/widgets/voice_animation.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class VoiceAnimation extends StatelessWidget {
  final bool isListening;

  const VoiceAnimation({Key? key, required this.isListening}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening 
                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
            ),
            child: Icon(
              Icons.mic,
              size: 30,
              color: isListening 
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isListening ? 'Listening...' : 'Tap to speak',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
EOF

        # Create assets directory and placeholder files
        mkdir -p assets
        mkdir -p assets/animations
        mkdir -p assets/sounds
        
        # Copy icon if available
        if [ -f "../../../assets/icon.png" ]; then
            cp "../../../assets/icon.png" assets/
        fi
        
        cd ../../installers/mobile
    else
        cd "../../apps/mobile"
    fi
    
    # Get dependencies
    flutter pub get
    
    # Generate launcher icons
    flutter pub run flutter_launcher_icons:main
    
    # Build APK
    echo "🔨 Building release APK..."
    flutter build apk --release --split-per-abi
    
    # Copy APKs to output directory
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "../../installers/mobile/$OUTPUT_DIR/BUDDY-${APP_VERSION}-arm64.apk"
    cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "../../installers/mobile/$OUTPUT_DIR/BUDDY-${APP_VERSION}-arm32.apk"
    cp build/app/outputs/flutter-apk/app-x86_64-release.apk "../../installers/mobile/$OUTPUT_DIR/BUDDY-${APP_VERSION}-x64.apk"
    
    # Build universal APK
    flutter build apk --release
    cp build/app/outputs/flutter-apk/app-release.apk "../../installers/mobile/$OUTPUT_DIR/BUDDY-${APP_VERSION}-universal.apk"
    
    echo "✅ Android APKs created in $OUTPUT_DIR/"
}

# Function to build iOS IPA
build_ios() {
    echo "🍎 Building iOS IPA..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ iOS builds require macOS with Xcode"
        return 1
    fi
    
    # Check if we're in mobile directory
    if [ ! -d "../../apps/mobile" ]; then
        echo "❌ Mobile app directory not found. Please run Android build first."
        return 1
    fi
    
    cd "../../apps/mobile"
    
    # Update iOS configuration
    if [ ! -f "ios/Runner/Info.plist" ]; then
        echo "❌ iOS project not properly configured"
        return 1
    fi
    
    # Build iOS
    echo "🔨 Building iOS app..."
    flutter build ios --release --no-codesign
    
    # Create IPA (requires manual signing in Xcode)
    echo "📦 Creating IPA requires Xcode for signing..."
    echo "   1. Open ios/Runner.xcworkspace in Xcode"
    echo "   2. Select your development team"
    echo "   3. Archive the project (Product → Archive)"
    echo "   4. Export IPA for distribution"
    
    cd ../../installers/mobile
}

# Function to create mobile installer script
create_mobile_installer() {
    echo "📱 Creating mobile installer script..."
    
    cat > "$OUTPUT_DIR/install-mobile.sh" << 'EOF'
#!/bin/bash
# BUDDY Mobile Installer Script

echo "📱 BUDDY AI Assistant Mobile Installer"
echo "====================================="

# Detect platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 macOS detected - iOS development available"
    IOS_AVAILABLE=true
else
    echo "🐧 Linux detected - Android only"
    IOS_AVAILABLE=false
fi

echo ""
echo "📋 Available installation options:"
echo "1) Install Android APK via ADB"
echo "2) Generate QR code for APK download"
echo "3) Create Android development environment"
if [ "$IOS_AVAILABLE" = true ]; then
    echo "4) Setup iOS development environment"
    echo "5) Build and install iOS app"
fi
echo ""

read -p "Select option: " choice

case $choice in
    1)
        echo "📱 Installing Android APK..."
        if ! command -v adb > /dev/null; then
            echo "❌ ADB not found. Please install Android SDK Platform Tools"
            exit 1
        fi
        
        echo "📱 Available APK files:"
        ls -la *.apk 2>/dev/null || {
            echo "❌ No APK files found in current directory"
            exit 1
        }
        
        echo ""
        read -p "Enter APK filename: " apk_file
        
        if [ -f "$apk_file" ]; then
            echo "📲 Installing $apk_file..."
            adb install "$apk_file"
            echo "✅ BUDDY mobile app installed!"
        else
            echo "❌ File not found: $apk_file"
        fi
        ;;
        
    2)
        echo "📱 Generating QR code for APK download..."
        
        # List available APKs
        echo "📱 Available APK files:"
        ls -la *.apk 2>/dev/null || {
            echo "❌ No APK files found"
            exit 1
        }
        
        read -p "Enter APK filename: " apk_file
        read -p "Enter download URL base (e.g., https://yourserver.com/): " base_url
        
        if [ -f "$apk_file" ]; then
            download_url="${base_url}${apk_file}"
            
            # Generate QR code using Python (if available)
            if command -v python3 > /dev/null; then
                python3 -c "
import qrcode
qr = qrcode.QRCode(version=1, box_size=10, border=5)
qr.add_data('$download_url')
qr.make(fit=True)
print('QR Code for: $download_url')
qr.print_ascii()
"
            else
                echo "📱 Download URL: $download_url"
                echo "   Scan this URL with your mobile device to download BUDDY"
            fi
        else
            echo "❌ File not found: $apk_file"
        fi
        ;;
        
    3)
        echo "🔧 Setting up Android development environment..."
        
        # Install Flutter
        if ! command -v flutter > /dev/null; then
            echo "📥 Installing Flutter..."
            cd /tmp
            wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
            tar xf flutter_linux_3.16.0-stable.tar.xz
            echo "export PATH=\"\$PATH:/tmp/flutter/bin\"" >> ~/.bashrc
            export PATH="$PATH:/tmp/flutter/bin"
        fi
        
        # Check Flutter
        flutter doctor
        
        echo "✅ Android development environment setup complete!"
        echo "📋 Next steps:"
        echo "   1. Install Android Studio"
        echo "   2. Setup Android SDK"
        echo "   3. Create virtual device or connect physical device"
        echo "   4. Run: flutter run"
        ;;
        
    4)
        if [ "$IOS_AVAILABLE" = true ]; then
            echo "🍎 Setting up iOS development environment..."
            
            # Check Xcode
            if ! command -v xcodebuild > /dev/null; then
                echo "❌ Xcode not found. Please install Xcode from App Store"
                exit 1
            fi
            
            # Install CocoaPods
            if ! command -v pod > /dev/null; then
                echo "📥 Installing CocoaPods..."
                sudo gem install cocoapods
            fi
            
            echo "✅ iOS development environment ready!"
            echo "📋 Next steps:"
            echo "   1. Connect iOS device or use iOS Simulator"
            echo "   2. Run: flutter run"
        else
            echo "❌ iOS development requires macOS"
        fi
        ;;
        
    5)
        if [ "$IOS_AVAILABLE" = true ]; then
            echo "🍎 Building and installing iOS app..."
            
            if [ -d "../apps/mobile" ]; then
                cd ../apps/mobile
                flutter build ios --release
                
                echo "📱 Opening Xcode for deployment..."
                open ios/Runner.xcworkspace
                
                echo "📋 Manual steps in Xcode:"
                echo "   1. Select your development team"
                echo "   2. Connect your iOS device"
                echo "   3. Build and run (Cmd+R)"
            else
                echo "❌ Mobile app source not found"
            fi
        else
            echo "❌ iOS builds require macOS"
        fi
        ;;
        
    *)
        echo "❌ Invalid option"
        ;;
esac
EOF

    chmod +x "$OUTPUT_DIR/install-mobile.sh"
    
    echo "✅ Mobile installer script created: $OUTPUT_DIR/install-mobile.sh"
}

# Main execution
echo "Select build target:"
echo "1) Android APK"
echo "2) iOS IPA (macOS only)"
echo "3) Both platforms"
echo "4) Create installer script only"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        build_android
        create_mobile_installer
        ;;
    2)
        build_ios
        create_mobile_installer
        ;;
    3)
        build_android
        build_ios
        create_mobile_installer
        ;;
    4)
        create_mobile_installer
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🎉 Mobile app build complete!"
echo "📁 Output directory: $OUTPUT_DIR/"
echo ""
echo "📱 Installation options:"
echo "  • Direct install: Use install-mobile.sh script"
echo "  • Sideload: Transfer APK to device and install"
echo "  • App Store: Submit IPA through App Store Connect"
echo "  • Enterprise: Distribute via MDM or direct download"