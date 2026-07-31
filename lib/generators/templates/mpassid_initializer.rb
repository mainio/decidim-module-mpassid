# frozen_string_literal: true

cert_path = Rails.application.root.join("config", "cert")

Decidim::Mpassid.configure do |config|
  # Define the service provider entity ID:
  # config.sp_entity_id = "https://www.example.org/users/auth/mpassid/metadata"
  # Or define it in your application configuration and apply it here:
  # config.sp_entity_id = Rails.application.config.mpassid_entity_id
  # Enable automatically assigned emails
  config.auto_email_domain = "example.org"
  config.certificate_file = "#{cert_path}/mpassid.crt"
  config.private_key_file = "#{cert_path}/mpassid.key"
end

# Register MPASSid as an OmniAuth provider in Decidim.
# Starting from Decidim v0.31, OmniAuth providers are no longer configured
# through config/secrets.yml. Instead, they must be registered directly in
# Decidim's configuration using config.omniauth_providers.
Decidim.configure do |config|
  config.omniauth_providers[:mpassid] = {
    enabled: Decidim::Env.new("OMNIAUTH_MPASSID_ENABLED", false),
    mode: Decidim::Env.new("OMNIAUTH_MPASSID_MODE", nil),
    icon_path: "decidim/mpassid/mpassid_logo.svg"
  }
end
