'use strict';

const { ipcRenderer } = require('electron');

const { getCurrentWindow } = require('@electron/remote');

const dimensions = require('./dimensions');

const mainWindow = getCurrentWindow();

const { format } = require('util');
const util = require('util');

const btnShowLog = document.getElementById('btn-show-log');
const btnUploadLog = document.getElementById('btn-upload-log');
const logContent = document.getElementById('note-content');

btnShowLog.addEventListener('click', (event) => {
	event.preventDefault();

	const cl = logContent.classList;
	const windowHeight = dimensions.osWindowHeight;
	const windowWidth = dimensions.windowWidth;
	const expandedHeight = dimensions.osWindowHeight + dimensions.infoboxHeight;
	if (cl.contains('open')) {
		cl.remove('open');
		// We have to call setMinimumSize before .setSize due to Electron bug
		// https://github.com/electron/electron/issues/15560
		mainWindow.setMinimumSize(windowWidth, windowHeight);
		mainWindow.setSize(windowWidth, windowHeight);
	} else {
		cl.add('open');
		// We have to call setMinimumSize before .setSize due to Electron bug
		// https://github.com/electron/electron/issues/15560
		//
		// We also first expand the window once 1 pixel more, and then set the correct
		// size because under X11 the first window expansion for some reason is getting
		// rendering to stuck in some cases.
		mainWindow.setMinimumSize(windowWidth, expandedHeight+1);
		mainWindow.setSize(windowWidth, expandedHeight+1);
		mainWindow.setMinimumSize(windowWidth, expandedHeight);
		mainWindow.setSize(windowWidth, expandedHeight);
	}
});

btnUploadLog.addEventListener('click', () => {
	ipcRenderer.send('log-upload-ask');
});

ipcRenderer.on('log', (e, msg) => {
	const para = document.createElement('p');
	const text = format.apply(util, msg.data);
	const t = msg.date;
	const timeStr = t.getHours().toString().padStart(2, '0') + ':' +
		t.getMinutes().toString().padStart(2, '0') + ':' +
		t.getSeconds().toString().padStart(2, '0') + '.' +
		(t.getMilliseconds() / 10 | 0).toString().padStart(2, '0');
	const node = document.createTextNode(`[${timeStr} ${msg.level}] ${text}`);
	para.appendChild(node);
	para.classList.add(msg.level);
	logContent.appendChild(para);
});
