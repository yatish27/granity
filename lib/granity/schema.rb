module Granity
  # Schema definition for Granity authorization model
  class Schema
    attr_reader :resource_types

    class << self
      # DSL entry point for defining schema
      def define(&block)
        @current = new
        @current.instance_eval(&block)
        @current
      end

      # Get current schema
      def current
        @current ||= new
      end
    end

    def initialize
      @resource_types = {}
    end

    # DSL method to define a resource type
    def resource_type(name, &block)
      resource_type = ResourceType.new(name)
      resource_type.instance_eval(&block) if block_given?
      @resource_types[name] = resource_type
    end

    def validate_schema
      # Validate that all relation types reference valid resource types
      @resource_types.each do |name, resource_type|
        resource_type.relations.each do |relation_name, relation|
          unless @resource_types.key?(relation.type.to_sym)
            raise SchemaError, "Resource type '#{name}' has relation '#{relation_name}' with invalid type '#{relation.type}'"
          end
        end
      end

      # More validations could be added here
    end
  end

  class SchemaError < StandardError; end
end
