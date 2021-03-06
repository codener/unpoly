###*
Forms
=====
  
Unpoly comes with functionality to [submit](/form-up-target) and [validate](/up-validate)
forms without leaving the current page. This means you can replace page fragments,
open dialogs with sub-forms, etc. all without losing form state.

@class up.form
###
up.form = (($) ->
  
  u = up.util

  ###*
  Sets default options for form submission and validation.

  @property up.form.config
  @param {Number} [config.observeDelay=0]
    The number of miliseconds to wait before [`up.observe`](/up.observe) runs the callback
    after the input value changes. Use this to limit how often the callback
    will be invoked for a fast typist.
  @param {Array} [config.validateTargets=['[up-fieldset]:has(&)', 'fieldset:has(&)', 'label:has(&)', 'form:has(&)']]
    An array of CSS selectors that are searched around a form field
    that wants to [validate](/up.validate). The first matching selector
    will be updated with the validation messages from the server.

    By default this looks for a `<fieldset>`, `<label>` or `<form>`
    around the validating input field, or any element with an
    `up-fieldset` attribute.
  @param {String} [config.fields]
    An array of CSS selectors that represent form fields, such as `input` or `select`.
  @stable
  ###
  config = u.config
    validateTargets: ['[up-fieldset]:has(&)', 'fieldset:has(&)', 'label:has(&)', 'form:has(&)']
    fields: [':input']
    observeDelay: 0

  reset = ->
    config.reset()

  ###*
  Submits a form via AJAX and updates a page fragment with the response.

      up.submit('form.new-user', { target: '.main' })
  
  Instead of loading a new page, the form is submitted via AJAX.
  The response is parsed for a CSS selector and the matching elements will
  replace corresponding elements on the current page.

  The UJS variant of this is the [`form[up-target]`](/form-up-target) selector.
  See the documentation for [`form[up-target]`](/form-up-target) for more
  information on how AJAX form submissions work in Unpoly.

  @function up.submit
  @param {Element|jQuery|String} formOrSelector
    A reference or selector for the form to submit.
    If the argument points to an element that is not a form,
    Unpoly will search its ancestors for the closest form.
  @param {String} [options.url]
    The URL where to submit the form.
    Defaults to the form's `action` attribute, or to the current URL of the browser window.
  @param {String} [options.method='post']
    The HTTP method used for the form submission.
    Defaults to the form's `up-method`, `data-method` or `method` attribute, or to `'post'`
    if none of these attributes are given.
  @param {String} [options.target]
    The selector to update when the form submission succeeds (server responds with status 200).
    Defaults to the form's `up-target` attribute, or to `'body'`.
  @param {String} [options.failTarget]
    The selector to update when the form submission fails (server responds with non-200 status).
    Defaults to the form's `up-fail-target` attribute, or to an auto-generated
    selector that matches the form itself.
  @param {Boolean|String} [options.history=true]
    Successful form submissions will add a history entry and change the browser's
    location bar if the form either uses the `GET` method or the response redirected
    to another page (this requires the `unpoly-rails` gem).
    If you want to prevent history changes in any case, set this to `false`.
    If you pass a `String`, it is used as the URL for the browser history.
  @param {String} [options.transition='none']
    The transition to use when a successful form submission updates the `options.target` selector.
    Defaults to the form's `up-transition` attribute, or to `'none'`.
  @param {String} [options.failTransition='none']
    The transition to use when a failed form submission updates the `options.failTarget` selector.
    Defaults to the form's `up-fail-transition` attribute, or to `options.transition`, or to `'none'`.
  @param {Number} [options.duration]
    The duration of the transition. See [`up.morph`](/up.morph).
  @param {Number} [options.delay]
    The delay before the transition starts. See [`up.morph`](/up.morph).
  @param {String} [options.easing]
    The timing function that controls the transition's acceleration. [`up.morph`](/up.morph).
  @param {Element|jQuery|String} [options.reveal]
    Whether to reveal the target element within its viewport.
  @param {Boolean} [options.restoreScroll]
    If set to `true`, this will attempt to [`restore scroll positions`](/up.restoreScroll)
    previously seen on the destination URL.
  @param {Boolean} [options.cache]
    Whether to force the use of a cached response (`true`)
    or never use the cache (`false`)
    or make an educated guess (`undefined`).

    By default only responses to `GET` requests are cached
    for a few minutes.
  @param {Object} [options.headers={}]
    An object of additional header key/value pairs to send along
    with the request.
  @return {Promise}
    A promise for the successful form submission.
  @stable
  ###
  submit = (formOrSelector, options) ->
    
    $form = $(formOrSelector).closest('form')

    options = u.options(options)
    target = u.option(options.target, $form.attr('up-target'), 'body')
    url = u.option(options.url, $form.attr('action'), up.browser.url())
    options.failTarget = u.option(options.failTarget, $form.attr('up-fail-target')) || u.selectorForElement($form)
    options.history = u.option(options.history, u.castedAttr($form, 'up-history'), true)
    options.transition = u.option(options.transition, u.castedAttr($form, 'up-transition'), 'none')
    options.failTransition = u.option(options.failTransition, u.castedAttr($form, 'up-fail-transition'), 'none')
    options.method = u.option(options.method, $form.attr('up-method'), $form.attr('data-method'), $form.attr('method'), 'post').toUpperCase()
    options.headers = u.option(options.headers, {})
    options.reveal = u.option(options.reveal, u.castedAttr($form, 'up-reveal'), true)
    options.cache = u.option(options.cache, u.castedAttr($form, 'up-cache'))
    options.restoreScroll = u.option(options.restoreScroll, u.castedAttr($form, 'up-restore-scroll'))
    options.origin = u.option(options.origin, $form)
    options.data = up.util.requestDataFromForm($form)
    options = u.merge(options, up.motion.animateOptions(options, $form))

    hasFileInputs = $form.find('input[type=file]').length
    canAjaxSubmit = !hasFileInputs || u.isFormData(options.data)
    canHistoryOption = up.browser.canPushState() || options.history == false

    if options.validate
      options.headers ||= {}
      options.headers['X-Up-Validate'] = options.validate
      # If a form has file inputs and the browser does not support FormData,
      # we cannot offer inline validations.
      unless canAjaxSubmit
        return u.unresolvablePromise()

    up.navigation.markActive($form)

    # If we can't submit this form via AJAX or if we wouldn't be able to change
    # the location URL as the result, fall back to a vanilla form submission.
    unless canAjaxSubmit && canHistoryOption
      $form.get(0).submit()
      return u.unresolvablePromise()

    promise = up.replace(target, url, options)
    promise.always -> up.navigation.unmarkActive($form)
    return promise

  ###*
  Observes a field or form and runs a callback when a value changes.

  This is useful for observing text fields while the user is typing.

  The UJS variant of this is the [`up-observe`](/up-observe) attribute.

  \#\#\#\# Example

  The following would submit the form whenever the
  text field value changes:

      up.observe('input[name=query]', function(value, $input) {
        up.submit($input)
      });

  \#\#\#\# Preventing concurrency

  Firing asynchronous code after a form field can cause
  [concurrency issues](https://makandracards.com/makandra/961-concurrency-issues-with-find-as-you-type-boxes).

  To mitigate this, `up.observe` will try to never run a callback
  before the previous callback has completed.
  To take advantage of this, your callback code must return a promise.
  Note that all asynchronous Unpoly functions return promises.

  \#\#\#\# Throttling

  If you are concerned about fast typists causing too much
  load on your server, you can use a `delay` option to wait
  a few miliseconds before executing the callback:

      up.observe('input', { delay: 100 }, function(value, $input) {
        up.submit($input)
      });

  @function up.observe
  @param {Element|jQuery|String} fieldOrSelector
  @param {Number} [options.delay=up.form.config.observeDelay]
    The number of miliseconds to wait before executing the callback
    after the input value changes. Use this to limit how often the callback
    will be invoked for a fast typist.
  @param {Function(value, $field)|String} onChange
    The callback to execute when the field's value changes.
    If given as a function, it must take two arguments (`value`, `$field`).
    If given as a string, it will be evaled as Javascript code in a context where
    (`value`, `$field`) are set.
  @return {Function}
    A destructor function that removes the observe watch when called.
  @stable
  ###
  observe = (selectorOrElement, args...) ->

    options = {}
    callbackArg = undefined
    if args.length == 1
      callbackArg = args[0]
    if args.length > 1
      options = u.options(args[0])
      callbackArg = args[1]

    $element = $(selectorOrElement)
    options = u.options(options)
    delay = u.option($element.attr('up-delay'), options.delay, config.observeDelay)
    delay = parseInt(delay)

    callback = null

    if u.isGiven(options.change)
      u.error('up.observe now takes the change callback as the last argument')

    rawCallback = u.option(u.presentAttr($element, 'up-observe'), callbackArg)
    if u.isString(rawCallback)
      callback = (value, $field) -> eval(rawCallback)
    else
      callback = rawCallback or u.error('up.observe: No change callback given')

    if $element.is('form')
      return observeForm($element, options, callback)

    knownValue = null
    callbackTimer = null
    callbackPromise = u.resolvedPromise()

    # This holds the next callback function, curried with `value` and `$field`.
    # Since we're waiting for callback promises to resolve before running
    # another callback, this might be overwritten while we're waiting for a
    # previous callback to finish.
    nextCallback = null

    runNextCallback = ->
      if nextCallback
        returnValue = nextCallback()
        nextCallback = null
        returnValue

    check = ->
      value = $element.val()
      # don't run the callback for the check during initialization
      skipCallback = u.isNull(knownValue)
      if knownValue != value
        knownValue = value
        unless skipCallback
          clearTimer()
          nextCallback = -> callback.apply($element.get(0), [value, $element])
          runAndChain = ->
            # Only run the callback once the previous callback's
            # promise resolves.
            callbackPromise.then ->
              returnValue = runNextCallback()
              # If the callback returns a promise, we will remember it
              # and chain additional callback invocations to it.
              if u.isPromise(returnValue)
                callbackPromise = returnValue
              else
                callbackPromise = u.resolvedPromise()
          u.setTimer(delay, runAndChain)

    clearTimer = ->
      clearTimeout(callbackTimer)

    changeEvents = if up.browser.canInputEvent()
      # Actually we only need `input`, but we want to notice
      # if another script manually triggers `change` on the element.
      'input change'
    else
      # Actually we won't ever get `input` from the user in this browser,
      # but we want to notice if another script manually triggers `input`
      # on the element.
      'input change keypress paste cut click propertychange'
    $element.on(changeEvents, check)

    check()

    # return destructor
    return ->
      $element.off(changeEvents, check)
      clearTimer()

  ###*
  @function observeForm
  @internal
  ###
  observeForm = ($form, options, callback) ->
    $fields = u.multiSelector(config.fields).find($form)
    destructors = u.map $fields, ($field) ->
      observe($field, callback)
    ->
      destructor() for destructor in destructors

  ###*
  [Observes](/up.observe) a field or form and submits the form when a value changes.

  The changed form field will be assigned a CSS class [`up-active`](/up-active)
  while the autosubmitted form is processing.

  The UJS variant of this is the [`up-autosubmit`](/up-autosubmit) attribute.

  @function up.autosubmit
  @param {String|Element|jQuery} selectorOrElement
    The field or form to observe.
  @param {Object} [options]
    See options for [`up.observe`](/up.observe)
  @return {Function}
    A destructor function that removes the observe watch when called.
  @stable
  ###
  autosubmit = (selectorOrElement, options) ->
    observe(selectorOrElement, options, (value, $field) ->
      $form = $field.closest('form')
      up.navigation.withActiveMark $field, -> submit($form)
    )

  resolveValidateTarget = ($field, options) ->
    target = u.option(options.target, $field.attr('up-validate'))
    if u.isBlank(target)
      target ||= u.detect(config.validateTargets, (defaultTarget) ->
        resolvedDefault = up.flow.resolveSelector(defaultTarget, options.origin)
        $field.closest(resolvedDefault).length
      )
    if u.isBlank(target)
      u.error('Could not find default validation target for %o (tried ancestors %o)', $field.get(0), config.validateTargets)
    unless u.isString(target)
      target = u.selectorForElement(target)
    target

  ###*
  Performs a server-side validation of a form and update the form
  with validation messages.

  `up.validate` submits the given field's form with an additional `X-Up-Validate`
  HTTP header. Upon seeing this header, the server is expected to validate (but not save)
  the form submission and render a new copy of the form with validation errors.

  The UJS variant of this is the [`[up-validate]`](/up-validate) selector.
  See the documentation for [`[up-validate]`](/up-validate) for more information
  on how server-side validation works in Unpoly.

  \#\#\#\# Example

      up.validate('input[name=email]', { target: '.email-errors' })

  @function up.validate
  @param {String|Element|jQuery} fieldOrSelector
  @param {String|Element|jQuery} [options.target]
  @return {Promise}
    A promise that is resolved when the server-side
    validation is received and the form was updated.
  @stable
  ###
  validate = (fieldOrSelector, options) ->
    $field = $(fieldOrSelector)
    options = u.options(options)
    options.origin = $field
    options.target = resolveValidateTarget($field, options)
    options.failTarget = options.target
    options.history = false
    options.headers = u.option(options.headers, {})
    # Make sure the X-Up-Validate header is present, so the server-side
    # knows that it should not persist the form submission
    options.validate = ($field.attr('name') || '__none__')
    options = u.merge(options, up.motion.animateOptions(options, $field))
    $form = $field.closest('form')
    promise = up.submit($form, options)
    promise

  currentValuesForSwitch = ($field) ->
    values = undefined
    if $field.is('input[type=checkbox]')
      if $field.is(':checked')
        values = [':checked', ':present', $field.val()]
      else
        values = [':unchecked', ':blank']
    else if $field.is('input[type=radio]')
      $checkedButton = $field.closest('form, body').find("input[type='radio'][name='#{$field.attr('name')}']:checked")
      if $checkedButton.length
        values = [':checked', ':present', $checkedButton.val()]
      else
        values = [':unchecked', ':blank']
    else
      value = $field.val()
      if u.isPresent(value)
        values = [':present', value]
      else
        values = [':blank']
    values

  currentValuesForSwitch = ($field) ->
    if $field.is('input[type=checkbox]')
      if $field.is(':checked')
        value = $field.val()
        meta = ':checked'
      else
        meta = ':unchecked'
    else if $field.is('input[type=radio]')
      $checkedButton = $field.closest('form, body').find("input[type='radio'][name='#{$field.attr('name')}']:checked")
      if $checkedButton.length
        meta = ':checked'
        value = $checkedButton.val()
      else
        meta = ':unchecked'
    else
      value = $field.val()
    values = []
    if u.isPresent(value)
      values.push(value)
      values.push(':present')
    else
      values.push(':blank')
    if u.isPresent(meta)
      values.push(meta)
    values

  ###*
  Shows or hides a target selector depending on the value.

  See [`[up-switch]`](/up-switch) for more documentation and examples.

  This function does not currently have a very useful API outside
  of our use for `up-switch`'s UJS behavior, that's why it's currently
  still marked `@internal`.

  @function up.form.switchTargets
  @param {String|Element|jQuery} fieldOrSelector
  @param {String} [options.target]
    The target selectors to switch.
    Defaults to an `up-switch` attribute on the given field.
  @internal
  ###
  switchTargets = (fieldOrSelector, options) ->
    $field = $(fieldOrSelector)
    options = u.options(options)
    targets = u.option(options.target, $field.attr('up-switch'))
    u.isPresent(targets) or u.error("No switch target given for %o", $field.get(0))
    fieldValues = currentValuesForSwitch($field)
    $(targets).each ->
      $target = $(this)
      if hideValues = $target.attr('up-hide-for')
        hideValues = hideValues.split(' ')
        show = u.intersect(fieldValues, hideValues).length == 0
      else
        if showValues = $target.attr('up-show-for')
          showValues = showValues.split(' ')
        else
          # If the target has neither up-show-for or up-hide-for attributes,
          # assume the user wants the target to be visible whenever anything
          # is checked or entered.
          showValues = [':present', ':checked']
        show = u.intersect(fieldValues, showValues).length > 0
      $target.toggle(show)

  ###*
  Forms with an `up-target` attribute are [submitted via AJAX](/up.submit)
  instead of triggering a full page reload.

      <form method="post" action="/users" up-target=".main">
        ...
      </form>

  The server response is searched for the selector given in `up-target`.
  The selector content is then [replaced](/up.replace) in the current page.

  The programmatic variant of this is the [`up.submit`](/up.submit) function.

  \#\#\#\# Failed submission

  When the server was unable to save the form due to invalid data,
  it will usually re-render an updated copy of the form with
  validation messages.

  For Unpoly to be able to detect a failed form submission,,
  the form must be re-rendered with a non-200 HTTP status code.
  We recommend to use either 400 (bad request) or
  422 (unprocessable entity).

  In Ruby on Rails, you can pass a
  [`:status` option to `render`](http://guides.rubyonrails.org/layouts_and_rendering.html#the-status-option)
  for this:

      class UsersController < ApplicationController

        def create
          user_params = params[:user].permit(:email, :password)
          @user = User.new(user_params)
          if @user.save?
            sign_in @user
          else
            render 'form', status: :bad_request
          end
        end

      end

  Note that you can also use the
  [`up-validate`](/up-validate) attribute to perform server-side
  validations while the user is completing fields.

  \#\#\#\# Redirects

  Unpoly requires two additional response headers to detect redirects,
  which are otherwise undetectable for an AJAX client.

  When the form's action performs a redirect, the server should echo
  the new request's URL as a response header `X-Up-Location`
  and the request's HTTP method as `X-Up-Method: GET`.

  If you are using Unpoly via the `unpoly-rails` gem, these headers
  are set automatically for every request.

  \#\#\#\# Giving feedback while the form is processing

  The `<form>` element will be assigned a CSS class `up-active` while
  the submission is loading.

  You can also [implement a spinner](/up.proxy/#spinners)
  by [listening](/up.on) to the [`up:proxy:slow`](/up:proxy:slow)
  and [`up:proxy:recover`](/up:proxy:recover) events.

  @selector form[up-target]
  @param {String} up-target
    The selector to [replace](/up.replace) if the form submission is successful (200 status code).
  @param {String} [up-fail-target]
    The selector to [replace](/up.replace) if the form submission is not successful (non-200 status code).
    If omitted, Unpoly will replace the `<form>` tag itself, assuming that the
    server has echoed the form with validation errors.
  @param {String} [up-transition]
    The animation to use when the form is replaced after a successful submission.
  @param {String} [up-fail-transition]
    The animation to use when the form is replaced after a failed submission.
  @param [up-history]
    Whether to push a browser history entry after a successful form submission.

    By default the form's target URL is used. If the form redirects to another URL,
    the redirect target will be used.

    Set this to `'false'` to prevent the URL bar from being updated.
    Set this to a URL string to update the history with the given URL.
  @param {String} [up-method]
    The HTTP method to be used to submit the form (`get`, `post`, `put`, `delete`, `patch`).
    Alternately you can use an attribute `data-method`
    ([Rails UJS](https://github.com/rails/jquery-ujs/wiki/Unobtrusive-scripting-support-for-jQuery))
    or `method` (vanilla HTML) for the same purpose.
  @param {String} [up-reveal='true']
    Whether to reveal the target element within its viewport before updating.
  @param {String} [up-restore-scroll='false']
    Whether to restore previously known scroll position of all viewports
    within the target selector.
  @param {String} [up-cache]
    Whether to force the use of a cached response (`true`)
    or never use the cache (`false`)
    or make an educated guess (`undefined`).

    By default only responses to `GET` requests are cached for a few minutes.
  @stable
  ###
  up.on 'submit', 'form[up-target]', (event, $form) ->
    event.preventDefault()
    submit($form)

  ###*
  When a form field with this attribute is changed,
  the form is validated on the server and is updated with
  validation messages.

  The programmatic variant of this is the [`up.validate`](/up.validate) function.

  \#\#\#\# Example

  Let's look at a standard registration form that asks for an e-mail and password:

      <form action="/users">

        <label>
          E-mail: <input type="text" name="email" />
        </label>

        <label>
          Password: <input type="password" name="password" />
        </label>

        <button type="submit">Register</button>

      </form>

  When the user changes the `email` field, we want to validate that
  the e-mail address is valid and still available. Also we want to
  change the `password` field for the minimum required password length.
  We can do this by giving both fields an `up-validate` attribute:

      <form action="/users">

        <label>
          E-mail: <input type="text" name="email" up-validate />
        </label>

        <label>
          Password: <input type="password" name="password" up-validate />
        </label>

        <button type="submit">Register</button>

      </form>

  Whenever a field with `up-validate` changes, the form is POSTed to
  `/users` with an additional `X-Up-Validate` HTTP header.
  Upon seeing this header, the server is expected to validate (but not save)
  the form submission and render a new copy of the form with validation errors.

  In Ruby on Rails the processing action should behave like this:

      class UsersController < ApplicationController

        # This action handles POST /users
        def create
          user_params = params[:user].permit(:email, :password)
          @user = User.new(user_params)
          if request.headers['X-Up-Validate']
            @user.valid?  # run validations, but don't save to the database
            render 'form' # render form with error messages
          elsif @user.save?
            sign_in @user
          else
            render 'form', status: :bad_request
          end
        end

      end

  Note that if you're using the `unpoly-rails` gem you can simply say `up.validate?`
  instead of manually checking for `request.headers['X-Up-Validate']`.

  The server now renders an updated copy of the form with eventual validation errors:

      <form action="/users">

        <label class="has-error">
          E-mail: <input type="text" name="email" value="foo@bar.com" />
          Has already been taken!
        </label>

        <button type="submit">Register</button>

      </form>

  The `<label>` around the e-mail field is now updated to have the `has-error`
  class and display the validation message.

  \#\#\#\# How validation results are displayed

  Although the server will usually respond to a validation with a complete,
  fresh copy of the form, Unpoly will by default not update the entire form.
  This is done in order to preserve volatile state such as the scroll position
  of `<textarea>` elements.

  By default Unpoly looks for a `<fieldset>`, `<label>` or `<form>`
  around the validating input field, or any element with an
  `up-fieldset` attribute.
  With the Bootstrap bindings, Unpoly will also look
  for a container with the `form-group` class.

  You can change this default behavior by setting `up.config.validateTargets`:

      // Always update the entire form containing the current field ("&")
      up.form.config.validateTargets = ['form &']

  You can also individually override what to update by setting the `up-validate`
  attribute to a CSS selector:

      <input type="text" name="email" up-validate=".email-errors">
      <span class="email-errors"></span>

  \#\#\#\# Updating dependent fields

  The `[up-validate]` behavior is also a great way to partially update a form
  when one fields depends on the value of another field.

  Let's say you have a form with one `<select>` to pick a department (sales, engineering, ...)
  and another `<select>` to pick an employeee from the selected department:

      <form action="/contracts">
        <select name="department">...</select> <!-- options for all departments -->
        <select name="employeed">...</select> <!-- options for employees of selected department -->
      </form>

  The list of employees needs to be updated as the appartment changes:

      <form action="/contracts">
        <select name="department" up-validate="[name=employee]">...</select>
        <select name="employee">...</select>
      </form>

  In order to update the `department` field in addition to the `employee` field, you could say
  `up-validate="&, [name=employee]"`, or simply `up-validate="form"` to update the entire form.

  @selector [up-validate]
  @param {String} up-validate
    The CSS selector to update with the server response.

    This defaults to a fieldset or form group around the validating field.
  @stable
  ###
  up.on 'change', '[up-validate]', (event, $field) ->
    validate($field)

  ###*
  Show or hide part of a form if certain options are selected or boxes are checked.

  \#\#\#\# Example

  The triggering input gets an `up-switch` attribute with a selector for the elements to show or hide:

      <select name="advancedness" up-switch=".target">
        <option value="basic">Basic parts</option>
        <option value="advanced">Advanced parts</option>
        <option value="very-advanced">Very advanced parts</option>
      </select>

  The target elements get a space-separated list of select values for which they are shown or hidden:

      <div class="target" up-show-for="basic">
        only shown for advancedness = basic
      </div>

      <div class="target" up-hide-for="basic">
        hidden for advancedness = basic
      </div>

      <div class="target" up-show-for="advanced very-advanced">
        shown for advancedness = advanced or very-advanced
      </div>

  For checkboxes you can also use the pseudo-values `:checked` or `:unchecked` like so:

      <input type="checkbox" name="flag" up-switch=".target">

      <div class="target" up-show-for=":checked">
        only shown when checkbox is checked
      </div>

  You can also use the pseudo-values `:blank` to match an empty input value,
  or `:present` to match a non-empty input value:

      <input type="text" name="email" up-switch=".target">

      <div class="target" up-show-for=":blank">
        please enter an email address
      </div>

  @selector [up-switch]
  @stable
  ###

  ###*
  Show this element only if a form field has a given value.

  See [`[up-switch]`](/up-switch) for more documentation and examples.

  @selector [up-show-for]
  @param up-show-for
    A space-separated list of values for which to show this element.
  @stable
  ###

  ###*
  Hide this element if a form field has a given value.

  See [`[up-switch]`](/up-switch) for more documentation and examples.

  @selector [up-hide-for]
  @param up-hide-for
    A space-separated list of values for which to hide this element.
  @stable
  ###

  up.on 'change', '[up-switch]', (event, $field) ->
    switchTargets($field)

  up.compiler '[up-switch]', ($field) ->
    switchTargets($field)

  ###*
  Observes this field or form and runs a callback when a value changes.

  This is useful for observing text fields while the user is typing.

  The programmatic variant of this is the [`up.observe`](/up.observe) function.

  \#\#\#\# Example

  The following would run a global `showSuggestions(value)` function
  whenever the `<input>` changes:

      <form>
        <input type="query" up-observe="showSuggestions(value)">
      </form>

  \#\#\#\# Callback context

  The script given to `up-observe` runs with the following context:

  | Name     | Type      | Description                           |
  | -------- | --------- | ------------------------------------- |
  | `value`  | `String`  | The current value of the field        |
  | `this`   | `Element` | The form field                        |
  | `$field` | `jQuery`  | The form field as a jQuery collection |

  @selector [up-observe]
  @param {String} up-observe
    The code to run when the field's value changes.
  @param {String} up-delay
    The number of miliseconds to wait after a change before the code is run.
  @stable
  ###
  up.compiler '[up-observe]', ($formOrField) -> observe($formOrField)

  ###*
  [Observes](/up.observe) this field or form and submits the form when a value changes.

  The form field will be assigned a CSS class [`up-active`](/up-active)
  while the autosubmitted form is processing.

  The programmatic variant of this is the [`up.autosubmit`](/up.autosubmit) function.

  \#\#\#\# Example

  The following would submit the form whenever the
  text field value changes:

      <form method="GET" action="/search" up-autosubmit>
        <input type="search" name="query">
      </form>

  The following would submit the form only if the query was changed,
  but not if the checkbox was changed:

      <form method="GET" action="/search">
        <input type="search" name="query" autosubmit>
        <input type="checkbox"> Include archive
      </form>

  @selector [up-autosubmit]
  @param {String} up-delay
    The number of miliseconds to wait after the change before the form is submitted.
  @stable
  ###
  up.compiler '[up-autosubmit]', ($formOrField) -> autosubmit($formOrField)

  up.on 'up:framework:reset', reset

  knife: eval(Knife?.point)
  config: config
  submit: submit
  observe: observe
  validate: validate
  switchTargets: switchTargets

)(jQuery)

up.submit = up.form.submit
up.observe = up.form.observe
up.autosubmit = up.form.autosubmit
up.validate = up.form.validate
