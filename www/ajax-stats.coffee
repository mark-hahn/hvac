###
    ajax-stats.coffee
    runs in browser
    gets system stats from server
###
 
updateMS  = 10000
delayMS   = 0
blinkMS   = 200
    
glblStats = {}
delayTo   = null
curRoom   = localStorage?.getItem('room') ? 'tvRoom'

$ ->
	$top       = $ '.top'
	$lftTemp   = $ '#lftTemp'
	$rgtTemp   = $ '#rgtTemp'
	$bot       = $ '.bot'
	$blinkEles = $rgtTemp.add($top).add($bot)
	changes    = room: curRoom
	
	updateScreen = ->
		# console.log 'updateScreen', new Date().toString()[0...24]
		$top.css border:'none', backgroundColor: '#aaa', color: 'gray'
		$('#'+curRoom).css border:'1px solid black', backgroundColor: 'yellow', color: 'black'
		if curRoom and (stat = glblStats[curRoom]) and stat.avgTemp
			$lftTemp.text stat.avgTemp.toFixed 1
			$rgtTemp.text switch stat.mode
				when 'heat' then stat.heatSetting.toFixed 1
				when 'cool' then stat.coolSetting.toFixed 1
				else ''
			$rgtTemp.css color: (
				if      stat.cooling then 'blue'
				else if stat.heating then 'red'
				else if stat.fanning then $rgtTemp.text 'Fan'; 'gray'
				else                       'white'
			)
			$bot.css border:'none', backgroundColor: '#aaa', color: 'gray'
			$('#'+stat.mode).css border:'1px solid black', backgroundColor: '#8f8', color: 'black'
			
	waitTimeout = 20
	waitingForStats = no
	
	do doGetStats = ->
		if waitingForStats and (--waitTimeout) > 0 or delayTo
			# console.log 'doGetStats waitingForStats', {waitingForStats, waitTimeout, delayTo}
			setTimeout doGetStats, 100
			return
		waitingForStats = yes
		$.post 'set', '{"nodata":"1"}', (stats) ->
			# console.log 'getStats', stats
			glblStats = stats
			updateScreen()
			waitTimeout = 20
			waitingForStats = no
			setTimeout doGetStats, updateMS
	
	setStats = window.setStats = -> 
		# console.log 'setStats', {changes}
		# if not (changes.mode or changes.coolSetting or changes.heatSetting) then return
		if delayTo then clearTimeout delayTo; delayTo = null
		if waitingForStats and (--waitTimeout) > 0 or delayTo
			# console.log 'setStats waitingForStats', {waitingForStats, waitTimeout, delayTo}
			setTimeout setStats, 100
		waitingForStats = yes
		changesIn = changes
		changes = room: curRoom
		$.post 'set', JSON.stringify(changesIn), (stats) ->
			glblStats = stats
			updateScreen()
			$blinkEles.hide()
			waitTimeout = 20
			waitingForStats = no
			setTimeout (-> $blinkEles.show()), blinkMS

	startDelay = ->
		updateScreen()
		if delayTo then clearTimeout delayTo
		delayTo = setTimeout setStats, delayMS
		
	$top.click (e) ->
		$tgt = $ e.target
		room = $tgt.attr 'room'
		localStorage?.setItem 'room', room
		if curRoom isnt room
			setStats()
			curRoom = room
			changes = room: curRoom
			updateScreen()
			
	$('#rgtPlus').click ->
		switch glblStats[curRoom].mode
			when 'cool' 
				newCoolSetting = Math.round(2 * glblStats[curRoom].coolSetting + 1) / 2
				changes.coolSetting = glblStats[curRoom].coolSetting = newCoolSetting
			when 'heat'
				newHeatSetting = Math.round(2 * glblStats[curRoom].heatSetting + 1) / 2
				changes.heatSetting = glblStats[curRoom].heatSetting = newHeatSetting
		startDelay()

	$('#rgtMinus').click ->
		switch glblStats[curRoom].mode
			when 'cool' 
				newCoolSetting = Math.round(2 * glblStats[curRoom].coolSetting - 1) / 2
				changes.coolSetting = glblStats[curRoom].coolSetting = newCoolSetting
			when 'heat'
				newHeatSetting = Math.round(2 * glblStats[curRoom].heatSetting - 1) / 2
				changes.heatSetting = glblStats[curRoom].heatSetting = newHeatSetting
		startDelay()

	$bot.click (e) ->
		setStats()
		$tgt = $ e.target
		mode = $tgt.attr 'mode'
		changes.mode = glblStats[curRoom].mode = mode
		updateScreen()
		startDelay()


