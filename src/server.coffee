Promise = require('bluebird')
childProcess = Promise.promisifyAll(require('child_process'))
express = require('express')
http = require('http')
bodyParser = require('body-parser')
WebSocket = require('ws')

config = {
  httpPort: process.env['HTTP_PORT'] ? 80
  streamPort: process.env['STREAM_PORT'] ? 8082
}

streamEnabled = (process.env['ENABLE_VIDEO_STREAM'] == '1')
secret = new Buffer(process.env['STREAM_API_KEY'])
killTimeout = null
killInterval = null
lastDataTime = Date.now()

startFfmpeg = ->
	if killTimeout?
		clearTimeout(killTimeout)
		killTimeout = null

	if killInterval?
		clearInterval(killInterval)
		killTimeout = null

	console.log('spawning ffmpeg...')
	ffmpeg = childProcess.spawn('bash', ['/app/bin/do_ffmpeg.sh'])
	ffmpeg.on 'exit', (code) ->
		console.log("child process exited with code " + code)
		# If it exits with 1 it probably means we have the "not enough bandwidth" problem
		# So we remove and re-add the USB device
		Promise.try ->
			if(code == 1)
				childProcess.execAync('lsusb -v')
				.then ->
					childProcess.execAync('echo 1 > /sys/bus/usb/drivers/usb/usb1/1-1/remove')
				.then ->
					childProcess.execAsync('lsusb -v')
		.then ->
			startFfmpeg()

	ffmpeg.stderr.on 'data', (data) ->
		if data.toString().match(/ fps= 0 /)
			console.log('Video froze,restarting...')
			ffmpeg.kill('SIGKILL')

	killTimeout = setTimeout ->
		killInterval = setInterval ->
			if Date.now() - lastDataTime > 1000
				console.log('ffmpeg seems dead, restarting...')
				ffmpeg.kill('SIGKILL')
		, 1000
	, 5000

if streamEnabled
	# Initiate websocket connection to server
	wsServerUrl = process.env['STREAMING_SERVER_URL']
	ws = new WebSocket(wsServerUrl)
	ws.on 'open', ->
		http.createServer (req, res) ->
			console.log(
				'Stream Connected: ' + req.socket.remoteAddress +
				':' + req.socket.remotePort
			)

			req.on 'data', (data) ->
				lastDataTime = Date.now()
				ws.send(data, { binary: true })

		.listen config.streamPort, ->
			console.log('Listening for video stream on port ' + config.streamPort)
			startFfmpeg()
