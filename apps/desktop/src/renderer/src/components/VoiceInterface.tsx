import React from 'react';

interface VoiceInterfaceProps {
  isVisible: boolean;
  onClose: () => void;
}

const VoiceInterface: React.FC<VoiceInterfaceProps> = ({ isVisible, onClose }) => {
  if (!isVisible) return null;

  return (
    <div className="voice-interface-overlay">
      <div className="voice-interface">
        <div className="voice-header">
          <h3>Voice Console</h3>
          <button onClick={onClose} className="close-button">×</button>
        </div>
        <div className="voice-content">
          <div className="voice-status">
            <div className="status-indicator idle">
              <div className="pulse-circle"></div>
              <span>Ready to listen</span>
            </div>
          </div>
          <div className="voice-controls">
            <button className="voice-button primary">
              🎤 Start Listening
            </button>
            <button className="voice-button secondary">
              ⏹️ Stop
            </button>
          </div>
          <div className="voice-transcript">
            <h4>Transcript</h4>
            <div className="transcript-content">
              <p>Say "Hey BUDDY" to start...</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default VoiceInterface;