# frozen_string_literal: true

require "decidim/mpassid/test/runtime"

# This call is required to set the @configured flag to true, which the engine checks
# to register the Devise OmniAuth strategy and verification workflow.
Decidim::Mpassid.configure do |config|
  config.mode = :test
end

# In Decidim v0.31+, providers are no longer read from config/secrets.yml.
# They must be registered explicitly here instead.
Decidim.configure do |config|
  config.omniauth_providers[:mpassid] = {
    enabled: true,
    mode: "test",
    icon_path: "decidim/mpassid/mpassid_logo.svg"
  }
end

Decidim::Mpassid::Test::Runtime.initialize
