# frozen_string_literal: true

require "omniauth"
require "omniauth-mpassid"

require_relative "mpassid/version"
require_relative "mpassid/engine"
require_relative "mpassid/verification"
require_relative "mpassid/mail_interceptors"

module Decidim
  module Mpassid
    include ActiveSupport::Configurable

    @configured = false

    # :production - For MPASSid production environment
    # :test - For MPASSid test environment
    config_accessor :mode, instance_reader: false

    # Defines the auto email domain to generate verified email addresses upon
    # the user's registration automatically that have format similar to
    # "mpassid-identifier@auto-email-domain.fi".
    #
    # In case this is not defined, the default is the organization's domain.
    config_accessor :auto_email_domain

    config_accessor :sp_entity_id, instance_reader: false

    # The certificate string for the application
    config_accessor :certificate, instance_reader: false

    # The private key string for the application
    config_accessor :private_key, instance_reader: false

    # The certificate file for the application
    config_accessor :certificate_file

    # The private key file for the application
    config_accessor :private_key_file

    # Extra configuration for the omniauth strategy
    config_accessor :extra do
      {}
    end

    # Allows customizing the authorization workflow e.g. for adding custom
    # workflow options or configuring an action authorizer for the
    # particular needs.
    config_accessor :workflow_configurator do
      lambda do |workflow|
        # By default, expiration is set to 0 minutes which means it will
        # never expire.
        workflow.expires_in = 0.minutes
      end
    end

    # Allows customizing how the authorization metadata gets collected from
    # the SAML attributes passed from the authorization endpoint.
    config_accessor :metadata_collector_class do
      Decidim::Mpassid::Verification::MetadataCollector
    end

    def self.configured?
      @configured
    end

    def self.configure
      @configured = true
      super
    end

    def self.mode
      return config.mode if config.mode
      return :production unless Rails.application.secrets.omniauth
      return :production unless Rails.application.secrets.omniauth[:mpassid]

      # Read the mode from the secrets
      secrets = Rails.application.secrets.omniauth[:mpassid]
      secrets[:mode] == "test" ? :test : :production
    end

    def self.sp_entity_id
      return config.sp_entity_id if config.sp_entity_id

      "#{application_host}/users/auth/mpassid/metadata"
    end

    def self.certificate
      return File.read(certificate_file) if certificate_file

      config.certificate
    end

    def self.private_key
      return File.read(private_key_file) if private_key_file

      config.private_key
    end

    def self.omniauth_settings
      settings = {
        mode: mode,
        sp_entity_id: sp_entity_id
      }
      if certificate && private_key
        settings[:certificate] = certificate
        settings[:private_key] = private_key
      end
      settings.merge!(config.extra) if config.extra.is_a?(Hash)
      settings
    end

    # Used to determine the default service provider entity ID in case not
    # specifically set by the `sp_entity_id` configuration option.
    def self.application_host
      conf = Rails.application.config
      url_options = conf.action_controller.default_url_options
      url_options = conf.action_mailer.default_url_options if !url_options || !url_options[:host]
      url_options ||= {}

      host = url_options[:host]
      port = url_options[:port]
      protocol = url_options[:protocol]
      protocol = [80, 3000].include?(port.to_i) ? "http" : "https" if protocol.blank?
      if host.blank?
        # Default to local development environment
        protocol = "http" if url_options[:protocol].blank?
        host = "localhost"
        port ||= 3000
      end

      return "#{protocol}://#{host}:#{port}" if port && ![80, 443].include?(port.to_i)

      "#{protocol}://#{host}"
    end
  end
end
