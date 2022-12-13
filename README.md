# Decidim::Mpassid

[![Build Status](https://github.com/mainio/decidim-module-mpassid/actions/workflows/ci_mpassid.yml/badge.svg)](https://github.com/mainio/decidim-module-mpassid/actions)
[![codecov](https://codecov.io/gh/mainio/decidim-module-mpassid/branch/master/graph/badge.svg)](https://codecov.io/gh/mainio/decidim-module-mpassid)

A [Decidim](https://github.com/decidim/decidim) module to add MPASSid
authentication to Decidim as a way to authenticate and authorize the users.

The gem has been developed by [Mainio Tech](https://www.mainiotech.fi/).

The development has been sponsored by the
[City of Helsinki](https://www.hel.fi/).

The MPASSid service is owned by the Ministry of the Education and Culture and
operated by CSC - Tieteen tietotekniikan keskus Oy. Neither of these parties or
the MPASSid maintainers are related to this gem in any way, nor do they provide
technical support for it. Please contact the gem maintainers in case you find
any issues with it.

## Preparation

Please refer to the
[`omniauth-mpassid`](https://github.com/mainio/omniauth-mpassid) documentation
in order to learn more about the preparation and getting started with MPASSid.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-mpassid"
```

And then execute:

```bash
$ bundle
```

After installation, you can add the initializer running the following command:

```bash
$ bundle exec rails generate decidim:mpassid:install
```

You need to set the following configuration options inside the initializer:

- `:sp_entity_id` - The service provider entity ID, i.e. your applications
  entity ID used to identify the service at the MPASSid SAML identity provider.
  * Default: depends on the application's URL, e.g.
    `https://www.example.org/users/auth/mpassid/metadata`

Optionally you can also configure the module with the following options:

- `:auto_email_domain` - Defines the auto-email domain for automatically
  verified email addresses for the identified users. This makes it easier for
  the users to use the system as they don't have to go through any extra steps
  verifying their email addresses, as they have already verified their identity.
  * The auto-generated email format is similar to the following string:
    `mpassid-756be91097ac490961fd04f121cb9550@example.org`. The email will
    always have the `mpassid-` prefix and the domain part is defined by the
    configuration option.
  * In case this is not defined, the organization's host will be used as the
    default.
- `:certificate_file` - Path to the local certificate included in the metadata
  sent to MPASSid.
- `:private_key_file` - Path to the local private key (corresponding to the
  certificate). Will be used to decrypt messages coming from MPASSid.

For more information about these options and possible other options, please
refer to the [`omniauth-mpassid`](https://github.com/mainio/omniauth-mpassid)
documentation.

The install generator will also enable the MPASSid authentication method for
OmniAuth by default by adding these lines your `config/secrets.yml`:

```yml
default: &default
  # ...
  omniauth:
    # ...
    mpassid:
      enabled: false
      icon: account-login
development:
  # ...
  omniauth:
    # ...
    mpassid:
      enabled: true
      mode: test
      icon: account-login
```

This will enable the MPASSid authentication for the development environment
only. In case you want to enable it for other environments as well, apply the
OmniAuth configuration keys accordingly to other environments as well.

The development environment is hooking into the MPASSid testing endpoints by
default which is defined by the `mode: test` option in the OmniAuth
configuration. For environments that you want to hook into the MPASSid
production environment, you can omit this configuration option completely.

The example configuration will set the `account-login` icon for the the
authentication button from the Decidim's own iconset. In case you want to have a
better and more formal styling for the sign in button, you will need to
customize the sign in / sign up views.

## Usage

After the installation steps, you will need to enable the MPASSid authorization
from Decidim's system management panel. After enabled, you can start using it.

This gem also provides a MPASSid sign in method which will automatically
authorize the user accounts. In case the users already have an account, they
can still authorize themselves using the MPASSid authorization.

## Customization

For some specific needs, you may need to store extra metadata for the MPASSid
authorization or add new authorization configuration options for the
authorization.

This can be achieved by applying the following configuration to the module
inside the initializer described above:

```ruby
# config/initializers/mpassid.rb

Decidim::Mpassid.configure do |config|
  # ... keep the default configuration as is ...
  # Add this extra configuration:
  config.workflow_configurator = lambda do |workflow|
    # When expiration is set to 0 minutes, it will never expire.
    workflow.expires_in = 0.minutes
    workflow.action_authorizer = "CustomMpassidActionAuthorizer"
    workflow.options do |options|
      options.attribute :custom_option, type: :string, required: false
    end
  end
  config.school_metadata_klass = "CustomMpassidModule::CustomMpassidClass"
  config.metadata_collector_class = CustomMpassidMetadataCollector
end
```

For the workflow configuration options, please refer to the
[decidim-verifications documentation](https://github.com/decidim/decidim/tree/master/decidim-verifications).

For the custom metadata collector, please extend the default class as follows:

```ruby
# frozen_string_literal: true

class CustomMpassidMetadataCollector < Decidim::Mpassid::Verification::MetadataCollector
  def metadata
    super.tap do |data|
      # You can access the SAML attributes using the `saml_attributes` accessor:
      school_codes = saml_attributes[:school_code]
      unless school_codes.blank?
        extra = school_codes.map do |school_code|
          "Extra data for: #{school_code}"
        end

        # This will actually add the data to the user's authorization metadata
        # hash.
        data[:extra] = extra.join(",")
      end
    end
  end
end
```

## Contributing

See [Decidim](https://github.com/decidim/decidim).

### Testing

To run the tests run the following in the gem development path:

```bash
$ bundle
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rake test_app
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rspec
```

Note that the database user has to have rights to create and drop a database in
order to create the dummy test app database.

In case you are using [rbenv](https://github.com/rbenv/rbenv) and have the
[rbenv-vars](https://github.com/rbenv/rbenv-vars) plugin installed for it, you
can add these environment variables to the root directory of the project in a
file named `.rbenv-vars`. In this case, you can omit defining these in the
commands shown above.

### Test code coverage

If you want to generate the code coverage report for the tests, you can use
the `SIMPLECOV=1` environment variable in the rspec command as follows:

```bash
$ SIMPLECOV=1 bundle exec rspec
```

This will generate a folder named `coverage` in the project root which contains
the code coverage report.

### Localization

If you would like to see this module in your own language, you can help with its
translation at Crowdin:

https://crowdin.com/project/decidim-mpassid

## License

See [LICENSE-AGPLv3.txt](LICENSE-AGPLv3.txt).
