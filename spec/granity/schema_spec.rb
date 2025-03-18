require "rails_helper"

RSpec.describe Granity::Schema do
  describe ".define" do
    it "creates resource types with relations and permissions" do
      schema = Granity::Schema.define do
        resource_type :user do
          # Empty resource type
        end

        resource_type :document do
          relation :owner, type: :user
          relation :viewer, type: :user

          permission :view do
            include_relation :owner
            include_relation :viewer
          end

          permission :edit do
            include_relation :owner
          end
        end
      end

      # Check resource types
      expect(schema.resource_types.keys).to contain_exactly(:user, :document)

      # Check document resource type
      document = schema.resource_types[:document]
      expect(document.name).to eq(:document)

      # Check relations
      expect(document.relations.keys).to contain_exactly(:owner, :viewer)
      expect(document.relations[:owner].target_type).to eq(:user)

      # Check permissions
      expect(document.permissions.keys).to contain_exactly(:view, :edit)

      # Check view permission rules
      view_permission = document.permissions[:view]
      expect(view_permission.rules.size).to eq(2)
      expect(view_permission.rules[0]).to be_a(Granity::Rules::Relation)
      expect(view_permission.rules[0].relation).to eq(:owner)

      # Check edit permission rules
      edit_permission = document.permissions[:edit]
      expect(edit_permission.rules.size).to eq(1)
      expect(edit_permission.rules[0]).to be_a(Granity::Rules::Relation)
      expect(edit_permission.rules[0].relation).to eq(:owner)
    end

    it "creates complex permission rules with any/all blocks" do
      schema = Granity::Schema.define do
        resource_type :document do
          relation :owner, type: :user
          relation :editor, type: :user
          relation :viewer, type: :user

          permission :access do
            include_any do
              include_relation :owner

              include_all do
                include_relation :editor
                include_relation :viewer
              end
            end
          end
        end
      end

      # Get the access permission
      document = schema.resource_types[:document]
      access_permission = document.permissions[:access]

      # Check the structure - should be an ANY rule at the top
      expect(access_permission.rules.size).to eq(1)
      expect(access_permission.rules[0]).to be_a(Granity::Rules::Any)

      # Check the ANY rule
      any_rule = access_permission.rules[0]
      expect(any_rule.rules.size).to eq(2)
      expect(any_rule.rules[0]).to be_a(Granity::Rules::Relation)
      expect(any_rule.rules[1]).to be_a(Granity::Rules::All)

      # Check the ALL rule
      all_rule = any_rule.rules[1]
      expect(all_rule.rules.size).to eq(2)
      expect(all_rule.rules[0]).to be_a(Granity::Rules::Relation)
      expect(all_rule.rules[1]).to be_a(Granity::Rules::Relation)
    end

    it "creates permissions that include other permissions" do
      schema = Granity::Schema.define do
        resource_type :document do
          relation :owner, type: :user
          relation :viewer, type: :user

          permission :view do
            include_relation :viewer
          end

          permission :manage do
            include_permission :view
            include_relation :owner
          end
        end
      end

      # Get the permissions
      document = schema.resource_types[:document]
      manage_permission = document.permissions[:manage]

      # Check manage permission structure
      expect(manage_permission.rules.size).to eq(2)
      expect(manage_permission.rules[0]).to be_a(Granity::Rules::Permission)
      expect(manage_permission.rules[0].permission).to eq(:view)
      expect(manage_permission.rules[1]).to be_a(Granity::Rules::Relation)
      expect(manage_permission.rules[1].relation).to eq(:owner)
    end

    it "creates relations with from clauses" do
      schema = Granity::Schema.define do
        resource_type :document do
          relation :organization, type: :organization

          permission :view do
            include_relation :member, from: :organization
          end
        end

        resource_type :organization do
          relation :member, type: :user
        end
      end

      # Get the permission
      document = schema.resource_types[:document]
      view_permission = document.permissions[:view]

      # Check the rule structure
      expect(view_permission.rules.size).to eq(1)
      expect(view_permission.rules[0]).to be_a(Granity::Rules::Relation)

      # Check the from clause
      relation_rule = view_permission.rules[0]
      expect(relation_rule.relation).to eq(:member)
      expect(relation_rule.from).to eq(:organization)
    end
  end

  describe ".current" do
    it "returns the last defined schema" do
      # Define a schema
      Granity::Schema.define do
        resource_type :document do
          relation :owner, type: :user
        end
      end

      # Define another schema
      schema2 = Granity::Schema.define do
        resource_type :user do
          # Empty
        end
      end

      # Current should be the last one defined
      expect(Granity::Schema.current).to eq(schema2)
      expect(Granity::Schema.current.resource_types.keys).to contain_exactly(:user)
    end
  end
end
