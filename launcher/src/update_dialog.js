'use strict';

const { BrowserWindow } = require('electron');
const log = require('electron-log');

/**
 * Opens the update dialog.
 * 
 * @param {BrowserWindow} parentWindow
 * @param {import("electron-updater").UpdateInfo} updateInfo
 * @returns {Promise<boolean>}
 */
function showUpdateDialog(parentWindow, updateInfo) {
	const { promise, resolve } = Promise.withResolvers();

	// If there are no release notes, we can make the window smaller.
	const dimensions = updateInfo.releaseNotes ? {
		height: 600,
		minHeight: 270,
		width: 800,
		minWidth: 600,
		resizable: true,
	} : {
		height: 210,
		width: 560,
		resizable: false,
	};

	// Adjustment for Windows to make sure that height is rought the same across
	// the operating systems.
	if (process.platform == 'win32') {
		dimensions.height += 23;
	}

	const win = new BrowserWindow({
		parent: parentWindow,
		modal: true,
		...dimensions,
		show: false,
		icon: `${__dirname}/renderer/spring-icon.png`,
		webPreferences: {
			nodeIntegration: true,
			enableRemoteModule: true,
			contextIsolation: false,
			worldSafeExecuteJavaScript: false,
		},
	});

	// Prevent all navigation to any pages in launcher just in case we made some bug in sanitizing.
	win.webContents.on('will-frame-navigate', (event) => {
		event.preventDefault();
		log.error(`Prevented navigation to: ${event.url}`);
	});

	// New window should be opened in external browser.
	win.webContents.setWindowOpenHandler(({ url }) => {
		try {
			const u = new URL(url);
			if (u.protocol !== 'https:') {
				throw new Error(`Invalid protocol: ${u.protocol}`);
			}
			log.info(`Opening external link: ${u}`);
			require('electron').shell.openExternal(u.href);
		} catch (e) {
			log.error(`Failed to open external link '${url}': ${e}`);
		}
		return { action: 'deny' };
	});

	// Forward all logs from renderer to main log.
	win.webContents.on('console-message', (event, level, message) => {
		log.info('From update dialog renderer:', message);
	});

	// User has to choose to update or not.
	win.on('close', (e) => e.preventDefault());

	win.webContents.ipc.handle('get-update-info', () => updateInfo);

	win.webContents.ipc.once('update-dialog-result', (event, result) => {
		win.destroy();
		resolve(result);
	});

	win.loadFile(`${__dirname}/renderer/update_dialog.html`);

	win.once('ready-to-show', () => {
		win.show();
	});

	// Workaround for linux/wayland on which electron has a problem with
	// properly setting window size from the beggining and a simple size refresh
	// after it got rendered once fixes it.
	win.once('show', () => {
		setTimeout(() => {
			win.setSize(dimensions.width, dimensions.height);
		}, 0);
	});

	// win.webContents.openDevTools();

	return promise;
}

module.exports = {
	showUpdateDialog
};
