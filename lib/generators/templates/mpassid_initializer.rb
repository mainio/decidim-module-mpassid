# frozen_string_literal: true

Decidim::Mpassid.configure do |config|
  # Define the service provider entity ID:
  # config.sp_entity_id = "https://www.example.org/users/auth/mpassid/metadata"
  # Or define it in your application configuration and apply it here:
  # config.sp_entity_id = Rails.application.config.mpassid_entity_id
  # Enable automatically assigned emails
  config.auto_email_domain = "example.org"
end
