require_relative "lib/granity/version"

Gem::Specification.new do |spec|
  spec.name        = "granity"
  spec.version     = Granity::VERSION
  spec.authors     = [ "Yatish Mehta" ]
  spec.email       = [ "yatish27@users.noreply.github.com" ]
  spec.homepage    = "https://github.com/yatish27/granity"
  spec.summary     = "Fine-grained authorization for Ruby on Rails applications"
  spec.description = "Granity is a Ruby gem that provides fine-grained authorization capabilities for Ruby on Rails applications, allowing developers to implement detailed access control policies."
  spec.license     = "MIT"
  spec.required_ruby_version = '>= 3.1'

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yatish27/granity"
  spec.metadata["documentation_uri"] = "https://github.com/yatish27/granity/blob/main/README.md"
  spec.metadata["changelog_uri"] = "https://github.com/yatish27/granity/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.0", ">= 8.0.2"

  # Development dependencies
  spec.add_development_dependency "rubocop-rails-omakase", "~> 1.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-rails", "~> 7.1"
end
