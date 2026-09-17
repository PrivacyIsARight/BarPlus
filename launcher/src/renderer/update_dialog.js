'use strict';

const { ipcRenderer } = require('electron');

window.addEventListener('load', async () => {
	/** @type {import("electron-updater").UpdateInfo} */
	const updateInfo = await ipcRenderer.invoke('get-update-info');

	document.getElementById('new-version').textContent = updateInfo.version;
	const dateStr = new Date(updateInfo.releaseDate)
		.toLocaleString('en-US', {month: 'long', year: 'numeric', day: 'numeric'});
	document.getElementById('new-version-date').textContent = dateStr;

	if (updateInfo.releaseNotes) {
		const md = document.getElementById('markdown-block-template').content.cloneNode(true);
		md.querySelector('.markdown-body').innerHTML = updateInfo.releaseNotes;

		// Open links in external browser.
		md.querySelectorAll('a').forEach(a => {
			a.setAttribute('target', '_blank');
		});

		// We use shadow DOM to prevent UI CSS from bulma interfering with the markdown styling.
		const shadow = document.getElementById('dialog-release-notes-text').attachShadow({ mode: 'open' });
		shadow.appendChild(md);
	} else {
		document.getElementById('dialog-release-notes').innerHTML = '';
	}

	document.getElementById('btn-update').addEventListener('click', () => {
		ipcRenderer.send('update-dialog-result', true);
	});

	document.getElementById('btn-skip').addEventListener('click', () => {
		ipcRenderer.send('update-dialog-result', false);
	});
});
