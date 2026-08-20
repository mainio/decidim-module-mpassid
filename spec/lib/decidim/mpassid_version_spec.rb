# frozen_string_literal: true

require "spec_helper"

describe Decidim::Mpassid do
  describe "::version" do
    subject { described_class.version }

    it { is_expected.to eq("0.32.0") }

    it "is a valid semantic version" do
      expect(subject).to match(/\A\d+\.\d+\.\d+(\.[a-z0-9]+)?\z/)
    end
  end

  describe "::decidim_version" do
    subject { described_class.decidim_version }

    it { is_expected.to eq("~> 0.32.0") }

    it "is a valid requirement string" do
      expect { Gem::Requirement.new(subject) }.not_to raise_error
    end

    it "is satisfied by the installed Decidim version" do
      expect(Gem::Requirement.new(subject)).to be_satisfied_by(
        Gem::Version.new(Decidim.version)
      )
    end
  end
end
