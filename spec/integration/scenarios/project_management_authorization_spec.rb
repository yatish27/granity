require "rails_helper"

RSpec.describe "Project Management Authorization" do
  before(:all) do
    # Define project management schema
    Granity.define do
      # User resource type
      resource_type :user do
        # Users don't have specific relations in this model
      end

      # Project resource type
      resource_type :project do
        # Relations for users
        relation :admin, type: :user
        relation :editor, type: :user
        relation :commenter, type: :user

        # Relations for teams
        relation :admin_team, type: :team
        relation :editor_team, type: :team
        relation :commenter_team, type: :team

        # Permission to check if a user can edit tasks in this project
        permission :can_edit_tasks do
          include_any do
            # Check if user is admin
            include_relation :admin

            # Check if user is editor
            include_relation :editor

            # Check if user is member of admin team
            include_relation :member, from: :admin_team

            # Check if user is member of editor team
            include_relation :member, from: :editor_team
          end
        end
      end

      # Team resource type
      resource_type :team do
        # Relation for users
        relation :member, type: :user
      end

      # Task resource type
      resource_type :task do
        # Relations for projects
        relation :belongs_to, type: :project

        # Relation for creator
        relation :creator, type: :user

        # Permission to edit a task
        permission :edit do
          include_any do
            # Creator can edit
            include_relation :creator

            # Project admins and editors can edit
            include_permission :can_edit_tasks, from: :belongs_to
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

  describe "Task Edit Permission" do
    let(:user1_id) { "user1" }
    let(:user2_id) { "user2" }
    let(:user3_id) { "user3" }
    let(:project_id) { "project1" }
    let(:team1_id) { "team1" }
    let(:team2_id) { "team2" }
    let(:task_id) { "task1" }

    it "allows task creator to edit the task" do
      # Create relation: user1 is the creator of task1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "creator",
        subject_type: "user",
        subject_id: user1_id
      )

      # Check if user1 can edit task1
      result = Granity.check_permission(
        subject_type: "user",
        subject_id: user1_id,
        permission: "edit",
        resource_type: "task",
        resource_id: task_id
      )

      expect(result).to be true
    end

    it "allows project admin to edit tasks in the project" do
      # Create relation: task1 belongs to project1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "belongs_to",
        subject_type: "project",
        subject_id: project_id
      )

      # Create relation: user2 is admin of project1
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "admin",
        subject_type: "user",
        subject_id: user2_id
      )

      # Check if user2 can edit task1
      result = Granity.check_permission(
        subject_type: "user",
        subject_id: user2_id,
        permission: "edit",
        resource_type: "task",
        resource_id: task_id
      )

      expect(result).to be true
    end

    it "allows project editor to edit tasks in the project" do
      # Create relation: task1 belongs to project1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "belongs_to",
        subject_type: "project",
        subject_id: project_id
      )

      # Create relation: user3 is editor of project1
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "editor",
        subject_type: "user",
        subject_id: user3_id
      )

      # Check if user3 can edit task1
      result = Granity.check_permission(
        subject_type: "user",
        subject_id: user3_id,
        permission: "edit",
        resource_type: "task",
        resource_id: task_id
      )

      expect(result).to be true
    end

    it "allows team members to edit tasks if their team has admin role on the project" do
      # Create relation: task1 belongs to project1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "belongs_to",
        subject_type: "project",
        subject_id: project_id
      )

      # Create relation: team1 is admin_team of project1
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "admin_team",
        subject_type: "team",
        subject_id: team1_id
      )

      # Create relation: user1 is member of team1
      Granity::RelationTuple.create!(
        object_type: "team",
        object_id: team1_id,
        relation: "member",
        subject_type: "user",
        subject_id: user1_id
      )

      # Check if user1 can edit task1 through team membership
      result = Granity.check_permission(
        subject_type: "user",
        subject_id: user1_id,
        permission: "edit",
        resource_type: "task",
        resource_id: task_id
      )

      expect(result).to be true
    end

    it "allows team members to edit tasks if their team has editor role on the project" do
      # Create relation: task1 belongs to project1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "belongs_to",
        subject_type: "project",
        subject_id: project_id
      )

      # Create relation: team2 is editor_team of project1
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "editor_team",
        subject_type: "team",
        subject_id: team2_id
      )

      # Create relation: user2 is member of team2
      Granity::RelationTuple.create!(
        object_type: "team",
        object_id: team2_id,
        relation: "member",
        subject_type: "user",
        subject_id: user2_id
      )

      # Check if user2 can edit task1 through team membership
      result = Granity.check_permission(
        subject_type: "user",
        subject_id: user2_id,
        permission: "edit",
        resource_type: "task",
        resource_id: task_id
      )

      expect(result).to be true
    end

    it "denies edit permission to users without appropriate roles" do
      # Create relation: task1 belongs to project1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "belongs_to",
        subject_type: "project",
        subject_id: project_id
      )

      # Create relation: user3 is commenter of project1 (not enough for edit)
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "commenter",
        subject_type: "user",
        subject_id: user3_id
      )

      # Check if user3 can edit task1 (should be denied)
      result = Granity.check_permission(
        subject_type: "user",
        subject_id: user3_id,
        permission: "edit",
        resource_type: "task",
        resource_id: task_id
      )

      expect(result).to be false
    end

    it "finds all users who can edit a task" do
      # Create relation: task1 belongs to project1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "belongs_to",
        subject_type: "project",
        subject_id: project_id
      )

      # Create relation: user1 is the creator of task1
      Granity::RelationTuple.create!(
        object_type: "task",
        object_id: task_id,
        relation: "creator",
        subject_type: "user",
        subject_id: user1_id
      )

      # Create relation: user2 is admin of project1
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "admin",
        subject_type: "user",
        subject_id: user2_id
      )

      # Create relation: team1 is admin_team of project1
      Granity::RelationTuple.create!(
        object_type: "project",
        object_id: project_id,
        relation: "admin_team",
        subject_type: "team",
        subject_id: team1_id
      )

      # Create relation: user3 is member of team1
      Granity::RelationTuple.create!(
        object_type: "team",
        object_id: team1_id,
        relation: "member",
        subject_type: "user",
        subject_id: user3_id
      )

      # Find all users who can edit task1
      editors = Granity.find_subjects(
        resource_type: "task",
        resource_id: task_id,
        permission: "edit"
      )

      # Should find all three users
      expect(editors.size).to eq(3)
      expect(editors).to include({type: "user", id: user1_id})
      expect(editors).to include({type: "user", id: user2_id})
      expect(editors).to include({type: "user", id: user3_id})
    end
  end
end
