const { join } = require('path');
const log = require('electron-log');

const { bridge } = require('../spring_api');
const springPlatform = require('../spring_platform');
const { Launcher } = require('../engine_launcher');
const { resolveInside } = require('../fs_utils');

bridge.register('StartNewSpring', async command => {
	const launcher = new Launcher();

	const engineName = String(command.Engine || '').toLowerCase();
	if (engineName.length === 0 || engineName.length > 255 ||
			engineName === '.' || engineName === '..' ||
			engineName.includes('/') || engineName.includes('\\') ||
			engineName.includes('\0')) {
		log.error(`StartNewSpring: rejected invalid engine identifier: ${engineName}`);
		return;
	}
	const engineDir = resolveInside(join(springPlatform.writePath, 'engine'), engineName);
	if (engineDir == null) {
		log.error(`StartNewSpring: engine path escapes the engines directory: ${engineName}`);
		return;
	}
	const enginePath = join(engineDir, springPlatform.springBin);

	const launchArgs = [];
	const demoName = command.StartDemoName;
	if (demoName != null) {
		const replayPath = resolveInside(springPlatform.writePath, String(demoName));
		if (replayPath == null) {
			log.error(`StartNewSpring: rejected replay path outside the game directory: ${demoName}`);
			return;
		}
		launchArgs.push(replayPath);
	}

	launcher.launchSpring(enginePath, launchArgs);

	launcher.on('stdout', (text) => {
		log.info(text);
	});

	launcher.on('stderr', (text) => {
		log.warn(text);
	});

	launcher.on('finished', (code) => {
		log.info(`Spring finished with code: ${code}`);
	});

	launcher.on('failed', (error) => {
		log.error(error);
	});

});
