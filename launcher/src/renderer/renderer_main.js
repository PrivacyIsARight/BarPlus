'use strict';

window.onload = function () {
	require('./renderer_config');
	require('./renderer_downloader');
	require('./renderer_ext');
	require('./renderer_launcher');
	require('./renderer_log');
	require('./renderer_misc');
	require('./renderer_wizard');
	require('electron').ipcRenderer.send('renderer-ready');
};
