'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const Module = require('module');

const LAUNCHER_CONFIG_PATH = require.resolve('../src/launcher_config.js');

const BUNDLED_CONFIG = {
	title: 'Beyond All Reason',
	setups: [
		{
			package: { id: 'bundled-linux', display: 'Alpha', platform: 'linux' },
			config_url: 'https://raw.githubusercontent.com/PrivacyIsARight/BarPlus/master/dist_cfg/config.json',
			launch: { engine: 'recoil_2026.07.04' },
		},
	],
};

const FOREIGN_CONFIG = {
	title: 'Beyond All Reason',
	setups: [
		{
			package: { id: 'foreign-linux', display: 'Alpha', platform: 'linux' },
			config_url: 'https://launcher-config.beyondallreason.dev/config.json',
			launch: { engine: 'recoil_2026.09.01' },
		},
	],
};

let tmp = null;

test.before(() => {
	tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'barplus-launcher-config-'));
});

test.after(() => {
	fs.rmSync(tmp, { recursive: true, force: true });
});

function loadLauncherConfig(bundledConfig, storedConfig) {
	const originalLoad = Module._load;

	if (storedConfig != null) {
		fs.writeFileSync(path.join(tmp, 'config.json'), JSON.stringify(storedConfig, null, 4));
	}

	Module._load = function (request, parent, isMain) {
		if (request === './config.json') {
			return bundledConfig;
		}
		if (request === './launcher_args') {
			return {};
		}
		if (request === './write_path') {
			return { resolveWritePath: () => tmp };
		}
		if (request === 'electron-log') {
			return { log: { info() {}, warn() {}, error() {} } };
		}
		return originalLoad.call(this, request, parent, isMain);
	};

	try {
		delete require.cache[LAUNCHER_CONFIG_PATH];
		return require(LAUNCHER_CONFIG_PATH);
	} finally {
		Module._load = originalLoad;
		delete require.cache[LAUNCHER_CONFIG_PATH];
	}
}

test('bundled config replaces a config stored by another launcher build', () => {
	const { config } = loadLauncherConfig(BUNDLED_CONFIG, FOREIGN_CONFIG);

	assert.equal(config.getConfigObj().package.id, 'bundled-linux');
	assert.deepEqual(config.getAvailableConfigs().map((setup) => setup.package.id), ['bundled-linux']);

	const stored = JSON.parse(fs.readFileSync(path.join(tmp, 'config.json'), 'utf8'));
	assert.equal(stored.setups[0].package.id, 'bundled-linux');
	assert.equal(stored.setups[0].config_url, BUNDLED_CONFIG.setups[0].config_url);
});

test('bundled config is used when the stored config cannot be parsed', () => {
	fs.writeFileSync(path.join(tmp, 'config.json'), '{ not json');

	const { config } = loadLauncherConfig(BUNDLED_CONFIG, null);

	assert.equal(config.getConfigObj().package.id, 'bundled-linux');
	assert.equal(JSON.parse(fs.readFileSync(path.join(tmp, 'config.json'), 'utf8')).setups[0].package.id, 'bundled-linux');
});

test('an identical stored config is left untouched', () => {
	const stored = JSON.parse(JSON.stringify(BUNDLED_CONFIG));
	const { config } = loadLauncherConfig(BUNDLED_CONFIG, stored);

	assert.equal(config.getConfigObj().package.id, 'bundled-linux');
	assert.equal(fs.existsSync(path.join(tmp, 'config.new.json')), false);
});
