# frozen_string_literal: true

module Decidim
  module Mpassid
    module AuthorizationRule
      class Role < Base
        def valid?
          return true if allowed_roles.blank?
          return false if authorization.metadata["role"].blank?

          authorized_roles = authorization.metadata["role"].to_s.split(",").compact.collect(&:to_s).map(&:downcase)
          authorized_roles.any? { |role| allowed_roles.include?(role) }
        end

        def error_key
          "disallowed_role"
        end

        private

        def allowed_roles
          options[:allowed_roles]
        end
      end
    end
  end
end
