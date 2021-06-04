# frozen_string_literal: true

require "spec_helper"

describe Decidim::Mpassid::ActionAuthorizer do
  subject { described_class.new(authorization, options, component, resource) }

  let(:organization) { create :organization }
  let(:process) { create(:participatory_process, organization: organization) }
  let(:component) { create(:component, manifest_name: "budgets", participatory_space: process) }
  let(:resource) { nil }

  let(:options) do
    {
      "allowed_municipalities" => "91,837,49",
      "allowed_roles" => "oppilas,opiskelija",
      "minimum_class_level" => 6,
      "maximum_class_level" => 10
    }
  end

  let(:authorization) { create(:authorization, :granted, user: user, metadata: metadata) }
  let(:user) { create :user, organization: organization }
  let(:metadata) { {} }

  context "when the user is in high school" do
    let(:metadata) do
      {
        municipality: "49",
        role: "opiskelija",
        school_code: "00002",
        student_class_level: nil
      }
    end

    it "passes the authorization" do
      expect(subject.authorize).to eq([:ok, {}])
    end
  end

  context "when a school is not in the list" do
    let(:metadata) do
      {
        municipality: "49",
        role: "opiskelija",
        school_code: "99999",
        student_class_level: nil
      }
    end

    it "is unauthorized" do
      expect(subject.authorize).to eq(
        [
          :unauthorized,
          {
            extra_explanation: {
              key: "disallowed_school",
              params: { scope: "mpassid_action_authorizer.restrictions" }
            }
          }
        ]
      )
    end
  end

  context "when the user is from a wrong municipality" do
    let(:metadata) do
      {
        municipality: "853",
        role: "oppilas",
        school_code: "00000",
        student_class_level: "5"
      }
    end

    it "is unauthorized" do
      expect(subject.authorize).to eq(
        [
          :unauthorized,
          {
            extra_explanation: {
              key: "disallowed_municipality",
              params: { scope: "mpassid_action_authorizer.restrictions" }
            }
          }
        ]
      )
    end
  end

  context "when the user has a wrong role" do
    let(:metadata) do
      {
        municipality: "837",
        role: "opettaja",
        school_code: "00000",
        student_class_level: "5"
      }
    end

    it "is unauthorized" do
      expect(subject.authorize).to eq(
        [
          :unauthorized,
          {
            extra_explanation: {
              key: "disallowed_role",
              params: { scope: "mpassid_action_authorizer.restrictions" }
            }
          }
        ]
      )
    end
  end

  context "when the user is in elementary school" do
    context "when the all rules are valid" do
      let(:metadata) do
        {
          municipality: "837",
          role: "oppilas",
          school_code: "00000",
          student_class_level: "8"
        }
      end

      it "passes the authorization" do
        expect(subject.authorize).to eq([:ok, {}])
      end
    end

    context "when the user is too young" do
      let(:metadata) do
        {
          municipality: "837",
          role: "oppilas",
          school_code: "00000",
          student_class_level: "5"
        }
      end

      it "is unauthorized" do
        expect(subject.authorize).to eq(
          [
            :unauthorized,
            {
              extra_explanation: {
                key: "class_level_not_allowed",
                params: {
                  max: 10,
                  min: 6,
                  scope: "mpassid_action_authorizer.restrictions"
                }
              }
            }
          ]
        )
      end
    end

    context "when the user is too old" do
      let(:metadata) do
        {
          municipality: "837",
          role: "oppilas",
          school_code: "00000",
          student_class_level: "11"
        }
      end

      it "is unauthorized" do
        expect(subject.authorize).to eq(
          [
            :unauthorized,
            {
              extra_explanation: {
                key: "class_level_not_allowed",
                params: {
                  max: 10,
                  min: 6,
                  scope: "mpassid_action_authorizer.restrictions"
                }
              }
            }
          ]
        )
      end
    end
  end
end
