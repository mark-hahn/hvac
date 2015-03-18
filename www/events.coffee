###
    www/events
    runs in browser
    event handlers
###

$ ->
	$win       = $ window
	$page      = $ '#page'
	$top       = $ '#top'
	$left      = $ '#left'
	$rgtPlus   = $ '#rgtPlus'
	$rgtMid    = $ '#rgtMid'
	$rgtTemp   = $ '#rgtTemp'
	$rgtMinus  = $ '#rgtMinus'
	$bottom    = $ '#bottom'
	
	winResize = ->
		w = $win.width()
		h = $win.height()
		
		$page.css width: w, height: h
		
		fsW = Math.round w/4
		fsH = Math.round h/2.5
		fs  = Math.min fsW, fsH
		
		$top.children().css
			fontSize: fs/3
			marginTop: (h/4 - fs * 1.2 / 3) / 2
		
		$left.css 
			fontSize: fs
			marginTop: (h/2 - fs * 1.2)/2
			
		$rgtPlus.css 
			fontSize: fs/3
			marginTop: (h/8 - fs * 1.2 / 3) / 2
			
		$rgtTemp.css
			fontSize: fs/1.5
			marginTop: (h/4 - fs * 1.2 / 1.5) / 2
			
		$rgtMinus.css 
			fontSize: fs/3
			marginTop: (h/8 - fs * 1.2 / 3) / 2

		$bottom.children().css
			fontSize: fs/3
			marginTop: (h/4 - fs * 1.2 / 3) / 2
		
		
		$page.show()

	winResize()
	$win.on 'resize', winResize
	
hidden = undefined
visibilityChange = undefined
if typeof document.hidden isnt "undefined"
  hidden = "hidden"
  visibilityChange = "visibilitychange"
else if typeof document.mozHidden isnt "undefined"
  hidden = "mozHidden"
  visibilityChange = "mozvisibilitychange"
else if typeof document.msHidden isnt "undefined"
  hidden = "msHidden"
  visibilityChange = "msvisibilitychange"
else if typeof document.webkitHidden isnt "undefined"
  hidden = "webkitHidden"
  visibilityChange = "webkitvisibilitychange"
    
if visibilityChange
  $(document).on visibilityChange, (e) ->
    if not document[hidden] then setStats()
      
