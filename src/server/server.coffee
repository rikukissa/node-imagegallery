
_         = require('underscore')
fs        = require('fs')
express   = require('express')
Mongolian = require('mongolian')
imagemagick = require('node-imagemagick')

class Post
  constructor: (@id, @filename)->
    @created = Date.now()

format = (arr) ->
  return _.map arr, (a) ->
    delete a._id
    a

module.exports.createServer = (config) ->
  
  # Database
  db = new Mongolian().db('upload')

  app     = express()
  httpd   = require('http').createServer(app)
  io      = require('socket.io').listen(httpd)

  app.configure ->
    app.use express.cookieParser()
    app.use express.bodyParser
      uploadDir: config.rootDir + '/public/static/'
      keepExtensions: true
    app.use express.session secret: "keyboard cat"
    app.use express.static config.rootDir + '/public/'   

  app.post '/signin', (req, res) ->
  app.post '/signup', (req, res) ->

  app.get '/users', (req, res) ->
    db.collection('users').find().toArray (err, arr) ->
      res.send format(arr) 

  app.get '/user/:id', (req, res) ->
    db.collection('users').find(id: req.params.id).toArray (err, arr) ->
      res.send format(arr)
      
  app.get '/posts', (req, res) ->
    db.collection('posts').find().toArray (err, arr) ->
      res.send format(arr)

  app.get '/post/:id', (req, res) ->
    db.collection('posts').find(id: req.params.id).toArray (err, arr) ->
      res.send format(arr)

  app.post '/post', (req, res) ->
    if not req.files.post?
      res.send 404
      return

    file = req.files.post
    
    error = (err) ->
      console.log err if err?
      fs.unlink file.path
      res.send 404

    
    # Validate file type
    if config.allowed_filetypes.indexOf(file.type) == -1 
      error("Unknown filetype: #{file.type}")
      return
      
    id = Date.now().toString(36)
    filename = "#{id}.#{file.name.split('.').pop()}"
    newPath = "#{config.rootDir}/public/static/#{filename}"
    thumbPath = "#{config.rootDir}/public/static/thumb/#{filename}"

    fs.readFile file.path, (err, data) ->
      if err?
        error(err)
        return     
      
      fs.writeFile newPath, data, (err) ->
        if err?
          error(err)
          return

        imagemagick.convert [newPath, '-resize', 'x200', thumbPath], (err, stdout) ->
          if err?
            error(err)
            return     

          post = new Post(id, filename)
          db.collection('posts').insert post
          io.sockets.emit 'new post', post
          res.send 201

        fs.unlink file.path

  return httpd