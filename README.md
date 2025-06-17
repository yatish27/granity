# Granity

Granity is a fine-grained authorization engine for Ruby on Rails applications. It provides a flexible DSL for defining authorization rules and efficient permission checking.

## Installation

Add this gem to your application's Gemfile:

```ruby
gem 'granity'
```

Then execute:

```bash
$ bundle install
```

Run the migrations:

```bash
rails granity:install:migrations
rails db:migrate
```

## Configuration

Create an initializer for Granity:

```ruby
# config/initializers/granity.rb
Granity.configure do |config|
  config.cache_provider = Rails.cache # Optional: Uses Rails.cache if provided
  config.cache_ttl = 10.minutes
  config.max_cache_size = 10_000
  config.enable_tracing = !Rails.env.production?
  config.max_traversal_depth = 10
end
```

## Defining Authorization Schema

Use the Granity DSL to define your authorization schema:

```ruby
# config/initializers/granity.rb
Granity.define do
  resource_type :user do
    # User schema
  end

  resource_type :document do
    relation :owner, type: :user
    relation :viewer, type: :user
    relation :team, type: :team

    permission :view do
      include_any do
        include_relation :owner
        include_relation :viewer
        include_relation :admin from :team
      end
    end

    permission :edit do
      include_relation :owner
    end
  end

  resource_type :team do
    relation :member, type: :user
    relation :admin, type: :user
  end
end
```

## Usage

### Checking Permissions

```ruby
# Check if a user has permission on a resource
if Granity.check_permission(
  subject_type: 'user',
  subject_id: current_user.id,
  permission: 'view',
  resource_type: 'document',
  resource_id: document.id
)
  # User can view the document
end
```

### Creating Relations

```ruby
# Grant a user owner access to a document
Granity.create_relation(
  object_type: 'document',
  object_id: document.id,
  relation: 'owner',
  subject_type: 'user',
  subject_id: user.id
)
```

### Finding Subjects

```ruby
# Find all users who can view a document
viewers = Granity.find_subjects(
  resource_type: 'document',
  resource_id: document.id,
  permission: 'view'
)
```

### Integration with Rails Controllers

```ruby
class ApplicationController < ActionController::Base
  def authorize!(resource, permission)
    unless Granity.check_permission(
      subject_type: 'user',
      subject_id: current_user.id,
      permission: permission,
      resource_type: resource.model_name.singular,
      resource_id: resource.id
    )
      raise Unauthorized, "Not authorized to #{permission} this #{resource.model_name.human}"
    end
  end
end

class DocumentsController < ApplicationController
  def show
    @document = Document.find(params[:id])
    authorize!(@document, :view)
    # ...
  end

  def update
    @document = Document.find(params[:id])
    authorize!(@document, :edit)
    # ...
  end
end
```

## DSL Reference

### Resource Types

Define the entities in your authorization model:

```ruby
resource_type :document do
  # Resource definition
end
```

### Relations

Define relationships between resources:

```ruby
relation :owner, type: :user
relation :parent_folder, type: :folder
```

### Permissions

Define access rules with Boolean logic:

```ruby
permission :view do
  include_any do
    include_relation :owner
    include_relation :viewer
    include_relation :editor
  end
end
```

### Boolean Logic

Combine relations with `include_any` (OR) and `include_all` (AND):

```ruby
permission :publish do
  include_all do
    include_relation :editor

    include_any do
      include_relation :approved
      include_relation :admin from :team
    end
  end
end
```

### Permission Composition

Reuse and compose permissions:

```ruby
permission :manage do
  include_permission :view
  include_permission :edit
  include_relation :owner
end
```

### Relation Traversal

Follow paths through related resources:

```ruby
include_relation :member, from: :team
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
