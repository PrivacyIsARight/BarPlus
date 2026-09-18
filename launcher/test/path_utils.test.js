'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { resolveInside, archiveEntryInside } = require('../src/path_utils');

let tmp = null;
let base = null;
let realBase = null;
let outside = null;
let outsideFile = null;

test.before(() => {
	tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'path-utils-test-'));
	base = path.join(tmp, 'base');
	outside = path.join(tmp, 'outside');
	outsideFile = path.join(outside, 'escape.txt');
	fs.mkdirSync(path.join(base, 'nested'), { recursive: true });
	fs.mkdirSync(outside, { recursive: true });
	fs.mkdirSync(path.join(outside, 'subdir'), { recursive: true });
	fs.writeFileSync(outsideFile, 'x');
	fs.symlinkSync(outside, path.join(base, 'evil_dir_link'));
	fs.symlinkSync(outsideFile, path.join(base, 'evil_file_link'));
	fs.symlinkSync(path.join(base, 'nested'), path.join(base, 'good_dir_link'));
	realBase = fs.realpathSync(base);
});

test.after(() => {
	if (tmp) {
		fs.rmSync(tmp, { recursive: true, force: true });
	}
});

test('.. traversal', () => {
	assert.equal(resolveInside(base, '../evil'), null);
	assert.equal(resolveInside(base, '../../evil'), null);
	assert.equal(resolveInside(base, 'nested/../../evil'), null);
	assert.equal(resolveInside(base, 'a/../..'), null);
});

test('absolute paths', () => {
	const absolute = path.join(os.homedir(), 'x');
	assert.equal(resolveInside(base, absolute), null);
	assert.equal(resolveInside(base, '/etc/passwd'), null);
	assert.equal(resolveInside(base, path.parse(base).root + 'etc/passwd'), null);
});

test('windows-style traversal', () => {
	const got = resolveInside(base, '..\\..\\evil.txt');
	if (process.platform === 'win32') {
		assert.equal(got, null);
	} else {
		assert.ok(got === null || got.startsWith(realBase));
	}
});

test('empty, non-string and NUL', () => {
	assert.equal(resolveInside(base, ''), null);
	assert.equal(resolveInside(base, undefined), null);
	assert.equal(resolveInside(base, null), null);
	assert.equal(resolveInside(base, 42), null);
	assert.equal(resolveInside(base, 'a\0b'), null);
});

test('symlink escapes', () => {
	assert.equal(resolveInside(base, 'evil_dir_link'), null);
	assert.equal(resolveInside(base, 'evil_dir_link/anything.txt'), null);
	assert.equal(resolveInside(base, 'evil_dir_link/subdir/..'), null);
	assert.equal(resolveInside(base, 'evil_file_link'), null);
});

test('valid paths inside base', () => {
	assert.equal(resolveInside(base, '.'), realBase);
	assert.equal(resolveInside(base, 'nested'), path.join(realBase, 'nested'));
	assert.equal(resolveInside(base, 'nested/deep/../x'), path.join(realBase, 'nested', 'x'));
	assert.equal(resolveInside(base, 'nested/newfile'), path.join(realBase, 'nested', 'newfile'));
	assert.equal(resolveInside(base, 'a/b/c'), path.join(realBase, 'a/b/c'));
	assert.ok(resolveInside(base, 'good_dir_link/sub').startsWith(realBase));
});

test('archive entry containment', () => {
	assert.equal(archiveEntryInside(base, 'file.txt'), true);
	assert.equal(archiveEntryInside(base, 'dir/nested/file.txt'), true);
	assert.equal(archiveEntryInside(base, '../evil'), false);
	assert.equal(archiveEntryInside(base, '..\\..\\evil'), false);
	assert.equal(archiveEntryInside(base, 'dir/../../evil'), false);
	assert.equal(archiveEntryInside(base, '/etc/passwd'), false);
	assert.equal(archiveEntryInside(base, ''), false);
	assert.equal(archiveEntryInside(base, 42), false);
});
