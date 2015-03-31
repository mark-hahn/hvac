
util = require 'util'

{render, doctype, html, head, title, body, div, img, raw, text, script} = require 'teacup'

module.exports = ->
	render ->
		doctype()
		html ->
			head ->
				title 'ceil'
			body style:'background-color:black; color:white;
					        font-size:450px; text-align:center;
                  font-family:tahoma', ->

        div style:'width:1520px; height:1000px; padding:200px; position:relative', ->

          div style:'width:100%; height:430px; position:relative;
                     overflow:hidden; margin-bottom:20px', ->
           div '#master', style:'display:inline-block; float:left'
           div style:'display:inline-block; float:right; font-size:250px', ->
              div '#mstrSetting', style:'position:relative; top:30px'

          div '#divider', style:'width:100%; height:6px; overflow:hidden;
										             background-color:white; position:relative; top:20px;'

          div style:'position:relative; width:100%; height:430px; top:0px; overflow:hidden', ->
           div '#time', style:'display:inline-block; float:left; height:100px'
           div style:'display:inline-block; float:right; font-size:250px', ->
              div '#outside', style:'position:relative; top:30px'

				script src: 'js/jquery-1.11.2.min.js'
				script src: 'js/primus.js'
				script src: 'lib/ceil-script.js'
