module Cacheable
  module ModelExtensions
    def self.included(base)
      super
      base.extend ClassMethods
    end

    module ClassMethods
      def cache_store
        ActionController::Base.cache_store
      end
    end

    def cache_store
      ActionController::Base.cache_store
    end
  end
end
