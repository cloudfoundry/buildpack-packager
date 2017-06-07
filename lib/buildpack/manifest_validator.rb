require 'kwalify'
require 'kwalify/parser/yaml-patcher'
require 'uri'
require 'semantic'

require 'buildpack/manifest_dependency'

module Buildpack
  class ManifestValidator
    class ManifestValidationError < StandardError; end

    SCHEMA_FILE = File.join(File.dirname(__FILE__), 'packager', 'manifest_schema.yml')

    attr_reader :errors

    def initialize(manifest_path)
      @manifest_path = manifest_path
    end

    def valid?
      validate
      errors.empty?
    end

    private

    def validate
      schema = Kwalify::Yaml.load_file(SCHEMA_FILE)
      validator = Kwalify::Validator.new(schema)
      parser = Kwalify::Yaml::Parser.new(validator)
      manifest_data = parser.parse_file(@manifest_path)

      @errors = {}
      @errors[:manifest_parser_errors] = parser.errors unless parser.errors.empty?

      if manifest_data['default_versions'] && !@errors[:manifest_parser_errors]
        default_version_errors = validate_default_versions(manifest_data)
        @errors[:default_version] = default_version_errors unless default_version_errors.empty?
      end
    end

    def validate_default_versions(manifest_data)
      error_messages = []

      default_versions = create_manifest_dependencies(manifest_data['default_versions'])
      dependency_versions = create_manifest_dependencies(manifest_data['dependencies'])

      error_messages += validate_no_duplicate_names(default_versions)
      error_messages += validate_defaults_in_dependencies(default_versions, dependency_versions)
      wrap_errors_with_common_text(error_messages)

      error_messages
    end

    def create_manifest_dependencies(dependency_entries)
      dependency_entries.map do |dependency|
        ManifestDependency.new(dependency['name'], dependency['version'])
      end
    end

    def validate_no_duplicate_names(default_versions)
      default_versions_names = default_versions.map { |default_version| default_version.name }
      duplicate_names = default_versions_names.find_all { |dep| default_versions_names.count(dep) > 1 }.uniq

      duplicate_names.map do |name|
        "- #{name} had more than one 'default_versions' entry in the buildpack manifest."
      end
    end

    def validate_defaults_in_dependencies(default_versions, dependency_versions)
      unmatched_dependencies = default_versions.reject { |d| version_exists?(d, dependency_versions) }
      unmatched_dependencies.map do |dependency|
        name_version = "#{dependency.name} #{dependency.version}"

        "- a 'default_versions' entry for #{name_version} was specified by the buildpack manifest, " +
          "but no 'dependencies' entry for #{name_version} was found in the buildpack manifest."
      end
    end

    def wrap_errors_with_common_text(error_messages)
      if error_messages.any?
        error_messages.unshift('The buildpack manifest is malformed:')
        error_messages<< 'For more information, see https://docs.cloudfoundry.org/buildpacks/custom.html#specifying-default-versions'
      end
    end

    private

    def version_exists?(default_dependency, dependency_versions)
      major, minor, patch = default_dependency.version.to_s.split('.')
      major = major.gsub('v','')

      if patch == 'x'
        dependency_versions.each do |d|
          d_version = Semantic::Version.new(d.version)
          return true if d.name == default_dependency.name && d_version.major.to_s == major && d_version.minor.to_s == minor
        end
      elsif patch.nil? && minor == 'x'
        dependency_versions.each do |d|
          d_version = Semantic::Version.new(d.version)
          return true if d.name == default_dependency.name && d_version.major.to_s == major
        end
      else
        return dependency_versions.include?(default_dependency)
      end

      return false
    end
  end
end

