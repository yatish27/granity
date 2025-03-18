module Granity
  class Engine < ::Rails::Engine
    isolate_namespace Granity

    initializer "granity.load_migrations" do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
