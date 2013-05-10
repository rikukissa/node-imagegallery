fs = require('fs')
config = JSON.parse fs.readFileSync 'config.json'
config.rootDir = __dirname
httpd = require('./src/server/server').createServer(config)
httpd.listen(8000)