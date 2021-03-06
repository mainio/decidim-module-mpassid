# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Mpassid
    # Tests the controller as well as the underlying SAML integration that the
    # OmniAuth strategy is correctly loading the attribute values from the SAML
    # response. Note that this is why we are using the `:request` type instead
    # of `:controller`, so that we get the OmniAuth middleware applied to the
    # requests and the MPASSid OmniAuth strategy to handle our generated
    # SAMLResponse.
    describe OmniauthCallbacksController, type: :request do
      let(:organization) { create(:organization) }

      # For testing with signed in user
      let(:confirmed_user) do
        create(:user, :confirmed, organization: organization)
      end

      before do
        # Make the time validation of the SAML response work properly
        allow(Time).to receive(:now).and_return(
          Time.utc(2019, 8, 14, 22, 35, 0)
        )

        # Set the correct host
        host! organization.host
      end

      describe "GET mpassid" do
        let(:saml_attributes_base) do
          {
            sn: "Mainio",
            firstName: "Matti Martti",
            givenName: "Matti",
            municipalityCode: "091",
            school: "Stadin skole",
            "urn:mpass.id:municipality" => "Helsinki",
            "urn:mpass.id:schoolCode" => "00001",
            "urn:mpass.id:class" => "9A",
            "urn:mpass.id:classLevel" => "9",
            "urn:mpass.id:role" => "Helsinki;00001;9A;Oppilas",
            "urn:mpass.id:uid" => saml_uid
          }
        end
        let(:saml_uid) { "MPASSOID.12a3bc45de678901234f5" }
        let(:saml_attributes) { {} }
        let(:saml_response) do
          attrs = saml_attributes_base.merge(saml_attributes)
          resp_xml = generate_saml_response(attrs)
          Base64.strict_encode64(resp_xml)
        end

        it "creates a new user record with the returned SAML attributes and auto-generated email" do
          omniauth_callback_get

          user = User.last

          expect(user.name).to eq("Matti Mainio")
          expect(user.nickname).to eq("matti_mainio")
          expect(user.email).to match(/mpassid-[a-z0-9]{32}@1.lvh.me/)

          authorization = Authorization.find_by(
            user: user,
            name: "mpassid_nids"
          )
          expect(authorization).not_to be_nil

          expect(authorization.metadata).to include(
            "first_name" => "Matti Martti",
            "given_name" => "Matti",
            "last_name" => "Mainio",
            "municipality" => "091",
            "municipality_name" => "Helsinki",
            "school_code" => "00001",
            "school_name" => "Stadin skole",
            "student_class" => "9A",
            "student_class_level" => "9",
            "role" => "Oppilas"
          )
        end

        context "when auto_email_domain is not defined" do
          before do
            allow(Decidim::Mpassid).to receive(:auto_email_domain).and_return(nil)
          end

          it "auto-generates the user's email based on organization's domain" do
            omniauth_callback_get

            user = User.last

            expect(user.email).to match(/mpassid-[a-z0-9]{32}@#{organization.host}/)
          end
        end

        context "with multi value colums having multiple values" do
          let(:saml_attributes) do
            {
              municipalityCode: %w(091 853),
              school: ["Stadin skole", "Tuolbuoljoggeen koulu"],
              "urn:mpass.id:municipality" => %w(Helsinki Turku),
              "urn:mpass.id:schoolCode" => %w(00001 00002),
              "urn:mpass.id:class" => %w(9A 9F),
              "urn:mpass.id:classLevel" => %w(9 9),
              "urn:mpass.id:role" => [
                "Helsinki;00001;9A;Oppilas",
                "Turku;00002;9F;Oppilas"
              ]
            }
          end

          it "separates the multiple values with a comma" do
            omniauth_callback_get

            user = User.last

            expect(user.name).to eq("Matti Mainio")
            expect(user.nickname).to eq("matti_mainio")

            authorization = Authorization.find_by(
              user: user,
              name: "mpassid_nids"
            )
            expect(authorization).not_to be_nil

            expect(authorization.metadata).to include(
              "first_name" => "Matti Martti",
              "given_name" => "Matti",
              "last_name" => "Mainio",
              "municipality" => "091,853",
              "municipality_name" => "Helsinki,Turku",
              "school_code" => "00001,00002",
              "school_name" => "Stadin skole,Tuolbuoljoggeen koulu",
              "student_class" => "9A,9F",
              "student_class_level" => "9,9",
              "role" => "Oppilas,Oppilas"
            )
          end
        end

        context "when the user is already signed in" do
          before do
            sign_in confirmed_user
          end

          it "adds the authorization to the signed in user" do
            omniauth_callback_get

            expect(confirmed_user.name).not_to eq("Matti Mainio")
            expect(confirmed_user.nickname).not_to eq("matti_mainio")

            authorization = Authorization.find_by(
              user: confirmed_user,
              name: "mpassid_nids"
            )
            expect(authorization).not_to be_nil

            expect(authorization.metadata).to include(
              "first_name" => "Matti Martti",
              "given_name" => "Matti",
              "last_name" => "Mainio",
              "municipality" => "091",
              "municipality_name" => "Helsinki",
              "school_code" => "00001",
              "school_name" => "Stadin skole",
              "student_class" => "9A",
              "student_class_level" => "9",
              "role" => "Oppilas"
            )
          end

          context "when user has set remember me" do
            before do
              confirmed_user.remember_created_at = Time.current
              confirmed_user.save!
            end

            it "forgets the user" do
              omniauth_callback_get
              expect(Decidim::User.find(confirmed_user.id).remember_created_at).to eq(nil)
            end
          end
        end

        context "when the user is already signed in and authorized" do
          let!(:authorization) do
            signature = OmniauthRegistrationForm.create_signature(
              :mpassid,
              saml_uid
            )
            authorization = Decidim::Authorization.create(
              user: confirmed_user,
              name: "mpassid_nids",
              attributes: {
                unique_id: signature,
                metadata: {}
              }
            )
            authorization.save!
            authorization.grant!
            authorization
          end

          before do
            sign_in confirmed_user
          end

          it "updates the existing authorization" do
            omniauth_callback_get

            # Check that the user record was NOT updated
            expect(confirmed_user.name).not_to eq("Matti Mainio")
            expect(confirmed_user.nickname).not_to eq("matti_mainio")

            # Check that the authorization is the same one
            authorizations = Authorization.where(
              user: confirmed_user,
              name: "mpassid_nids"
            )
            expect(authorizations.count).to eq(1)
            expect(authorizations.first).to eq(authorization)

            # Check that the metadata was updated
            expect(authorizations.first.metadata).to include(
              "first_name" => "Matti Martti",
              "given_name" => "Matti",
              "last_name" => "Mainio",
              "municipality" => "091",
              "municipality_name" => "Helsinki",
              "school_code" => "00001",
              "school_name" => "Stadin skole",
              "student_class" => "9A",
              "student_class_level" => "9",
              "role" => "Oppilas"
            )
          end
        end

        context "when another user is already identified with the same identity" do
          let(:another_user) do
            create(:user, :confirmed, organization: organization)
          end

          before do
            another_user.identities.create!(
              organization: organization,
              provider: "mpassid",
              uid: saml_uid
            )

            # Sign in the confirmed user
            sign_in confirmed_user
          end

          it "prevents the authorization with correct error message" do
            omniauth_callback_get

            authorization = Authorization.find_by(
              user: confirmed_user,
              name: "mpassid_nids"
            )
            expect(authorization).to be_nil
            expect(response).to redirect_to("/")
            expect(flash[:alert]).to eq(
              "Another user has already been identified using this identity. Please sign out and sign in again directly using MPASSid."
            )
          end
        end

        context "when another user is already authorized with the same identity" do
          let(:another_user) do
            create(:user, :confirmed, organization: organization)
          end

          before do
            signature = OmniauthRegistrationForm.create_signature(
              :mpassid,
              saml_uid
            )
            authorization = Decidim::Authorization.create(
              user: another_user,
              name: "mpassid_nids",
              attributes: {
                unique_id: signature,
                metadata: {}
              }
            )
            authorization.save!
            authorization.grant!

            # Sign in the confirmed user
            sign_in confirmed_user
          end

          it "prevents the authorization with correct error message" do
            omniauth_callback_get

            authorization = Authorization.find_by(
              user: confirmed_user,
              name: "mpassid_nids"
            )
            expect(authorization).to be_nil
            expect(response).to redirect_to("/")
            expect(flash[:alert]).to eq(
              "Another user has already authorized themselves with the same identity."
            )
          end
        end

        context "with response handling being outside of the allowed timeframe" do
          let(:saml_response) do
            attrs = saml_attributes_base.merge(saml_attributes)
            resp_xml = generate_saml_response(attrs) do |doc|
              conditions_node = doc.root.at_xpath(
                "//saml2:Assertion//saml2:Conditions",
                saml2: "urn:oasis:names:tc:SAML:2.0:assertion"
              )
              conditions_node["NotBefore"] = "2010-08-10T13:03:46.695Z"
              conditions_node["NotOnOrAfter"] = "2010-08-10T13:03:46.695Z"
            end
            Base64.strict_encode64(resp_xml)
          end

          it "calls the failure endpoint" do
            omniauth_callback_get

            expect(User.last).to be_nil
            expect(response).to redirect_to("/users/sign_in")
            expect(flash[:alert]).to eq(
              "The authentication request was not handled within an allowed timeframe. Please try again."
            )
          end
        end

        context "with authentication session expired" do
          let(:saml_response) do
            attrs = saml_attributes_base.merge(saml_attributes)
            resp_xml = generate_saml_response(attrs) do |doc|
              authn_node = doc.root.at_xpath(
                "//saml2:Assertion//saml2:AuthnStatement",
                saml2: "urn:oasis:names:tc:SAML:2.0:assertion"
              )
              authn_node["SessionNotOnOrAfter"] = "2010-08-10T13:03:46.695Z"
            end
            Base64.strict_encode64(resp_xml)
          end

          it "calls the failure endpoint" do
            omniauth_callback_get

            expect(User.last).to be_nil
            expect(response).to redirect_to("/users/sign_in")
            expect(flash[:alert]).to eq(
              "Authentication session expired. Please try again."
            )
          end
        end

        context "with failed authentication" do
          let(:saml_response) do
            resp_xml = saml_response_from_file("failed_request.xml")
            Base64.strict_encode64(resp_xml)
          end

          it "calls the failure endpoint" do
            omniauth_callback_get

            expect(User.last).to be_nil
            expect(response).to redirect_to("/users/sign_in")
            expect(flash[:alert]).to eq(
              "Authentication failed or cancelled. Please try again."
            )
          end
        end

        def omniauth_callback_get
          # Call the endpoint with the SAML response
          get "/users/auth/mpassid/callback", params: { SAMLResponse: saml_response }
        end
      end

      def generate_saml_response(attributes = {})
        saml_response_from_file("saml_response_unsigned.xml") do |doc|
          root_element = doc.root
          statements_node = root_element.at_xpath(
            "//saml2:Assertion//saml2:AttributeStatement",
            saml2: "urn:oasis:names:tc:SAML:2.0:assertion"
          )

          ::Devise.omniauth_configs[:mpassid].strategy[:request_attributes].each do |attr|
            key = begin
              if attr[:friendly_name]
                attr[:friendly_name].to_sym
              else
                attr[:name]
              end
            end
            value = attributes[key]
            next unless value

            attr_element = Nokogiri::XML::Node.new "saml2:Attribute", doc
            attr_element["FriendlyName"] = attr[:friendly_name]
            attr_element["Name"] = attr[:name]
            attr_element["NameFormat"] = attr[:name_format]

            value = [value] unless value.is_a?(Array)
            value.each do |val|
              attr_element.add_child("<saml2:AttributeValue>#{val}</saml2:AttributeValue>")
            end

            statements_node.add_child(attr_element)
          end

          yield doc if block_given?
        end
      end

      def saml_response_from_file(file)
        filepath = file_fixture(file)
        file_io = IO.read(filepath)
        doc = Nokogiri::XML::Document.parse(file_io)

        yield doc if block_given?

        sign_xml(doc.to_s)
      end

      def sign_xml(xml_string)
        cs = Decidim::Mpassid::Test::Runtime.cert_store
        OmniAuth::MPASSid::Test::Utility.signed_xml_from_string(
          xml_string,
          sign_certificate: cs.sign_certificate,
          sign_private_key: cs.sign_private_key
        )
      end
    end
  end
end
