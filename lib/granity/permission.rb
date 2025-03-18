module Granity
  # Definition of a permission in the authorization schema
  class Permission
    attr_reader :name, :resource_type, :description, :rules

    def initialize(name:, resource_type:, description: nil)
      @name = name
      @resource_type = resource_type
      @description = description
      @rules = []
    end

    # Include a relation in the permission
    def include_relation(relation, from: nil)
      @rules << Rules::Relation.new(relation: relation, from: from)
    end

    # Include another permission in this permission
    def include_permission(permission, from: nil)
      @rules << Rules::Permission.new(permission: permission, from: from)
    end

    # Define a set of rules where ANY must match
    def include_any(&block)
      rule = Rules::Any.new
      rule.instance_eval(&block)
      @rules << rule
    end

    # Define a set of rules where ALL must match
    def include_all(&block)
      rule = Rules::All.new
      rule.instance_eval(&block)
      @rules << rule
    end
  end
end
