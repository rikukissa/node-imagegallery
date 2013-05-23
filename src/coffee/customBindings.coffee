define (require) ->
  ko = require('knockout')
  ko.bindingHandlers.fileUpload =
    init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
      el = $(element)
      el.on 'change', (e) =>
   
        form = $('<form target="_iframe" method="post" action="/post" enctype="multipart/form-data"></form>')
        frame = $('<iframe name="_iframe">')
   
        frame.appendTo el.parent()
        el.wrap form
        frame.load (e, b) ->
          frame.off 'load'
          err = null
          try
            data = $.parseJSON(frame.contents().text())
          catch e
            err = e
          el.unwrap()
          form.remove()
          frame.remove()
          el.val('')
          valueAccessor().apply(viewModel, [err, data])
   
        el.parent().on('submit', (e) -> 
          e.stopPropagation()
        ).submit()

  ko.bindingHandlers.validation =
    init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
      error = ->
        $(element).addClass 'error'
      
      success = ->
        $(element).addClass 'success'

      clear = ->
        $(element).removeClass 'success error'

      valueAccessor().apply viewModel, [element, error, success, clear]
