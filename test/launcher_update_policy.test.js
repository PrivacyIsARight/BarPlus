'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.join(__dirname, '..');
const CONFIG_PATH = path.join(REPO_ROOT, 'dist_cfg', 'config.json');

test('manual setup disable_launcher_update_dialog placement is correct', () => {
	const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
	const config = JSON.parse(raw);

	assert.equal(Object.prototype.hasOwnProperty.call(config, 'disable_launcher_update_dialog'), false,
		'disable_launcher_update_dialog must not be at top level');

	assert.ok(Array.isArray(config.setups), 'setups must be an array');
	for (let i = 0; i < config.setups.length; i++) {
		const setup = config.setups[i];
		const pkg = setup.package || {};
		const id = pkg.id || setup.id || '';
		if (typeof id === 'string' && id.startsWith('manual-')) {
			assert.equal(setup.disable_launcher_update_dialog, true,
				`setup ${id} must have disable_launcher_update_dialog=true`);
		}
		if (typeof id === 'string' && id.startsWith('dev-')) {
			assert.equal(Object.prototype.hasOwnProperty.call(setup, 'disable_launcher_update_dialog'), false,
				`dev setup ${id} must not have disable_launcher_update_dialog`);
		}
	}
});
