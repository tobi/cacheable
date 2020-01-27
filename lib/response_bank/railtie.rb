# frozen_string_literal: true
require 'rails'
require 'response_bank/controller'
require 'response_bank/model_extensions'

module ResponseBank
  class Railtie < ::Rails::Railtie
    initializer "cachable.configure_active_record" do |config|
      config.middleware.insert_after(Rack::Head, ResponseBank::Middleware)

      ActiveSupport.on_load(:action_controller) do
        include ResponseBank::Controller
      end

      ActiveSupport.on_load(:active_record) do
        include ResponseBank::ModelExtensions
      end
    end
  end
end
