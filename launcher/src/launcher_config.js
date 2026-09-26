'use strict';

const log = require('electron-log');

const argv = require('./launcher_args');
const { resolveWritePath } = require('./write_path');
const path = require('path');
const fs = require('fs');
const stableStringify = require('json-stable-stringify');

const defaultSetup = {
	'package': {
		'platform': 'all',
		'portable': false,
		'display': 'Spring Launcher'
	},

	'isolation': true,
	'auto_download': false,
	'auto_start': false,
	'no_downloads': false,
	'no_start_script': false,
	'load_dev_exts': false,
	'log_upload_url': null,
	'config_url': null,
	'silent': true,
	'error_suffix': null,
	'disable_win_ascii_install_path_check': false,

	'links': undefined,

	'disable_launcher_update_dialog': false,

	'disable_engine_folder_deletion': false,

	'env_variables': {},

	'downloads': {
		'games': [],
		'maps': [],
		'engines': [],
		'resources': [],
	},

	'json_files': {},

	'launch': {
		'start_args': [],
		'game': undefined,
		'map': undefined,
		'engine': undefined,
		'map_options': undefined,
		'mod_options': undefined,
		'game_options': undefined,
		'springsettings': {}
	}
};

function canUse(config) {
	if (config.package.platform != 'all') {
		if (config.package.platform != process.platform) {
			return false;
		}
	}
	if (config.package.portable && !process.env.PORTABLE_EXECUTABLE_DIR) {
		return false;
	}
	if (process.env.PORTABLE_EXECUTABLE_DIR && !config.package.portable) {
		return false;
	}
	return true;
}

function isObject(item) {
	return (item && typeof item === 'object' && !Array.isArray(item));
}

function mergeDeep(target, ...sources) {
	if (sources.length === 0) {
		return target;
	}
	const source = sources.shift();

	if (isObject(target) && isObject(source)) {
		for (const key in source) {
			if (isObject(source[key])) {
				if (!target[key]) {
					Object.assign(target, { [key]: {} });
				}
				mergeDeep(target[key], source[key]);
			} else {
				Object.assign(target, { [key]: source[key] });
			}
		}
	}

	return mergeDeep(target, ...sources);
}

function stringifyConfig(conf) {
	return JSON.stringify(conf, null, 4);
}

function isSameConfig(configFile, bundled) {
	if (!fs.existsSync(configFile)) {
		return false;
	}

	try {
		return stringifyConfig(JSON.parse(fs.readFileSync(configFile, 'utf8'))) === bundled;
	} catch (err) {
		return false;
	}
}

function replaceStoredConfig(conf) {
	const writePath = resolveWritePath(conf.title);
	const configFile = path.join(writePath, 'config.json');

	if (!fs.existsSync(writePath)) {
		return;
	}

	const bundled = stringifyConfig(conf);
	if (isSameConfig(configFile, bundled)) {
		return;
	}

	console.log(`Replacing stored config file: ${configFile}`);
	const tmpConfigFile = path.join(writePath, 'config.new.json');
	fs.writeFileSync(tmpConfigFile, bundled);
	fs.renameSync(tmpConfigFile, configFile);
}

function loadConfig() {
	if (argv.config) {
		return require(argv.config);
	}

	const conf = require('./config.json');

	try {
		replaceStoredConfig(conf);
	} catch (err) {
		console.error('Cannot replace stored config.json. Using bundled config.');
		console.error(err);
	}

	return conf;
}

function applyDefaults(conf) {
	for (let i = 0; i < conf.setups.length; i++) {
		const defaultSetupCopy = JSON.parse(JSON.stringify(defaultSetup));
		const setup = mergeDeep(defaultSetupCopy, conf.setups[i]);
		setup.title = conf.title;
		if (!setup.error_suffix) setup.error_suffix = conf.error_suffix;
		if (!setup.links) setup.links = conf.links;

		for (const [file, val] of Object.entries(conf.json_files || {})) {
			if (!(file in setup.json_files)) {
				setup.json_files[file] = val;
			}
		}

		conf.setups[i] = setup;
	}
	return conf;
}

let configs = [];
let availableConfigs = [];
let currentConfig = null;
let configFile = null;
let originalEnv = { ...process.env };

function setCurrentConfig(setup) {
	process.env = { ...originalEnv };
	if (setup) {
		for (const key in setup.env_variables) {
			if (!(key in process.env)) {
				process.env[key] = setup.env_variables[key];
			}
		}
	}
	currentConfig = setup;
}

function reloadConfig(conf) {
	configFile = conf;
	configs = [];
	availableConfigs = [];
	currentConfig = null;
	setCurrentConfig(null);

	conf.setups.forEach((setup) => {
		configs.push(setup);

		if (canUse(setup)) {
			availableConfigs.push(setup);
			if (!currentConfig) {
				setCurrentConfig(setup);
			}
		}
	});

	return conf;
}

reloadConfig(applyDefaults(loadConfig()));

function objEqual(a, b, ignoreProp = []) {
	if (a === b) {
		return true;
	}
	if (!a || !b) {
		return false;
	}
	a = JSON.parse(JSON.stringify(a));
	b = JSON.parse(JSON.stringify(b));
	for (const prop of ignoreProp) {
		a[prop] = null;
		b[prop] = null;
	}
	return stableStringify(a) == stableStringify(b);
}

function validateNewConfig(newFile) {
	if (!isObject(newFile)) {
		throw Error('Config must be object');
	}
	if (newFile.title !== configFile.title) {
		throw Error('New config title must be identical to the old one');
	}
	if (!Array.isArray(newFile.setups) || !newFile.setups.some(canUse)) {
		throw Error('New config file must have at least 1 usable setup');
	}
}

function hotReloadSafe(newFile) {
	if (objEqual(newFile, configFile)) {
		return 'identical';
	}

	if (!objEqual(newFile, configFile, ['setups'])) {
		return 'reload';
	}

	for (const setup of newFile.setups) {
		if (setup.package.id == currentConfig.package.id &&
			objEqual(setup, currentConfig)) {
			return 'same-setup';
		}
	}

	return 'reload';
}

const proxy = new Proxy({
	setConfig: function (id) {
		var found = false;
		availableConfigs.forEach((cfg) => {
			if (cfg.package.id == id) {
				setCurrentConfig(cfg);
				found = true;
			}
		});
		if (!found) {
			log.error(`No config with ID: ${id} - ignoring`);
			return false;
		} else {
			return true;
		}
	},
	getAvailableConfigs: function () {
		return availableConfigs;
	},
	getConfigObj: function () {
		return currentConfig;
	}
}, {
	get: function (target, name) {
		if (target[name] != undefined) {
			return target[name];
		} else if (currentConfig[name] != undefined) {
			return currentConfig[name];
		}
		return configFile[name];
	},
	set: function (_, name, value) {
		currentConfig[name] = value;
		setCurrentConfig(currentConfig);
		return true;
	}
});

module.exports = {
	config: proxy,
	applyDefaults: applyDefaults,
	hotReloadSafe: hotReloadSafe,
	reloadConfig: reloadConfig,
	validateNewConfig: validateNewConfig
};
