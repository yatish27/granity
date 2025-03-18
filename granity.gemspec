require_relative "lib/granity/version"

Gem::Specification.new do |spec|
  spec.name = "granity"
  spec.version = Granity::VERSION
  spec.authors = ["Yatish Mehta"]
  spec.email = ["yatish27@users.noreply.github.com"]
  spec.homepage = "https://github.com/yatish27/granity"
  spec.summary = "Fine-grained authorization for Ruby on Rails"
  spec.description = "Granity is a flexible, caching-friendly authorization engine that provides fine-grained access control for Ruby on Rails applications"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = "https://github.com/yatish27/granity/blob/main/README.md"
  spec.metadata["changelog_uri"] = "https://github.com/yatish27/granity/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  rails_version = ">= 7.1"
  spec.add_dependency "activerecord", rails_version
  spec.add_dependency "railties", rails_version

  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "factory_bot_rails"
  spec.add_development_dependency "database_cleaner-active_record"
  spec.add_development_dependency "rubocop"
end
