# frozen_string_literal: true

require "spec_helper"

describe Decidim::Mpassid::Engine do
  # Some of the tests may be causing the Devise OmniAuth strategies to be
  # reconfigured in which case the strategy option information is lost in the
  # Devise configurations. In case the strategy is lost, re-initialize it
  # manually. Normally this is done when the application's middleware stack is
  # loaded.
  after do
    unless ::Devise.omniauth_configs[:mpassid].strategy
      ::OmniAuth::Strategies::MPASSid.new(
        Rails.application,
        Decidim::Mpassid.omniauth_settings
      ) do |strategy|
        ::Devise.omniauth_configs[:mpassid].strategy = strategy
      end
    end
  end

  it "mounts the routes to the core engine" do
    routes = double
    expect(Decidim::Core::Engine).to receive(:routes).and_return(routes)
    expect(routes).to receive(:prepend) do |&block|
      context = double
      expect(context).to receive(:mount).with(described_class => "/")
      context.instance_eval(&block)
    end

    run_initializer("decidim_mpassid.mount_routes")
  end

  it "adds the correct routes to the core engine" do
    run_initializer("decidim_mpassid.mount_routes")

    %w(GET POST).each do |method|
      expect(
        Decidim::Core::Engine.routes.recognize_path(
          "/users/auth/mpassid",
          method: method
        )
      ).to eq(
        controller: "decidim/mpassid/omniauth_callbacks",
        action: "passthru"
      )
      expect(
        Decidim::Core::Engine.routes.recognize_path(
          "/users/auth/mpassid/callback",
          method: method
        )
      ).to eq(
        controller: "decidim/mpassid/omniauth_callbacks",
        action: "mpassid"
      )
    end
  end

  it "configures the MPASSid omniauth strategy for Devise" do
    expect(Devise).to receive(:setup) do |&block|
      cs = Decidim::Mpassid::Test::Runtime.cert_store

      config = double
      expect(config).to receive(:omniauth).with(
        :mpassid,
        {
          mode: :test,
          sp_entity_id: "http://1.lvh.me/users/auth/mpassid/metadata",
          assertion_consumer_service_url: "http://1.lvh.me/users/auth/mpassid/callback",
          idp_cert: cs.sign_certificate.to_pem,
          idp_cert_multi: {
            signing: [cs.sign_certificate.to_pem]
          }
        }
      )
      block.call(config)
    end

    run_initializer("decidim_mpassid.setup")
  end

  it "configures the OmniAuth failure app" do
    expect(OmniAuth.config).to receive(:on_failure=) do |proc|
      env = double
      action = double
      expect(env).to receive(:[]).with("PATH_INFO").and_return(
        "/users/auth/mpassid"
      )
      expect(env).to receive(:[]=).with("devise.mapping", ::Devise.mappings[:user])
      expect(Decidim::Mpassid::OmniauthCallbacksController).to receive(
        :action
      ).with(:failure).and_return(action)
      expect(action).to receive(:call).with(env)

      proc.call(env)
    end

    run_initializer("decidim_mpassid.setup")
  end

  it "falls back on the default OmniAuth failure app" do
    failure_app = double

    expect(OmniAuth.config).to receive(:on_failure).and_return(failure_app)
    expect(OmniAuth.config).to receive(:on_failure=) do |proc|
      env = double
      expect(env).to receive(:[]).with("PATH_INFO").and_return(
        "/something/else"
      )
      expect(failure_app).to receive(:call).with(env)

      proc.call(env)
    end

    run_initializer("decidim_mpassid.setup")
  end

  it "adds the mail interceptor" do
    expect(ActionMailer::Base).to receive(:register_interceptor).with(
      Decidim::Mpassid::MailInterceptors::GeneratedRecipientsInterceptor
    )

    run_initializer("decidim_mpassid.mail_interceptors")
  end

  def run_initializer(initializer_name)
    config = described_class.initializers.find do |i|
      i.name == initializer_name
    end
    config.run
  end
end
