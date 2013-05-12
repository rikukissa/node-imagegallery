define (require) ->
  Backbone = require('backbone')
  
  Router = Backbone.Router.extend
    routes:
      "": "default"
      "list": "list"
      "list/:page": "list"
      "album/:hash": "list"
      "view/:hash": "view"
      "user/:username": "default"
      ":page": "notFound"
    
    view: -> @vmo.viewPost.apply @vmo, arguments

    notFound: () ->
      console.log 404

    default: ->
      @vmo.setDefault.apply @vmo, arguments

    initialize: (@vmo) ->
  return Router
