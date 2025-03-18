Granity.configure do |config|
  # Configure cache provider (defaults to nil)
  # config.cache_provider = Rails.cache

  # Configure cache TTL (defaults to 10 minutes)
  # config.cache_ttl = 10.minutes

  # Configure max cache size (defaults to 10,000)
  # config.max_cache_size = 10_000

  # Enable tracing (defaults to true in non-production)
  # config.enable_tracing = !Rails.env.production?

  # Configure max traversal depth (defaults to 10)
  # config.max_traversal_depth = 10
end

# Define your authorization schema
# Granity.define do
#   # Add your resource types, relations, and permissions here
# end
