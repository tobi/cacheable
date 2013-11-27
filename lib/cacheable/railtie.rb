module Cacheable

  class Railtie < ::Rails::Railtie
    initializer "cachable.configure_active_record" do |config|
      config.middleware.insert_after 'ActionDispatch::BestStandardsSupport', Cacheable::Middleware

      ActionController::Base.send(:include, Cacheable::Controller)

      ActiveRecord::Base.class_eval do
        def self.cache_store
          ActionController::Base.cache_store
        end

        def cache_store
          ActionController::Base.cache_store
        end
      end
    end
  end
end
