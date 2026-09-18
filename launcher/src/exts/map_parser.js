const fs = require('fs');

const { MapParser } = require('spring-map-parser');

const { bridge } = require('../spring_api');
const { log } = require('../spring_log');
const springPlatform = require('../spring_platform');
const { resolveInside } = require('../fs_utils');
const path7za = require('../path_7za');

let concurrentCalls = 0;

bridge.register('ParseMiniMap', async command => {
	const destinationPath = resolveInside(springPlatform.writePath, command.destination);
	const miniMapSize = command.miniMapSize || 4;

	if (destinationPath == null) {
		log.error(`ParseMiniMap: rejecting destination outside the game directory: ${command.destination}`);
		return;
	}
	const mapPath = resolveInside(springPlatform.writePath, command.mapPath);
	if (mapPath == null) {
		log.error(`ParseMiniMap: rejecting map path outside the game directory: ${command.mapPath}`);
		return;
	}
	if (!fs.existsSync(path7za)) {
		log.error(`Failed to find 7za at: ${path7za}, minimap cannot be parsed`);
		return;
	}

	while (concurrentCalls > 0) {
		await new Promise(resolve => setTimeout(resolve, 1000));
	}
	concurrentCalls++;
	log.info(`Parsing minimap from ${destinationPath}`);
	try {
		const parser = new MapParser({ verbose: true, mipmapSize: miniMapSize, skipSmt: true, path7za: path7za });
		const map = await parser.parseMap(mapPath);
		await map.miniMap.writeAsync(destinationPath);
	} catch(err) {
		log.error(`Failed to parse minimap from: ${destinationPath}`);
		log.error(err);
	} finally {
		concurrentCalls--;
	}

	bridge.send('ParseMiniMapFinished', {
		mapPath : command.mapPath,
		destinationPath: destinationPath
	});
});
