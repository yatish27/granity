require "rails_helper"

RSpec.describe Granity::PermissionEvaluator do
  describe ".evaluate" do
    before(:all) do
      # Define schema for testing
      Granity.define do
        resource_type :document do
          relation :owner, type: :user
          relation :viewer, type: :user
          relation :editor, type: :user
          relation :organization, type: :organization

          permission :view do
            include_any do
              include_relation :owner
              include_relation :viewer
              include_relation :editor
              include_relation :member, from: :organization
            end
          end

          permission :edit do
            include_any do
              include_relation :owner
              include_relation :editor
            end
          end

          permission :manage do
            include_relation :owner
          end
        end

        resource_type :organization do
          relation :member, type: :user
          relation :admin, type: :user
        end
      end
    end

    before(:each) do
      # Clear relation tuples before each test
      Granity::RelationTuple.delete_all
    end

    context "simple relations" do
      let(:doc_id) { "123" }
      let(:user_id) { "456" }

      it "should return true when relation exists" do
        # Create owner relation
        Granity::RelationTuple.create!(
          object_type: "document",
          object_id: doc_id,
          relation: "owner",
          subject_type: "user",
          subject_id: user_id
        )

        # Check permission
        result = described_class.evaluate(
          subject_type: "user",
          subject_id: user_id,
          permission: "view",
          resource_type: "document",
          resource_id: doc_id
        )

        expect(result).to be true
      end

      it "should return false when relation does not exist" do
        # No relations created

        result = described_class.evaluate(
          subject_type: "user",
          subject_id: user_id,
          permission: "view",
          resource_type: "document",
          resource_id: doc_id
        )

        expect(result).to be false
      end

      it "should handle different permissions based on relation" do
        # Create viewer relation
        Granity::RelationTuple.create!(
          object_type: "document",
          object_id: doc_id,
          relation: "viewer",
          subject_type: "user",
          subject_id: user_id
        )

        # Should have view permission
        view_result = described_class.evaluate(
          subject_type: "user",
          subject_id: user_id,
          permission: "view",
          resource_type: "document",
          resource_id: doc_id
        )

        # Should not have edit permission
        edit_result = described_class.evaluate(
          subject_type: "user",
          subject_id: user_id,
          permission: "edit",
          resource_type: "document",
          resource_id: doc_id
        )

        expect(view_result).to be true
        expect(edit_result).to be false
      end
    end

    context "relation traversal (from clauses)" do
      let(:doc_id) { "123" }
      let(:org_id) { "789" }
      let(:user_id) { "456" }

      it "should handle relation traversal" do
        # Create organization relation to document
        Granity::RelationTuple.create!(
          object_type: "document",
          object_id: doc_id,
          relation: "organization",
          subject_type: "organization",
          subject_id: org_id
        )

        # Create member relation to organization
        Granity::RelationTuple.create!(
          object_type: "organization",
          object_id: org_id,
          relation: "member",
          subject_type: "user",
          subject_id: user_id
        )

        # Check permission
        result = described_class.evaluate(
          subject_type: "user",
          subject_id: user_id,
          permission: "view",
          resource_type: "document",
          resource_id: doc_id
        )

        # User should have view permission through organization membership
        expect(result).to be true
      end

      it "should return false when traversal chain is broken" do
        # Create organization relation to document only
        Granity::RelationTuple.create!(
          object_type: "document",
          object_id: doc_id,
          relation: "organization",
          subject_type: "organization",
          subject_id: org_id
        )

        # No member relation to organization

        # Check permission
        result = described_class.evaluate(
          subject_type: "user",
          subject_id: user_id,
          permission: "view",
          resource_type: "document",
          resource_id: doc_id
        )

        # Should not have permission (chain is broken)
        expect(result).to be false
      end
    end
  end

  describe ".find_subjects" do
    before(:all) do
      # Define schema for testing
      Granity.define do
        resource_type :document do
          relation :owner, type: :user
          relation :viewer, type: :user

          permission :view do
            include_any do
              include_relation :owner
              include_relation :viewer
            end
          end
        end
      end
    end

    before(:each) do
      # Clear relation tuples before each test
      Granity::RelationTuple.delete_all
    end

    it "should return all subjects with a permission" do
      doc_id = "123"
      user1_id = "456"
      user2_id = "789"

      # Create relations
      Granity::RelationTuple.create!(
        object_type: "document",
        object_id: doc_id,
        relation: "owner",
        subject_type: "user",
        subject_id: user1_id
      )

      Granity::RelationTuple.create!(
        object_type: "document",
        object_id: doc_id,
        relation: "viewer",
        subject_type: "user",
        subject_id: user2_id
      )

      # Find subjects with view permission
      subjects = described_class.find_subjects(
        resource_type: "document",
        resource_id: doc_id,
        permission: "view"
      )

      # Should find both users
      expect(subjects.size).to eq(2)
      expect(subjects).to include({type: "user", id: user1_id})
      expect(subjects).to include({type: "user", id: user2_id})
    end

    it "should return empty array when no subjects have permission" do
      doc_id = "123"

      # No relations created

      # Find subjects with view permission
      subjects = described_class.find_subjects(
        resource_type: "document",
        resource_id: doc_id,
        permission: "view"
      )

      # Should return empty array
      expect(subjects).to be_empty
    end
  end
end
