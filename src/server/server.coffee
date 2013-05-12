
_         = require('underscore')
fs        = require('fs')
express   = require('express')
Mongolian = require('mongolian')
crypto    = require('crypto')
imagemagick = require('node-imagemagick')
passport = require('passport')
LocalStrategy = require('passport-local').Strategy

# Database
db = new Mongolian().db('upload')
ObjectId = Mongolian.ObjectId

class Post
  constructor: (@id, @filename)->
    @created = Date.now()

class User
  constructor: (@username, @email, @password) ->
    if arguments.length == 1
      user = arguments[0]
      delete user.password
      delete user._id
      delete user.email
      return user
    else
      @created = @id = Date.now()


formatObj = (obj) ->
  obj._id = obj._id.toString()
  obj

formatArr = (arr, ext) ->
  return _.map arr, (obj) ->
    if ext? then ext formatObj obj else formatObj obj

sha256 = (str, salt) ->
  crypt = crypto.createHash('sha256')
  crypt.update(str + salt)
  return crypt.digest('hex')

module.exports.createServer = (config) ->
  
  app     = express()
  httpd   = require('http').createServer(app)
  io      = require('socket.io').listen(httpd)
  
  app.configure ->
    app.use express.cookieParser()
    app.use express.limit(config.size_limit)
    app.use express.bodyParser
      uploadDir: config.rootDir + '/public/static/'
      keepExtensions: true
    app.use express.session secret: "keyboard cat"
    app.use express.static config.rootDir + '/public/'   
    io.set 'log level', 0

    app.use(passport.initialize())
    app.use(passport.session())
    passport.use new LocalStrategy (username, password, done) ->
      db.collection('users').findOne
        username: username
      , (err, user) ->

        return done(err) if err
        
        unless user
          return done null, false,
            message: "Incorrect username."
        
        unless sha256(password, config.salt) == user.password
          return done null, false,
            message: "Incorrect password."
          
        done null, user

    passport.serializeUser (user, done) ->
      done null, user.id

    passport.deserializeUser (id, done) ->
      db.collection('users').findOne id: id, (err, user) ->
        user._id = user.id
        done err, user

  # Routes
  app.post '/signin', passport.authenticate('local'), (req, res) ->
    res.status(200).send req.user
  
  app.post '/signup', (req, res) ->
    err = null
    error = (e) ->
      err = e
      console.log e
      res.status(400).send(e)

    return error('Missing credentials') unless req.body.username? and 
    req.body.password? and
    req.body.email?

    db.collection('users').find().toArray (err, arr) ->
      if arr.length > 0
        arr.forEach (u) ->
          return error('Username is taken') if u.username == req.body.username
          return error('Email already in use') if u.email == req.body.email
        return if err?

      user = new User req.body.username, 
      req.body.email, sha256(req.body.password, config.salt)

      db.collection('users').insert user
      req.login user, (err) ->
        return error(err) if err?
        res.status(201).send user

  app.get '/user', (req, res) ->
    if req.user? then res.send req.user else res.send {}

  app.get '/users', (req, res) ->
    db.collection('users').find().toArray (err, arr) ->
      res.send _.map formatArr(arr, User)

  app.get '/user/:username', (req, res) ->
    db.collection('users').find(id: req.params.id).toArray (err, arr) ->
      res.send formatArr(arr)

  app.get '/user/username/:username', (req, res) ->
    db.collection('users').find(username: req.params.username).toArray (err, arr) ->
      res.send formatArr(arr, User)
      
  app.get '/posts', (req, res) ->
    db.collection('posts').find().sort( created: -1 ).toArray (err, arr) ->
      res.send formatArr(arr)

  app.get '/post/:id', (req, res) ->
    db.collection('posts').findOne id: req.params.id, (err, post) ->
      return res.send 404 if not post?
      res.send formatObj(post)

  app.post '/post', (req, res) ->
    return res.send 404 if not req.files.post?

    file = req.files.post
    
    error = (err, line) ->
      console.log "\nline #{line}:\n" if line?
      console.log err if err?
      fs.unlink file.path
      fs.unlink file.newPath
      fs.unlink file.thumbPath
      res.send 404

    
    # Validate file type
    if config.allowed_filetypes.indexOf(file.type) == -1 
      return error("Unknown filetype: #{file.type}")
      
    id = Date.now().toString(36)
    filename = "#{id}.#{file.name.split('.').pop()}"
    file.newPath = "#{config.rootDir}/public/static/#{filename}"
    file.thumbPath = "#{config.rootDir}/public/static/thumb/#{filename}"

    fs.readFile file.path, (err, data) ->
      return error(err) if err?

      fs.writeFile file.newPath, data, (err) ->
        return error(err) if err?
      
        imagemagick.convert [file.newPath, '-resize', 'x150', file.thumbPath], (err, stdout) ->
          imagemagick.crop
            srcPath: file.thumbPath
            dstPath: file.thumbPath
            width: 150
            height: 150
            quality: 100
          , (err, stdout) ->
            return error(err, 87) if err?

            post = new Post(id, filename)

            db.collection('posts').insert post
            io.sockets.emit 'new post', post
            res.send 201

            fs.unlink file.path
  
  app.get '*', (req, res) ->
    res.sendfile config.rootDir + '/public/index.html'

  return httpd