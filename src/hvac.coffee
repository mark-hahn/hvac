###
	hvac.coffee

    cd C:\apps\insteon
	coffee hvac.coffee
###

process.setMaxListeners 100

require './server'

#console.log process.cwd()  #  C:\insteon
#console.log __dirname  	#  C:\insteon\lib
process.chdir '/root/apps/hvac'

utils   = require './utils'
getStat = require './get_stats'
setStat = require './set_stats'
sched   = require './cron'
ctrl    = require './control'
#www    = require './www'

dbg  = utils.dbg  'hvac'
dbg2 = utils.dbg2 'hvac'

dbg2 'Starting App - v2'

hvac = exports

hvac.defTemp    = 75
hvac.wakeupTemp = 67

hvac.argv = process.argv[2] ? null

legalArgs = [null, 'off', 'test', 'idle', 'wake']

if hvac.argv not in legalArgs
	dbg 'Invalid argument', hvac.argv, 'Vaild:', legalArgs
	process.exit 1
	return

if hvac.argv is 'off'
	dbg  'only clearing relays'

else if hvac.argv is 'test'
	dbg  'testing: furnace on, only master open'
	hvac.appState = 'testing'

else if hvac.argv is 'idle'
	dbg  'turning off every room except master which is being set to heat 63'
	hvac.appState = 'connecting'

else if hvac.argv is 'wake'
	dbg  'setting every room but guest to heat 68'
	setTimeout ->
		dbg 'setting wake up'
		ctrl.setSysMode 'heat'
		setStat.set ['tvRoom', 'kitchen', 'master'], 'heat', hvac.defTemp
	, 30*1000
	hvac.appState = 'connecting'

else hvac.appState = 'connecting'
