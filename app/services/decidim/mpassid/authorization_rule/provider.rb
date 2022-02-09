# frozen_string_literal: true

module Decidim
  module Mpassid
    module AuthorizationRule
      class Provider < Base
        def valid?
          return true if allowed_providers.blank?
          return false if authorization.metadata["provider_id"].blank?

          authorized_providers = authorization.metadata["provider_id"].to_s.split(",").compact.collect(&:to_s)
          authorized_providers.any? { |provider| allowed_providers.include?(provider) }
        end

        def error_key
          "disallowed_provider"
        end

        private

        def allowed_providers
          options[:allowed_providers]
        end
      end
    end
  end
end
