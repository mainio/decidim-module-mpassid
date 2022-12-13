# frozen_string_literal: true

module Decidim
  module Mpassid
    module Verification
      class MetadataCollector
        def initialize(saml_attributes)
          @saml_attributes = saml_attributes
        end

        def metadata
          {
            # Straight forward fetching of the "single" value attributes
            first_name: saml_attributes[:first_names] || saml_attributes[:given_name],
            given_name: saml_attributes[:given_name],
            last_name: saml_attributes[:last_name]
          }.tap do |data|
            # Map the SAML attribute keys to specific metadata attribute keys.
            {
              provider_id: :provider_id,
              provider_name: :provider_name,
              school_code: :school_code,
              school_name: :school_name,
              student_class: :class,
              student_class_level: :class_level
            }.each do |key, saml_key|
              # For all the "multi" value attributes, join the values with a
              # comma.
              val = saml_attributes[saml_key]
              val = val.join(",") if val
              data[key] = val
            end

            full_role = saml_attributes[:role]
            if full_role
              data[:role] = full_role.map do |role_string|
                # The fole string consists of four parts with the following
                # indexes:
                # - 0: Organization OID (same as `:provider_id`)
                # - 1: School code (same as `:school_code`)
                # - 2: Group (same as `:class`)
                # - 3: User's role in the group
                role_parts = role_string.split(";")
                role_parts[3] if role_parts.length > 3
              end.join(",")
              # Do not store anything in case no roles were found
              data[:role] = nil if data[:role].empty?
            end
          end
        end

        protected

        attr_reader :saml_attributes
      end
    end
  end
end
