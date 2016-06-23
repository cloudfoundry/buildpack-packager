require 'spec_helper'

describe 'Buildpack packager output' do
  let(:buildpack_type) { '--uncached' }
  let(:buildpack_fixture) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'buildpack') }

  subject do
    Dir.chdir(buildpack_fixture) do
      `buildpack-packager #{buildpack_type}`
    end
  end

  context 'on successfully building the cached buildpack' do
    it 'prints the type of buildpack created and where' do
      expect(subject).to include("Uncached buildpack created and saved as")
      expect(subject).to include("spec/fixtures/buildpack/go_buildpack-v1.7.8.zip")
    end
  end

  context 'on successfully building the uncached buildpack' do
    let(:buildpack_type) { '--cached' }

    it 'prints the type of buildpack created and where' do
      expect(subject).to include("Cached buildpack created and saved as")
      expect(subject).to include("spec/fixtures/buildpack/go_buildpack-cached-v1.7.8.zip")
    end
  end
end
