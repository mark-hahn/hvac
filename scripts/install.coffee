###
    install.coffee
    cd /apps/insteon
    service start
###

fs = require 'fs'

op = process.argv[2] ? 'start'
if op not in ['start', 'stop'] then console.log 'bad arg:', op; return

if fs.exists '/apps/insteon/lib/hvac-released.js'
	fs.unlinkSync '/apps/insteon/lib/hvac-released.js'

fs.createReadStream('/apps/insteon/lib/hvac.js').
	pipe fs.createWriteStream '/apps/insteon/lib/hvac-released.js'

Service = require("node-windows").Service

svc = new Service
	name: 			"HVAC"
	description: 	"Hahn 4-zone system"
	script: 		"C:\\apps\\insteon\\lib\\hvac.js"

svc.on "install", ->
	console.log 'HVAC Service Installed'

	svc.start()
	console.log 'HVAC Service Started'
	console.log "The service exists: ", svc.exists

svc.on "uninstall", ->
	console.log "HVAC Service Uninstalled"
	console.log "The service exists: ", svc.exists

	if op is 'start' then svc.install()

if op is 'stop' and svc.exists
	svc.uninstall()
else if op is 'start'
	svc.install()
else
	console.log 'hvac already stopped, nothing to do.'
