###
    C:\apps\insteon\get_stats.coffee
###

showStatMsgs    = yes
logAllRooms     = no
logRoomReqs     = no
logRowReqs      = no
logXbeeReqs     = no
showStatTraffic = no
showRetries		= no

_  = require 'underscore'

hvac   = require './hvac'
ctrl   = require './control'
send   = require './send'
cmd    = require './commands'
serial = require './serial'
utils  = require './utils'

dbg  = utils.dbg  'stat'
dbg2 = utils.dbg2 'stat'

getStats = exports

getStats.glblStats = glblStats =
	tvRoom: 	{}
	kitchen:	{}
	master:		{}
	guest:		{}
	acLine:		{}
	intake:		{}

calibrationOffset = kitchen: -3.5

setVal = (room, key, val) ->
	changed = (glblStats[room][key] isnt val)
#	dbg 'setVal', room, key, val, (if changed then '' else '(no chg)')
	if not changed then return
	glblStats[room][key] = val
	ctrl.update()

if hvac.argv and hvac.argv isnt 'idle' then return

allRooms = cmd.rooms()
allRooms.push 'acLine'
allRooms.push 'intake'

xBeeRoomIsInit = {}

initXbeeVals = (room) ->
	xBeeRoomIsInit[room] = yes
	setVal room, 'temp', hvac.defTemp
	allRooms = _.reject allRooms, (r) -> r is room
	
	if room not in ['acLine', 'intake']
		setVal room, 'mode', 		'off'
		setVal room, 'coolSetting', hvac.defTemp
		setVal room, 'heatSetting', hvac.defTemp
	
serial.xBeeCb = (room, temp) ->
	if not xBeeRoomIsInit[room] then initXbeeVals room
	setVal room, 'temp',  temp  + (calibrationOffset[room] ? 0)

