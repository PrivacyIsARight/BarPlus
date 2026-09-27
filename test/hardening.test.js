'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const OVERLAY = path.join(__dirname, '..', 'dist_cfg', 'launcher_src');

const EXT_COMMANDS = [
	'bridge_download',
	'dev_extension_loader',
	'discord_integration',
	'map_parser',
	'open_file',
	'replay_handler',
	'start_new_spring_handler',
	'track_files',
	'upload_log',
];

function read(...parts) {
	return fs.readFileSync(path.join(OVERLAY, ...parts), 'utf8');
}

test('the bridge drops commands that were never registered', () => {
	const bridge = read('spring_bridge.js');
	assert.match(bridge, /ALLOWED_CHANNELS/);
	assert.match(bridge, /ignoring unknown command/);
	assert.match(bridge, /register\(name, listener\)/);
	assert.match(bridge, /ALLOWED_CHANNELS\.add\(name\)/);
});

test('every bridge command handler registers itself', () => {
	for (const name of EXT_COMMANDS) {
		const source = read('exts', `${name}.js`);
		assert.doesNotMatch(source, /bridge\.on\(/, `${name}.js must use bridge.register so the allow-list admits it`);
		assert.match(source, /bridge\.register\(/, `${name}.js must register its command`);
	}
});

test('path handling is contained to the write path', () => {
	for (const name of ['open_file', 'map_parser', 'track_files', 'start_new_spring_handler']) {
		assert.match(read('exts', `${name}.js`), /resolveInside/, `${name}.js must validate paths`);
	}
	assert.match(read('replay_utils.js'), /resolveInside/);
	assert.match(read('http_downloader.js'), /resolveInside/);
});

test('downloads are restricted to https', () => {
	const source = read('http_downloader.js');
	assert.match(source, /url\.protocol !== 'https:'/);
	assert.match(source, /only https is allowed/);
});

test('archive extraction refuses entries that escape the destination', () => {
	const source = read('extractor.js');
	assert.match(source, /archiveEntryInside/);
	assert.match(source, /validateArchive/);
	for (const cls of ['Extractor7Zip', 'ExtractorZip']) {
		assert.match(source, new RegExp(`class ${cls} extends BaseArchiveExtractor`), `${cls} must validate before extracting`);
	}
});

test('StartNewSpring rejects engine identifiers that are not plain names', () => {
	const source = read('exts', 'start_new_spring_handler.js');
	assert.match(source, /engineName\.includes\('\/'\)/);
	assert.match(source, /engineName\.includes\('\\\\'\)/);
	assert.match(source, /engineName\.includes\('\\0'\)/);
	assert.match(source, /engineName === '\.'/);
	assert.match(source, /engineName === '\.\.'/);
	assert.match(source, /engineName\.length > 255/);
});

test('the loopback connection info is not world readable', () => {
	const source = read('engine_launcher.js');
	assert.match(source, /writeConnectionInfo\(\)/);
	assert.match(source, /mode: 0o600/);
	assert.match(source, /chmodSync\(filePath, 0o600\)/);
});
