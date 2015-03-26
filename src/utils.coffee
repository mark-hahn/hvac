###
    C:\apps\insteon\node_modules\utils.coffee
###


fs     = require 'fs'
util   = require 'util'
moment = require 'moment'
ctrl   = null
utils = exports

utils.maxRetries    =     3
utils.nakRetry      =  1000
utils.IMtimeout 	=  4000
utils.deviceTimeout =  4000
utils.statTimeout 	= 13000

utils.INSTEON_PLM_START 		= 0x02
utils.INSTEON_PLM_NAK 			= 0x15
utils.INSTEON_PLM_TIME_LIMIT 	= 240

utils.INSTEON_MESSAGES =

  # commands sent to serial port (IM)
  '60': #
    type: "Get IM Info"
    len: 9
  '62': # no defined length [must check message flag]
    type: "Send INSTEON Standard or Extended Message"
  '6b':
    type: "Set modem config -- monitor mode"
    len: 4
  '6d':
    type: "LED On"
    len: 3
  '6e':
    type: "LED Off"
    len: 3

  # commands received from serial port (IM)
  '50':
    type: "INSTEON Standard Message Received"
    len: 11
  '51':
    type: "INSTEON Extended Message Received"
    len: 25

lastDbg = 0

utils.dbg = (module, lines = 1) ->
	module += ':'
	while module.length < 7 then module += ' '

	(args...) ->
		if (dataLine = (args[0] is 'data'))
			ctrl = require './control'
			args[0] =
				if      ctrl.sysMode is 'heat' then 'H'
				else if ctrl.sysMode is 'cool' then 'C'
				else if ctrl.sysMode is 'off'  then 'O'
				else                                ' '

		lines = 0

		now = Date.now()
		newline = (if lines > 1 then '\n' else '')
		endLine = (if lines > 2 then '\n' else '')
		lastDbg = now

		time = moment().format 'MM/DD HH:mm:ss.SS'

		console.log newline + time, module, args..., endLine

		fs.appendFile 'c:\\apps\\insteon\\data\\hvac.log', time + ' ' + module + ' ' +
			util.inspect(args).replace(/[\[\]',\n]/g, ' ') + '\n'

utils.dbg2 = (module) -> utils.dbg module, 2

dbg = utils.dbg 'utils'

utils.dec2binstr = dec2binstr = (str, padding) ->
	bin = Number(str).toString(2)
	bin = "0" + bin  while bin.length < padding
	bin

utils.dec2hex = dec2hex = (str, padding = 2) ->
	hex = Number(str).toString 16
	while hex.length < padding then hex = '0' + hex
	hex

utils.arr2hexStr = arr2hexStr = (ba, spc) ->
	len = '' + ba.length
	if len.length < 2 then len = ' ' + len
	str = (if spc then '(' + len + ') ' else '')
	for byt in ba
		str += dec2hex(byt) + (if spc then ' ' else '')
	str

utils.hexStr2arr = hexStr2arr = (hex) ->
	arr = []
	for i in [0...hex.length] by 2
		arr.push parseInt hex[i..i+1], 16
	arr

utils.byteArrayToHexStringArray = byteArrayToHexStringArray = (ba) ->
  data = []
  i = 0
  while i < ba.length
    data.push dec2hex(ba[i])
    i++
  data

getInsteonCommandType = utils.getInsteonCommandType = getInsteonCommandType = (aByte) ->

  # given insteon command code (second byte) return associated type of message in plaintext
  msg = dec2hex(aByte)
  return utils.INSTEON_MESSAGES[msg].type  unless typeof (utils.INSTEON_MESSAGES[msg]) is "undefined"
  "" # not implemented

getMessageFlags = utils.getMessageFlags = getMessageFlags = (aByte) ->

  # returns parsed message flag in json
  binstr = dec2binstr(aByte, 8)
  type = binstr.substring(0, 3)
  switch type
    when "000"
      type = "Direct Message"
    when "001"
      type = "ACK of Direct Message"
    when "010"
      type = "ALL-Link Cleanup Message"
    when "011"
      type = "ACK of ALL-Link Cleanup Message"
    when "100"
      type = "Broadcast Message"
    when "101"
      type = "NAK of Direct Message"
    when "110"
      type = "ALL-Link Broadcast Message"
    when "111"
      type = "NAK of ALL-Link Cleanup Message"
    else
      throw "getMessageFlags:: undefined message type " + type + ""
  extended = parseInt(binstr.substring(3, 4), 2)
  hops_left = parseInt(binstr.substring(4, 6), 2)
  max_hops = parseInt(binstr.substring(6), 2)
  type: type
  extended: extended
  hops_left: hops_left
  max_hops: max_hops

#
# break an insteon message into various parts
#
utils.parseMsg = parseMsg = (byteArray) ->

  data =
    dec:  byteArray
    hex:  byteArrayToHexStringArray byteArray
    cmd:  byteArray[1]
    type: getInsteonCommandType byteArray[1]

  switch data.type

    when "Button Event Report"
      data.button_event = data.hex[2]

    when "Get IM Info"
      data.device_id = data.hex.slice(2, 5)
      data.device_cat = data.hex[5]
      data.device_subcat = data.hex[6]
      data.device_firmware = data.hex[7]
      data.ack_nak = data.hex[8]

    when "INSTEON Standard Message Received"
      data.from = data.hex.slice(2, 5)
      data.to = data.hex.slice(5, 8)
      data.message_flags = data.hex[8]
      data.command1 = data.hex[9]
      data.command2 = data.hex[10]
      data.message_flags_details = getMessageFlags(data.dec[8])

    when "INSTEON Extended Message Received"
      data.from = data.hex.slice(2, 5)
      data.to = data.hex.slice(5, 8)
      data.message_flags = data.hex[8]
      data.command1 = data.hex[9]
      data.command2 = data.hex[10]
      data.user_data = data.hex.slice(11)

    when "Send INSTEON Standard or Extended Message"
      data.to = data.hex.slice(2, 5)
      data.message_flags = data.hex[5]
      data.command1 = data.hex[6]
      data.command2 = data.hex[7]
      if data.hex.length is 9 # standard
        data.ack_nak = data.hex[8]
      else if data.hex.length is 23 # extended
        data.user_data = data.hex.slice(8, 22)
        data.ack_nak = data.hex[22]
      else
        throw ("insteonjs: standard or extended messages is invalid")

    when "Get IM utilsuration"
      data.utils_flags = data.hex[2]
      data.ack_nak = data.hex[5]

    when "Set IM utilsuration"
      data.utils_flags = data.hex[2]
      data.ack_nak = data.hex[3]

    when "Get First ALL-Link Record"
      data.ack_nak = data.hex[2]

    when "Get Next ALL-Link Record"
      data.ack_nak = data.hex[2]

    when "Start ALL-Linking"
      data.link_code = data.hex[2]
      data.all_link_group = data.hex[3]
      data.ack_nak = data.hex[4]

    when "Cancel ALL-Linking"
      data.ack_nak = data.hex[2]

    when "ALL-Link Record Response"
      data.record_flags = data.hex[2]
      data.link_group = data.hex[3]
      data.deviceid = data.hex.slice(4, 7)
      data.data1 = data.hex[7]
      data.data2 = data.hex[8]
      data.data3 = data.hex[9]

    when "Send ALL-Link Command"
      data.all_link_group = data.hex[2]
      data.all_link_command = data.hex[3]
      data.broadcast_cmd2 = data.hex[4]

    when "ALL-Linking Completed"
      data.link_code = data.hex[2]
      data.link_group = data.hex[3]
      data.device_id = data.hex.slice(4, 7)
      data.device_cat = data.hex[7]
      data.device_subcat = data.hex[8]
      data.device_firmware = data.hex[9]

    when "Reset the IM"
      data.ack_nak = data.hex[2]

    else
      data.error = "Unrecognized command or command not implemented"

  if byteArray[0] is utils.INSTEON_PLM_NAK
    data.error = "PLM NAK received (buffer overrun)"

  data
