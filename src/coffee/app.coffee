require.config
  baseUrl: "/js/modules"
  paths: 
    'jquery': '../vendor/jquery-1.8.2.min'
    'underscore': '../vendor/underscore'
    'backbone': '../vendor/backbone'
    'knockout': '../vendor/knockout'
    'knockback': '../vendor/knockback'
    'mapping': '../vendor/mapping'
    'moment': '../vendor/moment'
  
  shim:
    'underscore': 
      exports: '_'
    'backbone':
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'knockback':
      deps: ['underscore', 'backbone', 'knockout']
    'mapping':
      deps: ['knockout']
    
define (require) ->
  _ = require('underscore')
  $ = require('jquery')
  ko = require('knockout')
  kb = require('knockback')
  moment = require('moment')
  Backbone = require('backbone')
  ko.mapping = require('mapping')
  customBindings = require('customBindings')



  main: () ->
    class Post extends Backbone.Model
      defaults:
        id: null
        filename: 'missing.png'
        created: Date.now()
    
    class User extends Backbone.Model
      urlRoot: '/user'

    class PostsCollection extends Backbone.Collection
      model: Post
      url: '/posts'


    class ViewModel
      constructor: ->
        
        # Socket
        @socket = io.connect('http://localhost')
        @socket.on 'new post', (post) => 
          @posts.collection().unshift post
        
        @socket.on 'post update', (post) =>
          @currentPost().comments ko.mapping.fromJS(post.comments)()

        # User
        @user = ko.observable null
        @allUsers = []

        $.ajax
          dataType: 'json'
          url: "/user"
          success: (user) =>
            @user ko.mapping.fromJS user
          error: -> console.log arguments

        $.ajax
          dataType: 'json'
          url: "/users"
          success: (users) => @allUsers = users
          error: -> console.log arguments      


        # Computed values
        @getUser = (id) =>
          return _.findWhere @allUsers, _id: id()
          

        # View
        @currentView = ko.observable 'default'
        @currentPost = ko.observable null
        @currentUser = ko.observable null
        @panelOpen = ko.observable true

        # Collections
        @posts = kb.collectionObservable new PostsCollection(), kb.ViewModel

        # Router
        Router = require('router')
        @router = new Router(@)
        Backbone.history.start pushState: if history.pushState? then true else false
      

        # Validation
        @validation =
          username: (element, error, success, clear) ->
            $(element).on('blur', ->
              return error() if $(this).val().length > 20 or $(this).val().length < 3 
              $.ajax
                url: '/validation/username/' + $(this).val()
                success: success
                error: error
            ).on 'focus', clear

          email: (element, error, success, clear) ->
            reg = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/ 
            $(element).on('blur', ->
              return error() if not reg.test $(this).val()
              success()
            ).on 'focus', clear

          password: (element, error, success, clear) ->
            $(element).on('blur', ->
              return error() if $(this).val().length < 6
              success()
            ).on 'focus', clear

      organize: ->
        console.log 'e'

      uploaded: (err, data) ->
        #console.log err, data

      signin: (element) ->
        $(element).find('.error').addClass 'hidden'
        $.ajax
          type: 'POST'
          data: $(element).serialize()
          url: '/signin'
          success: (user) =>
            @user ko.mapping.fromJS user
          error: ->
            $(element).find('.error').removeClass 'hidden'
      
      submitComment: (element) =>
        $.ajax
          type: 'POST'
          data: $(element).serialize()
          url: "/post/#{@currentPost().id()}/comment"
          success: () => 
            $(element).find('input[name="comment"]').val('')
          error: () => console.log "err", arguments

      signup: (element) ->
        $.ajax
          type: 'POST'
          data: $(element).serialize()
          url: '/signup'
          success: (user) =>
            @user ko.mapping.fromJS user
          error: -> console.log arguments
      

      getPost: (id) ->
        return post for post in @currentUser().posts() when post._id() == id


      showPost: (post) =>
        @router.navigate 'view/' + post.id(), trigger: true

      showProfile: (user) =>
        @router.navigate 'profile/' + user.username(), trigger: true
      
      removePost: =>
        $.ajax
          type: 'DELETE'
          url: '/post/' + @currentPost().id()
          success: (user) =>
            @router.navigate 'profile/' + @user().username(), trigger: true
          error: -> console.log arguments

      movePost: -> console.log arguments


      uploadPost: (obj, e) => 
        $(e.target).parents('form').submit()

        frame = $('iframe[name="_iframe"]')
        frame.load => 
          frame.off 'load'
          post = JSON.parse frame.contents().text()
          @router.navigate 'view/' + post.id, trigger: true

      viewPost: (hash) ->
        $.ajax
          dataType: 'json'
          url: "/post/#{hash}"
          success: (post) =>
            @currentPost ko.mapping.fromJS post
            @currentView 'post'
          error: ->
            @router.navigate '404'

      logout: ->
        $.get '/logout', () -> location.reload()
      viewProfile: (username) -> 
        $.ajax
          dataType: 'json'
          url: "/user/#{username}"
          success: (user) =>
            @currentUser ko.mapping.fromJS user
            @currentView 'user'
          error: ->
            @router.navigate '404'


      enterDefault: ->
        @router.navigate "", trigger: true

      setDefault: ->
        @currentView 'default'
        @posts.collection().fetch(reset: true)
      
      setProfile: ->
      
      enterProfile: (user) => @showProfile user

      togglePanel: ->
        if @panelOpen() then @panelOpen false else @panelOpen true
    
    vmo = new ViewModel()
    ko.applyBindings vmo
