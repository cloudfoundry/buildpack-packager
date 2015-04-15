require 'spec_helper'
require 'buildpack/packager'

describe Buildpack::Packager::Package do
  let(:manifest) do
    {
      language: 'fake',
      exclude_files: []
    }
  end

  let(:options) do
    {
      root_dir: root_dir,
      manifest_path: 'manifest.yml',
      mode: :fake_mode,
      force_download: false
    }
  end

  describe '#execute' do
    subject(:package) { Buildpack::Packager::Package.new(options) }

    before do
      allow(package).to receive(:buildpack_version).and_return('1.0.0')
      allow(package).to receive(:manifest).and_return(manifest)
    end

    context 'directory has no space' do
      let(:root_dir) do
        dir_name = Dir.mktmpdir('nospace')
        File.write(File.join(dir_name, 'mock.txt'), "don't read this")
        dir_name
      end

      it "puts the zip file in the right place" do
        package.execute!
        puts options
        expect(File.exists?(File.join(root_dir, 'fake_buildpack-v1.0.0.zip'))).to be(true)
      end
    end

    context 'directory has a space' do
      let(:root_dir) do
        dir_name = Dir.mktmpdir('a space')
        File.write(File.join(dir_name, 'mock.txt'), "don't read this")
        dir_name
      end

      it "it puts the zip file in the right place" do
        package.execute!
        puts options
        expect(File.exists?(File.join(root_dir, 'fake_buildpack-v1.0.0.zip'))).to be(true)
      end
    end
  end
end
