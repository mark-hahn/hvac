###
    schedule.coffee
###

cronJob = require('cron').CronJob
_       = require 'underscore'

hvac    = require './hvac'
setStat = require './set_stats'
ctrl    = require './control'
utils   = require './utils'

dbg  = utils.dbg  'stat'

wakeupTvKit       = " 40  6 *  * *         "
wakeupMasterEarly = " 40  6 *  * 3,4       "
wakeupMasterLate  = "  0  9 *  * 0,1,2,5,6 "
wakeupOff         = "  0 11 *  * *         "
night             = "  0 20 *  * *         "
#                     -- -- - -- -
#                      │  │ │  │ │
#                      │  │ │  │ │
#                      │  │ │  │ └─ day of week (0 - 7) (0 to 6 are Sunday to Saturday)
#                      │  │ │  │		  (7 is Sunday, the same as 0), or use names
#                      │  │ │  └────────── month (1 - 12)
#                      │  │ └─────────────── day of month (1 - 31)
#                      │  └──────────────────── hour (0 - 23)
#                      └───────────────────────── min (0 - 59)
        
# new cronJob wakeupTvKit, ->
# 	dbg 'cron firing for wakeup'
# 	ctrl.setSysMode 'heat'
# 	setStat.set ['tvRoom', 'kitchen'], 'heat', 71
# 	ctrl.update()
# , null, yes
# 
# new cronJob wakeupMasterEarly, ->
# 	dbg 'cron firing for wakeup in master early'
# 	ctrl.setSysMode 'heat'
# 	setStat.set ['master'],            'heat', 67
# 	ctrl.update()
# , null, yes
# 
# new cronJob wakeupMasterLate, ->
# 	dbg 'cron firing for wakeup in master late'
# 	ctrl.setSysMode 'heat'
# 	setStat.set ['master'],            'heat', 68
# 	ctrl.update()
# , null, yes
# 
# new cronJob wakeupOff, ->
# 	dbg 'cron firing for wakeupOff'
# 	setStat.set ['tvRoom', 'kitchen', 'master', 'guest'], 'off'
# 	ctrl.update()
# , null, yes
# 
# new cronJob night, ->
# 	dbg 'cron firing for night'
# 	ctrl.setSysMode 'heat'
# 	setStat.set 'master', 'heat', 64.5
# 	ctrl.update()
# , null, yes
