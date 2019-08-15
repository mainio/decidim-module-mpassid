# frozen_string_literal: true

require "spec_helper"

describe Decidim::Mpassid do
  let(:config) { double }

  before do
    allow(subject).to receive(:config).and_return(config)
  end

  describe ".mode" do
    it "returns :production by default" do
      allow(config).to receive(:mode).and_return(nil)
      allow(Rails.application.secrets).to receive(:omniauth).and_return({})

      expect(subject.mode).to eq(:production)
    end

    context "when configured through module configuration" do
      let(:mode) { double }

      it "returns what is set by the module configuration" do
        allow(config).to receive(:mode).and_return(mode)

        expect(subject.mode).to eq(mode)
      end
    end

    context "when configured through OmniAuth configurations" do
      it "returns what is set by the module configuration" do
        allow(config).to receive(:mode).and_return(nil)
        allow(Rails.application.secrets).to receive(:omniauth).and_return(
          mpassid: { mode: "test" }
        )

        expect(subject.mode).to eq(:test)
      end
    end
  end

  describe ".sp_entity_id" do
    it "returns the correct path by default" do
      allow(config).to receive(:sp_entity_id).and_return(nil)
      expect(subject).to receive(:application_host).and_return(
        "https://www.example.org"
      )

      expect(subject.sp_entity_id).to eq(
        "https://www.example.org/users/auth/mpassid/metadata"
      )
    end

    context "when configured through module configuration" do
      let(:sp_entity_id) { double }

      it "returns what is set by the module configuration" do
        allow(config).to receive(:sp_entity_id).and_return(sp_entity_id)

        expect(subject.sp_entity_id).to eq(sp_entity_id)
      end
    end
  end

  describe ".omniauth_settings" do
    let(:mode) { double }
    let(:sp_entity_id) { double }
    let(:extra) { { extra1: "abc", extra2: 123 } }

    it "returns the expected omniauth configuration hash" do
      allow(subject).to receive(:mode).and_return(mode)
      allow(subject).to receive(:sp_entity_id).and_return(sp_entity_id)
      allow(config).to receive(:extra).and_return(extra)

      expect(subject.omniauth_settings).to include(
        mode: mode,
        sp_entity_id: sp_entity_id,
        extra1: "abc",
        extra2: 123
      )
    end
  end

  describe ".application_host" do
    let(:rails_config) { double }
    let(:controller_config) { double }
    let(:mailer_config) { double }

    let(:controller_defaults) { nil }
    let(:mailer_defaults) { nil }

    before do
      allow(Rails.application).to receive(:config).and_return(rails_config)
      allow(rails_config).to receive(:action_controller).and_return(controller_config)
      allow(rails_config).to receive(:action_mailer).and_return(mailer_config)
      allow(controller_config).to receive(:default_url_options).and_return(controller_defaults)
      allow(mailer_config).to receive(:default_url_options).and_return(mailer_defaults)
    end

    it "returns the development host by default" do
      expect(subject.application_host).to eq("http://localhost:3000")
    end

    context "with controller config without a host" do
      let(:controller_defaults) { { port: 8000 } }

      it "returns the default development host without applying the configured port" do
        expect(subject.application_host).to eq("http://localhost:3000")
      end

      context "and mailer configuration having a host" do
        let(:mailer_defaults) { { host: "https://www.example.org" } }

        it "returns the mailer config host" do
          expect(subject.application_host).to eq("https://www.example.org")
        end
      end

      context "and mailer configuration having a host and a port" do
        let(:mailer_defaults) { { host: "https://www.example.org", port: 4443 } }

        it "returns the mailer config host and port" do
          expect(subject.application_host).to eq("https://www.example.org:4443")
        end
      end
    end

    context "with controller config having a host" do
      let(:controller_defaults) { { host: "https://www.example.org" } }
      let(:mailer_defaults) { { host: "https://www.mailer.org", port: 4443 } }

      it "returns the controller config host" do
        expect(subject.application_host).to eq("https://www.example.org")
      end
    end

    context "with controller config having a host and a port" do
      let(:controller_defaults) { { host: "https://www.example.org", port: 8080 } }
      let(:mailer_defaults) { { host: "https://www.mailer.org", port: 4443 } }

      it "returns the controller config host and port" do
        expect(subject.application_host).to eq("https://www.example.org:8080")
      end

      context "when the port is 80" do
        let(:controller_defaults) { { host: "http://www.example.org", port: 80 } }

        it "does not append it to the host" do
          expect(subject.application_host).to eq("http://www.example.org")
        end
      end

      context "when the port is 443" do
        let(:controller_defaults) { { host: "https://www.example.org", port: 443 } }

        it "does not append it to the host" do
          expect(subject.application_host).to eq("https://www.example.org")
        end
      end
    end

    context "with mailer config having a host" do
      let(:mailer_defaults) { { host: "https://www.example.org" } }

      it "returns the mailer config host" do
        expect(subject.application_host).to eq("https://www.example.org")
      end
    end

    context "with mailer config having a host and a port" do
      let(:mailer_defaults) { { host: "https://www.example.org", port: 8080 } }

      it "returns the mailer config host and port" do
        expect(subject.application_host).to eq("https://www.example.org:8080")
      end

      context "when the port is 80" do
        let(:mailer_defaults) { { host: "http://www.example.org", port: 80 } }

        it "does not append it to the host" do
          expect(subject.application_host).to eq("http://www.example.org")
        end
      end

      context "when the port is 443" do
        let(:mailer_defaults) { { host: "https://www.example.org", port: 443 } }

        it "does not append it to the host" do
          expect(subject.application_host).to eq("https://www.example.org")
        end
      end
    end
  end
end
