# frozen_string_literal: true

module Decidim
  module Mpassid
    module Verification
      # This is an engine that performs user authorization.
      class Engine < ::Rails::Engine
        isolate_namespace Decidim::Mpassid::Verification

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        routes do
          resource :authorizations, only: [:new], as: :authorization

          root to: "authorizations#new"
        end

        initializer "decidim_mpassid.verification_workflow" do
          # We cannot use the name `:mpassid` for the verification workflow
          # because otherwise the route namespace (decidim_mpassid) would
          # conflict with the main engine controlling the authentication flows.
          # The main problem that this would bring is that the root path for
          # this engine would not be found.
          Decidim::Verifications.register_workflow(:mpassid_nids) do |workflow|
            workflow.engine = Decidim::Mpassid::Verification::Engine
            workflow.expires_in = Decidim::Mpassid.config.authorization_expiration
          end
        end

        def load_seed
          # Enable the `:mpassid_nids` authorization
          org = Decidim::Organization.first
          org.available_authorizations << :mpassid_nids
          org.save!
        end
      end
    end
  end
end
