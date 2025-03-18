module Granity
  # Definition of a relation between resources
  class Relation
    attr_reader :name, :resource_type, :target_type, :description

    def initialize(name:, resource_type:, target_type:, description: nil)
      @name = name
      @resource_type = resource_type
      @target_type = target_type
      @description = description
    end
  end
end
