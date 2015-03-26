sqlite3 = require("sqlite3").verbose()

getTemp = (cb) ->
  db = new sqlite3.Database '/var/lib/weewx/weewx.sdb', sqlite3.OPEN_READONLY, (err) ->
    if err then console.log 'Error opening weewx db', err; cb? err; return
    db.get 'SELECT outTemp FROM archive ORDER BY  dateTime DESC LIMIT 1', (err, res) ->
      if err
        console.log 'Error reading weewx db', err
        db.close()
        cb? err
        return
      cb? res
      db.close()

getTemp (res) ->
  console.log 'temp', res.outTemp
