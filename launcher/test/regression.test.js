'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const extractZip = require('extract-zip');
const { list: list7z } = require('node-7z');
const { path7za } = require('7zip-bin');

const { archiveEntryInside } = require('../src/path_utils');

const SEVENZ = '7z';

let tmp = null;
let good = null;
let evil = null;

function have7z() {
	const probe = spawnSync(SEVENZ, ['--help'], { stdio: 'ignore' });
	return !probe.error;
}

function makeZip(entries, outPath) {
	const script = [
		'import zipfile, sys',
		'inp, out = sys.argv[1], sys.argv[2]',
		'zf = zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED)',
		'for line in inp.split("\\n"):',
		'    if not line:',
		'        continue',
		'    zf.writestr(line, "x")',
		'zf.close()',
	].join('\n');
	const res = spawnSync('python3', ['-c', script, entries.join('\n'), outPath], { encoding: 'utf8' });
	assert.equal(res.status, 0, res.stderr || 'failure creating zip');
}

function listEntries(archive) {
	return new Promise((resolve, reject) => {
		const lst = list7z(archive, { $bin: path7za });
		const names = [];
		lst.on('data', (d) => {
			if (d && d.file) {
				names.push(d.file);
			}
		});
		lst.on('error', reject);
		lst.on('end', () => resolve(names));
	});
}

function validateAll(archive, destination) {
	return listEntries(archive).then((names) => {
		for (const name of names) {
			if (!archiveEntryInside(destination, name)) {
				throw new Error(`Archive entry escapes the destination directory: ${name}`);
			}
		}
		return names;
	});
}

test.before(() => {
	tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'barplus-regression-'));
	good = path.join(tmp, 'good.zip');
	evil = path.join(tmp, 'evil.zip');
	makeZip(['a.txt', 'nested/b.txt', 'z/c.txt'], good);
	makeZip(['a.txt', '../escape.txt', 'nested/b.txt'], evil);
});

test.after(() => {
	fs.rmSync(tmp, { recursive: true, force: true });
});

test('compatible archive contents are extracted by extract-zip', async (t) => {
	const dest = path.join(tmp, 'good-extracted');
	fs.mkdirSync(dest, { recursive: true });
	await extractZip(good, { dir: dest });
	assert.ok(fs.existsSync(path.join(dest, 'a.txt')));
	assert.ok(fs.existsSync(path.join(dest, 'nested', 'b.txt')));
	assert.ok(fs.existsSync(path.join(dest, 'z', 'c.txt')));
});

test('extract-zip rejects traversal when unwrapping would escape', async (t) => {
	const dest = path.join(tmp, 'evil-extracted');
	fs.mkdirSync(dest, { recursive: true });
	let threw = false;
	try {
		await extractZip(evil, { dir: dest });
	} catch {
		threw = true;
	}
	assert.ok(threw, 'extract-zip should refuse to extract the malicious archive');
});

test('7za lists compatible archive and every entry stays inside', { skip: !have7z() }, async () => {
	const names = await listEntries(good);
	assert.ok(names.includes('a.txt'));
	assert.ok(names.includes('nested/b.txt'));
	assert.ok(names.includes('z/c.txt'));
	const dest = path.join(tmp, 'destination');
	await validateAll(good, dest);
});

test('7za listing exposes traversal entries and validation rejects them', { skip: !have7z() }, async (t) => {
	const dest = path.join(tmp, 'destination');
	const names = await listEntries(evil);
	const bad = names.filter((n) => !archiveEntryInside(dest, n));
	assert.ok(bad.some((n) => n.indexOf('..') !== -1), 'expected a traversal entry in the fixture');
	await assert.rejects(() => validateAll(evil, dest), /escapes the destination/);
});

test('7z archive round-trip: create, list, and validate', { skip: !have7z() }, async () => {
	const stage = path.join(tmp, '7z-stage');
	fs.mkdirSync(stage, { recursive: true });
	fs.writeFileSync(path.join(stage, 'one.txt'), '1');
	fs.mkdirSync(path.join(stage, 'sub'), { recursive: true });
	fs.writeFileSync(path.join(stage, 'sub', 'two.txt'), '2');

	const archive = path.join(tmp, 'real.7z');
	const create = spawnSync(SEVENZ, ['a', '-bd', archive, '.'], { cwd: stage, encoding: 'utf8' });
	assert.equal(create.status, 0, create.stderr || '7z create failed');

	const names = await listEntries(archive);
	assert.ok(names.includes('one.txt'));
	assert.ok(names.includes('sub/two.txt'));
	await validateAll(archive, path.join(tmp, 'dest'));
});