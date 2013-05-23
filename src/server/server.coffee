
_             = require('underscore')
fs            = require('fs')
express       = require('express')
mongoose      = require('mongoose')
crypto        = require('crypto')
imagemagick   = require('node-imagemagick')

passport      = require('passport')
LocalStrategy = require('passport-local').Strategy

sha256 = (str, salt) ->
  crypt = crypto.createHash('sha256')
  crypt.update(str + salt)
  return crypt.digest('hex')

module.exports.createServer = (config) ->
  mongoose.connect 'mongodb://localhost/uploads'
  
  ObjectId = mongoose.Schema.Types.ObjectId

  commentSchema = new mongoose.Schema
    content: String
    user: 
      type: String
      ref: 'User'
    created: 
      type: Date
      default: () -> Date.now()

  Comment = mongoose.model 'Comment', commentSchema

  postSchema = new mongoose.Schema
    id: String
    filename: String
    user: 
      type: String
      ref: 'User'
    created: 
      type: Date
      default: () -> Date.now()
    album: type: ObjectId, ref: 'Album', default: null
    comments: type: [commentSchema], default: []

  Post = mongoose.model 'Post', postSchema

  albumSchema = new mongoose.Schema
    id: String
    title: String
    user: 
      type: String
      ref: 'User'
    created: 
      type: Date
      default: () -> Date.now()
    posts: [type: ObjectId, ref: 'Post']

  Album = mongoose.model 'Album', albumSchema

  userSchema = new mongoose.Schema
    username:
      type: String
      index: 
        unique: true
    password: String
    email: String
    posts: [type: ObjectId, ref: 'Post']
    albums: [type: ObjectId, ref: 'Album']
    created: 
      type: Date
      default: () -> Date.now()

  userSchema.methods =
    verifyPassword: (password) ->
      return sha256(password, config.salt) == @password

  userSchema.statics =
    authenticate: (username, password, cb) -> 
      @findOne {username: username}, (err, user) ->
        message = if !user?
          'Incorrect username'
        else if !user.verifyPassword(password)
          user = null
          'Incorrect password'
        else
          ''
        console.log message
        cb(err, user, message)

  User = mongoose.model 'User', userSchema
  
  app     = express()
  httpd   = require('http').createServer(app)
  io      = require('socket.io').listen(httpd)
  
  app.configure ->
    app.use express.cookieParser()
    app.use express.limit(config.size_limit)
    app.use express.bodyParser
      uploadDir: config.rootDir + '/public/static/'
      keepExtensions: true
    app.use express.session secret: config.secret
    app.use express.static config.rootDir + '/public/'   

    app.use passport.initialize()
    app.use passport.session()

    io.set 'log level', 0

    passport.use new LocalStrategy (username, password, done) -> 
      User.authenticate username, password, done

    passport.serializeUser (user, done) ->
      done null, user.id

    passport.deserializeUser (id, done) ->
      User.findById id, (err, user) ->
        done err, user



  # Routes
  app.post '/signin', passport.authenticate('local'), (req, res) ->
    res.status(200).send req.user
  
  app.get '/logout', (req, res) ->
    req.logout()
    res.send 200

  app.post '/signup', (req, res) ->
    error = (e) ->
      console.log e
      res.status(400).send(e)

    return error 'Missing credentials' unless req.body.username? and 
    req.body.password? and
    req.body.email?

    user = new User
      username: req.body.username
      password: sha256(req.body.password, config.salt)
      email: req.body.email
      created: Date.now()

    user.save (err, user) ->
      return error err if err?

      req.login user, (err) ->
        return error err if err?
        res.status(201).send user


  app.get '/validation/username/:username', (req, res) ->
    User.findOne username: req.params.username, (err, user) ->
      if user? then res.send 403 else res.send 200


  app.get '/user', (req, res) ->

    return res.send 404 if not req.user? 
    User.findOne(_id: req.user._id).populate('albums').populate('posts').exec().then (user) ->
      if user? then res.send user else res.send 404
  
  app.get '/users', (req, res) ->
    User.find (err, users) ->
      return console.log err if err?
      res.send users

  app.get '/user/:username', (req, res) ->
    User.findOne(username: req.params.username).populate('albums').populate('posts').exec().then (user) ->
      if user? then res.send user else res.send 404

  app.get '/posts', (req, res) ->
    Post.find().sort( created: -1 ).exec (err, arr) ->
      res.send arr

  app.get '/post/:id', (req, res) ->
    Post.findOne(id: req.params.id).exec().then (post) ->
      return res.send 404 if not post?
      res.send post

  app.delete '/post/:id', (req, res) ->
    Post.findOne(id: req.params.id).exec().then (post) ->
      return res.send 404 if not post?

      remove = ->
        post.remove()
        res.send 200

      return remove() if not post.album?
      Album.findOne(_id: post.album).exec().then (album) ->
        album.remove() if album? and album.posts.length == 1
        return remove()

  app.post '/post/:id/comment', (req, res) ->
    return res.send 403 if not req.user?
    Post.findOne id: req.params.id, (err, post) ->
      return console.log err if err? or !post?
      
      comment = new Comment
        content: req.body.comment
        user: req.user._id

      post.comments.push comment
      post.save (err, post) ->
        return console.log err if err?
        io.sockets.emit 'post update', post
        res.status(201).send post 

  app.post '/post', (req, res) ->

    return res.send 404 if not req.files.post?
    return res.send 403 if not req.user?

    user = req.user
    file = req.files.post
    album = null


    error = (err, line) ->
      console.log "\nline #{line}:\n" if line?
      console.log err if err?
      fs.unlink file.path
      fs.unlink file.newPath
      fs.unlink file.thumbPath
      res.send 404

    save = ->
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
              return error(err) if err?

              post = new Post
                id: id
                filename: filename
                user: req.user._id
                created: Date.now()

              user.posts.push post
              user.save()

              if album?
                album.posts.push post
                post.album = album
                album.save()

              post.save (err, post) ->
                return error err if err?  
                io.sockets.emit 'new post', post
                res.status(201).send post

              fs.unlink file.path

    if req.body['create_album']? and req.body['create_album'] != ""
      album = new Album
        id: Date.now().toString(36)
        title: req.body['create_album']
        user: user._id
        created: Date.now()

      return album.save (err, a) ->
        album = a
        user.albums.push album
        user.save save

    if req.body['album']?
      return Album.findOne 
        id: req.body['album']
        user: user._id
      , (err, a) ->
        return console.log(err) if err? 
        album = a
        save()



  app.get '/albums', (req, res) ->
    Album.find (err, albums) ->
    Album.find().populate('posts').exec().then (albums) ->
      res.send albums

  app.get '*', (req, res) ->
    res.sendfile config.rootDir + '/public/index.html'

  return httpd