module Granity
  # Evaluates permissions based on the defined schema and relation tuples
  class PermissionEvaluator
    class << self
      # Evaluate if a subject has a permission on a resource
      def evaluate(subject_type:, subject_id:, permission:, resource_type:, resource_id:)
        # Get the schema definition
        schema = Granity::Schema.current
        resource_type_def = schema.resource_types[resource_type.to_sym]

        # If resource type doesn't exist, deny permission
        return false unless resource_type_def

        # Get the permission definition
        permission_def = resource_type_def.permissions[permission.to_sym]

        # If permission doesn't exist, deny permission
        return false unless permission_def

        # Evaluate the permission rules
        evaluate_rules(
          rules: permission_def.rules,
          subject_type: subject_type,
          subject_id: subject_id,
          resource_type: resource_type,
          resource_id: resource_id
        )
      end

      # Find subjects with a permission on a resource
      def find_subjects(resource_type:, resource_id:, permission:)
        # Get the schema definition
        schema = Granity::Schema.current
        resource_type_def = schema.resource_types[resource_type.to_sym]

        # If resource type doesn't exist, return empty array
        return [] unless resource_type_def

        # Get the permission definition
        permission_def = resource_type_def.permissions[permission.to_sym]

        # If permission doesn't exist, return empty array
        return [] unless permission_def

        # Get all relation tuples for this resource
        collect_subjects_for_permission(
          rules: permission_def.rules,
          resource_type: resource_type,
          resource_id: resource_id
        )
      end

      private

      # Evaluate rules recursively
      def evaluate_rules(rules:, subject_type:, subject_id:, resource_type:, resource_id:, depth: 0)
        # Prevent infinite recursion
        max_depth = Granity.configuration.max_traversal_depth
        if depth > max_depth
          raise "Maximum permission evaluation depth (#{max_depth}) exceeded"
        end

        rules.each do |rule|
          case rule
          when Granity::Rules::Relation
            # Check if relation tuple exists, handling the "from" case
            if rule.from
              # Relation traversal is needed
              if check_relation_traversal(
                subject_type: subject_type,
                subject_id: subject_id,
                relation: rule.relation,
                from_relation: rule.from,
                object_type: resource_type,
                object_id: resource_id
              )
                return true
              end
            elsif check_relation(
              subject_type: subject_type,
              subject_id: subject_id,
              relation: rule.relation,
              object_type: resource_type,
              object_id: resource_id
            )
              # Direct relation check
              return true
            end
          when Granity::Rules::Permission
            # Check referenced permission, handling "from" case
            if rule.from
              # Permission check with traversal - check permission on the "from" related objects
              if check_permission_traversal(
                subject_type: subject_type,
                subject_id: subject_id,
                permission: rule.permission,
                from_relation: rule.from,
                object_type: resource_type,
                object_id: resource_id,
                depth: depth + 1
              )
                return true
              end
            elsif evaluate(
              subject_type: subject_type,
              subject_id: subject_id,
              permission: rule.permission,
              resource_type: resource_type,
              resource_id: resource_id
            )
              # Direct permission check on the same resource
              return true
            end
          when Granity::Rules::Any
            # Check if any of the subrules match
            if rule.rules.any? do |subrule|
              evaluate_rules(
                rules: [subrule],
                subject_type: subject_type,
                subject_id: subject_id,
                resource_type: resource_type,
                resource_id: resource_id,
                depth: depth + 1
              )
            end
              return true
            end
          when Granity::Rules::All
            # Check if all of the subrules match
            if rule.rules.all? do |subrule|
              evaluate_rules(
                rules: [subrule],
                subject_type: subject_type,
                subject_id: subject_id,
                resource_type: resource_type,
                resource_id: resource_id,
                depth: depth + 1
              )
            end
              return true
            end
          end
        end

        false
      end

      # Check if a direct relation tuple exists
      def check_relation(subject_type:, subject_id:, relation:, object_type:, object_id:)
        Granity::RelationTuple.exists?(
          subject_type: subject_type,
          subject_id: subject_id,
          relation: relation,
          object_type: object_type,
          object_id: object_id
        )
      end

      # Check relation with traversal (the "from" case)
      def check_relation_traversal(subject_type:, subject_id:, relation:, from_relation:, object_type:, object_id:)
        # First, find all intermediary objects through the 'from' relation
        intermediaries = Granity::RelationTuple.where(
          object_type: object_type,
          object_id: object_id,
          relation: from_relation
        )

        # For each intermediary, check if the subject has the relation to it
        intermediaries.any? do |tuple|
          Granity::RelationTuple.exists?(
            subject_type: subject_type,
            subject_id: subject_id,
            relation: relation,
            object_type: tuple.subject_type,
            object_id: tuple.subject_id
          )
        end
      end

      # Check permission with traversal (the "from" case)
      def check_permission_traversal(subject_type:, subject_id:, permission:, from_relation:, object_type:, object_id:, depth:)
        # First, find all intermediary objects through the 'from' relation
        intermediaries = Granity::RelationTuple.where(
          object_type: object_type,
          object_id: object_id,
          relation: from_relation
        )

        # For each intermediary, check if the subject has the permission on it
        intermediaries.any? do |tuple|
          evaluate(
            subject_type: subject_type,
            subject_id: subject_id,
            permission: permission,
            resource_type: tuple.subject_type,
            resource_id: tuple.subject_id
          )
        end
      end

      # Collect subjects that have a permission on a resource
      def collect_subjects_for_permission(rules:, resource_type:, resource_id:)
        subjects = []

        rules.each do |rule|
          case rule
          when Granity::Rules::Relation
            if rule.from
              # Handle relation traversal for finding subjects
              intermediaries = Granity::RelationTuple.where(
                object_type: resource_type,
                object_id: resource_id,
                relation: rule.from
              )

              intermediaries.each do |tuple|
                # For each intermediary, find subjects with the relation
                relations = Granity::RelationTuple.where(
                  object_type: tuple.subject_type,
                  object_id: tuple.subject_id,
                  relation: rule.relation
                )

                relations.each do |rel|
                  subjects << {type: rel.subject_type, id: rel.subject_id}
                end
              end
            else
              # Direct relation - find all subjects with this relation
              tuples = Granity::RelationTuple.where(
                object_type: resource_type,
                object_id: resource_id,
                relation: rule.relation
              )

              tuples.each do |tuple|
                subjects << {type: tuple.subject_type, id: tuple.subject_id}
              end
            end
          when Granity::Rules::Permission
            # Find subjects with referenced permission
            if rule.from
              # Permission with traversal - we would need to traverse the "from" relation
              # and then find subjects with the permission on those objects
              # This is a simplification - in a real implementation we would handle this more efficiently
              intermediaries = Granity::RelationTuple.where(
                object_type: resource_type,
                object_id: resource_id,
                relation: rule.from
              )

              intermediaries.each do |tuple|
                perm_subjects = find_subjects(
                  resource_type: tuple.subject_type,
                  resource_id: tuple.subject_id,
                  permission: rule.permission
                )

                subjects.concat(perm_subjects)
              end
            else
              # Direct permission check
              referenced_subjects = find_subjects(
                resource_type: resource_type,
                resource_id: resource_id,
                permission: rule.permission
              )

              subjects.concat(referenced_subjects)
            end
          when Granity::Rules::Any, Granity::Rules::All
            # Recursively collect subjects for each subrule
            rule.rules.each do |subrule|
              subrule_subjects = collect_subjects_for_permission(
                rules: [subrule],
                resource_type: resource_type,
                resource_id: resource_id
              )

              subjects.concat(subrule_subjects)
            end
          end
        end

        # Remove duplicates
        subjects.uniq { |s| "#{s[:type]}:#{s[:id]}" }
      end
    end
  end
end
