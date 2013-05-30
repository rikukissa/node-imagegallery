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
    'async': '../vendor/async'
  
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
  async = require('async')
  moment = require('moment')
  Backbone = require('backbone')
  ko.mapping = require('mapping')
  customBindings = require('customBindings')

  main: () ->
    $.ajaxSetup cache: false
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
        @allUsers = ko.observableArray []   


        # Computed values
        @getUser = (id) =>
          return _.findWhere @allUsers(), _id: id()
          

        # View
        @currentView = ko.observable 'default'
        @currentTab  = ko.observable null
        @currentPost = ko.observable null
        @currentUser = ko.observable null
        @panelOpen = ko.observable true

        # Collections
        @posts = kb.collectionObservable new PostsCollection(), kb.ViewModel


      

        # File input
        @selectedFile = ko.observable null


        # Notifications
        @notificationTimeout = null
        @notificationMessage = ko.observable null
        @notificationType = ko.observable null

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

      showNotification: (msg, type) =>
        clearTimeout @notificationTimeout if @notificationTimeout?
        @notificationMessage msg
        @notificationType type
        @notificationTimeout = setTimeout =>
          @notificationMessage null
          @notificationType null
        , 4000

      signin: (element) ->
        $(element).find('.error').addClass 'hidden'
        $.ajax
          type: 'POST'
          data: $(element).serialize()
          url: '/signin'
          success: (user) =>
            user.password = ""
            @user ko.mapping.fromJS user
          error: ->
            $(element).find('.error').removeClass 'hidden'
      
      removeUser: (user, e) =>
        e.stopPropagation()
        if confirm "Haluatko varmasti poistaa käyttäjän #{user.username}?" 
          $.ajax
            type: 'POST'
            data: 
              id: user._id
            url: "/user/remove"
            success: (users) => 
              @allUsers users
            error: () => console.log "err", arguments        
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

      findProfile: (username) => () => 
        @router.navigate 'profile/' + username, trigger: true

      showProfile: (user) =>
        @router.navigate 'profile/' + user.username(), trigger: true
      
      showProfiles: () => 
        @router.navigate 'profiles/', trigger: true
      
      viewProfiles: () =>
        @currentView 'profiles'

      showSettings: (user) =>
        @router.navigate "profile/#{user.username()}/settings", trigger: true

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

      viewNotFound: () =>
        @currentView "notFound"

      viewSettings: (username) ->
        return @router.navigate '404' unless @user()?

        if !@currentUser()
          @viewProfile username, =>
            @currentTab 'settings'
        else
          @currentView 'user'
          @currentTab 'settings'

      viewProfile: (username, cb) -> 
        $.ajax
          dataType: 'json'
          url: "/user/#{username}"
          success: (user) =>
            @currentUser ko.mapping.fromJS user
            @currentView 'user'
            @currentTab 'default'
            cb?()
          error: =>
            @router.navigate '404'

      logout: ->
        $.get '/logout', () -> location.reload()

      removeAccount: ->
        if confirm "Haluatko varmasti poistaa käyttäjätunnuksesi?"
          $.ajax
            type: 'POST'
            url: "/user/remove/me"
            success: () => 
              location.reload()
            error: () => console.log "err", arguments          

      enterDefault: ->
        @router.navigate "", trigger: true

      setDefault: ->
        @currentView 'default'
        @posts.collection().fetch(reset: true)
      
      setProfile: ->
      getProfile: (user) => () =>  @showProfile user
      enterProfile: (user) => @showProfile user

      togglePanel: ->
        if @panelOpen() then @panelOpen false else @panelOpen true

      updateUser: (element) =>
        $.ajax
          type: 'post'
          dataType: 'json'
          url: "/user"
          data: ko.mapping.toJS @user
          success: (user) => @showNotification "Käyttäjätiedot tallennettu", "success"
          error: => @showNotification "Jotain meni pieleen", "error"

    async.parallel [
      (done) ->
        $.ajax
          dataType: 'json'
          url: "/user"
          success: (user) => done null, user
          error: -> done null
    ,
      (done) ->
        $.ajax
          dataType: 'json'
          url: "/users"
          success: (users) => 
            done null, users
          error: -> done null
    ], (err, results) ->
      [user, users] = results

      vmo = new ViewModel()
      
      if user?
        user.password = ko.observable ""
        vmo.user ko.mapping.fromJS user 
      
      vmo.allUsers users

      # Router
      Router = require('router')
      vmo.router = new Router vmo
      Backbone.history.start pushState: if history.pushState? then true else false

      # Initialize
      ko.applyBindings vmo
