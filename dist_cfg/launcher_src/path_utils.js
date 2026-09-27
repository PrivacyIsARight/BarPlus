'use strict';

const fs = require('fs');
const path = require('path');

function realpathOf(target) {
	let current = path.resolve(target);
	const tail = [];
	while (true) {
		try {
			return path.join(fs.realpathSync(current), ...tail);
		} catch (e) {
			const parent = path.dirname(current);
			if (parent === current) {
				return path.join(current, ...tail);
			}
			tail.unshift(path.basename(current));
			current = parent;
		}
	}
}

function resolveInside(base, target) {
	if (typeof target !== 'string' || target.length === 0 || target.includes('\0')) {
		return null;
	}
	const baseReal = realpathOf(base);
	const targetReal = realpathOf(path.resolve(base, target));
	const rel = path.relative(baseReal, targetReal);
	if (rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel))) {
		return targetReal;
	}
	return null;
}

function archiveEntryInside(base, entryName) {
	if (typeof entryName !== 'string' || entryName.length === 0) {
		return false;
	}
	return resolveInside(base, entryName.replace(/\\/g, '/')) !== null;
}

module.exports = {
	resolveInside: resolveInside,
	archiveEntryInside: archiveEntryInside,
};
