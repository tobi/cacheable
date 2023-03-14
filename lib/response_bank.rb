# frozen_string_literal: true
require 'response_bank/middleware'
require 'response_bank/railtie' if defined?(Rails)
require 'response_bank/response_cache_handler'
require 'msgpack'

module ResponseBank
  class << self
    attr_accessor :cache_store
    attr_writer :logger

    def log(message)
      @logger.info("[ResponseBank] #{message}")
    end

    def acquire_lock(_cache_key)
      raise NotImplementedError, "Override ResponseBank.acquire_lock in an initializer."
    end

    def write_to_cache(_key)
      yield
    end

    def write_to_backing_cache_store(_env, key, payload, expires_in: nil)
      cache_store.write(key, payload, raw: true, expires_in: expires_in)
    end

    def read_from_backing_cache_store(_env, cache_key, backing_cache_store: cache_store)
      backing_cache_store.read(cache_key, raw: true)
    end

    def compress(content, encoding: 'gzip')
      case encoding
      when 'gzip'
        io = StringIO.new
        gz = Zlib::GzipWriter.new(io)
        gz.write(content)
        gz.close
        io.string
      when 'br'
        Brotli.deflate(string)
      else
        raise ArgumentError, "Unsupported encoding: #{encoding}"
      end
    end

    def decompress(content, encoding: 'gzip')
      case encoding
      when 'gzip'
        Zlib::GzipReader.new(StringIO.new(content)).read
      when 'br'
        Brotli.inflate(content)
      else
        raise ArgumentError, "Unsupported encoding: #{encoding}"
      end
    end

    def cache_key_for(data)
      case data
      when Hash
        return data.inspect unless data.key?(:key)

        key = hash_value_str(data[:key])

        return key unless data.key?(:version)

        version = hash_value_str(data[:version])

        [key, version].join(":")
      when Array
        data.inspect
      when Time, DateTime
        data.to_i
      when Date
        data.to_time.to_i
      when true, false, Integer, Symbol, String
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
