module Granity
  # Analyzes dependencies between relations and permissions for proper cache invalidation
  class DependencyAnalyzer
    class << self
      # Analyze dependencies for a permission check
      # Returns an array of dependencies for cache invalidation
      def analyze_permission_check(subject_type:, subject_id:, permission:, resource_type:, resource_id:)
        deps = []

        # Basic direct dependencies
        deps << "granity:subject:#{subject_type}:#{subject_id}"
        deps << "granity:resource:#{resource_type}:#{resource_id}"

        # Get schema dependencies for this permission
        schema_dependencies = analyze_permission_schema(resource_type, permission)
        deps.concat(schema_dependencies)

        deps
      end

      # Analyze dependencies for finding subjects with a permission
      def analyze_find_subjects(resource_type:, resource_id:, permission:)
        deps = []

        # Basic resource dependency
        deps << "granity:resource:#{resource_type}:#{resource_id}"

        # Get schema dependencies for this permission
        schema_dependencies = analyze_permission_schema(resource_type, permission)
        deps.concat(schema_dependencies)

        deps
      end

      private

      # Analyze schema dependencies for a permission
      def analyze_permission_schema(resource_type, permission)
        deps = []
        schema = Granity::Schema.current

        # Add dependency on the permission definition itself
        deps << "granity:schema:#{resource_type}:permission:#{permission}"

        # Get the resource type from schema
        resource_type_def = schema.resource_types[resource_type.to_sym]
        return deps unless resource_type_def

        # Get the permission definition
        permission_def = resource_type_def.permissions[permission.to_sym]
        return deps unless permission_def

        # Track visited permissions to prevent cycles
        visited = Set.new(["#{resource_type}:#{permission}"])

        # Add all relations that this permission depends on
        relations = extract_relations_from_permission(permission_def, [], visited)
        relations.each do |relation|
          deps << "granity:relation:#{resource_type}:#{relation}"
        end

        deps
      end

      # Extract all relations used in a permission definition
      def extract_relations_from_permission(rule_or_permission, relations = [], visited = Set.new)
        # Handle different types of input
        if rule_or_permission.is_a?(Granity::Permission)
          # It's a Permission object with rules
          rule_or_permission.rules.each do |rule|
            extract_relations_from_rule(rule, relations, visited, rule_or_permission.resource_type)
          end
        else
          # It's a rule object directly
          extract_relations_from_rule(rule_or_permission, relations, visited, nil)
        end

        relations.uniq
      end

      # Process a single rule to extract relations
      def extract_relations_from_rule(rule, relations = [], visited = Set.new, resource_type = nil)
        if rule.is_a?(Granity::Rules::Relation)
          # Direct relation - add to results
          relations << rule.relation
        elsif rule.is_a?(Granity::Rules::Any) || rule.is_a?(Granity::Rules::All)
          # Container rule - process each subrule
          rule.rules.each do |subrule|
            extract_relations_from_rule(subrule, relations, visited, resource_type)
          end
        elsif rule.is_a?(Granity::Rules::Permission)
          # Referenced permission - get from schema and process
          # Skip if we've already visited this permission to prevent cycles
          permission_key = "#{resource_type}:#{rule.permission}"
          return relations if visited.include?(permission_key)

          # Mark as visited to prevent cycles
          visited.add(permission_key)

          # Get referenced permission from schema (if possible)
          schema = Granity::Schema.current

          if resource_type && schema.resource_types[resource_type.to_sym]
            # If we know the resource type, look for the permission there
            resource_type_def = schema.resource_types[resource_type.to_sym]
            if resource_type_def.permissions.has_key?(rule.permission)
              referenced_permission = resource_type_def.permissions[rule.permission]
              extract_relations_from_permission(referenced_permission, relations, visited)
            end
          else
            # If resource type is unknown, look in all resource types
            resource_types = schema.resource_types.values
            resource_types.each do |rt|
              if rt.permissions.has_key?(rule.permission)
                referenced_permission = rt.permissions[rule.permission]
                extract_relations_from_permission(referenced_permission, relations, visited)
                break
              end
            end
          end
        end

        relations
      end
    end
  end
end
