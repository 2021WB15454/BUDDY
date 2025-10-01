import { contextBridge, ipcRenderer } from 'electron';

// Define the API interface
interface BuddyAPI {
  // App info
  getAppInfo: () => Promise<{
    version: string;
    platform: string;
    arch: string;
    backendReady: boolean;
    backendPort: number;
  }>;

  // Backend communication
  backendRequest: (endpoint: string, options?: RequestInit) => Promise<any>;

  // Voice functionality
  startVoiceRecording: () => Promise<{ success: boolean }>;
  stopVoiceRecording: () => Promise<{ success: boolean }>;

  // Window controls
  minimizeWindow: () => Promise<void>;
  maximizeWindow: () => Promise<void>;
  closeWindow: () => Promise<void>;

  // Event listeners
  onPushToTalk: (callback: (action: string) => void) => void;
  onShowPreferences: (callback: () => void) => void;
  onShowVoiceConsole: (callback: () => void) => void;

  // Remove listeners
  removeAllListeners: (channel: string) => void;
}

// Expose the API to the renderer process
const buddyAPI: BuddyAPI = {
  // App info
  getAppInfo: () => ipcRenderer.invoke('get-app-info'),

  // Backend communication
  backendRequest: (endpoint: string, options?: RequestInit) => 
    ipcRenderer.invoke('backend-request', endpoint, options),

  // Voice functionality
  startVoiceRecording: () => ipcRenderer.invoke('start-voice-recording'),
  stopVoiceRecording: () => ipcRenderer.invoke('stop-voice-recording'),

  // Window controls
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),
  maximizeWindow: () => ipcRenderer.invoke('maximize-window'),
  closeWindow: () => ipcRenderer.invoke('close-window'),

  // Event listeners
  onPushToTalk: (callback: (action: string) => void) => {
    ipcRenderer.on('push-to-talk', (_, action) => callback(action));
  },

  onShowPreferences: (callback: () => void) => {
    ipcRenderer.on('show-preferences', callback);
  },

  onShowVoiceConsole: (callback: () => void) => {
    ipcRenderer.on('show-voice-console', callback);
  },

  // Remove listeners
  removeAllListeners: (channel: string) => {
    ipcRenderer.removeAllListeners(channel);
  }
};

// Context bridge - securely expose API to renderer
contextBridge.exposeInMainWorld('buddyAPI', buddyAPI);

// Expose a typed version for TypeScript
declare global {
  interface Window {
    buddyAPI: BuddyAPI;
  }
}

export type { BuddyAPI };
