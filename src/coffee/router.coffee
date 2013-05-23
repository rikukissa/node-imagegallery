define (require) ->
  Backbone = require('backbone')
  
  Router = Backbone.Router.extend
    routes:
      "": "default"
      "list": "list"
      "list/:page": "list"
      "album/:hash": "list"
      "view/:hash": "view"
      "profile/:username": "profile"
      ":page": "notFound"
    
    view: -> @vmo.viewPost.apply @vmo, arguments

    notFound: () ->
      console.log 404

    default: ->
      @vmo.setDefault.apply @vmo, arguments
    
    profile: ->
      @vmo.viewProfile.apply @vmo, arguments

    initialize: (@vmo) ->
  return Router
