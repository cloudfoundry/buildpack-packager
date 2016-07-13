require 'spec_helper'
require 'fileutils'

describe 'Buildpack packager output' do
  let(:buildpack_type) { '--uncached' }
  let(:buildpack_fixture) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'buildpack') }

  before do
    home = ENV['HOME']
    if home
      buildpack_packager_cache = File.join(home, '.buildpack-packager')
      FileUtils.rm_rf(buildpack_packager_cache)
    end
  end

  def buildpack_packager_execute(buildpack_dir)
    Dir.chdir(buildpack_dir) do
      `buildpack-packager #{buildpack_type}`
    end
  end

  subject { buildpack_packager_execute(buildpack_fixture) }

  context 'building the uncached buildpack' do
    it 'outputs the type of buildpack created, where and its human readable size' do
      expect(subject).to include("Uncached buildpack created and saved as")
      expect(subject).to include("spec/fixtures/buildpack/go_buildpack-v1.7.8.zip")
      expect(subject).to match(/of size 4\.0K$/)
    end
  end

  context 'building the cached buildpack' do
    let(:buildpack_type) { '--cached' }

    it 'outputs the dependencies downloaded, their versions, and download source url' do
      expect(subject).to include("Downloading go version 1.6.1 from: https://storage.googleapis.com/golang/go1.6.1.linux-amd64.tar.gz")
      expect(subject).to include("Using go version 1.6.1 with size 81M")
      expect(subject).to include("Downloading go version 1.6.2 from: https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz")
      expect(subject).to include("Using go version 1.6.2 with size 81M")
      expect(subject).to include("Downloading godep version v74 from: https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/godep/godep-v74-linux-x64.tgz")
      expect(subject).to include("Using godep version v74 with size 2.8M")
    end

    it 'outputs the type of buildpack created, where and its human readable size' do
      expect(subject).to include("Cached buildpack created and saved as")
      expect(subject).to include("spec/fixtures/buildpack/go_buildpack-cached-v1.7.8.zip")
      expect(subject).to match(/of size 164M$/)
    end

    context 'with a buildpack packager dependency cache intact' do
      before { buildpack_packager_execute(buildpack_fixture) }

      it 'outputs the dependencies downloaded, their versions, and cache location' do
        expect(subject).to match(/Using go version 1.6.1 from local cache at: .*.buildpack-packager\/cache\/https___storage.googleapis.com_golang_go1.6.1.linux-amd64.tar.gz with size 81M/)
        expect(subject).to match(/Using go version 1.6.2 from local cache at: .*.buildpack-packager\/cache\/https___storage.googleapis.com_golang_go1.6.2.linux-amd64.tar.gz with size 81M/)
        expect(subject).to match(/Using godep version v74 from local cache at: .*.buildpack-packager\/cache\/https___pivotal-buildpacks.s3.amazonaws.com_concourse-binaries_godep_godep-v74-linux-x64.tgz with size 2.8M/)
      end
    end
  end
end
