Rails.application.routes.draw do

  mount JasmineRails::Engine => '/specs' if defined?(JasmineRails)
  root to: 'pages#start'

  get 'binding_test/:action', controller: 'binding_test'
  get 'css_test/:action', controller: 'css_test'

  namespace :form_test do
    resource :basic, only: [:new, :create]
    resource :upload, only: [:new, :create]
  end

end
