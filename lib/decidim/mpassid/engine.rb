# frozen_string_literal: true

module Decidim
  module Mpassid
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Mpassid

      routes do
        devise_scope :user do
          # Manually map the SAML omniauth routes for Devise because the default
          # routes are mounted by core Decidim. This is because we want to map
          # these routes to the local callbacks controller instead of the
          # Decidim core.
          # See: https://git.io/fjDz1
          match(
            "/users/auth/mpassid",
            to: "omniauth_callbacks#passthru",
            as: "user_mpassid_omniauth_authorize",
            via: [:get, :post]
          )

          match(
            "/users/auth/mpassid/callback",
            to: "omniauth_callbacks#mpassid",
            as: "user_mpassid_omniauth_callback",
            via: [:get, :post]
          )
        end
      end

      initializer "decidim_mpassid.mount_routes", before: :add_routing_paths do
        # Mount the engine routes to Decidim::Core::Engine because otherwise
        # they would not get mounted properly. Note also that we need to prepend
        # the routes in order for them to override Decidim's own routes for the
        # "mpassid" authentication.
        Decidim::Core::Engine.routes.prepend do
          mount Decidim::Mpassid::Engine => "/"
        end
      end

      initializer "decidim_mpassid.setup", before: "devise.omniauth" do
        next unless Decidim::Mpassid.configured?

        # Configure the SAML OmniAuth strategy for Devise
        ::Devise.setup do |config|
          config.omniauth(
            :mpassid,
            Decidim::Mpassid.omniauth_settings
          )
        end

        # Customized version of Devise's OmniAuth failure app in order to handle
        # the failures properly. Without this, the failure requests would end
        # up in an ActionController::InvalidAuthenticityToken exception.
        devise_failure_app = OmniAuth.config.on_failure
        OmniAuth.config.on_failure = proc do |env|
          if env["PATH_INFO"].match? %r{^/users/auth/mpassid(/.*)?}
            env["devise.mapping"] = ::Devise.mappings[:user]
            Decidim::Mpassid::OmniauthCallbacksController.action(
              :failure
            ).call(env)
          else
            # Call the default for others.
            devise_failure_app.call(env)
          end
        end
      end

      initializer "decidim_mpassid.mail_interceptors" do
        ActionMailer::Base.register_interceptor(
          MailInterceptors::GeneratedRecipientsInterceptor
        )
      end
    end
  end
end
