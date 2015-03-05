require 'yaml'
require 'net/https'
require 'kwalify'

def status_code url
  uri = URI.parse(url)
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

RSpec::Matchers.define :give_status_code do |expected|
  match do |actual|
    status_code( actual ) == expected
  end

  failure_message do |actual|
    "Expected that URI: #{actual} to exist somewhere but it didn't."
  end
end

describe 'Buildpack manifest' do

  let(:manifest_path) do
    'manifest.yml'
  end

  let(:manifest) do
    YAML.load_file(manifest_path)
  end

  context 'schema validation' do
    before(:all) do
      schema = Kwalify::Yaml.load_file("#{File.dirname(__FILE__)}/../fixtures/manifest_schema.yml")
      validator = Kwalify::Validator.new(schema)
      @parser = Kwalify::Yaml::Parser.new(validator)
    end

    it 'matches the predefined schema' do
      @parser.parse_file(manifest_path)
      expect(@parser.errors).to be_empty
    end

  end

  context 'validate uris' do

    it 'should have uris that point to somewhere' do
      manifest['dependencies'].each do |dependency|
        expect(dependency['uri']).to give_status_code(200)
      end
    end
  end

end
