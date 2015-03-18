###
    C:\apps\insteon\set_stats.coffee
###

showAllmsgs  = yes
showActivity = yes

fs = require 'fs'
_  = require 'underscore'

hvac    = require './hvac'
utils   = require './utils'
ctrl    = require './control'
cmd     = require './commands'
serial  = require './serial'
getStats = require './get_stats'
srvr     = require './server'

if hvac.argv and hvac.argv isnt 'idle' then return

dbg  = utils.dbg  'set'

setStat = exports

miniRemotes =
	'270b8a': 'tvroom1'
	'270b00': 'tvroom2'
	'27178d': 'master'

srvrAddr = utils.hexStr2arr '2413fd'

decClk =
	rgtClk: 	  0x11
	rgtDblClk: 	0x12
	lftClk: 	  0x13
	lftDblClk: 	0x14

setStat.set = (rooms, mode, temp) ->
	if typeof rooms is 'string' then rooms = [rooms]
	
	do oneRoom = ->
		if not (room = rooms.shift())
			ctrl.update()
			return
		stats = getStats.glblStats[room]
		if not stats.avgTemp then oneRoom(); return
		
		stats.mode = mode
		if mode is 'cool' then stats.coolSetting = temp
		if mode is 'heat' then stats.heatSetting = temp
		oneRoom()

adjSetting = (curTemp, up) -> curTemp + (if up then 1 else -1)

dec2clk = (dec) -> ['lftClk', 'lftDblClk', 'rgtClk', 'rgtDblClk'][dec - 0x11]

timeout = null
	
do sendCeil = ->
	date = new Date()
	hrs  = date.getHours()
	mins = '' + date.getMinutes()
	if hrs < 1 then hrs = 12
	if hrs > 12 then hrs -= 12
	if mins.length < 2 then mins = '0' + mins
	time = hrs + ':' + mins
	if getStats.glblStats?.master?.avgTemp
		
		masterStats = getStats.glblStats['master']
		master      = masterStats.avgTemp?.toFixed(1) or '----'
		mstrSetting = masterStats.coolSetting or '---'
		outside     = 
			Math.round fs.readFileSync('/Cumulus/realtime.txt', 'utf8').split(' ')[2]
		masterData = {master, mstrSetting, time, outside}		
		
		srvr.wsSend 'ceil', masterData

	if timeout then clearTimeout timeout
	timeout = setTimeout ->
		timeout = null
		sendCeil()
	, 5000


serial.port.on 'message', (data) ->

#	if showAllmsgs then	dbg 'got message', utils.arr2hexStr data, yes

	if data.length isnt 11 or data[0] isnt 0x02 or data[1] isnt 0x50 then return
	
	p1 = data[9];  p2 = data[10]

	if p1 is 6 and p2 is 0 then p1 = data[5]; p2 = data[7]
	else if data[5] isnt srvrAddr[0] or
			    data[6] isnt srvrAddr[1] or
			    data[7] isnt srvrAddr[2]
		return

	# console.log 'received p1 p2 data', p1, p2, '\n', utils.arr2hexStr(data, yes), '\n', data
	
	clk = switch p1*100 + p2
		when 1702 then 'A1'
		when 1802 then 'A2'
		when 1701 then 'B1'
		when 1801 then 'B2'
				
		when 1704 then 'C1'
		when 1804 then 'C2'
		when 1703 then 'D1'
		when 1803 then 'D2'
		
		when 1706 then 'E1'
		when 1806 then 'E2'
		when 1705 then 'F1'
		when 1805 then 'F2'
		
		when 1708 then 'lftClk'
		when 1808 then 'lftDblClk'
		when 1707 then 'rgtClk'
		when 1807 then 'rgtDblClk'
		else null

	up = (clk in ['rgtClk', 'rgtDblClk'])

	if not clk then return

	remote = miniRemotes[_.map(data[2..4], (i) -> utils.dec2hex(i)).join '']
	if not remote then return
	
	room = (if remote is 'master' then 'master' else 'tvRoom')

	dbg 'accepted', clk, 'remote:' , remote, ', up:', up
	
	if room is 'master' and p2 < 7

		# switch clk
		# 	when 'A1' then ceilRoom = [(cmd.idxByRoom[ceilRoom] + 1) % 4]
		# 	when 'B1' then ceilRoomIdx++; if ceilRoomIdx > 3 then ceilRoomIdx -= 4
		# 	when 'C1' then ceilRoomIdx--; if ceilRoomIdx < 0 then ceilRoomIdx += 4
		# 	when 'D1' then ceilRoomIdx++; if ceilRoomIdx > 3 then ceilRoomIdx -= 4
				
		sendCeil()
		
	else
	
		if clk in ['lftDblClk', 'rgtDblClk']
			setStat.set ['tvRoom', 'kitchen', 'master'], 'off'
			return
			
		if getStats.glblStats[room].avgTemp
			ctrl.autoSet room, up

  ###