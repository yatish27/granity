module Granity
  class Engine < ::Rails::Engine
    isolate_namespace Granity

    class << self
      def check_permission(subject_type:, subject_id:, permission:, resource_type:, resource_id:)
        trace "Checking permission: #{subject_type}:#{subject_id} -> #{permission} -> #{resource_type}:#{resource_id}"

        # Generate cache key
        cache_key = "permission:#{subject_type}:#{subject_id}:#{permission}:#{resource_type}:#{resource_id}"

        # Determine dependencies for proper invalidation
        data_deps = [
          "subject:#{subject_type}:#{subject_id}",
          "resource:#{resource_type}:#{resource_id}"
        ]

        schema_deps = dependency_analyzer.analyze_permission(resource_type, permission)
        all_deps = data_deps + schema_deps

        # Fetch from cache or compute
        cache.fetch(cache_key, all_deps, Granity.configuration.cache_ttl) do
          trace "Cache miss - evaluating permission rules"
          permission_evaluator.evaluate_permission(
            subject_type, subject_id, permission, resource_type, resource_id
          )
        end
      end

      def find_subjects(resource_type:, resource_id:, permission:)
        # Generate cache key
        cache_key = "subjects:#{permission}:#{resource_type}:#{resource_id}"

        # Dependencies for invalidation
        deps = ["resource:#{resource_type}:#{resource_id}"]
        schema_deps = dependency_analyzer.analyze_permission(resource_type, permission)
        all_deps = deps + schema_deps

        cache.fetch(cache_key, all_deps, Granity.configuration.cache_ttl) do
          permission_evaluator.find_subjects_with_permission(
            resource_type, resource_id, permission
          )
        end
      end

      def create_relation(object_type:, object_id:, relation:, subject_type:, subject_id:)
        # Store the relation tuple
        RelationTuple.create!(
          object_type: object_type,
          object_id: object_id,
          relation: relation,
          subject_type: subject_type,
          subject_id: subject_id
        )

        # Invalidate affected cache entries
        trace "Invalidating cache for new relation: #{object_type}:#{object_id} -> #{relation} -> #{subject_type}:#{subject_id}"

        # Precisely invalidate only affected items
        cache.invalidate("resource:#{object_type}:#{object_id}")
        cache.invalidate("subject:#{subject_type}:#{subject_id}")
        cache.invalidate("relation:#{object_type}:#{relation}")
      end

      def delete_relation(object_type:, object_id:, relation:, subject_type:, subject_id:)
        # Delete the relation tuple
        RelationTuple.where(
          object_type: object_type,
          object_id: object_id,
          relation: relation,
          subject_type: subject_type,
          subject_id: subject_id
        ).delete_all

        # Invalidate affected cache entries
        trace "Invalidating cache for deleted relation: #{object_type}:#{object_id} -> #{relation} -> #{subject_type}:#{subject_id}"
        cache.invalidate("resource:#{object_type}:#{object_id}")
        cache.invalidate("subject:#{subject_type}:#{subject_id}")
        cache.invalidate("relation:#{object_type}:#{relation}")
      end

      def reset_cache
        cache.clear
      end

      private

      def cache
        @cache ||= Granity.configuration.cache
      end

      def permission_evaluator
        @permission_evaluator ||= PermissionEvaluator.new
      end

      def dependency_analyzer
        @dependency_analyzer ||= DependencyAnalyzer.new
      end

      def trace(message)
        return unless Granity.configuration.enable_tracing
        Granity.configuration.logger.debug("[Granity] #{message}")
      end
    end

    initializer "granity.load_migrations" do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
