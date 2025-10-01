import React, { useEffect, useState } from 'react';
import ChatInterface from './components/ChatInterface';
import MemoryPanel from './components/MemoryPanel';
import SettingsPanel from './components/SettingsPanel';
import SkillsPanel from './components/SkillsPanel';
import StatusBar from './components/StatusBar';
import VoiceInterface from './components/VoiceInterface';
import { AppProvider } from './context/AppContext';
import { VoiceProvider } from './context/VoiceContext';

interface AppInfo {
  version: string;
  platform: string;
  arch: string;
  backendReady: boolean;
  backendPort: number;
}

interface AppState {
  activePanel: 'chat' | 'skills' | 'memory' | 'settings';
  appInfo: AppInfo | null;
  connected: boolean;
}

const App: React.FC = () => {
  const [state, setState] = useState<AppState>({
    activePanel: 'chat',
    appInfo: null,
    connected: false
  });

  const [showVoiceConsole, setShowVoiceConsole] = useState(false);

  useEffect(() => {
    // Initialize app
    const initializeApp = async () => {
      try {
        if (window.buddyAPI) {
          const appInfo = await window.buddyAPI.getAppInfo();
          setState(prev => ({
            ...prev,
            appInfo,
            connected: appInfo.backendReady
          }));
        }
      } catch (error) {
        console.error('Failed to get app info:', error);
      }
    };

    initializeApp();

    // Setup event listeners
    if (window.buddyAPI) {
      window.buddyAPI.onShowPreferences(() => {
        setState(prev => ({ ...prev, activePanel: 'settings' }));
      });
      window.buddyAPI.onShowVoiceConsole(() => {
        setShowVoiceConsole(true);
      });
    }

    // Cleanup
    return () => {
      if (window.buddyAPI) {
        window.buddyAPI.removeAllListeners('show-preferences');
        window.buddyAPI.removeAllListeners('show-voice-console');
      }
    };
  }, []);

  const handlePanelChange = (panel: AppState['activePanel']) => {
    setState(prev => ({ ...prev, activePanel: panel }));
  };

  const renderActivePanel = () => {
    switch (state.activePanel) {
      case 'chat':
        return <ChatInterface />;
      case 'skills':
        return <SkillsPanel />;
      case 'memory':
        return <MemoryPanel />;
      case 'settings':
        return <SettingsPanel />;
      default:
        return <ChatInterface />;
    }
  };

  if (!state.appInfo) {
    return (
      <div className="app-loading">
        <div className="loading-spinner" />
        <div>Loading BUDDY...</div>
      </div>
    );
  }

  return (
    <AppProvider>
      <VoiceProvider>
        <div className="app">
          {/* Navigation Sidebar */}
          <div className="sidebar">
            <div className="sidebar-header">
              <div className="logo">
                <img src="./assets/icon.png" alt="BUDDY" width="32" height="32" />
                <span>BUDDY</span>
              </div>
            </div>

            <nav className="sidebar-nav">
              <button
                className={`nav-item ${state.activePanel === 'chat' ? 'active' : ''}`}
                onClick={() => handlePanelChange('chat')}
              >
                <span className="nav-icon">💬</span>
                <span>Chat</span>
              </button>

              <button
                className={`nav-item ${state.activePanel === 'skills' ? 'active' : ''}`}
                onClick={() => handlePanelChange('skills')}
              >
                <span className="nav-icon">🛠️</span>
                <span>Skills</span>
              </button>

              <button
                className={`nav-item ${state.activePanel === 'memory' ? 'active' : ''}`}
                onClick={() => handlePanelChange('memory')}
              >
                <span className="nav-icon">🧠</span>
                <span>Memory</span>
              </button>

              <button
                className={`nav-item ${state.activePanel === 'settings' ? 'active' : ''}`}
                onClick={() => handlePanelChange('settings')}
              >
                <span className="nav-icon">⚙️</span>
                <span>Settings</span>
              </button>
            </nav>

            <div className="sidebar-footer">
              <button
                className="voice-toggle"
                onClick={() => setShowVoiceConsole(!showVoiceConsole)}
              >
                <span className="nav-icon">🎤</span>
                <span>Voice</span>
              </button>
            </div>
          </div>

          {/* Main Content */}
          <div className="main-panel">
            {renderActivePanel()}
          </div>

          {/* Voice Interface Overlay */}
          {showVoiceConsole && (
            <VoiceInterface
              isVisible={showVoiceConsole}
              onClose={() => setShowVoiceConsole(false)}
            />
          )}

          {/* Status Bar */}
          <StatusBar
            connected={state.connected}
            version={state.appInfo.version}
          />
        </div>
      </VoiceProvider>
    </AppProvider>
  );
};

export default App;