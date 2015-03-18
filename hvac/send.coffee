###
    C:\apps\insteon\send.coffee
###

showIMTraffic     = no
showIMnaks        = no
showDeviceTraffic = no
showRetries       = no

hvac     = require './hvac'
getStats = require './get_stats'
cmd      = require './commands'
serial   = require './serial'
utils    = require './utils'

dbg  = utils.dbg  'send'
dbg2 = utils.dbg2 'send'

send = exports

lastSendToIM = 0

send.sendToIM = (cmdData, cb) ->

	now = Date.now()
	if (now < lastSendToIM + 4000) and hvac.appState isnt 'connecting'
		cbDone
		setTimeout (-> send.sendToIM cmdData, cb), 1000
		return
	lastSend = now

	cbDone = no
	done = (err) ->
		if not cbDone
			cbDone = yes
			serial.port.removeListener 'message', listenForAck
			cb err

	listenForAck = (data) ->
		if cbDone then return

		if data[0] is 0x15
			if showIMnaks then dbg 'nack   im'
			setTimeout (-> serial.port.write new Buffer cmdData), utils.nakRetry
			return

		if showIMTraffic then dbg 'recv   im', utils.arr2hexStr data, yes

		if data[0] is 0x02 and data[1] is 0x60
			if data.length isnt 9 or data[data.length-1] isnt 6 then return

		else if data.length isnt cmdData.length + 1 or data[data.length-1] isnt 6 then return

		for i in [0...cmdData.length]
			if data[i] isnt cmdData[i] then return

		done null

	serial.port.on 'message', listenForAck

	triesLeft = utils.maxRetries

	do trySend = (retry = no) ->
		if showIMTraffic and not retry then dbg 'send   im', utils.arr2hexStr cmdData, yes

		serial.port.write new Buffer cmdData

		setTimeout ->
			if cbDone then return
			if triesLeft-- is 0
				done 'ERROR sendToIM ack timeout'
				return
			if showRetries then dbg 'rtry   im', utils.arr2hexStr cmdData, yes
			trySend yes
		, utils.IMtimeout

send2deviceBusy  = no
send2deviceQueue = []

send.sendToDevice = (cmdData, cb) ->

	if cmdData then send2deviceQueue.push [cmdData, cb]

	if send2deviceBusy then setTimeout send.sendToDevice, 100; return

	if send2deviceQueue.length then [cmdData, cb] = send2deviceQueue.shift()
	else return

	listenForAck = gotMsg = null
	cbDone = no; send2deviceBusy = yes

	done = (err) ->
		if not cbDone
			if showDeviceTraffic then dbg 'done  dev', err ? ''
			serial.port.removeListener 'message', gotMsg
			cbDone = yes
			send2deviceBusy = no
			cb? err

	gotMsg = (ackData) ->
		if cbDone then return

		if showDeviceTraffic then dbg 'rmsg  dev', utils.arr2hexStr ackData, yes

		if  ackData.length isnt 11			  or
				ackData[1] isnt 0x50 		  or
				ackData[2] isnt cmdData[2] 	  or
				ackData[3] isnt cmdData[3] 	  or
				ackData[4] isnt cmdData[4] 	  or
				ackData[5] isnt 0x24 		  or
				ackData[6] isnt 0x13 		  or
				ackData[7] isnt 0xfd 		  or
				(ackData[8] & 0x20) isnt 0x20 or
				ackData[ 9] isnt cmdData[6]   or
				ackData[10] isnt cmdData[7]
			return

		if showDeviceTraffic then dbg 'recv  dev', utils.arr2hexStr ackData, yes

		done null

	if showDeviceTraffic then dbg 'lstn  dev'
	serial.port.on 'message', gotMsg

	triesLeft = utils.maxRetries

	do trySend = ->

		if showDeviceTraffic then dbg 'send  dev', utils.arr2hexStr cmdData, yes

		send.sendToIM cmdData, (err) ->
			if cbDone then return

			if err then done 'ERROR sendToDevice cmd ' + err; done err; return

			setTimeout ->
				if cbDone then return
				if triesLeft-- is 0 then done 'ERROR sendToDevice ack timeout'; return
				if showRetries then dbg 'rtry  dev', utils.arr2hexStr cmdData, yes
				trySend()
			, utils.deviceTimeout

setTimeout ->
	send.sendToIM cmd.getVersion, (err) ->
		if err
			dbg 'ERROR getVersion', err
			if hvac.argv is 'off' then dbg 'off finished: failed'
			process.exit 0
			return

		send.sendToIM cmd.setIMflag, (err) ->
			if err
				dbg 'ERROR setIMflag', err
				if hvac.argv is 'off' then dbg 'off finished: failed'
				process.exit 0
				return
			hvac.appState = 'clearing relays'
			dbg 'connected'
	, yes
, 2000

