define (require) ->
  Backbone = require('backbone')
  
  Router = Backbone.Router.extend
    routes:
      "": "default"
      "list": "list"
      "list/:page": "list"
      "album/:hash": "list"
      "view/:hash": "view"
      "profiles/": "profiles"
      "profile/:username": "profile"
      "profile/:username/settings": "settings"
      ":page": "notFound"
    
    view: -> @vmo.viewPost.apply @vmo, arguments

    notFound: () ->
      @vmo.viewNotFound.apply @vmo, arguments

    default: ->
      @vmo.setDefault.apply @vmo, arguments
    
    profile: ->
      @vmo.viewProfile.apply @vmo, arguments
    profiles: ->
      @vmo.viewProfiles.apply @vmo, arguments
    settings: ->
      @vmo.viewSettings.apply @vmo, arguments
    initialize: (@vmo) ->
  return Router
