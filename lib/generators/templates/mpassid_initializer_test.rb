# frozen_string_literal: true

require "decidim/mpassid/test/runtime"

Decidim::Mpassid::Test::Runtime.initialize
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
