# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "generators/decidim/mpassid/install_generator"

describe Decidim::Mpassid::Generators::InstallGenerator do
  let(:options) { {} }

  before { subject.options = options }

  describe "#copy_initializer" do
    it "copies the initializer file" do
      # We don't want the generator to actually copy the file
      # rubocop:disable RSpec/SubjectStub
      expect(subject).to receive(:copy_file).with(
        "mpassid_initializer.rb",
        "config/initializers/mpassid.rb"
      )
      # rubocop:enable RSpec/SubjectStub
      subject.copy_initializer
    end

    context "with the test_initializer option set to true" do
      let(:options) { { test_initializer: true } }

      it "copies the test initializer file" do
        # We don't want the generator to actually copy the file
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:copy_file).with(
          "mpassid_initializer_test.rb",
          "config/initializers/mpassid.rb"
        )
        # rubocop:enable RSpec/SubjectStub
        subject.copy_initializer
      end
    end
  end
end
