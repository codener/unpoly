###*
Pop-up overlays
===============

Instead of [linking to a page fragment](/up.link), you can choose
to show a fragment in a popup overlay that rolls down from an anchoring element.

To open a popup, add an [`up-popup` attribute](/up-popup) to a link,
or call the Javascript function [`up.popup.attach`](/up.popup.attach).

For modal dialogs see [up.modal](/up.modal) instead.

\#\#\#\# Customizing the popup design

Loading the Unpoly stylesheet will give you a minimal popup design:

- Popup contents are displayed in a white box
- There is a a subtle box shadow around the popup
- The box will grow to fit the popup contents

The easiest way to change how the popup looks is by overriding the [default CSS styles](https://github.com/unpoly/unpoly/blob/master/lib/assets/stylesheets/up/popup.css.sass).

By default the popup uses the following DOM structure:

    <div class="up-popup">
      ...
    </div>

\#\#\#\# Closing behavior

The popup closes when the user clicks anywhere outside the popup area.

By default the popup also closes
*when a link within the popup changes a fragment behind the popup*.
This is useful to have the popup interact with the page that
opened it, e.g. by updating parts of a larger form or by signing in a user
and revealing additional information.

To disable this behavior, give the opening link an `up-sticky` attribute:

    <a href="/settings" up-popup=".options" up-sticky>Settings</a>

@class up.popup
###
up.popup = (($) ->

  u = up.util

  ###*
  Returns the source URL for the fragment displayed
  in the current popup, or `undefined` if no  popup is open.

  @function up.popup.url
  @return {String}
    the source URL
  @stable
  ###
  currentUrl = undefined

  ###*
  Returns the URL of the page or modal behind the popup.

  @function up.popup.coveredUrl
  @return {String}
  @experimental
  ###
  coveredUrl = ->
    $('.up-popup').attr('up-covered-url')

  ###*
  Sets default options for future popups.

  @property up.popup.config
  @param {String} [config.position='bottom-right']
    Defines where the popup is attached to the opening element.

    Valid values are `bottom-right`, `bottom-left`, `top-right` and `top-left`.
  @param {String} [config.history=false]
    Whether opening a popup will add a browser history entry.
  @param {String} [config.openAnimation='fade-in']
    The animation used to open a popup.
  @param {String} [config.closeAnimation='fade-out']
    The animation used to close a popup.
  @param {String} [config.openDuration]
    The duration of the open animation (in milliseconds).
  @param {String} [config.closeDuration]
    The duration of the close animation (in milliseconds).
  @param {String} [config.openEasing]
    The timing function controlling the acceleration of the opening animation.
  @param {String} [config.closeEasing]
    The timing function controlling the acceleration of the closing animation.
  @param {Boolean} [options.sticky=false]
    If set to `true`, the popup remains
    open even it changes the page in the background.
  @stable
  ###
  config = u.config
    openAnimation: 'fade-in'
    closeAnimation: 'fade-out'
    openDuration: null
    closeDuration: null
    openEasing: null
    closeEasing: null
    position: 'bottom-right'
    history: false

  reset = ->
    close(animation: false)
    config.reset()

  setPosition = ($link, position) ->
    css = {}

    $popup = $('.up-popup')
    popupBox = u.measure($popup)

    if u.isFixed($link)
      linkBox = $link.get(0).getBoundingClientRect()
      css['position'] = 'fixed'
    else
      linkBox = u.measure($link)

    switch position
      when "bottom-right" # anchored to bottom-right of link, opens towards bottom-left
        css['top'] = linkBox.top + linkBox.height
        css['left'] = linkBox.left + linkBox.width - popupBox.width
      when "bottom-left" # anchored to bottom-left of link, opens towards bottom-right
        css['top'] = linkBox.top + linkBox.height
        css['left'] = linkBox.left
      when "top-right" # anchored to top-right of link, opens to top-left
        css['top'] = linkBox.top - popupBox.height
        css['left'] = linkBox.left + linkBox.width - popupBox.width
      when "top-left" # anchored to top-left of link, opens to top-right
        css['top'] = linkBox.top - popupBox.height
        css['left'] = linkBox.left
      else
        u.error("Unknown position option '%s'", position)

    $popup.attr('up-position', position)
    $popup.css(css)

  discardHistory = ->
    $popup = $('.up-popup')
    $popup.removeAttr('up-covered-url')
    $popup.removeAttr('up-covered-title')
    
  createFrame = (target, options) ->
    promise = u.resolvedPromise()
    if isOpen()
      promise = promise.then -> close()
    promise = promise.then ->
      $popup = u.$createElementFromSelector('.up-popup')
      $popup.attr('up-sticky', '') if options.sticky
      $popup.attr('up-covered-url', up.browser.url())
      $popup.attr('up-covered-title', document.title)
      # Create an empty element that will match the
      # selector that is being replaced.
      u.$createPlaceholder(target, $popup)
      $popup.appendTo(document.body)
      $popup
    return promise

  ###*
  Returns whether popup modal is currently open.

  @function up.popup.isOpen
  @stable
  ###
  isOpen = ->
    $('.up-popup').length > 0

  ###*
  Attaches a popup overlay to the given element or selector.

  Emits events [`up:popup:open`](/up:popup:open) and [`up:popup:opened`](/up:popup:opened).
  
  @function up.popup.attach
  @param {Element|jQuery|String} elementOrSelector
  @param {String} [options.url]
  @param {String} [options.target]
    A CSS selector that will be extracted from the response and placed into the popup.
  @param {String} [options.position='bottom-right']
    Defines where the popup is attached to the opening element.

    Valid values are `bottom-right`, `bottom-left`, `top-right` and `top-left`.
  @param {String} [options.confirm]
    A message that will be displayed in a cancelable confirmation dialog
    before the modal is being opened.
  @param {String} [options.animation]
    The animation to use when opening the popup.
  @param {Number} [options.duration]
    The duration of the animation. See [`up.animate`](/up.animate).
  @param {Number} [options.delay]
    The delay before the animation starts. See [`up.animate`](/up.animate).
  @param {String} [options.easing]
    The timing function that controls the animation's acceleration. [`up.animate`](/up.animate).
  @param {String} [options.method="GET"]
    Override the request method.
  @param {Boolean} [options.sticky=false]
    If set to `true`, the popup remains
    open even if the page changes in the background.
  @param {Object} [options.history=false]
  @return {Promise}
    A promise that will be resolved when the popup has been loaded and
    the opening animation has completed.
  @stable
  ###
  attach = (linkOrSelector, options) ->
    $link = $(linkOrSelector)
    $link.length or u.error('Cannot attach popup to non-existing element %o', linkOrSelector)
    
    options = u.options(options)
    url = u.option(u.pluckKey(options, 'url'), $link.attr('up-href'), $link.attr('href'))
    html = u.option(u.pluckKey(options, 'html'))
    target = u.option(u.pluckKey(options, 'target'), $link.attr('up-popup'), 'body')
    options.position = u.option(options.position, $link.attr('up-position'), config.position)
    options.animation = u.option(options.animation, $link.attr('up-animation'), config.openAnimation)
    options.sticky = u.option(options.sticky, u.castedAttr($link, 'up-sticky'), config.sticky)
    options.history = if up.browser.canPushState() then u.option(options.history, u.castedAttr($link, 'up-history'), config.history) else false
    options.confirm = u.option(options.confirm, $link.attr('up-confirm'))
    options.method = up.link.followMethod($link, options)
    animateOptions = up.motion.animateOptions(options, $link, duration: config.openDuration, easing: config.openEasing)

    up.browser.confirm(options).then ->
      if up.bus.nobodyPrevents('up:popup:open', url: url, message: 'Opening popup')
        options.beforeSwap = -> createFrame(target, options)
        extractOptions = u.merge(options, animation: false)
        if html
          promise = up.extract(target, html, extractOptions)
        else
          promise = up.replace(target, url, extractOptions)
        promise = promise.then ->
          setPosition($link, options.position)
        promise = promise.then ->
          up.animate($('.up-popup'), options.animation, animateOptions)
        promise = promise.then ->
          up.emit('up:popup:opened', message: 'Popup opened')
        promise
      else
        # Although someone prevented the destruction, keep a uniform API for
        # callers by returning a promise that will never be resolved.
        u.unresolvablePromise()

  ###*
  This event is [emitted](/up.emit) when a popup is starting to open.

  @event up:popup:open
  @param event.preventDefault()
    Event listeners may call this method to prevent the popup from opening.
  @stable
  ###

  ###*
  This event is [emitted](/up.emit) when a popup has finished opening.

  @event up:popup:opened
  @stable
  ###
      
  ###*
  Closes a currently opened popup overlay.

  Does nothing if no popup is currently open.

  Emits events [`up:popup:close`](/up:popup:close) and [`up:popup:closed`](/up:popup:closed).

  @function up.popup.close
  @param {Object} options
    See options for [`up.animate`](/up.animate).
  @return {Promise}
    A promise that will be resolved once the modal's close
    animation has finished.
  @stable
  ###
  close = (options) ->
    $popup = $('.up-popup')
    if $popup.length
      if up.bus.nobodyPrevents('up:popup:close', $element: $popup)
        options = u.options(options,
          animation: config.closeAnimation,
          url: $popup.attr('up-covered-url'),
          title: $popup.attr('up-covered-title')
        )
        animateOptions = up.motion.animateOptions(options, duration: config.closeDuration, easing: config.closeEasing)
        u.extend(options, animateOptions)
        currentUrl = undefined
        promise = up.destroy($popup, options)
        promise = promise.then -> up.emit('up:popup:closed', message: 'Popup closed')
        promise
      else
        # Although someone prevented the destruction, keep a uniform API
        # for callers by returning a promise that will never be resolved.
        u.unresolvablePromise()
    else
      u.resolvedPromise()

  ###*
  This event is [emitted](/up.emit) when a popup dialog
  is starting to [close](/up.popup.close).

  @event up:popup:close
  @param event.preventDefault()
    Event listeners may call this method to prevent the popup from closing.
  @stable
  ###

  ###*
  This event is [emitted](/up.emit) when a popup dialog
  is done [closing](/up.popup.close).

  @event up:popup:closed
  @stable
  ###
      
  autoclose = ->
    unless $('.up-popup').is('[up-sticky]')
      discardHistory()
      close()

  ###*
  Returns whether the given element or selector is contained
  within the current popup.

  @methods up.popup.contains
  @param {String} elementOrSelector
  @stable
  ###
  contains = (elementOrSelector) ->
    $element = $(elementOrSelector)
    $element.closest('.up-popup').length > 0

  ###*
  Opens this link's destination of in a popup overlay:

      <a href="/decks" up-popup=".deck_list">Switch deck</a>

  If the `up-sticky` attribute is set, the dialog does not auto-close
  if a page fragment behind the popup overlay updates:

      <a href="/decks" up-popup=".deck_list">Switch deck</a>
      <a href="/settings" up-popup=".options" up-sticky>Settings</a>

  @selector [up-popup]
  @param [up-position]
    Defines where the popup is attached to the opening element.

    Valid values are `bottom-right`, `bottom-left`, `top-right` and `top-left`.
  @param {String} [up-confirm]
    A message that will be displayed in a cancelable confirmation dialog
    before the popup is opened.
  @param {String} [up-method='GET']
    Override the request method.
  @param [up-sticky]
    If set to `true`, the popup remains
    open even if the page changes in the background.
  @param {String} [up-history='false']
    Whether to push an entry to the browser history for the popup's source URL.

    Set this to `'false'` to prevent the URL bar from being updated.
    Set this to a URL string to update the history with the given URL.

  @stable
  ###
  up.link.onAction('[up-popup]', ($link) ->
    if $link.is('.up-current')
      close()
    else
      attach($link)
  )

  # Close the popup when someone clicks outside the popup
  # (but not on a popup opener).
  up.on('mousedown', 'body', (event, $body) ->
    $target = $(event.target)
    unless $target.closest('.up-popup').length || $target.closest('[up-popup]').length
      close()
  )
  
  up.on('up:fragment:inserted', (event, $fragment) ->
    if contains($fragment)
      if newSource = $fragment.attr('up-source')
        currentUrl = newSource
    else if contains(event.origin)
      autoclose()
  )
  
  # Close the pop-up overlay when the user presses ESC.
  up.bus.onEscape(-> close())

  ###*
  When an element with this attribute is clicked,
  a currently open popup is closed.

  Does nothing if no popup is currently open.

  To make a link that closes the current popup, but follows to
  a fallback destination if no popup is open:

      <a href="/fallback" up-close>Okay</a>

  @selector [up-close]
  @stable
  ###
  up.on('click', '[up-close]', (event, $element) ->
    if $element.closest('.up-popup').length
      close()
      # Only prevent the default when we actually closed a popup.
      # This way we can have buttons that close a popup when within a popup,
      # but link to a destination if not.
      event.preventDefault()
  )

  # The framework is reset between tests
  up.on 'up:framework:reset', reset

  knife: eval(Knife?.point)
  attach: attach
  close: close
  url: -> currentUrl
  coveredUrl: coveredUrl
  config: config
  defaults: -> u.error('up.popup.defaults(...) no longer exists. Set values on he up.popup.config property instead.')
  contains: contains
  open: -> up.error('up.popup.open no longer exists. Please use up.popup.attach instead.')
  source: -> up.error('up.popup.source no longer exists. Please use up.popup.url instead.')
  isOpen: isOpen

)(jQuery)
