'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..');
const PREPARE = path.join(REPO_ROOT, 'build', 'prepare_launcher.js');

const UPSTREAM_ARGS = `\t.option('write-path', {
		alias: 'w',
		type: 'string',
		description: 'Path to directory holding data'
	})
`;

const UPSTREAM_IMPORT = `const { handleConfigUpdate, handleConfigReload } = require('./launcher_config_update');
`;

const UPSTREAM_RESOURCES = `			config.downloads.resources.forEach((resource) => {
`;

let tmp = null;
let launcherDir = null;

function makeUpstream(dir) {
	fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
	fs.mkdirSync(path.join(dir, 'build'), { recursive: true });
	fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'spring-launcher', build: {} }, null, 2));
	fs.writeFileSync(path.join(dir, 'src', 'launcher_args.js'), `'use strict';\n${UPSTREAM_ARGS}.argv;\n`);
	fs.writeFileSync(path.join(dir, 'src', 'launcher_wizard.js'), `'use strict';\n${UPSTREAM_IMPORT}\nclass Wizard {\n\tgenerateSteps() {\n\t\tconst asyncSteps = [];\n\t\tconst steps = [];\n${UPSTREAM_RESOURCES}\t}\n}\n`);
	fs.writeFileSync(path.join(dir, 'build', 'icon.png'), 'upstream-icon');
}

function prepare() {
	return spawnSync('node', [PREPARE, launcherDir, 'Owner/Repo', '1.500.0'], { encoding: 'utf8' });
}

function read(...parts) {
	return fs.readFileSync(path.join(launcherDir, ...parts), 'utf8');
}

test.before(() => {
	tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'barplus-prepare-'));
	launcherDir = path.join(tmp, 'launcher');
	makeUpstream(launcherDir);
});

test.after(() => {
	fs.rmSync(tmp, { recursive: true, force: true });
});

test('prepare overlays the private config onto the fetched launcher', () => {
	const res = prepare();
	assert.equal(res.status, 0, res.stderr || 'prepare_launcher failed');

	const config = JSON.parse(read('src', 'config.json'));
	assert.equal(config.setups[0].config_url, 'https://raw.githubusercontent.com/PrivacyIsARight/BarPlus/master/dist_cfg/config.json');
	assert.ok(config.setups[0].launch.start_args[1].startsWith('BYAR Chobby '));
});

test('prepare leaves the unrecoil engine resolver out of the launcher', () => {
	assert.equal(fs.existsSync(path.join(launcherDir, 'src', 'engine_config.js')), false);
	assert.doesNotMatch(read('src', 'launcher_args.js'), /unrecoil/);
	assert.doesNotMatch(read('src', 'launcher_wizard.js'), /engine_config/);
	assert.doesNotMatch(read('src', 'config.json'), /engine_config_url/);
});

test('prepare copies every launcher source overlay, including nested handlers', () => {
	const overlay = path.join(REPO_ROOT, 'dist_cfg', 'launcher_src');
	const sources = [];
	const walk = (dir, prefix) => {
		for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
			if (entry.isDirectory()) {
				walk(path.join(dir, entry.name), `${prefix}${entry.name}/`);
			} else {
				sources.push(prefix + entry.name);
			}
		}
	};
	walk(overlay, '');

	assert.ok(sources.length > 1, 'expected the overlay to contain nested handlers');
	assert.ok(sources.some((s) => s.startsWith('exts/')), 'expected overlay files under exts/');

	for (const source of sources) {
		assert.ok(
			fs.existsSync(path.join(launcherDir, 'src', source)),
			`overlay file was not copied into the launcher: src/${source}`,
		);
	}
});

test('prepare stamps the package with the BarPlus identity', () => {
	const pkg = JSON.parse(read('package.json'));
	assert.equal(pkg.version.match(/^1\.500\.0-/) ? true : false, true);
	assert.equal(pkg.repository, 'github:Owner/Repo');
	assert.deepEqual(pkg.build.publish[0], { provider: 'github', owner: 'Owner', repo: 'Repo', releaseType: 'release' });
});

test('prepare is idempotent', () => {
	const before = read('src', 'config.json');
	prepare();
	prepare();
	assert.equal(read('src', 'config.json'), before);
	assert.deepEqual(
		JSON.parse(read('src', 'config.json')).setups[0].downloads.resources.filter((r) => 'engine_config_url' in r),
		[],
	);
});

test('prepare rejects a directory that is not a launcher checkout', () => {
	const bogus = path.join(tmp, 'bogus');
	fs.mkdirSync(path.join(bogus, 'src'), { recursive: true });
	fs.writeFileSync(path.join(bogus, 'package.json'), JSON.stringify({ name: 'nope', build: {} }));

	const res = spawnSync('node', [PREPARE, bogus, 'Owner/Repo', '1.500.0'], { encoding: 'utf8' });
	assert.notEqual(res.status, 0, 'prepare should not succeed against a non-launcher directory');
	assert.match(res.stderr, /Not a beyond-bar-launcher checkout/);
});
