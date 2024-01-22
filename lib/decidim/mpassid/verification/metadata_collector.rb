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
            first_name: saml_attributes[:first_name] || saml_attributes[:given_name],
            given_name: saml_attributes[:given_name],
            last_name: saml_attributes[:last_name],
            student_class_level: saml_attributes[:class_level],
          }.tap do |data|
            # Parse the school data from the school info as it is not provided
            # as separate attributes.
            school_code = []
            school_oid = []
            school_name = []
            school_info = saml_attributes[:school_info]
            if school_info
              school_info.each do |info_string|
                info_parts = info_string.split(";")
                if info_parts[0].match?(/\A[0-9]+\z/)
                  school_code << info_parts[0]
                else
                  school_oid << info_parts[0]
                end
                school_name << info_parts[1] unless school_name.include?(info_parts[1])
              end
            end
            data[:school_code] = school_code.empty? ? nil : school_code.join(",")
            data[:school_oid] = school_oid.empty? ? nil : school_oid.join(",")
            data[:school_name] = school_name.empty? ? nil : school_name.join(",")

            # Parse the education provider information as it is not provided as
            # separate attributes.
            provider_code = []
            provider_name = []
            provider_info = saml_attributes[:provider_info]
            if provider_info
              provider_info.each do |info_string|
                info_parts = info_string.split(";")
                provider_code << info_parts[0]
                provider_name << info_parts[1]
              end
            end
            data[:provider_code] = provider_code.empty? ? nil : provider_code.join(",")
            data[:provider_name] = provider_name.empty? ? nil : provider_name.join(",")

            groups = []
            full_role = saml_attributes[:role]
            if full_role
              group = []
              role = []
              full_role.map do |role_string|
                # The fole string consists of four parts with the following
                # indexes:
                # - 0: Organization OID (same as `:provider_code`)
                # - 1: School code (same as `:school_code`)
                # - 2: Group
                # - 3: User's role in the group
                role_parts = role_string.split(";")
                group << role_parts[2] if role_parts.length > 2
                role << role_parts[3] if role_parts.length > 3
              end.join(",")

              data[:group] = group.empty? ? nil : group.join(",")
              data[:role] = role.empty? ? nil : role.join(",")
            end
          end
        end

        protected

        attr_reader :saml_attributes
      end
    end
  end
end
