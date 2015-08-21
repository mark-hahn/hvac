###
    C:\apps\insteon\serial.coffee
###

utils    = require './utils'

dbg  = utils.dbg 'serial'

SerialPort = require('serialport').SerialPort

voltsAtZeroC = 1.05
voltsAt25C   = 0.83
voltsPerC    = (voltsAtZeroC - voltsAt25C) / 25

serial = exports

XBeePort = new SerialPort '/dev/xbee',
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
		when 0x0013a20040c33695 then 'tvRoom' 
		when 0x0013a20040b3a592 then 'kitchen' 
		when 0x0013a20040b3a903 then 'master'  
		when 0x0013a20040b3a954 then 'guest'
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
    
		console.log 'got xbee', {room, temp}

frameBuf = []

getFrameLen = (index) ->
	if frameBuf.length < index+4 then return 0
	if frameBuf[index+0] is 0x7e and
			(frameLen = frameBuf[index+1]*256 + frameBuf[index+2] + 4) and
			frameLen in [22,24] and frameBuf[index+3] is 0x92
		frameLen
	else 0

assembleFrame = (data) ->
	console.log 'assembleFrame', utils.arr2hexStr data, yes
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


###
contents of /etc/udev/rules.d/99-home-serial-usb.rules
SUBSYSTEMS=="usb-serial", DRIVERS=="cp210x", ATTRS{port_number}=="0", SYMLINK+="davis"
SUBSYSTEMS=="usb", ATTRS{serial}=="A6028N89", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="insteon"
SUBSYSTEMS=="usb", ATTRS{serial}=="A5025MT6", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="xbee"
###

# rooms
# function set ZigBee Router AT
# Firmware 22A7
# ID 6392
# SC 40
# D1 ADC[2]
# PR 1FF7
# IR 1000

# acline
# function set ZigBee Router AT
# Firmware 22A7
# ID 6392
# SC 40
# D1 ADC[2]
# D2 ADC[2]
# PR 1FF3
# IR 1000

#server
# product family XB24-ZB
# function set ZigBee Coordinator API
# Firmware 21A7
# MAC: 0013A20040BAFFAD
# ID 6392
# SC 40

