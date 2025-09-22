const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const isDev = require('electron-is-dev');
const DB = require('./lib/db');

let mainWindow;
let db;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      enableRemoteModule: false
    }
  });

  const startUrl = isDev
    ? 'http://localhost:3000'
    : `file://${path.join(__dirname, 'renderer', 'index.html')}`;

  mainWindow.loadURL(startUrl);

  if (isDev) mainWindow.webContents.openDevTools();
}

/**
 * Decideix on guardar les dades:
 * - Si existeix PORTABLE_EXECUTABLE_DIR -> usar això
 * - Si l'aplicació està empaquetada (app.isPackaged) -> crear ./data al costat de l'executable
 * - Altrament (dev) -> app.getPath('userData')
 *
 * Retorna la ruta absoluta del directori de dades i crea la carpeta si cal.
 */
function resolveDataDir() {
  // Preferència per variable d'entorn (útil per proves i per alguns empaquetadors)
  let base = process.env.PORTABLE_EXECUTABLE_DIR || process.env.PORTABLE_APP_DATA_DIR || null;

  // Si no hi ha variable, i l'app està empaquetada, utilitzem el directori de l'executable
  if (!base) {
    try {
      if (app.isPackaged) {
        base = path.dirname(process.execPath);
      }
    } catch (e) {
      // app.isPackaged pot no estar encara disponible; ignorem
      base = null;
    }
  }

  // Si tenim base (portable mode), les dades es posaran a <base>/data
  let dataDir;
  if (base) {
    dataDir = path.join(base, 'data');
  } else {
    // fallback a userData per entorns de desenvolupament
    dataDir = app.getPath('userData');
  }

  // Assegurem la carpeta existeix
  try {
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  } catch (err) {
    console.error('No s\'ha pogut crear data dir:', dataDir, err);
    // En cas d'error, fem fallback a userData
    dataDir = app.getPath('userData');
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  }

  return dataDir;
}

app.whenReady().then(async () => {
  // Cal esperar a que app estigui inicialitzada per usar app.isPackaged i app.getPath
  const dataDir = resolveDataDir();
  const dbPath = path.join(dataDir, 'gestor-obres.db');

  // Inicialitzem la BD passant la ruta definitiva de la DB (portable o userData)
  db = new DB(dbPath);
  await db.init(); // aplica migracions si cal

  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

/**
 * IPC handlers
 * Exposarem només operacions concretes i segures des del main
 */
ipcMain.handle('db:getProjects', async (_, filter) => {
  return db.getProjects(filter);
});
ipcMain.handle('db:addProject', async (_, project) => {
  return db.addProject(project);
});
ipcMain.handle('db:getWorkers', async () => {
  return db.getWorkers();
});
ipcMain.handle('db:addWorker', async (_, worker) => {
  return db.addWorker(worker);
});
ipcMain.handle('export:csv', async (_, { type, params }) => {
  // Mostra diàleg per elegir arxiu (opcional)
  const { filePath } = await dialog.showSaveDialog(mainWindow, {
    defaultPath: `${type}-${new Date().toISOString().slice(0,10)}.csv`
  });
  if (!filePath) throw new Error('cancelled');
  return db.exportCSV(type, params, filePath);
});
ipcMain.handle('backup:create', async (_, { password }) => {
  const { filePath } = await dialog.showSaveDialog(mainWindow, {
    defaultPath: `backup-${new Date().toISOString().slice(0,10)}.zip`
  });
  if (!filePath) throw new Error('cancelled');
  return db.createEncryptedBackup(filePath, password);
});
ipcMain.handle('auth:login', async (_, { username, password }) => {
  return db.authenticate(username, password);
});
