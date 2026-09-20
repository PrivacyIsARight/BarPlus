'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');

const ENGINE_CONFIG_PATH = require.resolve('../src/engine_config.js');

function stubConfig() {
	const config = {
		package: { platform: 'linux' },
		downloads: {
			resources: [
				{
					url: 'https://github.com/PrivacyIsARight/unrecoil/releases/download/2026.07.04/unrecoil_2026.07.04_amd64-linux.7z',
					destination: 'engine/unrecoil_2026.07.04-unrecoil',
					extract: true,
					engine_config_url: 'https://raw.githubusercontent.com/PrivacyIsARight/unrecoil/master/latest.json',
				},
			],
		},
		launch: { engine: 'unrecoil_2026.07.04-unrecoil' },
	};
	return config;
}

function loadEngineConfig(config, engineInfo, fetchError) {
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

test('resolveEngineConfig keeps pinned engine when no engine_config_url is set', async () => {
	const config = stubConfig();
	config.downloads.resources[0].engine_config_url = null;

	const result = await loadEngineConfig(config, null);
	assert.deepEqual(result, { applied: false, error: null });
	assert.equal(config.launch.engine, 'unrecoil_2026.07.04-unrecoil');
});

test('resolveEngineConfig applies the latest engine for the current platform', async () => {
	const config = stubConfig();
	const engineInfo = {
		version: '2026.09.01',
		engine: 'unrecoil_2026.09.01-unrecoil',
		resources: [
			{
				platform: 'linux',
				url: 'https://github.com/PrivacyIsARight/unrecoil/releases/download/2026.09.01/unrecoil_2026.09.01_amd64-linux.7z',
				destination: 'engine/unrecoil_2026.09.01-unrecoil',
				extract: true,
			},
		],
	};

	const result = await loadEngineConfig(config, engineInfo);
	assert.deepEqual(result, { applied: true, error: null });

	const resource = config.downloads.resources[0];
	assert.equal(resource.url, engineInfo.resources[0].url);
	assert.equal(resource.destination, engineInfo.resources[0].destination);
	assert.equal(resource.extract, true);
	assert.equal(config.launch.engine, 'unrecoil_2026.09.01-unrecoil');
});

test('resolveEngineConfig keeps the pinned engine when no platform entry matches', async () => {
	const config = stubConfig();
	const engineInfo = {
		version: '2026.09.01',
		engine: 'unrecoil_2026.09.01-unrecoil',
		resources: [
			{
				platform: 'win32',
				url: 'https://github.com/PrivacyIsARight/unrecoil/releases/download/2026.09.01/unrecoil_2026.09.01_amd64-windows.7z',
				destination: 'engine/unrecoil_2026.09.01-unrecoil',
				extract: true,
			},
		],
	};

	const result = await loadEngineConfig(config, engineInfo);
	assert.deepEqual(result, { applied: false, error: null });
	assert.equal(config.downloads.resources[0].url, 'https://github.com/PrivacyIsARight/unrecoil/releases/download/2026.07.04/unrecoil_2026.07.04_amd64-linux.7z');
	assert.equal(config.launch.engine, 'unrecoil_2026.07.04-unrecoil');
});

test('resolveEngineConfig keeps the pinned engine when the fetch fails', async () => {
	const config = stubConfig();

	const result = await loadEngineConfig(config, null, new Error('network down'));
	assert.deepEqual(result, { applied: false, error: null });
	assert.equal(config.downloads.resources[0].url, 'https://github.com/PrivacyIsARight/unrecoil/releases/download/2026.07.04/unrecoil_2026.07.04_amd64-linux.7z');
	assert.equal(config.launch.engine, 'unrecoil_2026.07.04-unrecoil');
});