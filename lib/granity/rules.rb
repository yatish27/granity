module Granity
  # Rules namespace for permission evaluation rules
  module Rules
    # Base class for all rules
    class Base
      def initialize
        # Base initialization
      end
    end

    # Rule for checking relation existence
    class Relation < Base
      attr_reader :relation, :from

      def initialize(relation:, from: nil)
        @relation = relation.to_sym
        @from = from.to_sym if from
      end
    end

    # Rule for checking another permission
    class Permission < Base
      attr_reader :permission, :from

      def initialize(permission:, from: nil)
        @permission = permission.to_sym
        @from = from.to_sym if from
      end
    end

    # Rule container where ANY rule must match
    class Any < Base
      attr_reader :rules

      def initialize
        @rules = []
      end

      def include_relation(relation, from: nil)
        @rules << Relation.new(relation: relation, from: from)
      end

      def include_permission(permission, from: nil)
        @rules << Permission.new(permission: permission, from: from)
      end

      def include_any(&block)
        rule = Any.new
        rule.instance_eval(&block)
        @rules << rule
      end

      def include_all(&block)
        rule = All.new
        rule.instance_eval(&block)
        @rules << rule
      end
    end

    # Rule container where ALL rules must match
    class All < Base
      attr_reader :rules

      def initialize
        @rules = []
      end

      def include_relation(relation, from: nil)
        @rules << Relation.new(relation: relation, from: from)
      end

      def include_permission(permission, from: nil)
        @rules << Permission.new(permission: permission, from: from)
      end

      def include_any(&block)
        rule = Any.new
        rule.instance_eval(&block)
        @rules << rule
      end

      def include_all(&block)
        rule = All.new
        rule.instance_eval(&block)
        @rules << rule
      end
    end
  end
end
