import React from 'react';

interface StatusBarProps {
  connected: boolean;
  version: string;
}

const StatusBar: React.FC<StatusBarProps> = ({ connected, version }) => {
  return (
    <div className="status-bar">
      <div className="status-left">
        <span className={`connection-status ${connected ? 'connected' : 'disconnected'}`}>
          {connected ? '🟢 Connected' : '🔴 Disconnected'}
        </span>
      </div>
      <div className="status-right">
        <span className="version">BUDDY v{version}</span>
      </div>
    </div>
  );
};

export default StatusBar;