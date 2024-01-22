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
            student_class_level: saml_attributes[:class_level]
          }.tap do |data|
            # Parse the school data from the school info as it is not provided
            # as separate attributes.
            schools = schools_form(saml_attributes[:school_info])
            data[:school_code] = schools.map { |s| s[:code] }.compact.join(",")
            data[:school_oid] = schools.map { |s| s[:oid] }.compact.join(",")
            data[:school_name] = schools.map { |s| s[:name] }.uniq.join(",")

            # Parse the education provider information as it is not provided as
            # separate attributes.
            providers = providers_from(saml_attributes[:provider_info])
            data[:provider_code] = providers.keys.join(",")
            data[:provider_name] = providers.values.join(",")

            # Parse the role information from the role data.
            roles = roles_from(saml_attributes[:role])
            data[:group] = roles.map { |r| r[:group] }.join(",")
            data[:role] = roles.map { |r| r[:role_name] }.join(",")

            [:school_code, :school_oid, :school_name, :provider_code, :provider_name, :group, :role].each do |key|
              data[key] = nil if data[key].empty?
            end
          end
        end

        protected

        attr_reader :saml_attributes

        def schools_form(school_info)
          data = []
          return data unless school_info

          school_info.each do |info_string|
            info_parts = info_string.split(";")
            data <<
              if info_parts[0].match?(/\A[0-9]+\z/)
                { code: info_parts[0]&.strip, name: info_parts[1]&.strip }
              else
                { oid: info_parts[0]&.strip, name: info_parts[1]&.strip }
              end
          end

          data
        end

        def providers_from(provider_info)
          data = {}
          return data unless provider_info

          provider_info.each do |info_string|
            info_parts = info_string.split(";")
            data[info_parts[0]] = info_parts[1]&.strip
          end

          data
        end

        def roles_from(role_info)
          data = []
          return data unless role_info

          role_info.map do |role_string|
            # The fole string consists of four parts with the following
            # indexes:
            # 0: Educational provider OID (same as `:provider_code`)
            # 1: School code / national educational institution code (same as `:school_code`)
            # 2: Group (or class, e.g. "1A")
            # 3: User's role name (e.g. "Oppilas")
            # 4: User's role code (e.g. "1")
            # 5: Educational institution OID (same as `:school_oid`)
            # 6: The office / branch OID (similar format as other OIDs, can be also empty)
            role_parts = role_string.split(";")
            data << {
              provider_oid: role_parts[0],
              school_code: role_parts[1],
              group: role_parts[2],
              role_name: role_parts[3],
              role_code: role_parts[4],
              school_oid: role_parts[5],
              branch_oid: role_parts[6]
            }.transform_values { |v| v&.strip }
          end

          data
        end
      end
    end
  end
end
