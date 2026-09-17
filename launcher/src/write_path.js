const { app } = require('electron');
const path = require('path');
const fs = require('fs');
const platformName = process.platform;
const isDev = !require('electron').app.isPackaged;

function resolveWritePath(title) {
	const argv = require('./launcher_args');
	if (argv.writePath != null) {
		return argv.writePath;
	}

	if (process.env.PORTABLE_EXECUTABLE_DIR != null) {
		return path.join(process.env.PORTABLE_EXECUTABLE_DIR, title);
	}

	if (platformName === 'win32') {
		if (isDev) {
			return path.join(app.getAppPath(), 'data');
		} else {
			return path.join(app.getAppPath(), '../../data');
		}
	}

	const oldDir = path.join(app.getPath('documents'), title);
	if (fs.existsSync(oldDir)) {
		return oldDir;
	}
	const xdgStateHome = process.env.XDG_STATE_HOME || path.join(process.env.HOME, '.local/state');
	return path.join(xdgStateHome, title);
}

module.exports = {
	resolveWritePath: resolveWritePath
};
