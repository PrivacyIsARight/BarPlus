const { bridge } = require('../spring_api');
const log_uploader = require('../log_uploader');

bridge.register('UploadLog', () => {
	log_uploader.upload()
		.then(obj => {
			bridge.send('UploadLogFinished', {
				url : obj.url
			});
		})
		.catch(err => {
			bridge.send('UploadLogFailed', {
				msg : err
			});
		});
});
