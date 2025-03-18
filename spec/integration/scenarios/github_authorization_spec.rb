require "rails_helper"

RSpec.describe "GitHub Authorization" do
  before(:all) do
    # Define GitHub schema
    Granity.define do
      resource_type :user do
        # Users don't have specific relations
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
        relation :organization, type: :organization

        permission :view do
          include_relation :member
          include_relation :maintainer
        end

        permission :manage do
          include_relation :maintainer
        end
      end

      resource_type :repository do
        relation :owner_user, type: :user
        relation :owner_org, type: :organization
        relation :collaborator, type: :user
        relation :reader_team, type: :team
        relation :writer_team, type: :team
        relation :admin_team, type: :team

        # Read access (view code, clone, pull)
        permission :read do
          include_any do
            include_relation :owner_user
            include_relation :collaborator
            include_relation :member, from: :reader_team
            include_relation :member, from: :writer_team
            include_relation :member, from: :admin_team
            include_permission :read_org_repos, from: :owner_org
          end
        end

        # Write access (push, create branches)
        permission :write do
          include_any do
            include_relation :owner_user
            include_relation :collaborator
            include_relation :member, from: :writer_team
            include_relation :member, from: :admin_team
            include_permission :write_org_repos, from: :owner_org
          end
        end

        # Admin access (settings, delete, transfer)
        permission :admin do
          include_any do
            include_relation :owner_user
            include_relation :member, from: :admin_team
            include_permission :admin_org_repos, from: :owner_org
          end
        end
      end

      # Organization permissions regarding repos
      resource_type :organization do
        # Can read all org repos
        permission :read_org_repos do
          include_relation :member
          include_relation :admin
        end

        # Can write to org repos if admin or explicitly granted
        permission :write_org_repos do
          include_relation :admin
        end

        # Can admin org repos
        permission :admin_org_repos do
          include_relation :admin
        end
      end
    end
  end

  before(:each) do
    Granity::AuthorizationEngine.reset_cache
  end

  describe "GitHub scenario" do
    # Define users
    let(:alice) { {type: "user", id: "alice"} }
    let(:bob) { {type: "user", id: "bob"} }
    let(:charlie) { {type: "user", id: "charlie"} }
    let(:diana) { {type: "user", id: "diana"} }

    # Define organizations
    let(:acme_org) { {type: "organization", id: "acme"} }

    # Define teams
    let(:engineering_team) { {type: "team", id: "engineering"} }
    let(:devops_team) { {type: "team", id: "devops"} }

    # Define repositories
    let(:personal_repo) { {type: "repository", id: "alice/personal"} }
    let(:api_repo) { {type: "repository", id: "acme/api"} }
    let(:docs_repo) { {type: "repository", id: "acme/docs"} }

    before(:each) do
      # Set up the scenario

      # Organization memberships
      # Alice is an admin of Acme org
      Granity.create_relation(
        object_type: acme_org[:type],
        object_id: acme_org[:id],
        relation: "admin",
        subject_type: alice[:type],
        subject_id: alice[:id]
      )

      # Bob is a member of Acme org
      Granity.create_relation(
        object_type: acme_org[:type],
        object_id: acme_org[:id],
        relation: "member",
        subject_type: bob[:type],
        subject_id: bob[:id]
      )

      # Charlie is a member of Acme org
      Granity.create_relation(
        object_type: acme_org[:type],
        object_id: acme_org[:id],
        relation: "member",
        subject_type: charlie[:type],
        subject_id: charlie[:id]
      )

      # Team memberships
      # Bob is in engineering team
      Granity.create_relation(
        object_type: engineering_team[:type],
        object_id: engineering_team[:id],
        relation: "member",
        subject_type: bob[:type],
        subject_id: bob[:id]
      )

      # Charlie is a maintainer of the engineering team
      Granity.create_relation(
        object_type: engineering_team[:type],
        object_id: engineering_team[:id],
        relation: "maintainer",
        subject_type: charlie[:type],
        subject_id: charlie[:id]
      )

      # Charlie is in devops team
      Granity.create_relation(
        object_type: devops_team[:type],
        object_id: devops_team[:id],
        relation: "member",
        subject_type: charlie[:type],
        subject_id: charlie[:id]
      )

      # Team to org relationship
      Granity.create_relation(
        object_type: engineering_team[:type],
        object_id: engineering_team[:id],
        relation: "organization",
        subject_type: acme_org[:type],
        subject_id: acme_org[:id]
      )

      Granity.create_relation(
        object_type: devops_team[:type],
        object_id: devops_team[:id],
        relation: "organization",
        subject_type: acme_org[:type],
        subject_id: acme_org[:id]
      )

      # Repository ownership
      # Alice owns her personal repo
      Granity.create_relation(
        object_type: personal_repo[:type],
        object_id: personal_repo[:id],
        relation: "owner_user",
        subject_type: alice[:type],
        subject_id: alice[:id]
      )

      # Acme org owns the API and Docs repos
      Granity.create_relation(
        object_type: api_repo[:type],
        object_id: api_repo[:id],
        relation: "owner_org",
        subject_type: acme_org[:type],
        subject_id: acme_org[:id]
      )

      Granity.create_relation(
        object_type: docs_repo[:type],
        object_id: docs_repo[:id],
        relation: "owner_org",
        subject_type: acme_org[:type],
        subject_id: acme_org[:id]
      )

      # Repository team access
      # Engineering team has write access to API repo
      Granity.create_relation(
        object_type: api_repo[:type],
        object_id: api_repo[:id],
        relation: "writer_team",
        subject_type: engineering_team[:type],
        subject_id: engineering_team[:id]
      )

      # DevOps team has admin access to API repo
      Granity.create_relation(
        object_type: api_repo[:type],
        object_id: api_repo[:id],
        relation: "admin_team",
        subject_type: devops_team[:type],
        subject_id: devops_team[:id]
      )

      # Engineering team has read access to Docs repo
      Granity.create_relation(
        object_type: docs_repo[:type],
        object_id: docs_repo[:id],
        relation: "reader_team",
        subject_type: engineering_team[:type],
        subject_id: engineering_team[:id]
      )

      # Direct collaborator access
      # Diana is a collaborator on Alice's personal repo
      Granity.create_relation(
        object_type: personal_repo[:type],
        object_id: personal_repo[:id],
        relation: "collaborator",
        subject_type: diana[:type],
        subject_id: diana[:id]
      )
    end

    context "Alice's personal repository" do
      it "allows Alice to admin her own repo" do
        expect(
          Granity.check_permission(
            subject_type: alice[:type],
            subject_id: alice[:id],
            permission: "admin",
            resource_type: personal_repo[:type],
            resource_id: personal_repo[:id]
          )
        ).to be true
      end

      it "allows Diana to write as a collaborator" do
        expect(
          Granity.check_permission(
            subject_type: diana[:type],
            subject_id: diana[:id],
            permission: "write",
            resource_type: personal_repo[:type],
            resource_id: personal_repo[:id]
          )
        ).to be true
      end

      it "does not allow Diana to admin the repo" do
        expect(
          Granity.check_permission(
            subject_type: diana[:type],
            subject_id: diana[:id],
            permission: "admin",
            resource_type: personal_repo[:type],
            resource_id: personal_repo[:id]
          )
        ).to be false
      end

      it "does not allow Bob to read the repo" do
        expect(
          Granity.check_permission(
            subject_type: bob[:type],
            subject_id: bob[:id],
            permission: "read",
            resource_type: personal_repo[:type],
            resource_id: personal_repo[:id]
          )
        ).to be false
      end
    end

    context "Acme organization's API repository" do
      it "allows Alice to admin as an org admin" do
        expect(
          Granity.check_permission(
            subject_type: alice[:type],
            subject_id: alice[:id],
            permission: "admin",
            resource_type: api_repo[:type],
            resource_id: api_repo[:id]
          )
        ).to be true
      end

      it "allows Bob to write as engineering team member" do
        expect(
          Granity.check_permission(
            subject_type: bob[:type],
            subject_id: bob[:id],
            permission: "write",
            resource_type: api_repo[:type],
            resource_id: api_repo[:id]
          )
        ).to be true
      end

      it "allows Charlie to admin as devops team member" do
        expect(
          Granity.check_permission(
            subject_type: charlie[:type],
            subject_id: charlie[:id],
            permission: "admin",
            resource_type: api_repo[:type],
            resource_id: api_repo[:id]
          )
        ).to be true
      end

      it "does not allow Diana to read the repo" do
        expect(
          Granity.check_permission(
            subject_type: diana[:type],
            subject_id: diana[:id],
            permission: "read",
            resource_type: api_repo[:type],
            resource_id: api_repo[:id]
          )
        ).to be false
      end
    end

    context "Acme organization's Docs repository" do
      it "allows Bob to read but not write as engineering team member" do
        # Can read
        expect(
          Granity.check_permission(
            subject_type: bob[:type],
            subject_id: bob[:id],
            permission: "read",
            resource_type: docs_repo[:type],
            resource_id: docs_repo[:id]
          )
        ).to be true

        # Cannot write
        expect(
          Granity.check_permission(
            subject_type: bob[:type],
            subject_id: bob[:id],
            permission: "write",
            resource_type: docs_repo[:type],
            resource_id: docs_repo[:id]
          )
        ).to be false
      end

      it "allows Charlie to read docs repo but not admin it" do
        # Charlie is in engineering (read access) and devops (which has no access to docs)
        # Can read
        expect(
          Granity.check_permission(
            subject_type: charlie[:type],
            subject_id: charlie[:id],
            permission: "read",
            resource_type: docs_repo[:type],
            resource_id: docs_repo[:id]
          )
        ).to be true

        # Cannot admin
        expect(
          Granity.check_permission(
            subject_type: charlie[:type],
            subject_id: charlie[:id],
            permission: "admin",
            resource_type: docs_repo[:type],
            resource_id: docs_repo[:id]
          )
        ).to be false
      end
    end
  end
end
