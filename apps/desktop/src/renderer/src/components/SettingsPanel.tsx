import React from 'react';

const SettingsPanel: React.FC = () => {
  return (
    <div className="settings-panel">
      <h2>Settings</h2>
      <div className="settings-sections">
        <div className="settings-section">
          <h3>Voice Settings</h3>
          <div className="setting-item">
            <label>Wake Word</label>
            <input type="text" defaultValue="hey buddy" />
          </div>
          <div className="setting-item">
            <label>Voice Model</label>
            <select defaultValue="tiny">
              <option value="tiny">Tiny (Fast)</option>
              <option value="base">Base (Balanced)</option>
            </select>
          </div>
        </div>
        
        <div className="settings-section">
          <h3>Sync Settings</h3>
          <div className="setting-item">
            <label>
              <input type="checkbox" defaultChecked />
              Enable device sync
            </label>
          </div>
          <div className="setting-item">
            <label>Sync Interval (minutes)</label>
            <input type="number" defaultValue={5} min={1} max={60} />
          </div>
        </div>
        
        <div className="settings-section">
          <h3>Privacy Settings</h3>
          <div className="setting-item">
            <label>
              <input type="checkbox" defaultChecked />
              Keep conversations local only
            </label>
          </div>
          <div className="setting-item">
            <label>
              <input type="checkbox" />
              Enable usage analytics
            </label>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SettingsPanel;