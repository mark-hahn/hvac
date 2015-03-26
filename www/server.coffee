###
    www/server.coffee
###

console.log process.cwd()  #  C:\insteon
console.log __dirname  	  #  C:\insteon\lib
process.chdir '/root/hvac'

http      	= require 'http'
Primus      = require 'primus'
url       	= require 'url'
_           = require 'underscore'
nodeStatic  = require 'node-static'
fileServer 	= new nodeStatic.Server '/root/hvac', cache: 0
getStats 	  = require './get_stats'
ctrl   	  	= require './control'
html        = require './index-html'
ceilHtml    = require './ceilHtml'

# reqSeq = 0

srvr = http.createServer (req, res) ->
	# console.log ++reqSeq, req.url
	if req.url is '/'
		res.writeHead 200, "Content-Type": "text/html"
		res.end html()
		console.log 'req:', req.url
		return

	if req.url is '/ceil'
		res.writeHead 200, "Content-Type": "text/html"
		res.end ceil-html()
		console.log 'req:', req.url
		return

	if req.url is '/bath'
		res.writeHead 200, "Content-Type": "text/html"
		res.end bath-html()
		console.log 'req:', req.url
		return

	if req.url is '/set'
		req.addListener "data", (data) ->
			try
				data = JSON.parse data.toString()
			catch e
				data = {}
			if (room = data.room) and (data.mode or data.coolSetting or data.heatSetting)
				# console.log 'req:', req.url, room
				stat = getStats.glblStats[room]
				if data.mode        then stat.mode        = data.mode
				if data.coolSetting then stat.coolSetting = data.coolSetting
				if data.heatSetting then stat.heatSetting = data.heatSetting
				ctrl.update ->
					res.writeHead 200, "Content-Type": "text/json"
					res.end JSON.stringify getStats.glblStats
				, yes
				return

			res.writeHead 200, "Content-Type": "text/json"
			res.end JSON.stringify getStats.glblStats

		return

#	console.log 'req:', req.url

	req.addListener('end', ->
		fileServer.serve req, res, (err) ->
			if err and req.url[-4..-1] not in ['.map', '.ico']
				console.log 'fileServer BAD URL:', req.url, err
	).resume()

srvr.listen 1339
console.log 'Listening on port', 1339

subscriptions = {}

primus = new Primus srvr, iknowhttpsisbetter: yes
primus.save 'lib/primus.js'

primus.on 'connection', (spark) ->
	console.log 'ws connection from ', spark.address

	spark.on 'data', (args) ->
	  console.log 'ws data', args
	  sub = (subscriptions[args.clientType] ?= {callbacks:[]})
	  sub.spark = spark
	  if args.data then for cb in sub.callbacks
	  	  cb args.data

exports.wsRecv = (clientType, cb) ->
	# console.log 'ws recv', clientType
	sub = subscriptions[clientType] ?= callbacks: []
	sub.callbacks.push cb

exports.wsSend = (clientType, data) ->
	# console.log 'ws send', clientType, data
	if (sub = subscriptions[clientType]) and (spark = sub.spark)
		spark.write data
