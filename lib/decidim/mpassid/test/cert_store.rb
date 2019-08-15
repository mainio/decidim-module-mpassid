# frozen_string_literal: true

module Decidim
  module Mpassid
    module Test
      class CertStore
        attr_reader :sign_certificate, :sign_private_key

        def initialize
          # Use local certificate and private key for signing because otherwise
          # the locally signed SAMLResponse's signature cannot be properly
          # validated as we cannot sign it using the actual environments private
          # key which is unknown.
          sign_certgen = OmniAuth::MPASSid::Test::CertificateGenerator.new
          @sign_certificate = sign_certgen.certificate
          @sign_private_key = sign_certgen.private_key
        end
      end
    end
  end
end
