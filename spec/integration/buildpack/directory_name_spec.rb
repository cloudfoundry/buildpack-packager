require 'spec_helper'
require 'buildpack/packager'

module Buildpack
  describe Packager do
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
      File.write(File.join(dir_name, 'mock.txt'), 'fake!')
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

    before do
      @pwd ||= Dir.pwd
      Dir.chdir(root_dir)
    end

    after do
      Dir.chdir(@pwd)
    end

    describe 'directory naming structure' do
      before do
        allow_any_instance_of(Packager::Package).to receive(:buildpack_version).and_return('1.0.0')
        allow_any_instance_of(Packager::Package).to receive(:manifest).and_return(manifest)
        allow(FileUtils).to receive(:cp)
        Packager.package(options)
      end

      context 'directory has no space' do
        let(:root_dir) do
          dir_name = Dir.mktmpdir('nospace')
          File.write(File.join(dir_name, 'mock.txt'), "don't read this")
          dir_name
        end

        it 'puts the zip file in the right place' do
          expect(File.exist?(File.join(root_dir, 'fake_buildpack-v1.0.0.zip'))).to be(true)
        end
      end

      context 'directory has a space' do
        let(:root_dir) do
          dir_name = Dir.mktmpdir('a space')
          File.write(File.join(dir_name, 'mock.txt'), "don't read this")
          dir_name
        end

        it 'it puts the zip file in the right place' do
          expect(File.exist?(File.join(root_dir, 'fake_buildpack-v1.0.0.zip'))).to be(true)
        end
      end
    end
  end
end
