require 'spec_helper'
require 'buildpack/manifest_validator'

describe Buildpack::ManifestValidator do
  let(:manifest_path) { "#{File.dirname(__FILE__)}/../fixtures/manifests/#{manifest_file_name}" }

  context 'with a valid manifest' do
    let(:manifest_file_name) { "manifest_valid.yml" }

    it 'reports valid manifests correctly' do
      expect(Buildpack::ManifestValidator.valid?(manifest_path)).to be(true)
    end
  end

  context 'with a manifest with an invalid md5 key' do
    let(:manifest_file_name) { "manifest_invalid-md6.yml" }

    it 'reports invalid manifests correctly' do
      puts Buildpack::ManifestValidator.validate(manifest_path)
      expect(Buildpack::ManifestValidator.valid?(manifest_path)).to be(false)
    end
  end

  context 'with a manifest with a nonexistent uri' do
    let(:manifest_file_name) { "manifest_invalid-uri.yml" }

    it 'reports invalid manifests correctly' do
      puts Buildpack::ManifestValidator.validate(manifest_path)
      expect(Buildpack::ManifestValidator.valid?(manifest_path)).to be(false)
    end
  end
end
