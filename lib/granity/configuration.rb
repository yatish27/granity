module Granity
  # Configuration class to hold Granity settings
  class Configuration
    attr_accessor :cache_provider
    attr_accessor :cache_ttl
    attr_accessor :max_cache_size
    attr_accessor :enable_tracing
    attr_accessor :max_traversal_depth

    def initialize
      @cache_provider = nil
      @cache_ttl = 10.minutes
      @max_cache_size = 10_000
      @enable_tracing = !defined?(Rails) || !Rails.env.production?
      @max_traversal_depth = 10
    end
  end
end
