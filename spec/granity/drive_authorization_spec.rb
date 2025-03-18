require 'rails_helper'

RSpec.describe "Google Drive Authorization" do
  before(:all) do
    # Define Google Drive schema
    Granity.define do
      resource_type :user do
        # Users don't have specific relations
      end

      resource_type :group do
        relation :member, type: :user
      end

      resource_type :folder do
        relation :owner, type: :user
        relation :parent, type: :folder
        relation :viewer, type: :user
        relation :viewer_group, type: :group  # For groups who can view

        permission :view do
          include_any do
            include_relation :owner
            include_relation :viewer
            include_relation :member, from: :viewer_group
            include_permission :view, from: :parent
          end
        end

        permission :create_file do
          include_relation :owner
        end
      end

      resource_type :document do
        relation :owner, type: :user
        relation :parent, type: :folder
        relation :viewer, type: :user
        relation :viewer_group, type: :group  # For groups who can view

        permission :view do
          include_any do
            include_relation :owner
            include_relation :viewer
            include_relation :member, from: :viewer_group
            include_permission :view, from: :parent
          end
        end

        permission :write do
          include_any do
            include_relation :owner
            include_permission :create_file, from: :parent
          end
        end

        permission :change_owner do
          include_relation :owner
        end

        permission :share do
          include_any do
            include_relation :owner
            include_permission :create_file, from: :parent
          end
        end
      end
    end
  end

  before(:each) do
    # Clear relation tuples and cache before each test
    Granity::RelationTuple.delete_all
    Granity::AuthorizationEngine.reset_cache
  end

  describe "Google Drive scenario" do
    # Define users
    let(:anne) { { type: 'user', id: 'anne' } }
    let(:beth) { { type: 'user', id: 'beth' } }
    let(:charles) { { type: 'user', id: 'charles' } }
    let(:daniel) { { type: 'user', id: 'daniel' } }

    # Define groups
    let(:contoso) { { type: 'group', id: 'contoso' } }
    let(:fabrikam) { { type: 'group', id: 'fabrikam' } }

    # Define folders and documents
    let(:product_folder) { { type: 'folder', id: 'product_2021' } }
    let(:public_roadmap) { { type: 'document', id: 'public_roadmap' } }
    let(:roadmap_2021) { { type: 'document', id: 'roadmap_2021' } }

    before(:each) do
      # Set up the scenario

      # Group memberships
      Granity.create_relation(
        object_type: contoso[:type],
        object_id: contoso[:id],
        relation: 'member',
        subject_type: anne[:type],
        subject_id: anne[:id]
      )

      Granity.create_relation(
        object_type: contoso[:type],
        object_id: contoso[:id],
        relation: 'member',
        subject_type: beth[:type],
        subject_id: beth[:id]
      )

      Granity.create_relation(
        object_type: fabrikam[:type],
        object_id: fabrikam[:id],
        relation: 'member',
        subject_type: charles[:type],
        subject_id: charles[:id]
      )

      # Folder structure
      Granity.create_relation(
        object_type: product_folder[:type],
        object_id: product_folder[:id],
        relation: 'owner',
        subject_type: anne[:type],
        subject_id: anne[:id]
      )

      Granity.create_relation(
        object_type: product_folder[:type],
        object_id: product_folder[:id],
        relation: 'viewer_group',
        subject_type: fabrikam[:type],
        subject_id: fabrikam[:id]
      )

      # Documents and their parents
      Granity.create_relation(
        object_type: public_roadmap[:type],
        object_id: public_roadmap[:id],
        relation: 'parent',
        subject_type: product_folder[:type],
        subject_id: product_folder[:id]
      )

      Granity.create_relation(
        object_type: roadmap_2021[:type],
        object_id: roadmap_2021[:id],
        relation: 'parent',
        subject_type: product_folder[:type],
        subject_id: product_folder[:id]
      )

      # Document permissions
      Granity.create_relation(
        object_type: roadmap_2021[:type],
        object_id: roadmap_2021[:id],
        relation: 'viewer',
        subject_type: beth[:type],
        subject_id: beth[:id]
      )

      # Make public roadmap viewable by everyone
      # For simplicity, we'll add each user directly
      [ anne, beth, charles, daniel ].each do |user|
        Granity.create_relation(
          object_type: public_roadmap[:type],
          object_id: public_roadmap[:id],
          relation: 'viewer',
          subject_type: user[:type],
          subject_id: user[:id]
        )
      end
    end

    context "2021 Roadmap document" do
      it "allows Anne to write" do
        expect(
          Granity.check_permission(
            subject_type: anne[:type],
            subject_id: anne[:id],
            permission: 'write',
            resource_type: roadmap_2021[:type],
            resource_id: roadmap_2021[:id]
          )
        ).to be true
      end

      it "does not allow Beth to change owner" do
        expect(
          Granity.check_permission(
            subject_type: beth[:type],
            subject_id: beth[:id],
            permission: 'change_owner',
            resource_type: roadmap_2021[:type],
            resource_id: roadmap_2021[:id]
          )
        ).to be false
      end

      it "allows Charles to read (view)" do
        expect(
          Granity.check_permission(
            subject_type: charles[:type],
            subject_id: charles[:id],
            permission: 'view',
            resource_type: roadmap_2021[:type],
            resource_id: roadmap_2021[:id]
          )
        ).to be true
      end

      it "does not allow Charles to write" do
        expect(
          Granity.check_permission(
            subject_type: charles[:type],
            subject_id: charles[:id],
            permission: 'write',
            resource_type: roadmap_2021[:type],
            resource_id: roadmap_2021[:id]
          )
        ).to be false
      end

      it "does not allow Daniel to read" do
        expect(
          Granity.check_permission(
            subject_type: daniel[:type],
            subject_id: daniel[:id],
            permission: 'view',
            resource_type: roadmap_2021[:type],
            resource_id: roadmap_2021[:id]
          )
        ).to be false
      end
    end

    context "Public Roadmap document" do
      it "allows Daniel to read" do
        expect(
          Granity.check_permission(
            subject_type: daniel[:type],
            subject_id: daniel[:id],
            permission: 'view',
            resource_type: public_roadmap[:type],
            resource_id: public_roadmap[:id]
          )
        ).to be true
      end

      it "allows Anne to write" do
        expect(
          Granity.check_permission(
            subject_type: anne[:type],
            subject_id: anne[:id],
            permission: 'write',
            resource_type: public_roadmap[:type],
            resource_id: public_roadmap[:id]
          )
        ).to be true
      end

      it "does not allow Charles to write" do
        expect(
          Granity.check_permission(
            subject_type: charles[:type],
            subject_id: charles[:id],
            permission: 'write',
            resource_type: public_roadmap[:type],
            resource_id: public_roadmap[:id]
          )
        ).to be false
      end
    end
  end
end
