'use strict';

const fs = require('fs');
const assert = require('assert');

function createPackagejson (packageJson, configJson, repoFullName, version) {
	const configStr = fs.readFileSync(configJson);
	const config = JSON.parse(configStr);

	assert(config.title != null, 'Missing config title');

	const repoDotName = repoFullName.replace(/\//g, '.');

	const packageTemplate = JSON.parse(fs.readFileSync(packageJson).toString());
	packageTemplate.name = config.title.replace(/ /g, '-');
	// eslint-disable-next-line no-template-curly-in-string
	packageTemplate.build.artifactName = config.title + '-${version}.${ext}';

	const uniqueIdentifier = process.env.GITHUB_SHA ? process.env.GITHUB_SHA.substring(0, 7) : Date.now().toString().substring(5);
	packageTemplate.version = `${version}-${uniqueIdentifier}`;

	const [owner, repo] = repoFullName.split('/');
	packageTemplate.repository = `github:${repoFullName}`;
	packageTemplate.build.appId = `com.springrts.launcher.${repoDotName}`;
	packageTemplate.build.publish = [{
		provider: "github",
		owner: owner,
		repo: repo,
		releaseType: "release"
	}];

	if (config.dependencies != null) {
		packageTemplate.dependencies = packageTemplate.dependencies || {};
		for (const dependency in config.dependencies) {
			packageTemplate.dependencies[dependency] = config.dependencies[dependency];
		}
	}

	fs.writeFileSync(packageJson, JSON.stringify(packageTemplate, null, 2), 'utf8');
}

if (require.main === module) {
	const args = process.argv;
	if (args.length < 6) {
		console.log('Wrong arguments');
		process.exit(-1);
	}

	createPackagejson(args[2], args[3], args[4], args[5]);
}
