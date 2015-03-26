###
    C:\apps\insteon\control.coffee
    v11
###

fs		 = require 'fs'
_        = require 'underscore'
Logger   = require 'nedb-logger'

hvac     = require './hvac'
getStats = require './get_stats'
cmd      = require './commands'
serial   = require './serial'
utils    = require './utils'
send     = require './send'
srvr     = require './server'

dbg    	 = utils.dbg  'ctrl'
dbg2     = utils.dbg2 'ctrl'

ctrl = exports
ctrl.sysMode = 'off'
ctrl.logDb = logDb = new Logger filename: 'logDb'
ctrl.logSeq = Date.now()
lastHvacMode  = hamperDelayTO = hamperAboutToDelay = lastSecs = null
pwsData = {}
lastLogStr = null
lastAc = lastAcOff = blankLineMins = 0
extIntake = acOn = startAcMelt = melting = allDampersOn = no

tempHistory =
	tvRoom:	 []
	kitchen: []
	master:	 []
	guest:	 []
	acLine:	 []
	intake:	 []

############ settings ###########

hysteresis    		= 0.5
acFreezeTemp  		= -5
minAcOffMins  		= 5
acFanOffDelay 		= 10
lowIntExtTempDiff	= 3
highIntExtTempDiff = 6

logMelt = (action) ->
	ctrl.logSeq += 1
	ctrl.logDb.insert
		type:    'melt'
		time:    Date.now()
		seq:     ctrl.logSeq
		action:	 action

setInterval () ->
	now = Date.now()
	for sensor of tempHistory
		stat = getStats.glblStats[sensor]
		tempH = tempHistory[sensor]
		tempH.push stat.temp
		tempH.splice 0, tempH.length - 10

		avgTemp = 0
		avgTemp += t for t in tempH
		avgTemp = avgTemp / tempH.length
		stat.avgTemp = avgTemp

	hvacState = cmd.ctrlState.hvac & 0x7
	if hvacState is 2 and getStats.glblStats.acLine.avgTemp < acFreezeTemp
		startAcMelt = yes
		melting = yes
		dbg2 'AC Melting Started'
		logMelt 'start'
		ctrl.update()
, 1000

ctrl.setSysMode = (mode) -> ctrl.sysMode = mode

ctrl.autoSet = (room, up) ->
	dbg 'autoSet', room, up
	now = Date.now()
	stat = getStats.glblStats[room]

	switch (stat.mode = ctrl.sysMode)
		when 'heat' then stat.heatSetting = stat.avgTemp + (if up then 1.5 else -1  )
		when 'cool' then stat.coolSetting = stat.avgTemp + (if up then 1   else -1.5)

	if room is 'tvRoom' and ctrl.sysMode is 'cool'
		statK             = getStats.glblStats.kitchen
		statK.mode 	  	  = stat.mode
		statK.coolSetting = stat.coolSetting

	ctrl.update()

acDelaying = -> Date.now() < lastAcOff + minAcOffMins * 60000

getHvacState = ->
	switch cmd.ctrlState.hvac & 0x7
		when 1 then 'H'
		when 2 then 'C'
		when 4 then 'F'
		else 'O'

blnks = (n) -> s=''; s += ' ' for i in [1..n]; s

ctrl.update = (cb) ->
	# dbg 'ctrl.update', getStats.glblStats
	# return

	now = Date.now()

	if hvac.appState isnt 'running' then cb?(); return

	fanCount = heatCount = coolCount = 0
	for room of cmd.roomMask
		switch getStats.glblStats[room].mode
			when 'heat' then heatCount++
			when 'cool' then coolCount++
			when 'fan'  then fanCount++
	if heatCount is coolCount is fanCount is 0  then ctrl.setSysMode 'off'
	if heatCount is coolCount is 0 and fanCount then ctrl.setSysMode 'fan'
	if heatCount > coolCount                   	then ctrl.setSysMode 'heat'
	if coolCount and coolCount >= heatCount 		then ctrl.setSysMode 'cool'

	if ctrl.sysMode is 'off'
			lastAc = 0

#	dbg {sysMode: ctrl.sysMode, heatCount, coolCount}

	stats = getStats.glblStats

	hvacMode = 'off'
	dampers  = 0x0f

#	dbData = {}

	logRooms = []
	rooms = cmd.rooms()
	rooms.unshift 'acLine'

	for room in rooms
		stat = stats[room]
		roomWasCooling = stat.cooling

		if not stat.temp?
			logRooms.push room[0].toUpperCase() + '                  '
			continue

		# for ceil display
		if room is 'tvRoom' and
			 getStats.glblStats.tvRoom?.avgTemp and
			 getStats.glblStats.kitchen?.avgTemp and
			 getStats.glblStats.master?.avgTemp and
			 getStats.glblStats.guest?.avgTemp

			mstrStat = getStats.glblStats.master
			mstrSetting = switch mstrStat.mode
				when 'heat' then mstrStat.heatSetting.toFixed(1)
				when 'cool' then mstrStat.coolSetting.toFixed(1)
				else '----'

			try
				fs.writeFileSync '/root/hvac/data/inside-temps.txt',
					getStats.glblStats.tvRoom.avgTemp.toFixed(1)  + ',' +
					getStats.glblStats.kitchen.avgTemp.toFixed(1) + ',' +
					getStats.glblStats.master.avgTemp.toFixed(1)  + ',' +
					getStats.glblStats.guest.avgTemp.toFixed(1)   + ',' +
					mstrSetting + ',' +
					Math.round(fs.readFileSync('/root/hvac/data/outside-wx.txt', 'utf8').split(' ')[2])
			catch e

		# for plotting
		date = new Date()
		secs = date.getSeconds()
		if Math.floor(secs/30) isnt lastSecs and
				getStats.glblStats.master?.avgTemp and
				getStats.glblStats.acLine?.avgTemp and
				getStats.glblStats.tvRoom?.avgTemp and
				getStats.glblStats.kitchen?.avgTemp and
				getStats.glblStats.guest?.avgTemp
			lastSecs = Math.floor(secs/30)

			runStates = ''
			for room2 in cmd.rooms()
				runStates += (if getStats.glblStats[room2].active  then ',1' else ',0')

			# fs.appendFileSync 'data/house-temp-history.csv',
			# 				(Math.floor(Date.now()/30000) - 46719359) + ',' +
			# 				getStats.glblStats.acLine.avgTemp.toFixed(3) + ',' +
			# 				getStats.glblStats.tvRoom.avgTemp.toFixed(3) + ',' +
			# 				getStats.glblStats.kitchen.avgTemp.toFixed(3) + ',' +
			# 				getStats.glblStats.master.avgTemp.toFixed(3) + ',' +
			# 				getStats.glblStats.guest.avgTemp.toFixed(3) +
			# 				runStates + '\n'

		threshold = switch
			when stat.mode is 'heat' then stat.heatSetting +
					(if stat.heating then +1 else -1) * hysteresis
			when stat.mode is 'cool' then stat.coolSetting +
					(if stat.cooling then -1 else +1) * hysteresis
			else 0

#		console.log 'threshold', threshold, stat

		stat.fanning = stat.heating = stat.cooling = no

		if ctrl.sysMode is 'heat' and stat.mode is 'heat' and stat.avgTemp < threshold
			stat.heating = yes
			hvacMode = 'heat'
			dampers &= ~parseInt cmd.roomMask[room], 16

		if ctrl.sysMode is 'cool' and stat.mode is 'cool' and stat.avgTemp > threshold and
														  not acDelaying()
			stat.cooling = yes
			hvacMode = 'cool'
			melting  = no
			dampers &= ~parseInt cmd.roomMask[room], 16

		if ctrl.sysMode is 'fan' and stat.mode is 'fan'
			stat.fanning = yes
			hvacMode = 'fan'
			dampers &= ~parseInt cmd.roomMask[room], 16

		if room is 'acLine'
			atmp = stat.avgTemp
			# if (neg = (atmp < 0)) then atmp *= -1
			# tempStr = (if neg then '-' else '') + Math.floor atmp
			# while tempStr.length < 2 then tempStr = ' ' + tempStr
			# pwsData = fs.readFileSync('/Cumulus/realtime.txt', 'utf8').split ' '
			# logRooms.push tempStr + ' ' +
			# 							Math.round(getStats.glblStats.intake.avgTemp) + '-' +
			# 							Math.round(pwsData[2])

		else logRooms.push room[0].toUpperCase() + ':' +
				(stat.mode?[0] ? '-').toUpperCase() +
				(if stat.active then getHvacState() else '-') + ' ' +
				stat.avgTemp.toFixed(1) + ' ' +
				if threshold is 0 then '--.-'
				else threshold.toFixed(1)

#		dbData[room] = stat

	# allDampersOn = (ctrl.sysMode is 'cool' and
	# 						        hvacMode is 'off'  and
	# 				   logRooms[3][2..3] is 'CF'   and
	# 					           dampers is 0x0f)

	# console.log '*********', {sysMode: ctrl.sysMode, hvacMode, dampers, logRooms, allDampersOn}

	# if allDampersOn
	# 	for i in [1..4]
	# 		lr = logRooms[i]
	# 		logRooms[i] = lr[0..2] + 'F' + lr[4...]
	#
	logStr = logRooms.join('   ') + (if allDampersOn then '   ad' else '     ')
	# dbg '*********', logStr
	if logStr[13..] isnt lastLogStr?[13..] and logStr.indexOf('NaN') is -1
		if (mins = new Date().getMinutes()) isnt blankLineMins
			blankLineMins = mins

			line = blnks(47)
			for room2 in cmd.rooms()
				stat = getStats.glblStats[room2]
				diff = stat.avgTemp - stat.lastAvgTemp ? 0
				if Math.abs(diff) < 0.05 then line += '    '
				else
					diff = diff.toFixed(1)
					while diff.length < 4 then diff = ' ' + diff
					line += diff
				line += blnks(13)
				stat.lastAvgTemp = stat.avgTemp
			console.log line
			console.log()

		hdr = ctrl.sysMode.toUpperCase()[0] + getHvacState() +
					(if extIntake then 'E' else 'I') +
					(if acDelaying() then 'D' else ' ') + ' '

		dbg2 hdr + logStr
		lastLogStr = logStr

#		pwsData = fs.readFileSync('/Cumulus/realtime.txt', 'utf8').split ' '
#		pws =
#			temp: 		+pwsData[2]
#			hum: 		+pwsData[3]
#			avgWind: 	+pwsData[5]
#			gust: 		+pwsData[40]
#
#		ctrl.logSeq += 1
#
#		dbData =
#			type:    'stats'
#			time:    Date.now()
#			seq:	 ctrl.logSeq
#			sysMode: ctrl.sysMode
#			pws: 	 pws
#		intakeTempC = getStats.glblStats.intake.avgTemp
#		dbData.intake = temp: (if intakeTempC then intakeTempC * (9/5) + 32)
#
#		_.extend dbData, getStats.glblStats
#		dbData.acLine = temp: dbData.acLine.temp, avgTemp: dbData.acLine.avgTemp
#		logDb.insert dbData

	if room is 'acLine' then cb?(); return

	if hvacMode is 'cool' then lastAc = now
	if now > lastAc + acFanOffDelay * 60000  then lastAc = 0

	if (lastAc or ctrl.sysMode is 'cool') and hvacMode isnt 'cool'
		dampers = 15
		for room2 in cmd.rooms()
			if stats[room2].mode in ['fan', 'cool']
				dampers &= ~parseInt cmd.roomMask[room2], 16
		if dampers is 15 then dampers = 0
		# hvacMode = (if melting then 'fan' else 'off')
		hvacMode = 'fan'

	# if allDampersOn then dampers = 0

	if startAcMelt
		startAcMelt = no
		hvacMode = 'fan'

	tempDiff = getStats.glblStats.intake.avgTemp - pwsData[2]
	if ctrl.sysMode is 'heat' or
		          extIntake and (tempDiff < lowIntExtTempDiff)
		extIntake = off
	else if not extIntake and (tempDiff > highIntExtTempDiff)
		extIntake = on

	for room2 in cmd.rooms()
		isOn = ((dampers & parseInt(cmd.roomMask[room2], 16)) is 0)
		getStats.glblStats[room2].active = isOn

	cmd.dampersCmd dampers, (err) ->
		if err
			dbg 'dampersCmd err', err
			hvac.appState = 'closing'
			cmd.allCtrlOff()
			process.exit 1
			return

		# cmd.hvacModeCmd hvacMode, false, cb
		cmd.hvacModeCmd hvacMode, extIntake, cb

		if acOn and hvacMode isnt 'cool' then lastAcOff = now
		acOn = (hvacMode is 'cool')
