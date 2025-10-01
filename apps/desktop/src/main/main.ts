import { ChildProcess, spawn } from 'child_process';
import { app, BrowserWindow, dialog, globalShortcut, ipcMain, Menu } from 'electron';
import * as os from 'os';
import * as path from 'path';

interface BuddyBackend {
  process?: ChildProcess;
  port: number;
  ready: boolean;
}

class BuddyDesktop {
  private mainWindow: BrowserWindow | null = null;
  private backend: BuddyBackend = {
    port: 8000,
    ready: false
  };

  async initialize() {
    // Wait for Electron to be ready
    await app.whenReady();

    // Start the Python backend
    await this.startBackend();

    // Create the main window
    this.createMainWindow();

    // Setup global shortcuts
    this.setupGlobalShortcuts();

    // Setup menu
    this.setupMenu();

    // Setup IPC handlers
    this.setupIPC();

    // Handle app events
    this.setupAppEvents();
  }

  private async startBackend(): Promise<void> {
    return new Promise((resolve, reject) => {
      console.log('Starting BUDDY backend...');

      // Determine Python executable
      const pythonCmd = process.platform === 'win32' ? 'python' : 'python3';
      
      // Backend path (relative to app)
      const backendPath = app.isPackaged 
        ? path.join(process.resourcesPath, 'backend')
        : path.join(__dirname, '../../packages/core');

      // Start the backend process
      this.backend.process = spawn(pythonCmd, [
        '-m', 'uvicorn',
        'buddy.main:app',
        '--host', '0.0.0.0',
        '--port', this.backend.port.toString(),
        '--log-level', 'info'
      ], {
        cwd: backendPath,
        stdio: ['pipe', 'pipe', 'pipe'],
        env: {
          ...process.env,
          PYTHONPATH: backendPath,
          BUDDY_DATA_DIR: path.join(os.homedir(), '.buddy'),
          BUDDY_LOG_LEVEL: 'INFO'
        }
      });

      if (!this.backend.process) {
        reject(new Error('Failed to start backend process'));
        return;
      }

      // Handle backend output
      this.backend.process.stdout?.on('data', (data) => {
        const output = data.toString();
        console.log('Backend:', output);
        
        // Check if backend is ready
        if (output.includes('Uvicorn running on')) {
          this.backend.ready = true;
          console.log('✅ BUDDY backend ready');
          resolve();
        }
      });

      this.backend.process.stderr?.on('data', (data) => {
        console.error('Backend Error:', data.toString());
      });

      this.backend.process.on('close', (code) => {
        console.log(`Backend process exited with code ${code}`);
        this.backend.ready = false;
      });

      // Timeout after 30 seconds
      setTimeout(() => {
        if (!this.backend.ready) {
          reject(new Error('Backend startup timeout'));
        }
      }, 30000);
    });
  }

  private createMainWindow(): void {
    this.mainWindow = new BrowserWindow({
      width: 1200,
      height: 800,
      minWidth: 800,
      minHeight: 600,
      titleBarStyle: 'hiddenInset',
      vibrancy: 'under-window',
      visualEffectState: 'active',
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        preload: path.join(__dirname, 'preload.js')
      },
      icon: path.join(__dirname, '../assets/icon.png'),
      show: false // Don't show until ready
    });

    // Load the renderer
    if (process.env.NODE_ENV === 'development') {
      this.mainWindow.loadURL('http://localhost:5173');
      this.mainWindow.webContents.openDevTools();
    } else {
      this.mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));
    }

    // Show window when ready
    this.mainWindow.once('ready-to-show', () => {
      this.mainWindow?.show();
      
      // Focus window
      if (process.platform === 'darwin') {
        app.dock.show();
      }
      this.mainWindow?.focus();
    });

    // Handle window closed
    this.mainWindow.on('closed', () => {
      this.mainWindow = null;
    });

    // Handle window minimize to tray on macOS
    this.mainWindow.on('minimize', (event: Electron.Event) => {
      if (process.platform === 'darwin') {
        event.preventDefault();
        this.mainWindow?.hide();
      }
    });
  }

  private setupGlobalShortcuts(): void {
    // Register global shortcuts
    globalShortcut.register('CmdOrCtrl+Shift+B', () => {
      if (this.mainWindow) {
        if (this.mainWindow.isVisible()) {
          this.mainWindow.hide();
        } else {
          this.mainWindow.show();
          this.mainWindow.focus();
        }
      }
    });

    // Push-to-talk shortcut
    globalShortcut.register('CmdOrCtrl+Space', () => {
      this.mainWindow?.webContents.send('push-to-talk', 'start');
    });
  }

  private setupMenu(): void {
    const template: Electron.MenuItemConstructorOptions[] = [
      {
        label: 'BUDDY',
        submenu: [
          {
            label: 'About BUDDY',
            click: () => {
              dialog.showMessageBox(this.mainWindow!, {
                type: 'info',
                title: 'About BUDDY',
                message: 'BUDDY Personal AI Assistant',
                detail: 'Version 0.1.0\nPrivacy-first, offline-capable AI assistant'
              });
            }
          },
          { type: 'separator' },
          {
            label: 'Preferences...',
            accelerator: 'CmdOrCtrl+,',
            click: () => {
              this.mainWindow?.webContents.send('show-preferences');
            }
          },
          { type: 'separator' },
          {
            label: 'Hide BUDDY',
            accelerator: 'CmdOrCtrl+H',
            role: 'hide'
          },
          {
            label: 'Hide Others',
            accelerator: 'CmdOrCtrl+Shift+H',
            role: 'hideOthers'
          },
          {
            label: 'Show All',
            role: 'unhide'
          },
          { type: 'separator' },
          {
            label: 'Quit',
            accelerator: 'CmdOrCtrl+Q',
            click: () => {
              app.quit();
            }
          }
        ]
      },
      {
        label: 'Edit',
        submenu: [
          { role: 'undo' },
          { role: 'redo' },
          { type: 'separator' },
          { role: 'cut' },
          { role: 'copy' },
          { role: 'paste' },
          { role: 'selectAll' }
        ]
      },
      {
        label: 'View',
        submenu: [
          { role: 'reload' },
          { role: 'forceReload' },
          { role: 'toggleDevTools' },
          { type: 'separator' },
          { role: 'resetZoom' },
          { role: 'zoomIn' },
          { role: 'zoomOut' },
          { type: 'separator' },
          { role: 'togglefullscreen' }
        ]
      },
      {
        label: 'Window',
        submenu: [
          { role: 'minimize' },
          { role: 'close' },
          { type: 'separator' },
          {
            label: 'Voice Console',
            accelerator: 'CmdOrCtrl+Shift+V',
            click: () => {
              this.mainWindow?.webContents.send('show-voice-console');
            }
          }
        ]
      },
      {
        label: 'Help',
        submenu: [
          {
            label: 'Documentation',
            click: () => {
              require('electron').shell.openExternal('https://docs.buddy-ai.dev');
            }
          },
          {
            label: 'Report Issue',
            click: () => {
              require('electron').shell.openExternal('https://github.com/buddy-ai/buddy/issues');
            }
          }
        ]
      }
    ];

    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
  }

  private setupIPC(): void {
    // Handle backend communication
    ipcMain.handle('backend-request', async (_event, endpoint, options = {}) => {
      try {
        const response = await fetch(`http://localhost:${this.backend.port}${endpoint}`, {
          ...options,
          headers: {
            'Content-Type': 'application/json',
            ...options.headers
          }
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();
      } catch (error) {
        console.error('Backend request failed:', error);
        throw error;
      }
    });

    // Handle voice recording
    ipcMain.handle('start-voice-recording', async () => {
      // TODO: Implement voice recording
      return { success: true };
    });

    ipcMain.handle('stop-voice-recording', async () => {
      // TODO: Implement voice recording stop
      return { success: true };
    });

    // Handle app info
    ipcMain.handle('get-app-info', () => {
      return {
        version: app.getVersion(),
        platform: process.platform,
        arch: process.arch,
        backendReady: this.backend.ready,
        backendPort: this.backend.port
      };
    });

    // Handle window controls
    ipcMain.handle('minimize-window', () => {
      this.mainWindow?.minimize();
    });

    ipcMain.handle('maximize-window', () => {
      if (this.mainWindow?.isMaximized()) {
        this.mainWindow.unmaximize();
      } else {
        this.mainWindow?.maximize();
      }
    });

    ipcMain.handle('close-window', () => {
      this.mainWindow?.close();
    });
  }

  private setupAppEvents(): void {
    // Handle app activation (macOS)
    app.on('activate', () => {
      if (this.mainWindow === null) {
        this.createMainWindow();
      } else {
        this.mainWindow.show();
      }
    });

    // Handle all windows closed
    app.on('window-all-closed', () => {
      if (process.platform !== 'darwin') {
        app.quit();
      }
    });

    // Handle app quit
    app.on('before-quit', () => {
      // Cleanup global shortcuts
      globalShortcut.unregisterAll();

      // Stop backend
      if (this.backend.process) {
        console.log('Stopping backend...');
        this.backend.process.kill();
      }
    });

    // Handle second instance (single instance lock)
    app.on('second-instance', () => {
      if (this.mainWindow) {
        if (this.mainWindow.isMinimized()) {
          this.mainWindow.restore();
        }
        this.mainWindow.focus();
      }
    });
  }
}

// Ensure single instance
const gotTheLock = app.requestSingleInstanceLock();

if (!gotTheLock) {
  app.quit();
} else {
  // Initialize BUDDY Desktop
  const buddyDesktop = new BuddyDesktop();
  buddyDesktop.initialize().catch(console.error);
}