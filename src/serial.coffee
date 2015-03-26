###
    C:\apps\insteon\serial.coffee
###

showSendData = no
showRecvData = no
showXbeeData = no

portName = '/dev/ttyUSB1'
portXBee = '/dev/ttyUSB2'

getStats = require './get_stats'
utils   = require './utils'
cmd     = require './commands'

dbg  = utils.dbg 'serial'

SerialPort = require('serialport').SerialPort

voltsAtZeroC = 1.05
voltsAt25C   = 0.83
voltsPerC    = (voltsAtZeroC - voltsAt25C) / 25

serial = exports

parser = ->
	data = []
	messages = []
	msglen = -1
	start = 0

	(emitter, buffer) ->
#		console.log 'buffer in', buffer, buffer.length

		for b in buffer
			if start and Date.now() - start > utils.INSTEON_PLM_TIME_LIMIT
				start = Date.now()
				if data.length
					dbg 'parser: Incomplete message ( '+
						utils.arr2hexStr(data) +
						') discarded, exceeded time limit'
					data = []
				msglen = -1

			if msglen is -1
				if b is utils.INSTEON_PLM_NAK
					msglen = 1

				else if b is utils.INSTEON_PLM_START
					msglen = 0
					start = Date.now()
					if data.length
						dbg "parser: Incomplete message (" +
							arr2hexStr(data) +
							") discarded, unknown command length"
						msglen = -1
						data = []

			data.push b

			if data.length is 2 and msglen is 0
				cmdByt = utils.dec2hex data[1]
				if not (msglen = utils.INSTEON_MESSAGES[cmdByt]?.len) then msglen = -1

			else if data.length is 6 and utils.dec2hex(data[1]) is "62"
				msglen = (if (data[5] & 0x10) is 0x10 then 23 else 9)

			else if data.length > 0 and msglen is data.length
			  messages.push data
			  data = []
			  msglen = -1
			  start = 0

#			b = utils.dec2hex b
#			console.log {b, msglen, data, messages}

#		console.log 'end buffer', {b, msglen, data, messages}

		for msg in messages
			if showRecvData then dbg 'recv    srl', utils.arr2hexStr msg, yes
			emitter.emit 'message', msg
		messages = []

serial.port = new SerialPort portName,
    baudrate: 19200,
    databits: 8,
    stopbits: 1,
    parity: 0,
    flowcontrol: 0,
    parser: parser()

serial.port.on 'error', (err) ->
	console.log 'ERROR from port', err


#xBeeParser = (emitter, buffer) ->
#	console.log 'xBeeParser', emitter, buffer

XBeePort = new SerialPort portXBee,
    baudrate: 9600,
    databits: 8,
    stopbits: 1,
    parity: 0,
    flowcontrol: 0,

serial.xBeeCb = null

newTemp = (data) ->
	srcAddr = 0
	for idx in [4...12] by 1
		srcAddr *= 256
		srcAddr += data[idx]
	room = switch srcAddr
		when 0x0013a20040baffa4 then 'tvRoom'
		when 0x0013a20040b3a903 then 'master'
		when 0x0013a20040b3a954 then 'kitchen'
		when 0x0013a20040b3a592 then 'guest'
		when 0x0013A20040BD2529 then 'acLine'
		else null
	if not room then return

	volts  = ((data[19] * 256 + data[20]) / 1024) * 1.2

	if room is 'acLine'
		if data.length isnt 24
			console.log 'acLine frame len error', data
			return

		temp   = ((voltsAtZeroC - volts ) / voltsPerC) * 9/5 + 32
		serial.xBeeCb? 'intake', temp

		volts = ((data[21] * 256 + data[22]) / 1024) * 1.2
		temp   =  (voltsAtZeroC - volts) / voltsPerC
		serial.xBeeCb? 'acLine', temp

	else
		if data.length isnt 22
			console.log 'frame len error', data
			return

		temp  = volts * 100
		serial.xBeeCb? room, temp

frameBuf = []

getFrameLen = (index) ->
	if frameBuf.length < index+4 then return 0
	if frameBuf[index+0] is 0x7e and
			(frameLen = frameBuf[index+1]*256 + frameBuf[index+2] + 4) and
			frameLen in [22,24] and frameBuf[index+3] is 0x92
		frameLen
	else 0

assembleFrame = (data) ->
	# dbg 'assembleFrame data', data

	for i in [0...data.length] then frameBuf.push data[i]

	loop
		if (frameLen = getFrameLen 0) and frameBuf.length >= frameLen
			frame = frameBuf.splice 0, frameLen
			cksum = 0
			for byte in frame[3..frameLen-2] then cksum += byte
			cksum &= 0xff
			if (0xff - cksum) isnt frame[frameLen-1]
				console.log 'xBee checksum error', frame
				frameBuf = []
			else
				newTemp frame
		else
			break

	for index in [0..frameBuf.length-4]
		if (frameLen = getFrameLen index)
			frameBuf.splice 0, index
			break

XBeePort.on 'open', ->
	dbg 'XBee Port open'
	XBeePort.on 'data', assembleFrame

XBeePort.on 'error', (err) ->
	console.log 'ERROR from xBee port', err
