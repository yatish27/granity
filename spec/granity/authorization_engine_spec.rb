require "rails_helper"

RSpec.describe Granity::AuthorizationEngine do
  before(:all) do
    # Define GitHub-like schema
    Granity.define do
      resource_type :user do
        # Users don't have specific relations in this simple model
      end

      resource_type :organization do
        relation :member, type: :user
        relation :admin, type: :user
        relation :team, type: :team

        permission :view do
          include_relation :member
          include_relation :admin
        end

        permission :admin do
          include_relation :admin
        end
      end

      resource_type :team do
        relation :member, type: :user
        relation :maintainer, type: :user

        permission :view do
          include_relation :member
          include_relation :maintainer
        end

        permission :manage do
          include_relation :maintainer
        end
      end

      resource_type :repository do
        relation :owner, type: :user
        relation :collaborator, type: :user
        relation :organization, type: :organization

        permission :read do
          include_any do
            include_relation :owner
            include_relation :collaborator
            include_relation :member, from: :organization
          end
        end

        permission :write do
          include_any do
            include_relation :owner
            include_relation :collaborator
          end
        end

        permission :admin do
          include_relation :owner
        end
      end
    end
  end

  before(:each) do
    # Clear relation tuples and cache before each test
    Granity::RelationTuple.delete_all
    Granity::AuthorizationEngine.reset_cache
  end

  describe ".check_permission" do
    let(:user_alice) { {type: "user", id: "alice"} }
    let(:user_bob) { {type: "user", id: "bob"} }
    let(:user_charlie) { {type: "user", id: "charlie"} }

    let(:org_acme) { {type: "organization", id: "acme"} }
    let(:team_engineering) { {type: "team", id: "engineering"} }
    let(:repo_api) { {type: "repository", id: "api"} }

    context "direct relation permissions" do
      it "grants permission when subject has direct relation to resource" do
        # Make Alice the owner of the API repo
        Granity.create_relation(
          object_type: repo_api[:type],
          object_id: repo_api[:id],
          relation: "owner",
          subject_type: user_alice[:type],
          subject_id: user_alice[:id]
        )

        # Alice should have read permission as owner
        expect(
          Granity.check_permission(
            subject_type: user_alice[:type],
            subject_id: user_alice[:id],
            permission: "read",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be true

        # Alice should have write permission as owner
        expect(
          Granity.check_permission(
            subject_type: user_alice[:type],
            subject_id: user_alice[:id],
            permission: "write",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be true

        # Alice should have admin permission as owner
        expect(
          Granity.check_permission(
            subject_type: user_alice[:type],
            subject_id: user_alice[:id],
            permission: "admin",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be true
      end

      it "denies permission when subject has no relation to resource" do
        # Bob has no relations to the API repo

        # Bob should not have read permission
        expect(
          Granity.check_permission(
            subject_type: user_bob[:type],
            subject_id: user_bob[:id],
            permission: "read",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be false
      end

      it "grants specific permissions based on relation" do
        # Make Bob a collaborator on the API repo
        Granity.create_relation(
          object_type: repo_api[:type],
          object_id: repo_api[:id],
          relation: "collaborator",
          subject_type: user_bob[:type],
          subject_id: user_bob[:id]
        )

        # Bob should have read permission as collaborator
        expect(
          Granity.check_permission(
            subject_type: user_bob[:type],
            subject_id: user_bob[:id],
            permission: "read",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be true

        # Bob should have write permission as collaborator
        expect(
          Granity.check_permission(
            subject_type: user_bob[:type],
            subject_id: user_bob[:id],
            permission: "write",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be true

        # Bob should NOT have admin permission as collaborator
        expect(
          Granity.check_permission(
            subject_type: user_bob[:type],
            subject_id: user_bob[:id],
            permission: "admin",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be false
      end
    end

    context "indirect relation permissions" do
      it "grants permission through organization membership" do
        # Setup organization and repository relationship
        Granity.create_relation(
          object_type: repo_api[:type],
          object_id: repo_api[:id],
          relation: "organization",
          subject_type: org_acme[:type],
          subject_id: org_acme[:id]
        )

        # Make Charlie a member of the Acme organization
        Granity.create_relation(
          object_type: org_acme[:type],
          object_id: org_acme[:id],
          relation: "member",
          subject_type: user_charlie[:type],
          subject_id: user_charlie[:id]
        )

        # Charlie should have read permission through org membership
        expect(
          Granity.check_permission(
            subject_type: user_charlie[:type],
            subject_id: user_charlie[:id],
            permission: "read",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be true

        # Charlie should NOT have write permission through org membership
        expect(
          Granity.check_permission(
            subject_type: user_charlie[:type],
            subject_id: user_charlie[:id],
            permission: "write",
            resource_type: repo_api[:type],
            resource_id: repo_api[:id]
          )
        ).to be false
      end
    end

    context "caching behavior" do
      it "caches permission check results" do
        # Create relations
        Granity.create_relation(
          object_type: repo_api[:type],
          object_id: repo_api[:id],
          relation: "owner",
          subject_type: user_alice[:type],
          subject_id: user_alice[:id]
        )

        # Spy on the evaluate method to track real calls
        allow(Granity::PermissionEvaluator).to receive(:evaluate).and_call_original

        # First check should hit the database
        result1 = Granity.check_permission(
          subject_type: user_alice[:type],
          subject_id: user_alice[:id],
          permission: "read",
          resource_type: repo_api[:type],
          resource_id: repo_api[:id]
        )

        # Second check should use cache
        result2 = Granity.check_permission(
          subject_type: user_alice[:type],
          subject_id: user_alice[:id],
          permission: "read",
          resource_type: repo_api[:type],
          resource_id: repo_api[:id]
        )

        # Both results should be the same
        expect(result1).to eq(true)
        expect(result2).to eq(true)

        # PermissionEvaluator should only be called once
        expect(Granity::PermissionEvaluator).to have_received(:evaluate).once
      end

      it "invalidates cache when relations change" do
        # Check permission before any relations (should be false)
        initial_result = Granity.check_permission(
          subject_type: user_alice[:type],
          subject_id: user_alice[:id],
          permission: "read",
          resource_type: repo_api[:type],
          resource_id: repo_api[:id]
        )

        # Create relation after checking
        Granity.create_relation(
          object_type: repo_api[:type],
          object_id: repo_api[:id],
          relation: "owner",
          subject_type: user_alice[:type],
          subject_id: user_alice[:id]
        )

        # Check again - should get fresh result
        after_relation_result = Granity.check_permission(
          subject_type: user_alice[:type],
          subject_id: user_alice[:id],
          permission: "read",
          resource_type: repo_api[:type],
          resource_id: repo_api[:id]
        )

        # Results should differ
        expect(initial_result).to eq(false)
        expect(after_relation_result).to eq(true)
      end
    end
  end
end
