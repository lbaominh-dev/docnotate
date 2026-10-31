require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Docnotate
  class << self
    def mode
      val = ENV["DOCNOTATE_MODE"].to_s.strip.downcase
      if val.present?
        val == "cloud" ? "cloud" : "local"
      elsif %w[1 true yes].include?(ENV["DOCNOTATE_CLOUD_MODE"].to_s.strip.downcase) ||
            %w[1 true yes].include?(ENV["DOCNOTATE_CLOUD"].to_s.strip.downcase)
        "cloud"
      else
        "local"
      end
    end

    def cloud?
      mode == "cloud"
    end

    def local?
      !cloud?
    end
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
