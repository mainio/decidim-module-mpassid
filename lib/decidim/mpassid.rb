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
    # "mpassid-identifier@auto-email-domain.fi"
    config_accessor :auto_email_domain

    config_accessor :sp_entity_id, instance_reader: false

    # Extra configuration for the omniauth strategy
    config_accessor :extra do
      {}
    end

    # In case you want to set the authorization to expire.
    # Default is set to 0 minutes which means it will never expire.
    config_accessor :authorization_expiration do
      0.minutes
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

    def self.omniauth_settings
      settings = {
        mode: mode,
        sp_entity_id: sp_entity_id
      }
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
      if host.blank?
        # Default to local development environment
        host = "http://localhost"
        port ||= 3000
      end

      return "#{host}:#{port}" if port && ![80, 443].include?(port.to_i)

      host
    end
  end
end
