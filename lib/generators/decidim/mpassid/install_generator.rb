# frozen_string_literal: true

require "rails/generators/base"

module Decidim
  module Mpassid
    module Generators
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("../../templates", __dir__)

        desc "Creates a Decidim MPASSid initializer and copies locale files to your application."

        class_option(
          :test_initializer,
          desc: "Copies the test initializer instead of the actual one (for test dummy app).",
          type: :boolean,
          default: false,
          hide: true
        )

        def copy_initializer
          if options[:test_initializer]
            copy_file "mpassid_initializer_test.rb", "config/initializers/mpassid.rb"
          else
            copy_file "mpassid_initializer.rb", "config/initializers/mpassid.rb"
          end
        end
      end
    end
  end
end
