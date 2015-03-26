
util = require 'util'

{render, doctype, html, head, title, body, div, img, raw, text, script} = require 'teacup'

module.exports = ->
	render ->
		doctype()
    res.writeHead 200, "Content-Type": "text/html"
    res.end render ->
      doctype()
      html ->
        head ->
          title 'forecast - bath'
        body style:'background-color:black', ->
          div style:'width:100%; height:1375px', ->
            div '#forecast', style:'width:100%; height:45%'
            div style:'clear:both; float:left; width:100%; height:3px;
                  position: relative; top: 9%;
                  background-color:white; margin-top:-2%;'
            div '#current'
            div style:'clear:both; float:left; width:100%; height:3px;
                  position: relative; top: 0%;
                  background-color:white; margin-top:-2%;'
            div ->
              div '#dow', style:'clear:both; float:left; margin:5% 0 0% 12%;
                        color:white'
              div '#time', style:'float:right; margin:5% 9% 0% 0;
                        color:white;'

          script src: 'http://code.jquery.com/jquery-1.11.0.min.js'
          script src: 'lib/teacup.js'
          script src: 'lib/bath-script.js'
