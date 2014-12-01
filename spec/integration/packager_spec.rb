require 'spec_helper'
require 'tmpdir'
require 'zip'

# TODO pull out as helper
def make_fake_files(root, file_list)
  file_list.each do |file|
    full_path = File.join(root, file)
    `mkdir -p #{File.dirname(full_path)}`
    `echo 'a' > #{full_path}`
  end
end

def all_files(root)
  `tree -afi --noreport #{root}`.
      split("\n").
      map { |filename| filename.gsub(root, "").gsub(/^\//, "") }
end

def get_zip_contents(zip_path)
  Zip::File.open(zip_path) do |zip_file|
    zip_file.
        map { |entry| entry.name }.
        select { |name| name[/\/$/].nil? }
  end
end

module Buildpack
  describe Packager do

    let(:tmp_dir) { Dir.mktmpdir }
    let(:buildpack_dir) { File.join(tmp_dir, 'sample-buildpack-root-dir') }
    let(:cache_dir) { File.join(tmp_dir, 'cache-dir') }
    let(:buildpack) {
      {
          root_dir: buildpack_dir,
          mode: buildpack_mode,
          language: 'sample',
          dependencies: ["file:///etc/hosts"],
          exclude_files: files_to_exclude,
          cache_dir: cache_dir
      }
    }
    let(:files_to_include) {
      [
          'VERSION',
          'README.md',
          'lib/sai.to',
          'lib/rash'
      ]
    }

    let(:files_to_exclude) {
      [
          '.gitignore'
      ]
    }

    let(:files) { files_to_include + files_to_exclude }
    let(:cached_file) { File.join(cache_dir, 'file____etc_hosts') }

    before do
      make_fake_files(
          buildpack_dir,
          files
      )
      `echo "1.2.3" > #{File.join(buildpack_dir, 'VERSION')}`
    end

    after do
      FileUtils.remove_entry tmp_dir
    end


    describe 'a well formed zip file name' do
      context 'an online buildpack' do
        let(:buildpack_mode) { :online }

        specify do
          Packager.package(buildpack)

          expect(all_files(buildpack_dir)).to include('sample_buildpack-online-v1.2.3.zip')
        end
      end

      context 'an offline buildpack' do
        let(:buildpack_mode) { :offline }

        specify do
          Packager.package(buildpack)

          expect(all_files(buildpack_dir)).to include('sample_buildpack-offline-v1.2.3.zip')
        end

      end
    end

    describe 'the zip file contents' do
      context 'an online buildpack' do
        let(:buildpack_mode) { :online }

        specify do
          Packager.package(buildpack)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-online-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to match_array(files_to_include)
        end
      end

      context 'an offline buildpack' do
        let(:buildpack_mode) { :offline }

        specify do
          Packager.package(buildpack)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-offline-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)
          dependencies = ["dependencies/file____etc_hosts"]

          expect(zip_contents).to match_array(files_to_include + dependencies)
        end
      end
    end

    describe 'excluded files' do
      let(:buildpack_mode) { :online }

      specify do
        Packager.package(buildpack)

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-online-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        expect(zip_contents).to_not include(*files_to_exclude)
      end
    end

    describe 'caching of dependencies' do
      context 'an online buildpack' do
        let(:buildpack_mode) { :online }

        specify do
          Packager.package(buildpack)

          expect(File).to_not exist(cached_file)
        end
      end

      context 'an offline buildpack' do
        let(:buildpack_mode) { :offline }
        let(:cached_file) { File.join(cache_dir, "file____etc_hosts") }

        context 'by default' do
          specify do
            Packager.package(buildpack)
            expect(File).to exist(cached_file)
          end
        end

        context 'with the cache option enabled' do
          context 'cached file does not exist' do
            specify do
              Packager.package(buildpack.merge(cache: true))
              expect(File).to exist(cached_file)
            end
          end

          context 'on subsequent calls' do
            it 'uses the cached file instead of downloading it again' do
              Packager.package(buildpack.merge(cache: true))
              File.write(cached_file, 'a')
              Packager.package(buildpack.merge(cache: true))
              expect(File.read(cached_file)).to eq 'a'
            end
          end
        end
      end
    end

    describe 'existence of zip' do
      let(:buildpack_mode) {:online}

      context 'zip is installed' do
        specify do
          expect{Packager.package(buildpack)}.not_to raise_error
        end
      end

      context 'zip is not installed' do
        specify do
          expect(Open3).to receive(:capture3).with("which zip").and_return(['', '', 'exit 1'])
          expect{Packager.package(buildpack)}.to raise_error(RuntimeError)
        end
      end
    end
  end

  # yet to test.
  # X exclude files user does not want
  # X if offline, download dependencies - use url translation
  # X make sure side effects do not appear in buildpack folder (Eg, create a temp directory and clone buildpack)
  # X local download caching (deps are cached on the buildpack developers machine)
  #    SKIPPED - Support both OSX and Linux Caching directories - not easily tested
  # X use-cache option (only valid in offline mode)
  # X complain if zip is missing

  # unprovable
  # - really did use a seperate tmp dir
  # - cleaned up tmp dir after


end
