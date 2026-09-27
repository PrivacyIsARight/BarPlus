const { bridge } = require('../spring_api');
const file_opener = require('../file_opener');
const springPlatform = require('../spring_platform');
const { log } = require('../spring_log');
const { resolveInside } = require('../fs_utils');

bridge.register('OpenFile', async (command) => {
	let success = false;
	try {
		const path = resolveInside(springPlatform.writePath, command.path);
		if (path == null) {
			log.error(`OpenFile: rejecting path outside the game directory: ${command.path}`);
		} else {
			await file_opener.open(path);
			success = true;
		}
	} catch (e) {
		success = false;
	}

	if (success) {
		bridge.send('OpenFileFinished', {
			path: command.path
		});
	} else {
		bridge.send('OpenFileFailed', {
			path: command.path
		});
	}
});
