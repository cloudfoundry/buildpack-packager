require_relative '../spec_helper'

def status_code url
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  http.head(uri.request_uri).code.to_i rescue 600
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

  it 'is present' do
    expect(manifest).not_to be nil
  end

  context 'schema validation' do
    before(:all) do
      schema = Kwalify::Yaml.load_file("spec/fixtures/manifest_schema.yml")
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
