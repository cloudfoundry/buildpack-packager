require 'kwalify'

module Buildpack
  class ManifestValidator
    class ManifestValidationError < StandardError; end

    SCHEMA_FILE = File.join(File.dirname(__FILE__), 'packager', 'manifest_schema.yml')

    def self.valid?(manifest_path)
      self.validate(manifest_path).values.all? { |value| value.empty? }
    end

    def self.validate(manifest_path)
      schema = Kwalify::Yaml.load_file(SCHEMA_FILE)
      validator = Kwalify::Validator.new(schema)
      parser = Kwalify::Yaml::Parser.new(validator)
      manifest_data = parser.parse_file(manifest_path)

      errors = {}
      errors[:manifest_parser_errors] = parser.errors
      errors[:invalid_uris] = self.validate_uris(manifest_data['dependencies'])

      errors
    end


    protected
    def self.validate_uris(dependencies)
      invalid_uris = []

      dependencies.each do |dependency|
        uri = dependency['uri']
        invalid_uris << uri if self.status_code(uri) != 200
      end

      invalid_uris
    end

    def self.status_code(uri)
        uri = URI.parse(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        begin
          status_code = http.head(uri.request_uri).code.to_i
          return status_code unless 404 #if doesn't support head requests

          Net::HTTP.start(uri.host,
                          uri.port,
                          :use_ssl => uri.scheme == 'https'
                         ) do |http|
                           request = Net::HTTP::Get.new uri

                           http.request request do |response|
                             return response.code.to_i
                           end
                         end
        rescue
          false
        end
      end



  end
end
