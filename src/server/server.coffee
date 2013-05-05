
express = require('express')

module.exports.createServer = () ->
  app     = express()
  httpd   = require('http').createServer(app)
  return httpd