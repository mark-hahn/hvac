
console.log 'trying Primus.connect'

wsWrite = null
  
primus = Primus.connect '',  
  websockets: yes
  timeout: 10e3
  reconnect:
    max:     10e3
    retries: Infinity
    factor:  1.1

primus.on 'open', (spark) ->
  console.log 'ws open'
  wsWrite null

primus.on 'data', (data) ->
  console.log 'ws received', data
  wsRecv data
  
primus.on 'error', (err) ->
  console.log 'ws err', err
  
wsWrite = (data) ->
  primus.write {clientType: 'ceil', data}

 wsRecv = (master) ->
  for name, value of master
    $('#' + name).text value
