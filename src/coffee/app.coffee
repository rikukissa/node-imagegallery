require.config
  baseUrl: "js/modules"
  paths: 
    'jquery': 'https://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min'
    'underscore': '../vendor/underscore'
    'backbone': '../vendor/backbone'
    'knockout': '../vendor/knockout'
    'knockback': '../vendor/knockback'
    'masonry': '../vendor/masonry'
  
  shim:
    'underscore': 
      exports: '_'
    'backbone':
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'knockback':
      deps: ['underscore', 'backbone', 'knockout']
    'masonry':
      deps: ['jquery']

    
define (require) ->
  _ = require('underscore')
  $ = require('jquery')
  ko = require('knockout')
  kb = require('knockback')
  Backbone = require('backbone')
  masonry = require('masonry')


  ko.bindingHandlers.fileUpload =
    init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
      el = $(element)
      el.on 'change', (e) =>
   
        form = $('<form target="_iframe" method="post" action="/post" enctype="multipart/form-data"></form>')
        frame = $('<iframe name="_iframe">')
   
        frame.appendTo el.parent()
        el.wrap form
        frame.load (e, b)->
          frame.off 'load'
          err = null
          try
            data = $.parseJSON(frame.contents().text())
          catch e
            err = e
          el.unwrap()
          form.remove()
          frame.remove()
          valueAccessor().apply(viewModel, [err, data])
   
        el.parent().on('submit', (e) -> 
          e.stopPropagation()
        ).submit()

  main: () ->
    class Post extends Backbone.Model
      defaults:
        id: null
        filename: 'missing.png'
        created: Date.now()

    class PostsCollection extends Backbone.Collection
      model: Post
      url: '/posts'

    posts = new PostsCollection
    posts.fetch(reset: true)

    class ViewModel
      constructor: ->
        @socket = io.connect('http://localhost')
        @socket.on 'new post', (post) => @posts.collection().add post
        
        @columnLength = ko.observable $(window).width() / 200
        @marginWidth = ko.observable $(window).width() % 200        

        @posts = kb.collectionObservable posts, kb.ViewModel

      organize: ->
        console.log 'e'
      uploaded: (err, data) ->
        #console.log err, data
    ko.applyBindings new ViewModel
