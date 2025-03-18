module Granity
  class AuthorizationEngine
    class << self
      def check_permission(subject_type:, subject_id:, permission:, resource_type:, resource_id:)
        cache_key = "granity:permission:#{subject_type}:#{subject_id}:#{permission}:#{resource_type}:#{resource_id}"

        # Try fetching from cache first
        cached_result = cache.read(cache_key)
        if cached_result
          trace("CACHE HIT: #{cache_key} -> #{cached_result}")
          return cached_result
        end

        trace("CACHE MISS: #{cache_key}")

        # Generate dependencies for this permission check
        dependencies = DependencyAnalyzer.analyze_permission_check(
          subject_type: subject_type,
          subject_id: subject_id,
          permission: permission,
          resource_type: resource_type,
          resource_id: resource_id
        )

        # Check the permission
        result = PermissionEvaluator.evaluate(
          subject_type: subject_type,
          subject_id: subject_id,
          permission: permission,
          resource_type: resource_type,
          resource_id: resource_id
        )

        # Store in cache with all dependency keys
        cache.write(cache_key, result, dependencies: dependencies)
        trace("CACHE WRITE: #{cache_key} -> #{result} with dependencies: #{dependencies}")

        result
      end

      def find_subjects(resource_type:, resource_id:, permission:)
        cache_key = "granity:subjects:#{permission}:#{resource_type}:#{resource_id}"

        # Try fetching from cache first
        cached_result = cache.read(cache_key)
        if cached_result
          trace("CACHE HIT: #{cache_key}")
          return cached_result
        end

        trace("CACHE MISS: #{cache_key}")

        # Generate dependencies for this subjects query
        dependencies = DependencyAnalyzer.analyze_find_subjects(
          resource_type: resource_type,
          resource_id: resource_id,
          permission: permission
        )

        # Get the subjects
        subjects = PermissionEvaluator.find_subjects(
          resource_type: resource_type,
          resource_id: resource_id,
          permission: permission
        )

        # Store in cache with all dependency keys
        cache.write(cache_key, subjects, dependencies: dependencies)
        trace("CACHE WRITE: #{cache_key} with dependencies: #{dependencies}")

        subjects
      end

      def create_relation(object_type:, object_id:, relation:, subject_type:, subject_id:)
        # Create the relation tuple in the database
        tuple = Granity::RelationTuple.create!(
          object_type: object_type,
          object_id: object_id,
          relation: relation,
          subject_type: subject_type,
          subject_id: subject_id
        )

        # Invalidate cache entries that depend on this relation
        invalidate_cache_for_relation(object_type, object_id, relation)

        tuple
      rescue ActiveRecord::RecordNotUnique
        # If the relation already exists, just return it
        Granity::RelationTuple.find_by(
          object_type: object_type,
          object_id: object_id,
          relation: relation,
          subject_type: subject_type,
          subject_id: subject_id
        )
      end

      def delete_relation(object_type:, object_id:, relation:, subject_type:, subject_id:)
        tuple = Granity::RelationTuple.find_by(
          object_type: object_type,
          object_id: object_id,
          relation: relation,
          subject_type: subject_type,
          subject_id: subject_id
        )

        return false unless tuple

        tuple.destroy

        # Invalidate cache entries that depend on this relation
        invalidate_cache_for_relation(object_type, object_id, relation)

        true
      end

      def reset_cache
        cache.clear
      end

      private

      def cache
        @cache ||= begin
          config = Granity.configuration
          config.cache_provider || Granity::InMemoryCache.new(
            max_size: config.max_cache_size,
            ttl: config.cache_ttl
          )
        end
      end

      def invalidate_cache_for_relation(object_type, object_id, relation)
        # This is a simplified approach. In a real implementation, we would use
        # a more sophisticated approach to track which cache keys depend on which
        # relations, possibly using Redis sets or a similar mechanism.

        # For now, we take a conservative approach and invalidate any cache entry
        # that might depend on this relation being changed
        dependency_key = "granity:relation:#{object_type}:#{object_id}:#{relation}"
        cache.invalidate_dependencies([dependency_key])

        trace("CACHE INVALIDATE for dependency: #{dependency_key}")
      end

      def trace(message)
        return unless Granity.configuration.enable_tracing

        # In a real implementation, this would use a proper logging system
        puts "[Granity] #{message}"
      end
    end
  end
end
