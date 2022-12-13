# frozen_string_literal: true

require "decidim/dev"
require "omniauth-mpassid/test"
require "webmock"

require "decidim/mpassid/test/cert_store"
require "decidim/mpassid/test/runtime"
require "decidim/mpassid/metadata_template"

require "simplecov" if ENV.fetch("SIMPLECOV", true) || ENV.fetch("CODECOV", true)
if ENV["CODECOV"]
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

ENV["ENGINE_ROOT"] = File.dirname(__dir__)

Decidim::Dev.dummy_app_path =
  File.expand_path(File.join(__dir__, "decidim_dummy_app"))

require_relative "base_spec_helper"

Decidim::Mpassid::Test::Runtime.initializer do
  # Silence the OmniAuth logger
  OmniAuth.config.logger = Logger.new("/dev/null")

  # Configure the MPASSid module
  Decidim::Mpassid.configure do |config|
    cs = Decidim::Mpassid::Test::Runtime.cert_store

    config.mode = :test
    config.sp_entity_id = "http://1.lvh.me/users/auth/mpassid/metadata"
    config.auto_email_domain = "1.lvh.me"
    config.action_authorizer = "Decidim::Mpassid::ActionAuthorizer"
    config.school_metadata_klass = "Decidim::Mpassid::MetadataTemplate"
    config.extra = {
      assertion_consumer_service_url: "http://1.lvh.me/users/auth/mpassid/callback",
      idp_cert: cs.sign_certificate.to_pem,
      idp_cert_multi: {
        signing: [cs.sign_certificate.to_pem]
      }
    }
  end
end

Decidim::Mpassid::Test::Runtime.load_app

# Add the test templates path to ActionMailer
ActionMailer::Base.prepend_view_path(
  File.expand_path(File.join(__dir__, "fixtures", "mailer_templates"))
)

RSpec.configure do |config|
  # Make it possible to sign in and sign out the user in the request type specs.
  # This is needed because we need the request type spec for the omniauth
  # callback tests.
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.before do
    # Respond to the metadata request with a stubbed request to avoid external
    # HTTP calls.
    base_path = File.expand_path(File.join(__dir__, ".."))
    metadata_path = File.expand_path(
      File.join(base_path, "spec", "fixtures", "files", "idp_metadata.xml")
    )
    stub_request(
      :get,
      "https://mpass-proxy-test.csc.fi/idp/shibboleth"
    ).to_return(status: 200, body: File.new(metadata_path), headers: {})

    # Re-define the password validators due to a bug in the "email included"
    # check which does not work well for domains such as "1.lvh.me" that we are
    # using during tests.
    PasswordValidator.send(:remove_const, :VALIDATION_METHODS)
    PasswordValidator.const_set(
      :VALIDATION_METHODS,
      [
        :password_too_short?,
        :password_too_long?,
        :not_enough_unique_characters?,
        :name_included_in_password?,
        :nickname_included_in_password?,
        # :email_included_in_password?,
        :domain_included_in_password?,
        :password_too_common?,
        :blacklisted?
      ].freeze
    )
  end
end
