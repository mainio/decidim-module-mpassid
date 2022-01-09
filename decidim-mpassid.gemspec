# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "decidim/mpassid/version"

Gem::Specification.new do |spec|
  spec.name = "decidim-mpassid"
  spec.version = Decidim::Mpassid::VERSION
  spec.required_ruby_version = ">= 2.7"
  spec.authors = ["Antti Hukkanen"]
  spec.email = ["antti.hukkanen@mainiotech.fi"]

  spec.summary = "Provides possibility to bind MPASSid authentication provider to Decidim."
  spec.description = "Adds MPASSid authentication provider to Decidim."
  spec.homepage = "https://github.com/mainio/decidim-module-mpassid"
  spec.license = "AGPL-3.0"

  spec.files = Dir[
    "{app,config,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "decidim-core", Decidim::Mpassid::DECIDIM_VERSION
  spec.add_dependency "omniauth-mpassid", "~> 0.3.1"

  spec.add_development_dependency "decidim-dev", Decidim::Mpassid::DECIDIM_VERSION
end
