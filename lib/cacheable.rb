require 'cacheable/middleware'
require 'cacheable/railtie' if defined?(Rails)
require 'cacheable/response_cache_handler'
require 'msgpack'

module Cacheable
  class << self
    def cache_store=(cache_store)
      @cache_store = cache_store
    end

    def cache_store
      @cache_store
    end

    def log(message)
      @logger.info "[Cacheable] #{message}"
    end

    def logger=(logger)
      @logger = logger
    end

    def acquire_lock(cache_key)
      raise NotImplementedError, "Override Cacheable.acquire_lock in an initializer."
    end

    def write_to_cache(key)
      yield
    end

    def compress(content)
      io = StringIO.new
      gz = Zlib::GzipWriter.new(io)
      gz.write(content)
      io.string
    ensure
      gz.close
    end

    def decompress(content)
      Zlib::GzipReader.new(StringIO.new(content)).read
    end

    def cache_key_for(data)
      case data
      when Hash
        return data.inspect unless data.key?(:key)

        key = hash_value_str(data[:key])

        return key unless data.key?(:version)

        version = hash_value_str(data[:version])

        return [key, version].join(":")
      when Array
        data.inspect
      when Time, DateTime
        data.to_i
      when Date
        data.to_time.to_i
      when true, false, Fixnum, Symbol, String
        data.inspect
      else
        data.to_s.inspect
      end
    end

    private

    def hash_value_str(data)
      if data.is_a?(Hash)
        data.values.join(",")
      else
        data.to_s
      end
    end
  end
end
