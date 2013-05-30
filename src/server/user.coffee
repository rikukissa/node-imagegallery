mongoose      = require('mongoose')
crypto        = require('crypto')

ObjectId = mongoose.Schema.Types.ObjectId

sha256 = (str, salt) ->
  crypt = crypto.createHash('sha256')
  crypt.update(str + salt)
  return crypt.digest('hex')

module.exports = (config) -> 
  userSchema = new mongoose.Schema
    username:
      type: String
      index: 
        unique: true
    password: String
    email: String
    posts: [type: ObjectId, ref: 'Post']
    albums: [type: ObjectId, ref: 'Album']
    level: 
      type: String
      default: 'user'
    created: 
      type: Date
      default: () -> Date.now()

  userSchema.methods =
    verifyPassword: (password) ->
      return sha256(password, config.salt) == @password

  userSchema.statics =
    toJSON: -> return 'moi'
    authenticate: (username, password, cb) -> 
      @findOne username: username, (err, user) ->
        message = if !user?
          'Incorrect username'
        else if !user.verifyPassword(password)
          user = null
          'Incorrect password'
        else
          ''
        cb(err, user, message)

  return mongoose.model 'User', userSchema