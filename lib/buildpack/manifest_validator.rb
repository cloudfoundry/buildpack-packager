require 'kwalify'
require 'uri'

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
    end
  end
end
