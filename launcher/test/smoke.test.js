'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(REPO_ROOT, 'dist_cfg', 'config.json');
const MODINFO_PATH = path.join(REPO_ROOT, 'modinfo.lua');
const MAKE_PACKAGE_JSON = path.join(REPO_ROOT, 'build', 'make_package_json.js');
const UPDATE_CONFIG = path.join(REPO_ROOT, 'build', 'update_launcher_config.js');

const PRODUCTION_SETS = [
	'manual-linux',
	'manual-win',
	'manual-linux-test-engine',
	'manual-win-test-engine',
];

let tmp = null;

test.before(() => {
	tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'barplus-smoke-'));
});

test.after(() => {
	fs.rmSync(tmp, { recursive: true, force: true });
});

test('dist_cfg/config.json is valid and structurally complete', () => {
	const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

	assert.equal(typeof config.title, 'string');
	assert.ok(config.title.length > 0, 'title is empty');
	assert.equal(typeof config.log_upload_url, 'string');
	assert.equal(typeof config.error_suffix, 'string');
	assert.ok(Array.isArray(config.setups), 'setups is not an array');
	assert.ok(config.setups.length > 0, 'setups is empty');
	assert.ok(Array.isArray(config.links));
	assert.ok(config.links.every((l) => typeof l === 'object' && l !== null), 'links entries are not objects');
	assert.equal(typeof config.default_springsettings, 'object');
	assert.equal(typeof config.discord_rich_presence, 'object');

	const ids = new Set();
	for (const setup of config.setups) {
		const id = setup.package.id;
		assert.equal(typeof id, 'string');
		assert.ok(id.length > 0, 'setup has empty package.id');
		assert.ok(!ids.has(id), `duplicate setup id: ${id}`);
		ids.add(id);
		assert.equal(typeof setup.package.display, 'string');
		assert.equal(typeof setup.package.platform, 'string');
		assert.equal(typeof setup.config_url, 'string');
		if ('auto_download' in setup) {
			assert.equal(typeof setup.auto_download, 'boolean');
		}
		assert.equal(typeof setup.downloads, 'object');
		if (setup.downloads.games != null) {
			assert.ok(Array.isArray(setup.downloads.games), `${id}: downloads.games is not an array`);
		}
		if (setup.downloads.resources != null) {
			assert.ok(Array.isArray(setup.downloads.resources), `${id}: downloads.resources is not an array`);
		}
		assert.equal(typeof setup.launch, 'object');
		assert.ok(Array.isArray(setup.launch.start_args));
		assert.equal(typeof setup.launch.engine, 'string');
	}

	for (const id of PRODUCTION_SETS) {
		assert.ok(ids.has(id), `missing production setup: ${id}`);
	}
});

test('production setups all resolve the same current menu build', () => {
	const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

	let commonDestination = null;
	for (const setup of config.setups) {
		if (!PRODUCTION_SETS.includes(setup.package.id)) {
			continue;
		}
		const menus = setup.downloads.resources.filter(
			(r) => (r.destination || '').indexOf('games/BYAR-Chobby') === 0,
		);
		assert.equal(menus.length, 1, `${setup.package.id}: expected exactly one menu resource`);
		const dest = menus[0].destination;
		const m = /^games\/BYAR-Chobby-(\d+)\.sdd$/.exec(dest);
		assert.ok(m, `${setup.package.id}: unexpected menu destination ${dest}`);
		if (commonDestination === null) {
			commonDestination = dest;
		} else {
			assert.equal(commonDestination, dest, 'production setups disagree on menu build');
		}
	}
	assert.ok(commonDestination !== null, 'no menu destination found in production setups');
	const url = config.setups[0].downloads.resources.find((r) => r.destination === commonDestination);
	assert.ok(url && url.url, 'menu resource is missing its url');
});

test('modinfo.lua exposes the $VERSION placeholder for the pack step', () => {
	const modinfo = fs.readFileSync(MODINFO_PATH, 'utf8');
	assert.ok(/version\s*=\s*'\$VERSION'/.test(modinfo), 'modinfo.lua version is not \$VERSION');
});

test('build/make_package_json.js stamps the package correctly', () => {
	const pkgSrc = fs.readFileSync(path.join(REPO_ROOT, 'launcher', 'package.json'), 'utf8');
	const configSrc = fs.readFileSync(CONFIG_PATH, 'utf8');
	fs.writeFileSync(path.join(tmp, 'package.json'), pkgSrc);
	fs.writeFileSync(path.join(tmp, 'config.json'), configSrc);

	const res = spawnSync(
		'node',
		[MAKE_PACKAGE_JSON, path.join(tmp, 'package.json'), path.join(tmp, 'config.json'), 'Owner/Repo', '1.500.0'],
		{ encoding: 'utf8' },
	);
	assert.equal(res.status, 0, res.stderr || 'make_package_json failed');

	const pkg = JSON.parse(fs.readFileSync(path.join(tmp, 'package.json'), 'utf8'));
	const title = JSON.parse(configSrc).title;
	assert.equal(pkg.name, title.replace(/ /g, '-'));
	assert.equal(pkg.build.artifactName, `${title}-\${version}.\${ext}`);
	assert.ok(pkg.version.match(/^1\.500\.0-/) , `unexpected version: ${pkg.version}`);
	assert.equal(pkg.repository, 'github:Owner/Repo');
	assert.deepEqual(pkg.build.publish, [{
		provider: 'github',
		owner: 'Owner',
		repo: 'Repo',
		releaseType: 'release',
	}]);
});

test('build/update_launcher_config.js updates production setups', () => {
	const configSrc = fs.readFileSync(CONFIG_PATH, 'utf8');
	const cfgPath = path.join(tmp, 'config-to-update.json');
	fs.writeFileSync(cfgPath, configSrc);

	const menuUrl = 'https://github.com/Owner/Repo/releases/download/v1.500.0-abc1234/BYAR-Chobby-9999.sdd.7z';
	const res = spawnSync('node', [UPDATE_CONFIG, cfgPath, menuUrl, '9999'], { encoding: 'utf8' });
	assert.equal(res.status, 0, res.stderr || 'update_launcher_config failed');

	const config = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
	for (const setup of config.setups) {
		const id = setup.package.id;
		if (!PRODUCTION_SETS.includes(id)) {
			continue;
		}
		const menus = setup.downloads.resources.filter(
			(r) => (r.destination || '').indexOf('games/BYAR-Chobby') === 0,
		);
		assert.equal(menus.length, 1, `${id}: expected one menu resource`);
		assert.equal(menus[0].url, menuUrl, `${id}: wrong menu url`);
		assert.equal(menus[0].destination, 'games/BYAR-Chobby-9999.sdd', `${id}: wrong menu destination`);
		assert.equal(menus[0].extract, true, `${id}: menu should extract`);
		assert.deepEqual(setup.launch.start_args, ['--menu', 'BYAR Chobby 9999'], `${id}: wrong start args`);
	}
});

test('dev setups are left untouched by update_launcher_config.js', () => {
	const configSrc = fs.readFileSync(CONFIG_PATH, 'utf8');
	const cfgPath = path.join(tmp, 'config-dev.json');
	const original = JSON.parse(configSrc);
	const devBefore = JSON.stringify(original.setups.filter((s) => !PRODUCTION_SETS.includes(s.package.id)));

	fs.writeFileSync(cfgPath, configSrc);
	const res = spawnSync(
		'node',
		[UPDATE_CONFIG, cfgPath, 'https://github.com/Owner/Repo/releases/download/v1.500.0-x/BYAR-Chobby-9999.sdd.7z', '9999'],
		{ encoding: 'utf8' },
	);
	assert.equal(res.status, 0, res.stderr || 'update_launcher_config failed');

	const updated = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
	const devAfter = JSON.stringify(updated.setups.filter((s) => !PRODUCTION_SETS.includes(s.package.id)));
	assert.equal(devBefore, devAfter, 'dev setups were modified');
});

test('menu pack stage: version substitution and 7z round-trip verify', (t) => {
	const sevenZ = '7z';
	if (spawnSync(sevenZ, ['--help'], { stdio: 'ignore' }).error) {
		t.skip('no 7z binary available');
		return;
	}

	const stage = path.join(tmp, 'stage');
	fs.mkdirSync(stage, { recursive: true });
	fs.writeFileSync(path.join(stage, 'modinfo.lua'), "version = '$VERSION'\n");
	fs.writeFileSync(path.join(stage, 'foo.txt'), 'hello smoke');

	const modinfoPath = path.join(stage, 'modinfo.lua');
	let modinfo = fs.readFileSync(modinfoPath, 'utf8');
	modinfo = modinfo.replace(/\$VERSION/g, '9999');
	fs.writeFileSync(modinfoPath, modinfo);
	assert.ok(fs.readFileSync(modinfoPath, 'utf8').includes("version = '9999'"));

	const archive = path.join(tmp, 'BYAR-Chobby-9999.sdd.7z');
	let res = spawnSync(sevenZ, ['a', '-bd', archive, '.'], { cwd: stage, encoding: 'utf8' });
	assert.equal(res.status, 0, res.stderr || '7z create failed');

	res = spawnSync(sevenZ, ['l', archive], { encoding: 'utf8' });
	assert.equal(res.status, 0, res.stderr || '7z list failed');
	assert.ok(res.stdout.includes('modinfo.lua'), 'archive missing modinfo.lua');
	assert.ok(res.stdout.includes('foo.txt'), 'archive missing foo.txt');
});
