'use-strict';

// This module is for including in both renderer and main process and purpose
// is to hardcoded all the constants related to the window dimensions.

const dimensions = {
	windowHeight: 388,
	windowWidth: 800,
	infoboxHeight: 362,
};

// On Windows, we need to include titlebar in the window height, yes, this is
// a magic hardcoded variable... Unfortunatelly the useContentSize is not
// reliable.
dimensions.osWindowHeight = dimensions.windowHeight;
if (process.platform === 'win32') {
	dimensions.osWindowHeight += 23;
}

module.exports = dimensions;
