'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');

const ENGINE_CONFIG_PATH = require.resolve('../src/engine_config.js');

const PINNED_URL = 'https://github.com/beyond-all-reason/RecoilEngine/releases/download/2026.07.04/recoil_2026.07.04_amd64-linux.7z';

function stubConfig() {
	const config = {
		package: { platform: 'linux' },
		downloads: {
			resources: [
				{
					url: PINNED_URL,
					destination: 'engine/recoil_2026.07.04',
					extract: true,
					engine_config_url: 'https://raw.githubusercontent.com/PrivacyIsARight/unrecoil/master/latest.json',
				},
			],
		},
		launch: { engine: 'recoil_2026.07.04' },
	};
	return config;
}

function unrecoilEngineInfo(platform) {
	const platformName = platform === 'win32' ? 'windows' : 'linux';
	return {
		version: '2026.09.01',
		display: 'unrecoil',
		engine: '2026.09.01',
		resources: [
			{
				platform,
				url: `https://github.com/PrivacyIsARight/unrecoil/releases/download/2026.09.01/unrecoil_2026.09.01_amd64-${platformName}.7z`,
				destination: 'engine/2026.09.01',
				extract: true,
			},
		],
	};
}

function loadEngineConfig(config, engineInfo, fetchError, unrecoil) {
	const originalLoad = Module._load;

	const log = { info() {}, warn() {}, error() {} };
	const gotStub = {};
	gotStub.json = async () => {
		if (fetchError) {
			throw fetchError;
		}
		return engineInfo;
	};
	const got = () => gotStub;

	Module._load = function (request, parent, isMain) {
		if (request === './launcher_config') {
			return { config };
		}
		if (request === './spring_log') {
			return { log };
		}
		if (request === './launcher_args') {
			return { unrecoil: unrecoil === true };
		}
		if (request === 'got') {
			return got;
		}
		return originalLoad.call(this, request, parent, isMain);
	};

	try {
		const { resolveEngineConfig } = require(ENGINE_CONFIG_PATH);
		return resolveEngineConfig(config.package.platform);
	} finally {
		Module._load = originalLoad;
		delete require.cache[ENGINE_CONFIG_PATH];
	}
}

function assertPinned(config) {
	assert.equal(config.downloads.resources[0].url, PINNED_URL);
	assert.equal(config.downloads.resources[0].destination, 'engine/recoil_2026.07.04');
	assert.equal(config.launch.engine, 'recoil_2026.07.04');
}

test('resolveEngineConfig keeps pinned engine when no engine_config_url is set', async () => {
	const config = stubConfig();
	config.downloads.resources[0].engine_config_url = null;

	const result = await loadEngineConfig(config, null, null, true);
	assert.deepEqual(result, { applied: false, error: null });
	assertPinned(config);
});

test('resolveEngineConfig applies the unrecoil engine when the flag is set', async () => {
	const config = stubConfig();
	const engineInfo = unrecoilEngineInfo('linux');

	const result = await loadEngineConfig(config, engineInfo, null, true);
	assert.deepEqual(result, { applied: true, error: null });

	const resource = config.downloads.resources[0];
	assert.equal(resource.url, engineInfo.resources[0].url);
	assert.equal(resource.destination, engineInfo.resources[0].destination);
	assert.equal(resource.extract, true);
	assert.equal(config.launch.engine, '2026.09.01');
});

test('resolveEngineConfig keeps the pinned engine when the flag is not set', async () => {
	const config = stubConfig();

	const result = await loadEngineConfig(config, unrecoilEngineInfo('linux'), null, false);
	assert.deepEqual(result, { applied: false, error: null });
	assertPinned(config);
});

test('resolveEngineConfig keeps the pinned engine when the engine config is not unrecoil', async () => {
	const config = stubConfig();
	const engineInfo = unrecoilEngineInfo('linux');
	delete engineInfo.display;

	let result = await loadEngineConfig(config, engineInfo, null, true);
	assert.deepEqual(result, { applied: false, error: null });
	assertPinned(config);

	engineInfo.display = 'recoil';
	result = await loadEngineConfig(config, engineInfo, null, true);
	assert.deepEqual(result, { applied: false, error: null });
	assertPinned(config);
});

test('resolveEngineConfig keeps the pinned engine when no platform entry matches', async () => {
	const config = stubConfig();
	const engineInfo = unrecoilEngineInfo('win32');

	const result = await loadEngineConfig(config, engineInfo, null, true);
	assert.deepEqual(result, { applied: false, error: null });
	assertPinned(config);
});

test('resolveEngineConfig keeps the pinned engine when the fetch fails', async () => {
	const config = stubConfig();

	const result = await loadEngineConfig(config, null, new Error('network down'), true);
	assert.deepEqual(result, { applied: false, error: null });
	assertPinned(config);
});
