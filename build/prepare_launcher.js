'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { spawnSync } = require('child_process');

const { createPackagejson } = require('./make_package_json');

const REPO_ROOT = path.resolve(__dirname, '..');
const DIST_CFG = path.join(REPO_ROOT, 'dist_cfg');
const PATCH_DIR = path.join(REPO_ROOT, 'build', 'patches');

const UPSTREAM_URL = 'https://gitlab.com/TorGibson/beyond-bar-launcher.git';
const UPSTREAM_REF = process.env.BBL_REF || 'v0.1.1';

function run(cmd, args, cwd) {
	const result = spawnSync(cmd, args, { cwd, stdio: 'inherit' });
	if (result.error) {
		throw result.error;
	}
	if (result.status !== 0) {
		throw new Error(`${cmd} ${args.join(' ')} failed with ${result.status}`);
	}
}

function isEmptyDir(dir) {
	if (!fs.existsSync(dir)) {
		return true;
	}
	return fs.readdirSync(dir).length === 0;
}

function fetch(dir) {
	if (!isEmptyDir(dir)) {
		return;
	}
	fs.mkdirSync(path.dirname(dir), { recursive: true });
	run('git', ['clone', '--depth', '1', '--branch', UPSTREAM_REF, UPSTREAM_URL, dir]);
}

function assertUpstream(dir) {
	for (const required of ['package.json', 'src/launcher_wizard.js', 'src/launcher_args.js']) {
		assert.ok(fs.existsSync(path.join(dir, required)), `Not a beyond-bar-launcher checkout: missing ${required}`);
	}
}

function overlayDistCfg(dir) {
	run('cp', ['-r', `${DIST_CFG}/config.json`, path.join(dir, 'src', 'config.json')]);

	const rendererDst = path.join(dir, 'src', 'renderer');
	fs.mkdirSync(rendererDst, { recursive: true });
	run('cp', ['-r', `${DIST_CFG}/renderer/.`, rendererDst]);

	fs.mkdirSync(path.join(dir, 'build'), { recursive: true });
	run('cp', ['-r', `${DIST_CFG}/build/.`, path.join(dir, 'build')]);

	const launcherSrc = path.join(DIST_CFG, 'launcher_src');
	fs.cpSync(launcherSrc, path.join(dir, 'src'), { recursive: true });
}

function applyPatches(dir) {
	if (!fs.existsSync(PATCH_DIR)) {
		return;
	}
	const patches = fs.readdirSync(PATCH_DIR)
		.filter(f => f.endsWith('.patch'))
		.sort();
	const root = path.dirname(path.resolve(dir));
	for (const patch of patches) {
		const file = path.join(PATCH_DIR, patch);
		const check = spawnSync('git', ['apply', '-R', '--check', file], { cwd: root });
		if (check.status === 0) {
			console.log(`${patch} is already applied, skipping`);
			continue;
		}
		try {
			run('git', ['apply', '--ignore-whitespace', file], root);
		} catch (error) {
			throw new Error(`${patch} does not apply to ${dir}: ${error.message}`);
		}
	}
}

function assertBuildFields(dir) {
	const pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'));
	assert.ok(pkg.build && typeof pkg.build === 'object', 'Upstream package.json has no build block');
}

function prepareLauncher(dir, repoFullName, version) {
	fetch(dir);
	assertUpstream(dir);
	overlayDistCfg(dir);
	applyPatches(dir);
	assertBuildFields(dir);
	createPackagejson(path.join(dir, 'package.json'), path.join(DIST_CFG, 'config.json'), repoFullName, version);
}

module.exports = {
	prepareLauncher,
	overlayDistCfg,
	applyPatches,
	UPSTREAM_URL,
	UPSTREAM_REF,
};

if (require.main === module) {
	const args = process.argv;
	if (args.length < 4) {
		console.error('Usage: prepare_launcher.js <launcher-dir> <repo-full-name> <version>');
		process.exit(1);
	}
	try {
		prepareLauncher(args[2], args[3], args[4]);
	} catch (err) {
		console.error(err.message);
		process.exit(1);
	}
}
