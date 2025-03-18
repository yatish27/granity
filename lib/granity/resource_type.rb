module Granity
  # Definition of a resource type in the authorization schema
  class ResourceType
    attr_reader :name, :relations, :permissions

    def initialize(name)
      @name = name.to_sym
      @relations = {}
      @permissions = {}
    end

    # DSL method to define a relation
    def relation(name, type:, description: nil)
      @relations[name.to_sym] = Relation.new(
        name: name.to_sym,
        resource_type: @name,
        target_type: type.to_sym,
        description: description
      )
    end

    # DSL method to define a permission
    def permission(name, description: nil, &block)
      permission = Permission.new(
        name: name.to_sym,
        resource_type: @name,
        description: description
      )

      permission.instance_eval(&block) if block_given?
      @permissions[name.to_sym] = permission
    end
  end
end
