require "granity/version"
require "granity/configuration"
require "granity/schema"
require "granity/resource_type"
require "granity/relation"
require "granity/permission"
require "granity/rules"
require "granity/in_memory_cache"
require "granity/dependency_analyzer"
require "granity/permission_evaluator"
require "granity/authorization_engine"
# Rails engine is loaded at the end
require "granity/engine" if defined?(Rails)

module Granity
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    # Entry point for DSL schema definition
    def define(&block)
      Schema.define(&block)
    end

    # Configuration setup
    def configure
      yield(configuration) if block_given?
      configuration
    end

    # Public API to check permissions
    def check_permission(subject_type:, subject_id:, permission:, resource_type:, resource_id:)
      AuthorizationEngine.check_permission(
        subject_type: subject_type,
        subject_id: subject_id,
        permission: permission,
        resource_type: resource_type,
        resource_id: resource_id
      )
    end

    # Public API to find subjects with a permission
    def find_subjects(resource_type:, resource_id:, permission:)
      AuthorizationEngine.find_subjects(
        resource_type: resource_type,
        resource_id: resource_id,
        permission: permission
      )
    end

    # Public API to create relation tuples
    def create_relation(object_type:, object_id:, relation:, subject_type:, subject_id:)
      AuthorizationEngine.create_relation(
        object_type: object_type,
        object_id: object_id,
        relation: relation,
        subject_type: subject_type,
        subject_id: subject_id
      )
    end

    # Public API to delete relation tuples
    def delete_relation(object_type:, object_id:, relation:, subject_type:, subject_id:)
      AuthorizationEngine.delete_relation(
        object_type: object_type,
        object_id: object_id,
        relation: relation,
        subject_type: subject_type,
        subject_id: subject_id
      )
    end
  end
end
