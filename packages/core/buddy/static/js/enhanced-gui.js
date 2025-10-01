// Enhanced Mobile-Optimized BUDDY GUI functionality

// Base BuddyGUI class
class BuddyGUI {
    constructor() {
        this.setupEventListeners();
    }

    setupEventListeners() {
        // Basic event listeners
        const voiceBtn = document.getElementById('voiceBtn');
        if (voiceBtn) {
            voiceBtn.addEventListener('click', () => this.toggleVoice());
        }

        const chatForm = document.getElementById('chatForm');
        if (chatForm) {
            chatForm.addEventListener('submit', (e) => this.handleSubmit(e));
        }
    }

    toggleVoice() {
        // Basic voice toggle functionality
        console.log('Voice toggle');
    }

    handleSubmit(e) {
        e.preventDefault();
        const input = document.getElementById('messageInput');
        if (input && input.value.trim()) {
            this.sendMessage(input.value.trim());
            input.value = '';
        }
    }

    sendMessage(message) {
        this.addMessage('user', message);
        // Send to backend (to be implemented)
    }

    addMessage(sender, content) {
        const messagesContainer = document.getElementById('messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${sender}`;
        messageDiv.innerHTML = `<div class="message-content">${content}</div>`;
        messagesContainer.appendChild(messageDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
}

class BuddyGUIEnhanced extends BuddyGUI {
    constructor() {
        super();
        this.setupMobileOptimizations();
        this.setupNotifications();
        this.setupKeyboardShortcuts();
        this.setupTouchGestures();
        this.setupOfflineDetection();
        this.setupPerformanceOptimizations();
        this.setupAccessibility();
        this.setupThemeManager();
        this.setupAdvancedFeatures();
        
        // Initialize properties
        this.isRecording = false;
        this.mediaRecorder = null;
        this.audioChunks = [];
        this.websocket = null;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.notifications = [];
    }

    setupMobileOptimizations() {
        // Detect mobile device
        this.isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        this.isTablet = /iPad|Android(?=.*Tablet)|(?=.*\bTablet\b)/i.test(navigator.userAgent);
        
        // Optimize viewport for mobile
        if (this.isMobile) {
            const viewport = document.querySelector('meta[name="viewport"]');
            if (viewport) {
                viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            }
        }

        // Add mobile-specific styles
        const style = document.createElement('style');
        style.textContent = `
            @media (max-width: 768px) {
                .mobile-toolbar { display: flex !important; }
                .desktop-only { display: none !important; }
                
                /* Enhanced touch targets */
                .btn, button, input, select, textarea {
                    min-height: 44px;
                    min-width: 44px;
                }
                
                /* Improved text readability */
                body {
                    font-size: 16px;
                    line-height: 1.6;
                }
                
                /* Better spacing for touch */
                .control-panel, .status-bar {
                    padding: 12px;
                }
            }

            /* Voice recording animation */
            .btn.recording {
                background: #e74c3c !important;
                animation: pulse 1s infinite !important;
            }
            
            @keyframes pulse {
                0% { box-shadow: 0 0 0 0 rgba(231, 76, 60, 0.7); }
                70% { box-shadow: 0 0 0 10px rgba(231, 76, 60, 0); }
                100% { box-shadow: 0 0 0 0 rgba(231, 76, 60, 0); }
            }
        `;
        document.head.appendChild(style);
    }

    setupNotifications() {
        // Create notification container
        const container = document.createElement('div');
        container.id = 'notificationContainer';
        container.className = 'notification-container';
        document.body.appendChild(container);

        // Add styles
        const style = document.createElement('style');
        style.textContent = `
            .notification-container {
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 10000;
                max-width: 300px;
            }
            
            .notification {
                background: #333;
                color: white;
                padding: 12px 16px;
                margin-bottom: 8px;
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                animation: slideIn 0.3s ease-out;
                position: relative;
            }
            
            .notification.success { background: #4caf50; }
            .notification.error { background: #f44336; }
            .notification.warning { background: #ff9800; }
            
            @keyframes slideIn {
                from { transform: translateX(100%); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
        `;
        document.head.appendChild(style);
    }

    showNotification(message, type = 'info', duration = 3000) {
        const container = document.getElementById('notificationContainer');
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        container.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, duration);
    }

    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + Enter to send message
            if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                const form = document.getElementById('chatForm');
                if (form) form.dispatchEvent(new Event('submit'));
            }
            
            // Space to toggle voice (when input not focused)
            if (e.code === 'Space' && !e.target.matches('input, textarea')) {
                e.preventDefault();
                this.toggleVoice();
            }
        });
    }

    setupTouchGestures() {
        if (!this.isMobile) return;

        let touchStartY = 0;
        let touchStartTime = 0;

        // Swipe to refresh messages
        const messagesContainer = document.getElementById('messages');
        if (messagesContainer) {
            messagesContainer.addEventListener('touchstart', (e) => {
                touchStartY = e.touches[0].clientY;
                touchStartTime = Date.now();
            });

            messagesContainer.addEventListener('touchend', (e) => {
                const touchEndY = e.changedTouches[0].clientY;
                const touchEndTime = Date.now();
                const deltaY = touchEndY - touchStartY;
                const deltaTime = touchEndTime - touchStartTime;

                // Swipe down at top to refresh
                if (deltaY > 100 && deltaTime < 300 && messagesContainer.scrollTop === 0) {
                    this.refreshMessages();
                }
            });
        }

        // Long press for voice input
        let longPressTimer;
        const voiceBtn = document.getElementById('voiceBtn');
        if (voiceBtn) {
            voiceBtn.addEventListener('touchstart', (e) => {
                longPressTimer = setTimeout(() => {
                    navigator.vibrate && navigator.vibrate(50);
                    this.startVoiceRecording();
                }, 500);
            });

            voiceBtn.addEventListener('touchend', () => {
                clearTimeout(longPressTimer);
                if (this.isRecording) {
                    this.stopVoiceRecording();
                }
            });
        }
    }

    setupOfflineDetection() {
        window.addEventListener('online', () => {
            this.showNotification('Connection restored', 'success');
            this.updateConnectionStatus('connected');
            this.reconnectWebSocket();
        });

        window.addEventListener('offline', () => {
            this.showNotification('Connection lost', 'warning');
            this.updateConnectionStatus('disconnected');
        });

        // Update initial status
        this.updateConnectionStatus(navigator.onLine ? 'connected' : 'disconnected');
    }

    setupPerformanceOptimizations() {
        // Throttle scroll events
        let scrollTimer;
        const messagesContainer = document.getElementById('messages');
        if (messagesContainer) {
            messagesContainer.addEventListener('scroll', () => {
                clearTimeout(scrollTimer);
                scrollTimer = setTimeout(() => {
                    this.checkAutoScroll();
                }, 100);
            });
        }

        // Optimize images
        const images = document.querySelectorAll('img');
        images.forEach(img => {
            img.loading = 'lazy';
        });

        // Monitor performance
        if ('performance' in window) {
            window.addEventListener('load', () => {
                setTimeout(() => {
                    const perfData = performance.getEntriesByType('navigation')[0];
                    if (perfData.loadEventEnd - perfData.loadEventStart > 3000) {
                        console.warn('Slow page load detected');
                    }
                }, 0);
            });
        }
    }

    setupAccessibility() {
        // Add ARIA labels
        const elements = [
            { id: 'voiceBtn', label: 'Start voice input' },
            { id: 'messageInput', label: 'Type your message' },
            { id: 'sendBtn', label: 'Send message' },
            { id: 'messages', label: 'Conversation history' }
        ];

        elements.forEach(({ id, label }) => {
            const element = document.getElementById(id);
            if (element && !element.getAttribute('aria-label')) {
                element.setAttribute('aria-label', label);
            }
        });

        // Focus management
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Tab') {
                document.body.classList.add('keyboard-navigation');
            }
        });

        document.addEventListener('mousedown', () => {
            document.body.classList.remove('keyboard-navigation');
        });

        // Add skip link
        const skipLink = document.createElement('a');
        skipLink.href = '#messages';
        skipLink.textContent = 'Skip to messages';
        skipLink.className = 'skip-link';
        skipLink.style.cssText = `
            position: absolute;
            top: -40px;
            left: 6px;
            background: #000;
            color: #fff;
            padding: 8px;
            text-decoration: none;
            z-index: 1000;
            border-radius: 4px;
        `;
        skipLink.addEventListener('focus', () => {
            skipLink.style.top = '6px';
        });
        skipLink.addEventListener('blur', () => {
            skipLink.style.top = '-40px';
        });
        document.body.insertBefore(skipLink, document.body.firstChild);
    }

    // Enhanced message sending with retry logic
    async sendMessage(message) {
        if (!message.trim()) return;

        this.addMessage('user', message);
        this.showTypingIndicator();

        const maxRetries = 3;
        let retries = 0;

        while (retries < maxRetries) {
            try {
                const response = await fetch('/api/v1/voice/text', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ text: message })
                });

                if (response.ok) {
                    const data = await response.json();
                    this.hideTypingIndicator();
                    this.addMessage('buddy', data.response || 'No response received');
                    this.saveConversation();
                    return;
                } else {
                    throw new Error(`HTTP ${response.status}`);
                }
            } catch (error) {
                retries++;
                if (retries < maxRetries) {
                    await new Promise(resolve => setTimeout(resolve, 1000 * retries));
                    continue;
                }
                
                console.error('Error sending message:', error);
                this.hideTypingIndicator();
                this.addMessage('buddy', '❌ Sorry, I couldn\'t process your message right now. Please try again.');
                this.showNotification('Failed to send message', 'error');
                return;
            }
        }
    }

    showTypingIndicator() {
        const existing = document.querySelector('.typing-indicator');
        if (existing) return;

        const indicator = document.createElement('div');
        indicator.className = 'message buddy typing-indicator';
        indicator.innerHTML = `
            <div class="message-content">
                <div class="typing-dots">
                    <span></span>
                    <span></span>
                    <span></span>
                </div>
            </div>
        `;

        const messagesContainer = document.getElementById('messages');
        messagesContainer.appendChild(indicator);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;

        // Add typing animation styles
        if (!document.getElementById('typingStyles')) {
            const style = document.createElement('style');
            style.id = 'typingStyles';
            style.textContent = `
                .typing-dots {
                    display: flex;
                    gap: 4px;
                    align-items: center;
                }
                
                .typing-dots span {
                    width: 8px;
                    height: 8px;
                    background: #666;
                    border-radius: 50%;
                    animation: typing 1.4s infinite ease-in-out;
                }
                
                .typing-dots span:nth-child(1) { animation-delay: -0.32s; }
                .typing-dots span:nth-child(2) { animation-delay: -0.16s; }
                
                @keyframes typing {
                    0%, 80%, 100% { transform: scale(0.8); opacity: 0.5; }
                    40% { transform: scale(1); opacity: 1; }
                }
            `;
            document.head.appendChild(style);
        }
    }

    hideTypingIndicator() {
        const indicator = document.querySelector('.typing-indicator');
        if (indicator) {
            indicator.remove();
        }
    }

    // Enhanced voice recording with better error handling
    async setupVoiceRecognition() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ 
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });
            
            this.mediaRecorder = new MediaRecorder(stream, {
                mimeType: 'audio/webm;codecs=opus'
            });
            
            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this.audioChunks.push(event.data);
                }
            };
            
            this.mediaRecorder.onstop = () => {
                this.processAudioRecording();
            };
            
            return true;
        } catch (error) {
            console.error('Voice setup failed:', error);
            this.showNotification('Voice access denied', 'error');
            return false;
        }
    }

    async toggleVoice() {
        if (this.isRecording) {
            this.stopVoiceRecording();
        } else {
            await this.startVoiceRecording();
        }
    }

    async startVoiceRecording() {
        if (!this.mediaRecorder) {
            const success = await this.setupVoiceRecognition();
            if (!success) return;
        }

        this.audioChunks = [];
        this.mediaRecorder.start();
        this.isRecording = true;
        
        const voiceBtn = document.getElementById('voiceBtn');
        if (voiceBtn) {
            voiceBtn.classList.add('recording');
            voiceBtn.innerHTML = '⏹️';
        }
        
        this.showVoiceProcessing();
        this.showNotification('Recording...', 'info', 1000);
    }

    stopVoiceRecording() {
        if (this.mediaRecorder && this.isRecording) {
            this.mediaRecorder.stop();
            this.isRecording = false;
            
            const voiceBtn = document.getElementById('voiceBtn');
            if (voiceBtn) {
                voiceBtn.classList.remove('recording');
                voiceBtn.innerHTML = '🎤';
            }
            
            this.hideVoiceIndicator();
        }
    }

    async processAudioRecording() {
        try {
            const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
            const formData = new FormData();
            formData.append('audio', audioBlob);

            const response = await fetch('/api/v1/voice/transcribe', {
                method: 'POST',
                body: formData
            });

            if (response.ok) {
                const data = await response.json();
                if (data.text) {
                    const messageInput = document.getElementById('messageInput');
                    if (messageInput) {
                        messageInput.value = data.text;
                        messageInput.focus();
                    }
                    this.showNotification('Voice transcribed', 'success');
                }
            }
        } catch (error) {
            console.error('Voice processing failed:', error);
            this.showNotification('Voice processing failed', 'error');
        }
    }

    // WebSocket connection with auto-reconnect
    connectWebSocket() {
        try {
            this.websocket = new WebSocket(`ws://${window.location.host}/ws/voice`);
            
            this.websocket.onopen = () => {
                console.log('WebSocket connected');
                this.updateConnectionStatus('connected');
                this.reconnectAttempts = 0;
            };
            
            this.websocket.onmessage = (event) => {
                const data = JSON.parse(event.data);
                if (data.type === 'response') {
                    this.addMessage('buddy', data.content);
                }
            };
            
            this.websocket.onclose = () => {
                console.log('WebSocket disconnected');
                this.updateConnectionStatus('disconnected');
                this.attemptReconnect();
            };
            
            this.websocket.onerror = (error) => {
                console.error('WebSocket error:', error);
                this.updateConnectionStatus('error');
            };
        } catch (error) {
            console.error('WebSocket connection failed:', error);
            this.updateConnectionStatus('error');
        }
    }

    attemptReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            this.updateConnectionStatus('connecting');
            
            setTimeout(() => {
                this.connectWebSocket();
            }, 1000 * this.reconnectAttempts);
        }
    }

    reconnectWebSocket() {
        this.reconnectAttempts = 0;
        this.connectWebSocket();
    }

    // Skills management
    async loadSkills() {
        const skillsList = document.getElementById('skillsList');
        if (!skillsList) return;
        
        // Show loading state
        skillsList.innerHTML = '<div class="skills-loading">Loading skills...</div>';
        
        try {
            // Check cache first
            const cachedSkills = localStorage.getItem('buddySkills');
            const cacheTime = localStorage.getItem('buddySkillsTime');
            
            if (cachedSkills && cacheTime && (Date.now() - parseInt(cacheTime)) < 300000) {
                // Use cached skills if less than 5 minutes old
                this.displaySkills(JSON.parse(cachedSkills));
                return;
            }
            
            const response = await fetch('/api/v1/skills');
            if (response.ok) {
                const skills = await response.json();
                
                // Cache the skills
                localStorage.setItem('buddySkills', JSON.stringify(skills));
                localStorage.setItem('buddySkillsTime', Date.now().toString());
                
                this.displaySkills(skills);
            } else {
                throw new Error(`HTTP ${response.status}`);
            }
        } catch (error) {
            console.error('Error loading skills:', error);
            skillsList.innerHTML = '<div class="skill-item">❌ Failed to load skills</div>';
            this.showNotification('Failed to load skills', 'error');
        }
    }

    displaySkills(skills) {
        const skillsList = document.getElementById('skillsList');
        if (!skillsList) return;

        skillsList.innerHTML = skills.map(skill => `
            <div class="skill-item" data-skill="${skill.name}">
                <div class="skill-icon">${skill.icon || '🔧'}</div>
                <div class="skill-info">
                    <div class="skill-name">${skill.name}</div>
                    <div class="skill-description">${skill.description}</div>
                </div>
                <div class="skill-status ${skill.enabled ? 'enabled' : 'disabled'}">
                    ${skill.enabled ? '✅' : '❌'}
                </div>
            </div>
        `).join('');
    }

    refreshMessages() {
        this.showNotification('Refreshing...', 'info', 1000);
        // Add refresh logic here
    }

    checkAutoScroll() {
        const messagesContainer = document.getElementById('messages');
        if (!messagesContainer) return;

        const isAtBottom = messagesContainer.scrollTop + messagesContainer.clientHeight >= 
                          messagesContainer.scrollHeight - 10;
        
        if (isAtBottom) {
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
    }

    // Enhanced message display with formatting
    addMessage(sender, content) {
        const messagesContainer = document.getElementById('messages');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${sender}`;
        
        const now = new Date();
        const timeStr = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        
        // Format content with basic markdown support
        const formattedContent = this.formatMessage(content);
        
        messageDiv.innerHTML = `
            <div class="message-header">${sender === 'user' ? 'You' : 'BUDDY'} • ${timeStr}</div>
            <div class="message-content">${formattedContent}</div>
        `;
        
        messagesContainer.appendChild(messageDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
        
        // Save conversation after adding message
        this.saveConversation();
    }

    formatMessage(content) {
        // Enhanced markdown formatting with more features
        return content
            // Code blocks
            .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
            // Inline code
            .replace(/`([^`]+)`/g, '<code class="inline-code">$1</code>')
            // Bold text
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            // Italic text
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            // Links
            .replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
            // Bullet points
            .replace(/^[\s]*\*[\s]+(.+)$/gm, '<li>$1</li>')
            .replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>')
            // Numbered lists
            .replace(/^[\s]*\d+\.[\s]+(.+)$/gm, '<li>$1</li>')
            .replace(/(<li>.*<\/li>)/s, '<ol>$1</ol>')
            // Line breaks
            .replace(/\n/g, '<br>');
    }

    // Save conversation history
    saveConversation() {
        const messages = Array.from(document.querySelectorAll('.message:not(.typing-indicator)')).map(msg => ({
            sender: msg.classList.contains('user') ? 'user' : 'buddy',
            content: msg.querySelector('.message-content').textContent,
            time: msg.querySelector('.message-header') ? msg.querySelector('.message-header').textContent : ''
        }));
        
        localStorage.setItem('buddyConversation', JSON.stringify(messages));
    }

    // Load conversation history
    loadConversation() {
        const saved = localStorage.getItem('buddyConversation');
        if (saved) {
            const messages = JSON.parse(saved);
            const messagesContainer = document.getElementById('messages');
            messagesContainer.innerHTML = '';
            
            messages.forEach(msg => {
                this.addMessage(msg.sender, msg.content);
            });
        }
    }

    // Connection status management
    updateConnectionStatus(status) {
        const indicator = document.getElementById('connectionStatus');
        if (!indicator) return;

        indicator.className = `connection-status ${status}`;
        indicator.textContent = status === 'connected' ? '●' : 
                               status === 'connecting' ? '○' : '×';
        
        const label = indicator.nextElementSibling;
        if (label) {
            label.textContent = status === 'connected' ? 'Connected' :
                               status === 'connecting' ? 'Connecting...' : 'Disconnected';
        }
    }

    // Voice response indicators
    showVoiceProcessing() {
        const indicator = document.getElementById('voiceIndicator');
        if (indicator) {
            indicator.className = 'voice-indicator processing';
            indicator.innerHTML = '🎤 Processing...';
        }
    }

    showVoiceResponse() {
        const indicator = document.getElementById('voiceIndicator');
        if (indicator) {
            indicator.className = 'voice-indicator responding';
            indicator.innerHTML = '🔊 Speaking...';
        }
    }

    hideVoiceIndicator() {
        const indicator = document.getElementById('voiceIndicator');
        if (indicator) {
            indicator.className = 'voice-indicator';
            indicator.innerHTML = '';
        }
    }

    // Theme Management System
    setupThemeManager() {
        // Load saved theme
        this.currentTheme = localStorage.getItem('buddyTheme') || 'auto';
        this.applyTheme(this.currentTheme);

        // Add theme styles
        const style = document.createElement('style');
        style.id = 'themeStyles';
        style.textContent = `
            [data-theme="light"] {
                --bg-primary: #ffffff;
                --bg-secondary: #f8f9fa;
                --text-primary: #212529;
                --text-secondary: #6c757d;
                --border-color: #dee2e6;
                --accent-color: #007bff;
                --message-user-bg: #e3f2fd;
                --message-buddy-bg: #f3e5f5;
            }

            [data-theme="dark"] {
                --bg-primary: #1a1a1a;
                --bg-secondary: #2d2d2d;
                --text-primary: #ffffff;
                --text-secondary: #b0b0b0;
                --border-color: #404040;
                --accent-color: #4dabf7;
                --message-user-bg: #1e3a8a;
                --message-buddy-bg: #581c87;
            }

            [data-theme="auto"] {
                --bg-primary: #ffffff;
                --bg-secondary: #f8f9fa;
                --text-primary: #212529;
                --text-secondary: #6c757d;
                --border-color: #dee2e6;
                --accent-color: #007bff;
                --message-user-bg: #e3f2fd;
                --message-buddy-bg: #f3e5f5;
            }

            @media (prefers-color-scheme: dark) {
                [data-theme="auto"] {
                    --bg-primary: #1a1a1a;
                    --bg-secondary: #2d2d2d;
                    --text-primary: #ffffff;
                    --text-secondary: #b0b0b0;
                    --border-color: #404040;
                    --accent-color: #4dabf7;
                    --message-user-bg: #1e3a8a;
                    --message-buddy-bg: #581c87;
                }
            }

            body {
                background-color: var(--bg-primary);
                color: var(--text-primary);
                transition: background-color 0.3s ease, color 0.3s ease;
            }

            .message.user {
                background-color: var(--message-user-bg);
            }

            .message.buddy {
                background-color: var(--message-buddy-bg);
            }

            .inline-code {
                background-color: var(--bg-secondary);
                padding: 2px 4px;
                border-radius: 3px;
                font-family: 'Courier New', monospace;
                font-size: 0.9em;
            }

            pre code {
                background-color: var(--bg-secondary);
                border: 1px solid var(--border-color);
                border-radius: 8px;
                padding: 12px;
                display: block;
                overflow-x: auto;
                font-family: 'Courier New', monospace;
                white-space: pre-wrap;
            }
        `;
        document.head.appendChild(style);
    }

    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        this.currentTheme = theme;
        localStorage.setItem('buddyTheme', theme);
    }

    toggleTheme() {
        const themes = ['auto', 'light', 'dark'];
        const currentIndex = themes.indexOf(this.currentTheme);
        const nextTheme = themes[(currentIndex + 1) % themes.length];
        this.applyTheme(nextTheme);
        this.showNotification(`Theme changed to ${nextTheme}`, 'success');
    }

    // Advanced Features Setup
    setupAdvancedFeatures() {
        this.setupCommandPalette();
        this.setupQuickActions();
        this.setupAdvancedSearch();
        this.setupAIPersonality();
    }

    // Command Palette System
    setupCommandPalette() {
        // Add command palette HTML
        const commandPalette = document.createElement('div');
        commandPalette.id = 'commandPalette';
        commandPalette.className = 'command-palette hidden';
        commandPalette.innerHTML = `
            <div class="command-palette-overlay" onclick="this.parentElement.classList.add('hidden')"></div>
            <div class="command-palette-content">
                <input type="text" id="commandInput" placeholder="Type a command..." autocomplete="off">
                <div id="commandResults" class="command-results"></div>
            </div>
        `;
        document.body.appendChild(commandPalette);

        // Add command palette styles
        const style = document.createElement('style');
        style.textContent = `
            .command-palette {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                z-index: 10001;
                display: flex;
                align-items: flex-start;
                justify-content: center;
                padding-top: 10vh;
            }

            .command-palette.hidden {
                display: none;
            }

            .command-palette-overlay {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.5);
                backdrop-filter: blur(4px);
            }

            .command-palette-content {
                background: var(--bg-primary);
                border: 1px solid var(--border-color);
                border-radius: 12px;
                width: 90%;
                max-width: 600px;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
                position: relative;
                overflow: hidden;
            }

            #commandInput {
                width: 100%;
                padding: 16px 20px;
                border: none;
                background: transparent;
                font-size: 16px;
                color: var(--text-primary);
                outline: none;
                border-bottom: 1px solid var(--border-color);
            }

            .command-results {
                max-height: 300px;
                overflow-y: auto;
            }

            .command-item {
                padding: 12px 20px;
                cursor: pointer;
                border-bottom: 1px solid var(--border-color);
                display: flex;
                align-items: center;
                gap: 12px;
            }

            .command-item:hover, .command-item.selected {
                background: var(--bg-secondary);
            }

            .command-icon {
                font-size: 18px;
                width: 24px;
                text-align: center;
            }

            .command-info {
                flex: 1;
            }

            .command-name {
                font-weight: 500;
                margin-bottom: 2px;
            }

            .command-description {
                font-size: 14px;
                color: var(--text-secondary);
            }

            .command-shortcut {
                font-size: 12px;
                background: var(--bg-secondary);
                padding: 2px 6px;
                border-radius: 4px;
                color: var(--text-secondary);
            }
        `;
        document.head.appendChild(style);

        // Setup command palette functionality
        this.commands = [
            { name: 'Toggle Theme', description: 'Switch between light, dark, and auto themes', icon: '🎨', action: () => this.toggleTheme(), shortcut: 'Ctrl+T' },
            { name: 'Clear Conversation', description: 'Clear all messages from current conversation', icon: '🗑️', action: () => clearConversation(), shortcut: 'Ctrl+K' },
            { name: 'Export Chat', description: 'Export conversation in text format', icon: '📄', action: () => exportConversation(), shortcut: 'Ctrl+E' },
            { name: 'Toggle Voice', description: 'Start or stop voice recording', icon: '🎤', action: () => this.toggleVoice(), shortcut: 'Space' },
            { name: 'Focus Input', description: 'Focus on message input field', icon: '✏️', action: () => document.getElementById('messageInput')?.focus(), shortcut: 'Ctrl+I' },
            { name: 'Reload Skills', description: 'Refresh the skills list', icon: '🔄', action: () => this.loadSkills(), shortcut: 'Ctrl+R' },
            { name: 'Show Help', description: 'Display keyboard shortcuts and help', icon: '❓', action: () => this.showHelp(), shortcut: 'Ctrl+?' }
        ];

        // Command palette keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            // Ctrl+P to open command palette
            if ((e.ctrlKey || e.metaKey) && e.key === 'p') {
                e.preventDefault();
                this.openCommandPalette();
            }
            
            // Additional shortcuts
            if ((e.ctrlKey || e.metaKey) && e.key === 't') {
                e.preventDefault();
                this.toggleTheme();
            }
            
            if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                e.preventDefault();
                clearConversation();
            }
        });

        // Command input handling
        const commandInput = document.getElementById('commandInput');
        if (commandInput) {
            commandInput.addEventListener('input', (e) => this.filterCommands(e.target.value));
            commandInput.addEventListener('keydown', (e) => this.handleCommandKeyboard(e));
        }
    }

    openCommandPalette() {
        const palette = document.getElementById('commandPalette');
        const input = document.getElementById('commandInput');
        
        palette.classList.remove('hidden');
        input.value = '';
        input.focus();
        this.filterCommands('');
    }

    filterCommands(query) {
        const results = document.getElementById('commandResults');
        const filtered = this.commands.filter(cmd => 
            cmd.name.toLowerCase().includes(query.toLowerCase()) ||
            cmd.description.toLowerCase().includes(query.toLowerCase())
        );

        results.innerHTML = filtered.map((cmd, index) => `
            <div class="command-item ${index === 0 ? 'selected' : ''}" data-index="${index}" onclick="this.parentElement.parentElement.parentElement.parentElement.classList.add('hidden'); window.buddyGUI.commands[${this.commands.indexOf(cmd)}].action()">
                <div class="command-icon">${cmd.icon}</div>
                <div class="command-info">
                    <div class="command-name">${cmd.name}</div>
                    <div class="command-description">${cmd.description}</div>
                </div>
                <div class="command-shortcut">${cmd.shortcut}</div>
            </div>
        `).join('');
    }

    handleCommandKeyboard(e) {
        const results = document.getElementById('commandResults');
        const items = results.querySelectorAll('.command-item');
        const selected = results.querySelector('.command-item.selected');
        
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            const next = selected?.nextElementSibling || items[0];
            selected?.classList.remove('selected');
            next?.classList.add('selected');
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            const prev = selected?.previousElementSibling || items[items.length - 1];
            selected?.classList.remove('selected');
            prev?.classList.add('selected');
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (selected) {
                const index = parseInt(selected.dataset.index);
                const filteredCommands = this.commands.filter(cmd => 
                    cmd.name.toLowerCase().includes(e.target.value.toLowerCase()) ||
                    cmd.description.toLowerCase().includes(e.target.value.toLowerCase())
                );
                filteredCommands[index]?.action();
                document.getElementById('commandPalette').classList.add('hidden');
            }
        } else if (e.key === 'Escape') {
            document.getElementById('commandPalette').classList.add('hidden');
        }
    }

    // Quick Actions Setup
    setupQuickActions() {
        // Add quick action buttons to mobile toolbar
        const toolbar = document.querySelector('.mobile-toolbar');
        if (toolbar) {
            const quickActions = document.createElement('div');
            quickActions.className = 'quick-actions';
            quickActions.innerHTML = `
                <button class="quick-action-btn" onclick="window.buddyGUI.toggleTheme()" title="Toggle Theme">🎨</button>
                <button class="quick-action-btn" onclick="window.buddyGUI.openCommandPalette()" title="Command Palette">⚡</button>
                <button class="quick-action-btn" onclick="exportConversation()" title="Export Chat">📄</button>
            `;
            toolbar.appendChild(quickActions);

            // Add quick actions styles
            const style = document.createElement('style');
            style.textContent = `
                .quick-actions {
                    display: flex;
                    gap: 8px;
                    margin-left: auto;
                }

                .quick-action-btn {
                    background: none;
                    border: none;
                    font-size: 18px;
                    padding: 8px;
                    border-radius: 6px;
                    cursor: pointer;
                    transition: background-color 0.2s ease;
                }

                .quick-action-btn:hover {
                    background: var(--bg-secondary);
                }
            `;
            document.head.appendChild(style);
        }
    }

    // Advanced Search Functionality
    setupAdvancedSearch() {
        this.searchHistory = JSON.parse(localStorage.getItem('buddySearchHistory') || '[]');
    }

    searchConversation(query) {
        const messages = document.querySelectorAll('.message:not(.typing-indicator)');
        const results = [];
        
        messages.forEach((msg, index) => {
            const content = msg.querySelector('.message-content').textContent.toLowerCase();
            if (content.includes(query.toLowerCase())) {
                results.push({
                    index,
                    element: msg,
                    content: content.substring(0, 100) + '...',
                    sender: msg.classList.contains('user') ? 'You' : 'BUDDY'
                });
            }
        });

        this.highlightSearchResults(results, query);
        return results;
    }

    highlightSearchResults(results, query) {
        // Remove previous highlights
        document.querySelectorAll('.search-highlight').forEach(el => {
            el.classList.remove('search-highlight');
        });

        // Add highlights to results
        results.forEach(result => {
            result.element.classList.add('search-highlight');
        });

        // Add search highlight styles
        if (!document.getElementById('searchStyles')) {
            const style = document.createElement('style');
            style.id = 'searchStyles';
            style.textContent = `
                .search-highlight {
                    border: 2px solid var(--accent-color) !important;
                    box-shadow: 0 0 10px rgba(0, 123, 255, 0.3) !important;
                }
            `;
            document.head.appendChild(style);
        }
    }

    // AI Personality Configuration
    setupAIPersonality() {
        this.personality = localStorage.getItem('buddyPersonality') || 'friendly';
        this.personalitySettings = {
            friendly: { emoji: '😊', greeting: 'Hello! I\'m here to help you with anything you need!' },
            professional: { emoji: '💼', greeting: 'Good day. How may I assist you today?' },
            casual: { emoji: '😎', greeting: 'Hey there! What\'s up?' },
            enthusiastic: { emoji: '🚀', greeting: 'Hi! I\'m super excited to help you today!' }
        };
    }

    setPersonality(personality) {
        this.personality = personality;
        localStorage.setItem('buddyPersonality', personality);
        this.showNotification(`Personality changed to ${personality}`, 'success');
    }

    // Help System
    showHelp() {
        const helpContent = `
            <h3>🎯 BUDDY Keyboard Shortcuts</h3>
            <ul>
                <li><kbd>Ctrl+P</kbd> - Open Command Palette</li>
                <li><kbd>Ctrl+T</kbd> - Toggle Theme</li>
                <li><kbd>Ctrl+K</kbd> - Clear Conversation</li>
                <li><kbd>Ctrl+E</kbd> - Export Chat</li>
                <li><kbd>Ctrl+Enter</kbd> - Send Message</li>
                <li><kbd>Space</kbd> - Toggle Voice (when not typing)</li>
                <li><kbd>Ctrl+I</kbd> - Focus Input</li>
                <li><kbd>Ctrl+R</kbd> - Reload Skills</li>
            </ul>
            
            <h3>🎨 Themes</h3>
            <p>Choose from Auto, Light, or Dark themes. Auto theme follows your system preference.</p>
            
            <h3>🎤 Voice Features</h3>
            <p>Click the microphone button or use Space key to record voice messages. Long-press on mobile for voice input.</p>
            
            <h3>📱 Mobile Features</h3>
            <p>Swipe down to refresh messages. Use the mobile toolbar for quick actions.</p>
        `;

        this.addMessage('buddy', helpContent);
    }
}

// Additional utility functions
function exportConversation() {
    if (window.buddyGUI) {
        const messages = Array.from(document.querySelectorAll('.message:not(.typing-indicator)')).map(msg => {
            const sender = msg.classList.contains('user') ? 'You' : 'BUDDY';
            const content = msg.querySelector('.message-content').textContent;
            const time = msg.querySelector('.message-header') ? msg.querySelector('.message-header').textContent : '';
            return `${time}\n${sender}: ${content}\n`;
        }).join('\n');
        
        const blob = new Blob([messages], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `buddy-conversation-${new Date().toISOString().split('T')[0]}.txt`;
        a.click();
        URL.revokeObjectURL(url);
    }
}

function clearConversation() {
    if (confirm('Clear all messages?')) {
        document.getElementById('messages').innerHTML = '';
        localStorage.removeItem('buddyConversation');
        
        // Add welcome message back
        if (window.buddyGUI) {
            window.buddyGUI.addMessage('buddy', 
                'Hello! I\'m BUDDY, your personal AI assistant. How can I help you today?'
            );
        }
    }
}

// Initialize enhanced GUI
document.addEventListener('DOMContentLoaded', () => {
    window.buddyGUI = new BuddyGUIEnhanced();
    
    // Load previous conversation
    window.buddyGUI.loadConversation();
    
    // Save conversation periodically
    setInterval(() => {
        window.buddyGUI.saveConversation();
    }, 30000);
    
    // Save conversation before page unload
    window.addEventListener('beforeunload', () => {
        window.buddyGUI.saveConversation();
    });
    
    // Connect WebSocket
    window.buddyGUI.connectWebSocket();
    
    // Load skills
    window.buddyGUI.loadSkills();
});