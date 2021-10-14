# frozen_string_literal: true

module Decidim
  module Mpassid
    class OmniauthCallbacksController < ::Decidim::Devise::OmniauthRegistrationsController
      # Make the view helpers available needed in the views
      helper Decidim::Mpassid::Engine.routes.url_helpers
      helper_method :omniauth_registrations_path

      skip_before_action :verify_authenticity_token, only: [:mpassid, :failure]
      skip_after_action :verify_same_origin_request, only: [:mpassid, :failure]

      # This is called always after the user returns from the authentication
      # flow from the MPASSid identity provider.
      def mpassid
        if user_signed_in?
          # The user is most likely returning from an authorization request
          # because they are already signed in. In this case, add the
          # authorization and redirect the user back to the authorizations view.

          # Make sure the user has an identity created in order to aid future
          # MPASSid sign ins.
          identity = current_user.identities.find_by(
            organization: current_organization,
            provider: oauth_data[:provider],
            uid: user_identifier
          )
          unless identity
            # Check that the identity is not already bound to another user.
            id = Decidim::Identity.find_by(
              organization: current_organization,
              provider: oauth_data[:provider],
              uid: user_identifier
            )
            return fail_authorize(:identity_bound_to_other_user) if id

            current_user.identities.create!(
              organization: current_organization,
              provider: oauth_data[:provider],
              uid: user_identifier
            )
          end

          # Add the authorization for the user
          return fail_authorize unless authorize_user(current_user)

          # Forget user's "remember me"
          current_user.forget_me!
          cookies.delete :remember_user_token, domain: current_organization.host
          cookies.delete :remember_admin_token, domain: current_organization.host
          cookies.update response.cookies

          # Show the success message and redirect back to the authorizations
          flash[:notice] = t(
            "authorizations.create.success",
            scope: "decidim.mpassid.verification"
          )
          return redirect_to(
            stored_location_for(resource || :user) ||
            decidim.root_path
          )
        end

        # Normal authentication request, proceed with Decidim's internal logic.
        send(:create)
      end

      def failure
        strategy = failed_strategy
        saml_response = strategy.response_object if strategy
        return super unless saml_response

        # In case we want more info about the returned status codes, use the
        # code below.
        #
        # Status codes:
        #   Requester = A problem with the request OR the user cancelled the
        #               request at the identity provider.
        #   Responder = The handling of the request failed.
        #   VersionMismatch = Wrong version in the request.
        #
        # Additional state codes:
        #   AuthnFailed = The authentication failed OR the user cancelled
        #                 the process at the identity provider.
        #   RequestDenied = The authenticating endpoint (which the
        #                   identity provider redirects to) rejected the
        #                   authentication.
        # if !saml_response.send(:validate_success_status) && !saml_response.status_code.nil?
        #   codes = saml_response.status_code.split(" | ").map do |full_code|
        #     full_code.split(":").last
        #   end
        # end

        # Some extra validation checks
        validations = [
          # The success status validation fails in case the response status
          # code is something else than "Success". This is most likely because
          # of one the reasons explained above. In general there are few
          # possible explanations for this:
          # 1. The user cancelled the request and returned to the service.
          # 2. The underlying identity service the IdP redirects to rejected
          #    the request for one reason or another. E.g. the user cancelled
          #    the request at the identity service.
          # 3. There is some technical problem with the identity provider
          #    service or the XML request sent to there is malformed.
          :success_status,
          # Checks if the local session should be expired, i.e. if the user
          # took too long time to go through the authorization endpoint.
          :session_expiration,
          # The NotBefore and NotOnOrAfter conditions failed, i.e. whether the
          # request is handled within the allowed timeframe by the IdP.
          :conditions
        ]
        validations.each do |key|
          next if saml_response.send("validate_#{key}")

          flash[:alert] = t(".#{key}")
          return redirect_to after_omniauth_failure_path_for(resource_name)
        end

        super
      end

      # This is overridden method from the Devise controller helpers
      # This is called when the user is successfully authenticated which means
      # that we also need to add the authorization for the user automatically
      # because a succesful MPASSid authentication means the user has been
      # successfully authorized as well.
      def sign_in_and_redirect(resource_or_scope, *args)
        # Add authorization for the user
        if resource_or_scope.is_a?(::Decidim::User)
          return fail_authorize unless authorize_user(resource_or_scope)
        end

        super
      end

      # Disable authorization redirect for the first login
      def first_login_and_not_authorized?(_user)
        false
      end

      private

      def authorize_user(user)
        authorization = Decidim::Authorization.find_by(
          name: "mpassid_nids",
          unique_id: user_signature
        )
        if authorization
          return nil if authorization.user != user
        else
          authorization = Decidim::Authorization.find_or_initialize_by(
            name: "mpassid_nids",
            user: user
          )
        end

        authorization.attributes = {
          unique_id: user_signature,
          metadata: authorization_metadata
        }
        authorization.save!

        # This will update the "granted_at" timestamp of the authorization which
        # will postpone expiration on re-authorizations in case the
        # authorization is set to expire (by default it will not expire).
        authorization.grant!

        authorization
      end

      def fail_authorize(failure_message_key = :already_authorized)
        flash[:alert] = t(
          "failure.#{failure_message_key}",
          scope: "decidim.mpassid.omniauth_callbacks"
        )
        redirect_to stored_location_for(resource || :user) || decidim.root_path
      end

      # Data that is stored against the authorization "permanently" (i.e. as
      # long as the authorization is valid).
      def authorization_metadata
        metadata_collector.metadata
      end

      def metadata_collector
        @metadata_collector ||= Decidim::Mpassid::Verification::Manager.metadata_collector_for(
          saml_attributes
        )
      end

      # Needs to be specifically defined because the core engine routes are not
      # all properly loaded for the view and this helper method is needed for
      # defining the omniauth registration form's submit path.
      def omniauth_registrations_path(resource)
        Decidim::Core::Engine.routes.url_helpers.omniauth_registrations_path(resource)
      end

      # Private: Create form params from omniauth hash
      # Since we are using trusted omniauth data we are generating a valid signature.
      def user_params_from_oauth_hash
        return nil if oauth_data.empty?
        return nil if saml_attributes.empty?
        return nil if user_identifier.blank?

        {
          provider: oauth_data[:provider],
          uid: user_identifier,
          name: oauth_data[:info][:name],
          # The nickname is automatically "parametrized" by Decidim core from
          # the name string, i.e. it will be in correct format.
          nickname: oauth_data[:info][:name],
          oauth_signature: user_signature,
          avatar_url: oauth_data[:info][:image],
          raw_data: oauth_hash
        }
      end

      def user_signature
        @user_signature ||= OmniauthRegistrationForm.create_signature(
          oauth_data[:provider],
          user_identifier
        )
      end

      # The MPASSid's assigned UID for the person. Note that this may change in
      # case the user moves to another "registry". Not sure what they mean with
      # "registry" in this context, but could be e.g. to another school or
      # municipality.
      def user_identifier
        @user_identifier ||= oauth_data[:uid]
      end

      # Digested format of the person's identifier to be used in the
      # auto-generated emails. This is used so that the actual identifier is not
      # revealed directly to the end user.
      def person_identifier_digest
        @person_identifier_digest ||= Digest::MD5.hexdigest(
          "MPASSID:#{user_identifier}:#{Rails.application.secrets.secret_key_base}"
        )
      end

      def verified_email
        @verified_email ||= begin
          domain = Decidim::Mpassid.auto_email_domain || current_organization.host
          "mpassid-#{person_identifier_digest}@#{domain}"
        end
      end

      def saml_attributes
        @saml_attributes ||= oauth_hash[:extra][:saml_attributes]
      end
    end
  end
end
