###
		commands.coffee
###

_ = require 'underscore'

request  = require 'request'

hvac     = require './hvac'
utils    = require './utils'
ctrl     = require './control'
getStats = require './get_stats'
setStat  = require './set_stats'

dbg  = utils.dbg  'cmd'
dbg2 = utils.dbg2 'cmd'

cmd = exports

cmd.getVersion = [0x02, 0x60]
cmd.setIMflag  = [0x02, 0x6b, 0x40]

cmd.address = address =
	relay:
		hvac:		  '387EFD'
		dampers:	'387B9E'

statUrlPfx = "http://192.168.1.103:1342/io/set/#{address.relay.hvac}/"
dampUrlPfx = "http://192.168.1.103:1342/io/set/#{address.relay.dampers}/"

arr2hex = (arr) ->
	hex = ''
	for val in arr
		txt = val.toString 16
		hex += (if txt.length < 2 then '0' + txt else txt)
	hex

hex2arr = (hex) ->
	arr = []
	for idx in [0...hex.length] by 2
		arr.push parseInt hex[idx..idx+1], 16
	arr

cmdPfx = '0262'

flags  =
	normal:   '0F'
	extended: '1F'

toExtended = (hex, byt3 = 0) ->
	arr = hex2arr hex
	sum = arr[-2..-2][0] + arr[-1..-1][0]
	for i in [1..13]
		val = (if i is 3 then byt3 else 0)
		arr.push val
		sum += val
	arr.push -sum & 0xff
#	dbg 'toExtended', {hex, byt3}, arr2hex arr
	arr

cmd.rooms = -> ['tvRoom', 'kitchen', 'master', 'guest']
cmd.idxByRoom =
	tvRoom:	 0
	kitchen: 1
	master:	 2
	guest:	 3

addrByRoom = (room) -> address.room[room]

cmd.roomByAddr = (addr) ->
	for room, roomAddr of address.room
		if roomAddr is addr then return room
	null

statusCmdByt3 = [0, 1, 9]

relayOp =
	on:	 	'45'
	off: 	'46'
	set:	'48'

fan =
	on:  relayOp.on  + '02'
	off: relayOp.off + '02'

roomIdx =
	tvRoom:	 '00'
	kitchen: '01'
	master:	 '02'
	guest:	 '03'

cmd.hvacMask = hvacMask =
	off:   	  0x00
	heat:     0x01
	cool:     0x02
	fan:      0x04
	heatExt:  0x09
	coolExt:  0x0A
	fanExt:   0x0C

cmd.roomMask = roomMask =
	tvRoom:	 '01'
	kitchen: '02'
	master:	 '04'
	guest:	 '08'

cmd.ctrlState = ctrlState =
	hvac: 	 null
	dampers: null

lastCtrlStateStr = ''
lastTime = 0

showCrlState = ->
	str = '???'
	for mode, mask of hvacMask
		if ctrlState.hvac is mask
			str = mode
			break
	hvacMode = str
	while str.length < 8 then str += ' '

	dampersOn = []

	if ctrlState.dampers is 0
		dampersStr = '<all open>'
		dampersOn = ['tvRoom', 'kitchen', 'master', 'guest']
	else if ctrlState.dampers is 15
		dampersStr = '<all closed>'
	else
		for room, mask of roomMask
			if (ctrlState.dampers & parseInt(mask, 16)) is 0
				dampersOn.push room
		dampersStr = '<' + dampersOn.join(',') + '>'
	str += dampersStr

	if str is lastCtrlStateStr then return
	lastCtrlStateStr = str

	now = Date.now()
	elapsed = ((now - lastTime) / 60000).toFixed(1)
	dbg2 '(' + elapsed + ') ' + str

	if hvacMode is 'off' then dampersOn = []

	ctrl.logSeq += 1

	# ctrl.logDb.insert {
	# 	type:    'state'
	# 	time:    now
	# 	seq:     ctrl.logSeq
	# 	elapsed: now - lastTime
	# 	sysMode: ctrl.sysMode
	# 	dampersOn, hvacMode
	# }

	lastTime = now


cmd.hvacModeCmd = (mode, ext = no, cb) ->
	# dbg 'hvacModeCmd', mode, ext

	if ext then switch mode
		when 'heat' then mode = 'heatExt'
		when 'cool' then mode = 'coolExt'
		when 'fan'  then mode = 'fanExt'

	# dbg 'hvacModeCmd mode ext', mode, ext

	if hvacMask[mode] is ctrlState.hvac then cb?(); return
	
	request statUrlPfx + utils.dec2hex(hvacMask[mode]), (err, res) ->
		# console.log 'commands res', {err, res}
		if err
			dbg 'hvacModeCmd err', err
			cb? err
			return
		ctrlState.hvac = hvacMask[mode]
		# dbg 'ctrlState.hvac', ctrlState.hvac, mode, hvacMask[mode]
		if hvac.appState in ['running', 'testing'] then showCrlState()
		cb?()

cmd.dampersCmd = (dampers, cb, force = no) ->
	if dampers is 0xf then dampers = 0

	if not force and dampers is ctrlState.dampers then cb?(); return

	request dampUrlPfx + utils.dec2hex(dampers), (err, res) ->
		if err
			dbg 'dampersCmd err', err
			cb? err
			return
		ctrlState.dampers = dampers
		if hvac.appState in ['running', 'testing'] then showCrlState()
		cb?()

do cmd.allCtrlOff = ->
	# disable control xxx
#	hvac.appState = 'running'
#	return

	if not hvac.appState or hvac.appState is 'connecting'
		setTimeout cmd.allCtrlOff, 1000
		return

	dbg  'clearing relays'
	cmd.hvacModeCmd 'off', no, (err) ->
		if err
			dbg 'clearing hvac relay failed', err
			process.exit 1
		cmd.dampersCmd 0, (err) ->
			if err
				dbg 'clearing dampers relay failed', err
				if hvac.argv is 'off' then dbg 'off finished: failed'
				process.exit 1

			if hvac.argv is 'off'
				dbg 'off finished: success'
				process.exit 0

			if hvac.argv is 'test'
				dbg  'relays cleared - app is testing'
				hvac.appState = 'testing'
				cmd.dampersCmd (~roomMask.master & 0x0f), (err) ->
					if err
						dbg 'setting dampers for test failed', err
						dbg 'test finished: failed'
						process exit 1
						return
					cmd.hvacModeCmd 'heat', no, (err) ->
						if err
							dbg 'setting heat mode while testing failed', err
							dbg 'test finished: failed'
							process.exit 1
							return
						dbg 'test finished: success'
						process.exit 0
				return

			dbg  'relays cleared - app is running'

			if hvac.argv is 'idle'
				hvac.argv = null
				setStat.set ['tvRoom', 'kitchen', 'master', 'guest'], 'off'

			hvac.appState = 'running'
		, yes
	, yes

setTimeout ->
	hvac.appState = 'clearing relays'
	dbg 'connected'
, 3000
