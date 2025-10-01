import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles/global.css';

// Wait for DOM and BUDDY API to be ready
document.addEventListener('DOMContentLoaded', async () => {
  try {
    // Wait for BUDDY API to be available
    if (!window.buddyAPI) {
      throw new Error('BUDDY API not available');
    }

    // Get app info and check backend status
    const appInfo = await window.buddyAPI.getAppInfo();
    console.log('BUDDY Desktop App Info:', appInfo);

    if (!appInfo.backendReady) {
      throw new Error('Backend not ready');
    }

    // Hide loading screen and show app
    const loadingElement = document.getElementById('loading');
    const appElement = document.getElementById('app');
    
    if (loadingElement && appElement) {
      loadingElement.style.display = 'none';
      appElement.style.display = 'block';
    }

    // Mount React app
    const root = ReactDOM.createRoot(
      document.querySelector('.main-content') as HTMLElement
    );
    
    root.render(
      <React.StrictMode>
        <App />
      </React.StrictMode>
    );

  } catch (error) {
    console.error('Failed to initialize BUDDY:', error);
    
    // Show error state
    const loadingElement = document.getElementById('loading');
    if (loadingElement) {
      loadingElement.innerHTML = `
        <div class="loading-spinner" style="border-top-color: #ff6b6b;"></div>
        <div class="loading-text" style="color: #ff6b6b;">Failed to Start BUDDY</div>
        <div class="loading-detail">${error instanceof Error ? error.message : String(error)}</div>
        <div style="margin-top: 20px; font-size: 12px;">
          Try restarting the application
        </div>
      `;
    }
  }
});