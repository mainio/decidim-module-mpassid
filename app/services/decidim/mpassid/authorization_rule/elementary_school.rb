# frozen_string_literal: true

module Decidim
  module Mpassid
    module AuthorizationRule
      class ElementarySchool < Base
        # rubocop:disable Metrics/CyclomaticComplexity
        def valid?
          return false unless school_code_in_the_list?
          return true unless authorized_user_in_elementary_school?
          return true if min_class_level.blank? && max_class_level.blank?
          return false if authorization.metadata["student_class_level"].blank?

          authorized_class_levels.any? do |level|
            (min_class_level.blank? || level >= min_class_level) &&
              (max_class_level.blank? || level <= max_class_level)
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        def error_key
          return "disallowed_school" unless school_code_in_the_list?
          return "class_level_not_defined" if authorization.metadata["student_class_level"].blank?
          return "class_level_not_allowed_min" if max_class_level.blank?
          return "class_level_not_allowed_max" if min_class_level.blank?
          return "class_level_not_allowed_one" if max_class_level == min_class_level

          "class_level_not_allowed"
        end

        def error_params
          return super if authorization.metadata["student_class_level"].blank?

          super.tap do |params|
            if max_class_level.blank?
              params[:min] = min_class_level
            elsif min_class_level.blank?
              params[:max] = max_class_level
            elsif max_class_level == min_class_level
              params[:level] = max_class_level
            else
              params[:min] = min_class_level
              params[:max] = max_class_level
            end
          end
        end

        private

        def school_code_in_the_list?
          authorization.metadata["school_code"].split(",").map do |school_code|
            return true if school_metadata_klass.exists?(school_code)
          end
          false
        end

        # The class level check is only relevant for school types 11, 12 and 19
        # which have elementary schools. For high schools and vocational schools,
        # voting is automatically allowed because the students are old enough.
        def authorized_user_in_elementary_school?
          [11, 12, 19].any? { |type| authorized_school_types.include?(type) }
        end

        def authorized_school_types
          @authorized_school_types ||= authorization.metadata["school_code"].split(",").map do |school_code|
            school_metadata_klass.type_for_school(school_code)
          end.compact
        end

        def authorized_class_levels
          @authorized_class_levels ||= authorization.metadata["student_class_level"].split(",").map do |group|
            group.gsub(/^[^0-9]*/, "").to_i
          end
        end

        def min_class_level
          options[:min_class_level]
        end

        def max_class_level
          options[:max_class_level]
        end

        def school_metadata_klass
          return Decidim::Mpassid.school_metadata_klass if Decidim::Mpassid.school_metadata_klass.is_a? Class

          Decidim::Mpassid.school_metadata_klass.constantize
        end
      end
    end
  end
end
