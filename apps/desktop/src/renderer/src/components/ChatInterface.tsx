import React, { useEffect, useRef, useState } from 'react';

interface Message {
  id: string;
  sender: 'user' | 'buddy';
  content: string;
  timestamp: Date;
  type?: 'text' | 'voice' | 'skill';
}

const ChatInterface: React.FC = () => {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      sender: 'buddy',
      content: 'Hello! I\'m BUDDY, your personal AI assistant. I\'m here to help you with various tasks including voice commands, reminders, calculations, and much more. How can I assist you today?',
      timestamp: new Date(),
      type: 'text'
    }
  ]);
  const [inputText, setInputText] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [connected, setConnected] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  useEffect(() => {
    // Simulate connection monitoring
    const checkConnection = async () => {
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 5000);
        
        const response = await fetch('http://localhost:8000/api/health', {
          method: 'GET',
          signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        setConnected(response.ok);
      } catch (error) {
        setConnected(false);
      }
    };

    // Check connection every 30 seconds
    const interval = setInterval(checkConnection, 30000);
    
    // Initial connection check
    checkConnection();

    return () => clearInterval(interval);
  }, []);

  const handleSendMessage = async (text: string = inputText, type: 'text' | 'voice' = 'text') => {
    if (!text.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      sender: 'user',
      content: text,
      timestamp: new Date(),
      type
    };

    setMessages(prev => [...prev, userMessage]);
    setInputText('');
    setIsTyping(true);

    try {
      // Simulate API call to BUDDY backend
      const response = await fetch('http://localhost:8000/api/v1/voice/text', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text })
      });

      if (response.ok) {
        const data = await response.json();
        const buddyMessage: Message = {
          id: (Date.now() + 1).toString(),
          sender: 'buddy',
          content: data.response || 'I understand your message.',
          timestamp: new Date(),
          type: 'text'
        };
        setMessages(prev => [...prev, buddyMessage]);
      } else {
        throw new Error('API Error');
      }
    } catch (error) {
      console.error('Error sending message:', error);
      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        sender: 'buddy',
        content: '❌ Sorry, I encountered an error. Please try again.',
        timestamp: new Date(),
        type: 'text'
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsTyping(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const handleVoiceToggle = () => {
    setIsRecording(!isRecording);
    // Voice recording logic would go here
  };

  const formatTimestamp = (timestamp: Date) => {
    return timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', backgroundColor: '#f8f9fa' }}>
      {/* Chat Header */}
      <div style={{ 
        backgroundColor: 'white', 
        borderBottom: '1px solid #e9ecef', 
        padding: '16px 24px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ 
            width: '40px', 
            height: '40px', 
            backgroundColor: '#007bff', 
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '18px'
          }}>
            🤖
          </div>
          <div>
            <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600', color: '#212529' }}>BUDDY</h2>
            <p style={{ margin: 0, fontSize: '14px', color: '#6c757d' }}>
              {connected ? 'Online' : 'Offline'} • Personal AI Assistant
            </p>
          </div>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            onClick={handleVoiceToggle}
            style={{
              padding: '8px 16px',
              borderRadius: '20px',
              border: 'none',
              backgroundColor: isRecording ? '#dc3545' : '#007bff',
              color: 'white',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500',
              animation: isRecording ? 'pulse 1s infinite' : 'none'
            }}
          >
            {isRecording ? '⏹️ Stop' : '🎤 Voice'}
          </button>
        </div>
      </div>

      {/* Messages Area */}
      <div style={{ 
        flex: 1, 
        overflowY: 'auto', 
        padding: '20px', 
        display: 'flex',
        flexDirection: 'column',
        gap: '16px'
      }}>
        {messages.map((message) => (
          <div
            key={message.id}
            style={{
              display: 'flex',
              justifyContent: message.sender === 'user' ? 'flex-end' : 'flex-start'
            }}
          >
            <div
              style={{
                maxWidth: '70%',
                padding: '12px 16px',
                borderRadius: '16px',
                backgroundColor: message.sender === 'user' ? '#007bff' : 'white',
                color: message.sender === 'user' ? 'white' : '#212529',
                border: message.sender === 'buddy' ? '1px solid #e9ecef' : 'none',
                borderBottomRightRadius: message.sender === 'user' ? '4px' : '16px',
                borderBottomLeftRadius: message.sender === 'buddy' ? '4px' : '16px',
                boxShadow: message.sender === 'buddy' ? '0 2px 4px rgba(0,0,0,0.1)' : 'none'
              }}
            >
              <div style={{ 
                display: 'flex', 
                justifyContent: 'space-between', 
                alignItems: 'center',
                marginBottom: '4px',
                fontSize: '12px',
                opacity: 0.7
              }}>
                <span>{message.sender === 'user' ? 'You' : 'BUDDY'}</span>
                <span>{formatTimestamp(message.timestamp)}</span>
              </div>
              <p style={{ 
                margin: 0, 
                fontSize: '14px', 
                lineHeight: '1.4',
                whiteSpace: 'pre-wrap'
              }}>
                {message.content}
              </p>
              {message.type === 'voice' && (
                <div style={{ marginTop: '8px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span style={{ fontSize: '12px', opacity: 0.7 }}>🎤 Voice message</span>
                </div>
              )}
            </div>
          </div>
        ))}

        {/* Typing Indicator */}
        {isTyping && (
          <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
            <div style={{
              backgroundColor: 'white',
              border: '1px solid #e9ecef',
              borderRadius: '16px',
              borderBottomLeftRadius: '4px',
              padding: '12px 16px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <div style={{ display: 'flex', gap: '4px' }}>
                  {[0, 1, 2].map(i => (
                    <div
                      key={i}
                      style={{
                        width: '8px',
                        height: '8px',
                        backgroundColor: '#6c757d',
                        borderRadius: '50%',
                        animation: `bounce 1.4s infinite ${i * 0.2}s`
                      }}
                    />
                  ))}
                </div>
                <span style={{ fontSize: '12px', color: '#6c757d' }}>BUDDY is typing...</span>
              </div>
            </div>
          </div>
        )}

        {/* Voice Recording Indicator */}
        {isRecording && (
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <div style={{
              backgroundColor: '#fff5f5',
              border: '2px dashed #dc3545',
              borderRadius: '12px',
              padding: '16px 24px',
              textAlign: 'center'
            }}>
              <div style={{ 
                display: 'flex', 
                justifyContent: 'center', 
                gap: '3px',
                marginBottom: '8px'
              }}>
                {[0, 1, 2, 3, 4].map(i => (
                  <div
                    key={i}
                    style={{
                      width: '4px',
                      backgroundColor: '#dc3545',
                      borderRadius: '2px',
                      animation: `wave 1s infinite ${i * 0.1}s`,
                      height: `${Math.random() * 20 + 10}px`
                    }}
                  />
                ))}
              </div>
              <p style={{ margin: 0, fontSize: '14px', color: '#dc3545', fontWeight: '500' }}>
                🎤 Listening...
              </p>
              <p style={{ margin: '4px 0 0', fontSize: '12px', color: '#dc3545' }}>
                Speak your message to BUDDY
              </p>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input Area */}
      <div style={{ 
        backgroundColor: 'white', 
        borderTop: '1px solid #e9ecef', 
        padding: '16px' 
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{ flex: 1, position: 'relative' }}>
            <input
              ref={inputRef}
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Type your message to BUDDY..."
              style={{
                width: '100%',
                padding: '12px 48px 12px 16px',
                border: '1px solid #ced4da',
                borderRadius: '25px',
                outline: 'none',
                fontSize: '14px',
                backgroundColor: '#f8f9fa'
              }}
              disabled={!connected}
            />
            <button
              onClick={() => handleSendMessage()}
              disabled={!inputText.trim() || !connected}
              style={{
                position: 'absolute',
                right: '8px',
                top: '50%',
                transform: 'translateY(-50%)',
                padding: '8px',
                border: 'none',
                backgroundColor: 'transparent',
                color: '#007bff',
                cursor: 'pointer',
                borderRadius: '50%'
              }}
            >
              📤
            </button>
          </div>
          
          <button
            onClick={handleVoiceToggle}
            style={{
              padding: '12px',
              borderRadius: '50%',
              border: 'none',
              backgroundColor: isRecording ? '#dc3545' : '#f8f9fa',
              color: isRecording ? 'white' : '#6c757d',
              cursor: 'pointer',
              fontSize: '16px',
              animation: isRecording ? 'pulse 1s infinite' : 'none'
            }}
            disabled={!connected}
          >
            🎤
          </button>
        </div>
        
        {!connected && (
          <div style={{ marginTop: '8px', textAlign: 'center' }}>
            <span style={{ fontSize: '12px', color: '#dc3545' }}>
              ❌ Disconnected from BUDDY - Attempting to reconnect...
            </span>
          </div>
        )}
      </div>

      <style>
        {`
          @keyframes bounce {
            0%, 60%, 100% { transform: translateY(0); }
            30% { transform: translateY(-10px); }
          }
          
          @keyframes wave {
            0%, 100% { height: 20px; }
            50% { height: 40px; }
          }
          
          @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
          }
        `}
      </style>
    </div>
  );
};

export default ChatInterface;