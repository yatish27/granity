module Granity
  # Simple in-memory cache with dependency tracking and TTL
  class InMemoryCache
    def initialize(max_size: 10_000, ttl: 600)
      @data = {}
      @dependencies = {}
      @max_size = max_size
      @default_ttl = ttl
      @mutex = Mutex.new
    end

    # Read a value from cache
    def read(key)
      @mutex.synchronize do
        entry = @data[key]
        return nil unless entry

        # Check if entry is expired
        if entry[:expires_at] && entry[:expires_at] < Time.now
          @data.delete(key)
          return nil
        end

        entry[:value]
      end
    end

    # Write a value to cache with dependencies
    def write(key, value, dependencies: [], ttl: nil)
      @mutex.synchronize do
        # Set expiration time if ttl provided
        expires_at = ttl ? Time.now + ttl : (@default_ttl ? Time.now + @default_ttl : nil)

        # Store the value
        @data[key] = {
          value: value,
          expires_at: expires_at
        }

        # Register dependencies
        dependencies.each do |dependency|
          @dependencies[dependency] ||= []
          @dependencies[dependency] << key unless @dependencies[dependency].include?(key)
        end

        # Enforce max size by removing oldest entries if needed
        if @data.size > @max_size
          # Simple LRU - just remove oldest N/4 entries
          keys_to_remove = @data.keys.take(@max_size / 4)
          keys_to_remove.each { |k| @data.delete(k) }
        end

        value
      end
    end

    # Invalidate cache entries by dependency key
    def invalidate_dependencies(dependency_keys)
      @mutex.synchronize do
        keys_to_invalidate = []

        dependency_keys.each do |dep_key|
          # Get all cache keys dependent on this key
          if @dependencies[dep_key]
            keys_to_invalidate.concat(@dependencies[dep_key])
            @dependencies.delete(dep_key)
          end
        end

        # Remove the invalidated entries
        keys_to_invalidate.uniq.each do |key|
          @data.delete(key)
        end

        keys_to_invalidate.size
      end
    end

    # Clear the entire cache
    def clear
      @mutex.synchronize do
        @data.clear
        @dependencies.clear
      end
    end

    # Get current cache size
    def size
      @mutex.synchronize { @data.size }
    end
  end
end
