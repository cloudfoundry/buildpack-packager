require 'spec_helper'
require 'buildpack/packager'

describe Buildpack::Packager::Package do

  let(:fake_file_uri) do
    location = File.join(Dir.mktmpdir, 'fake.file')
    File.write(location, 'fake text')
    "file://#{location}"
  end

  let(:md5) { Digest::MD5.file(fake_file_uri.gsub(/file:\/\//, '')).hexdigest }

  let(:manifest) do
    {
      language: 'fake',
      exclude_files: [],
      dependencies: [
        {
          'name' => 'fake',
          'uri' => fake_file_uri,
          'md5' => md5
        }
      ]
    }
  end

  let(:mode) { :uncached }
  let(:cache_dir) { '' }

  let(:root_dir) do
    dir_name = Dir.mktmpdir('fake-buildpack')
    File.write(File.join(dir_name, 'mock.txt'), "fake!")
    dir_name
  end

  let(:options) do
    {
      root_dir: root_dir,
      manifest_path: 'manifest.yml',
      mode: mode,
      force_download: false,
      cache_dir: cache_dir
    }
  end

  describe '#execute!' do
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
        expect(File.exists?(File.join(root_dir, 'fake_buildpack-v1.0.0.zip'))).to be(true)
      end
    end

    context 'cached mode' do
      let(:mode) { :cached }

      context 'cache has same file but with different MD5' do
        let(:fake_file) { fake_file_uri.gsub(/[\/:]/, '_') }
        let(:cache_dir) do
          cache_dir = Dir.mktmpdir('cache')
          File.write(File.join(cache_dir, fake_file), 'not the right stuff')
          cache_dir
        end

        it 'redownloads the file' do
          package.execute!
          expect(Digest::MD5.file(File.join(cache_dir, fake_file)).hexdigest).to eq(md5)
        end
      end

      context 'cache does not have file but with different MD5' do
        let(:cache_dir) { Dir.mktmpdir('cache') }
        let(:md5) { 'fake-md5' }

        it 'throws an error' do
          expect { package.execute! }.to raise_error(Buildpack::Packager::CheckSumError)
        end
      end
    end
  end
end
