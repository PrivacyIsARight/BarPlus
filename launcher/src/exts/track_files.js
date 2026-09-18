const { bridge } = require('../spring_api');
const springPlatform = require('../spring_platform');
const { log } = require('../spring_log');
const { resolveInside } = require('../fs_utils');

const chokidar = require('chokidar');

var watcher = chokidar.watch('file', {
	ignoreInitial: true,
	persistent: true,
	followSymlinks: true,
	// TODO: chokidar doesn't seem to work without explicitly enabling polling
	// This is probably less efficient and should be reported/fixed
	// It does seem to work if initialized with a dir instead
	// gameDir = '/home/user/.config/spring/games/SomeGame.sdd/'
	// chokidar.watch(gameDir, {ignored: /(^|[\/\\])\../}).on('all', (event, path) => {
	usePolling: true
});

function Notify(path, type) {
	bridge.send('FileChanged', {
		path: path,
		type: type
	});
}

watcher.on('add', (path) => {
	Notify(path, 'add');
});
watcher.on('addDir', (path) => {
	Notify(path, 'addDir');
});
watcher.on('change', (path) => {
	Notify(path, 'change');
});
watcher.on('unlink', (path) => {
	Notify(path, 'unlink');
});
watcher.on('unlinkDir', (path) => {
	Notify(path, 'unlinkDir');
});

bridge.register('WatchFile', command => {
	const path = resolveInside(springPlatform.writePath, command.path);
	if (path == null) {
		log.error(`WatchFile: rejecting path outside the game directory: ${command.path}`);
		return;
	}
	watcher.add(path);
});
