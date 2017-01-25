require 'spec_helper'
require 'buildpack/manifest_validator'

describe Buildpack::ManifestValidator do
  let(:manifest_path) { "#{File.dirname(__FILE__)}/../fixtures/manifests/#{manifest_file_name}" }
  let(:validator) { Buildpack::ManifestValidator.new(manifest_path) }

  context 'with a valid manifest' do
    let(:manifest_file_name) { 'manifest_valid.yml' }

    it 'reports valid manifests correctly' do
      expect(validator.valid?).to be(true)
      expect(validator.errors).to be_empty
    end

    context 'and deprecation dates' do
      let(:manifest_file_name) { 'manifest_valid_plus_deprecation_dates.yml' }

      it 'reports valid manifests correctly' do
        expect(validator.valid?).to be(true)
        expect(validator.errors).to be_empty
      end
    end
  end

  context 'with a manifest with an invalid md5 key' do
    let(:manifest_file_name) { 'manifest_invalid-md6.yml' }

    it 'reports invalid manifests correctly' do
      expect(validator.valid?).to be(false)
      expect(validator.errors[:manifest_parser_errors]).not_to be_empty
    end

    context 'and incorrect defaults' do
      let(:manifest_file_name) { 'manifest_invalid-md6_and_defaults.yml' }

      it 'reports manifest parser errors only' do
        expect(validator).to_not receive(:validate_default_versions)
        expect(validator.valid?).to be(false)
        expect(validator.errors[:manifest_parser_errors]).not_to be_empty
      end
    end
  end
end
