'use strict';

const got = require('got');

const { config } = require('./launcher_config');
const { log } = require('./spring_log');

function getEngineResources() {
	return (config.downloads.resources || []).filter((resource) => resource.engine_config_url != null);
}

const argv = require('./launcher_args');

function applyEngineConfig(resource, engineInfo, platform) {
	const entry = (engineInfo.resources || []).find((candidate) => candidate.platform === platform);
	if (entry == null) {
		log.warn(`No ${platform} resource entry in engine config, keeping pinned engine`);
		return false;
	}

	if (engineInfo.display === 'unrecoil' && !argv.unrecoil) {
		return false;
	}

	if (entry.url != null) {
		resource.url = entry.url;
	}
	if (entry.destination != null) {
		resource.destination = entry.destination;
	}
	if (entry.extract != null) {
		resource.extract = entry.extract;
	}
	if (engineInfo.engine != null) {
		config.launch.engine = engineInfo.engine;
	}
	return true;
}

async function resolveEngineConfig(platform) {
	let applied = false;

	for (const resource of getEngineResources()) {
		let engineInfo;
		try {
			engineInfo = await got(resource.engine_config_url, { timeout: { request: 5000 } }).json();
		} catch (error) {
			log.warn(`Failed to fetch engine config from ${resource.engine_config_url}: ${error}`);
			continue;
		}

		log.info(`Got engine config (version ${engineInfo.version}) from ${resource.engine_config_url}`);
		applied = applyEngineConfig(resource, engineInfo, platform) || applied;
	}

	return { applied, error: null };
}

module.exports = {
	resolveEngineConfig,
};
