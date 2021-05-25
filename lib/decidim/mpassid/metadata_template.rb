# frozen_string_literal: true

module Decidim
  module Mpassid
    # Template for school metadata, used also to test this module.
    class MetadataTemplate
      MAPPING = {
        "00000" => { name: "Testikoulu", type: 11, postal_codes: ["33100"], districts: [1] }
      }.freeze

      def self.select_list
        MAPPING.map { |key, school| ["#{school[:name]} (#{key})", key] }
      end

      def self.metadata_for_school(school_code)
        MAPPING[school_code]
      end

      def self.exists?(school_code)
        metadata_for_school(school_code).present?
      end

      def self.detail_for_school(school_code, key)
        data = metadata_for_school(school_code)
        return nil unless data

        data[key]
      end

      def self.type_for_school(school_code)
        detail_for_school(school_code, :type)
      end

      def self.postal_codes_for_school(school_code)
        detail_for_school(school_code, :postal_codes)
      end

      def self.districts_for_school(school_code)
        detail_for_school(school_code, :districts)
      end
    end
  end
end
