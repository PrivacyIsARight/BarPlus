'use strict';

const fs = require('fs');

const PRODUCTION_SETS = [
	'manual-linux',
	'manual-win',
	'manual-linux-test-engine',
	'manual-win-test-engine',
];

function updateLauncherConfig(configJson, menuUrl, buildNum) {
	const config = JSON.parse(fs.readFileSync(configJson, 'utf8'));

	for (const setup of config.setups) {
		if (!PRODUCTION_SETS.includes(setup.package.id)) {
			continue;
		}

		const resources = setup.downloads.resources;
		const entry = {
			url: menuUrl,
			destination: `games/BYAR-Chobby-${buildNum}.sdd`,
			extract: true,
		};

		const idx = resources.findIndex((r) => (r.destination || '').indexOf('games/BYAR-Chobby') === 0);
		if (idx >= 0) {
			resources[idx] = entry;
		} else {
			resources.push(entry);
		}

		setup.launch.start_args = ['--menu', `BYAR Chobby ${buildNum}`];
	}

	fs.writeFileSync(configJson, JSON.stringify(config, null, 2) + '\n');
}

if (require.main === module) {
	const args = process.argv;
	if (args.length < 5) {
		console.error('Usage: update_launcher_config.js <config.json> <menu-url> <build-num>');
		process.exit(1);
	}
	updateLauncherConfig(args[2], args[3], args[4]);
}

module.exports = { updateLauncherConfig };