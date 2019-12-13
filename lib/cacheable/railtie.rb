# frozen_string_literal: true
require 'rails'
require 'cacheable/controller'
require 'cacheable/model_extensions'

module Cacheable
  class Railtie < ::Rails::Railtie
    initializer "cachable.configure_active_record" do |config|
      config.middleware.insert_after(Rack::Head, Cacheable::Middleware)

      ActiveSupport.on_load(:action_controller) do
        include Cacheable::Controller
      end

      ActiveSupport.on_load(:active_record) do
        include Cacheable::ModelExtensions
      end
    end
  end
end
