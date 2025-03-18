module Granity
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_migration
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        copy_file "create_granity_tables.rb", "db/migrate/#{timestamp}_create_granity_tables.rb"
      end

      def create_initializer
        copy_file "initializer.rb", "config/initializers/granity.rb"
      end
    end
  end
end
