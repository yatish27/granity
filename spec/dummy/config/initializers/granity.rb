# Configure Granity for tests
Granity.configure do |config|
  config.max_cache_size = 1000
  config.cache_ttl = 5.minutes
  config.enable_tracing = false
  config.max_traversal_depth = 5
end
