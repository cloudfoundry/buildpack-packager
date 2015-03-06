require 'spec_helper'
require 'tmpdir'

module Buildpack
  describe Packager do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:buildpack_dir) { File.join(tmp_dir, 'sample-buildpack-root-dir') }
    let(:cache_dir) { File.join(tmp_dir, 'cache-dir') }
    let(:file_location) { '/etc/hosts' }
    let(:md5) { Digest::MD5.file(file_location).hexdigest }

    let(:buildpack) {
      {
        root_dir: buildpack_dir,
        mode: buildpack_mode,
        language: 'sample',
        dependencies: [{
          'version' => '1.0',
          'name' => 'etc_host',
          'md5' => md5,
          'uri' => "file://#{file_location}"
        }],
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

          expect(all_files(buildpack_dir)).to include('sample_buildpack-v1.2.3.zip')
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

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
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

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        expect(zip_contents).to_not include(*files_to_exclude)
      end

      context 'when appending an exclusion for the zip file' do
        specify do
          Packager.package(buildpack)
          Packager.package(buildpack.merge(exclude_files: files_to_exclude + ['VERSION']))

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to_not include('VERSION')
        end
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
            let(:cached_file) { File.join(cache_dir, "file____temp_file") }

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
      let(:buildpack_mode) { :online }

      context 'zip is installed' do
        specify do
          expect { Packager.package(buildpack) }.not_to raise_error
        end
      end

      context 'zip is not installed' do
        before do
          allow(Open3).to receive(:capture3).
            with("which zip").
            and_return(['', '', 'exit 1'])
        end

        specify do
          expect { Packager.package(buildpack) }.to raise_error(RuntimeError)
        end
      end
    end

    describe 'avoid changing state of buildpack folder, other than creating the artifact (.zip)' do
      context 'create an offline buildpack' do
        let(:buildpack_mode) { :offline }

        specify 'user does not see dependencies directory in their buildpack folder' do
          Packager.package(buildpack)

          expect(all_files(buildpack_dir)).not_to include("dependencies")
        end
      end
    end
  end
end
