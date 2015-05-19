require 'spec_helper'
require 'tmpdir'

module Buildpack
  describe Packager do
    let(:tmp_dir) do
      dir = FileUtils.mkdir_p(File.join(Dir.mktmpdir, rand.to_s[2..-1]))[0]
      puts dir
      dir
    end
    let(:buildpack_dir) { File.join(tmp_dir, 'sample-buildpack-root-dir') }
    let(:cache_dir) { File.join(tmp_dir, 'cache-dir') }
    let(:file_location) do
      location = File.join(tmp_dir, 'sample_host')
      File.write(location, 'contents!')
      puts "FILE CONTENTS--------------------"
      puts location
      puts `cat #{location}`
      location
    end
    let(:translated_file_location) { 'file___' + file_location.gsub(/[:\/]/, '_') }

    let(:md5) { Digest::MD5.file(file_location).hexdigest }

    let(:options) {
      {
        root_dir: buildpack_dir,
        mode: buildpack_mode,
        cache_dir: cache_dir,
        manifest_path: manifest_path
      }
    }

    let(:manifest_path) { 'manifest.yml' }
    let(:manifest) {
      {
        exclude_files: files_to_exclude,
        language: 'sample',
        url_to_dependency_map: [{
          match: "ruby-(\d+\.\d+\.\d+)",
          name: "ruby",
          version: "$1",
        }],
        dependencies: [{
          'version' => '1.0',
          'name' => 'etc_host',
          'md5' => md5,
          'uri' => "file://#{file_location}"
        }]
      }
    }

    let(:files_to_include) {
      [
        'VERSION',
        'README.md',
        'lib/sai.to',
        'lib/rash',
        'log/log.txt',
        'first-level/log/log.txt',
        'log.txt',
        'blog.txt',
        'blog/blog.txt'
      ]
    }

    let(:files_to_exclude) {
      [
        '.gitignore'
      ]
    }

    let(:files) { files_to_include + files_to_exclude }
    let(:cached_file) { File.join(cache_dir, translated_file_location) }

    def create_manifest(manifest)
      File.write(File.join(buildpack_dir, manifest_path), manifest.to_yaml)
    end

    before do
      make_fake_files(buildpack_dir, files)
      files_to_include << 'manifest.yml'
      create_manifest(manifest)
      `echo "1.2.3" > #{File.join(buildpack_dir, 'VERSION')}`

      @pwd ||= Dir.pwd
      Dir.chdir(buildpack_dir)
    end

    after do
      Dir.chdir(@pwd)
      FileUtils.remove_entry tmp_dir
    end

    describe 'a well formed zip file name' do
      context 'an uncached buildpack' do
        let(:buildpack_mode) { :uncached }

        specify do
          Packager.package(options)

          expect(all_files(buildpack_dir)).to include('sample_buildpack-v1.2.3.zip')
        end
      end

      context 'a cached buildpack' do
        let(:buildpack_mode) { :cached }

        specify do
          puts `ls #{buildpack_dir}`

          puts Packager.package(options)

          expect(all_files(buildpack_dir)).to include('sample_buildpack-cached-v1.2.3.zip')
        end

      end
    end

    describe 'the zip file contents' do
      context 'an uncached buildpack' do
        let(:buildpack_mode) { :uncached }

        specify do
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to match_array(files_to_include)
        end
      end

      context 'a cached buildpack' do
        let(:buildpack_mode) { :cached }

        specify do
          Packager.package(options)


          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-cached-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)
          dependencies = ["dependencies/#{translated_file_location}"]

          expect(zip_contents).to match_array(files_to_include + dependencies)
        end
      end
    end

    describe 'excluded files' do
      let(:buildpack_mode) { :uncached }

      it 'excludes files from exclude_files list in the manifest' do
        Packager.package(options)

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        expect(zip_contents).to_not include(*files_to_exclude)
      end

      context 'when appending an exclusion for the zip file' do
        specify do
          create_manifest(manifest.merge(exclude_files: files_to_exclude + ['VERSION']))
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to_not include('VERSION')
        end
      end

      context 'when using a directory pattern in exclude_files' do
        it 'excludes directories with that name' do
          create_manifest(manifest.merge(exclude_files: files_to_exclude + ['log/']))
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to_not include('first-level/log/log.txt')
          expect(zip_contents).to_not include('log/log.txt')
          expect(zip_contents).to include('blog/blog.txt')
          expect(zip_contents).to include('log.txt')
        end
      end

      context 'when using glob patterns in exclude_files' do
        it 'can accept glob patterns' do
          create_manifest(manifest.merge(exclude_files: files_to_exclude + ['*log.txt']))
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to_not include('log.txt')
          expect(zip_contents).to_not include('log/log.txt')
          expect(zip_contents).to_not include('first-level/log/log.txt')
          expect(zip_contents).to_not include('blog/blog.txt')
          expect(zip_contents).to_not include('blog.txt')
        end

        it 'does not do fuzzy matching by default' do
          create_manifest(manifest.merge(exclude_files: files_to_exclude + ['log.txt']))
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to_not include('log.txt')
          expect(zip_contents).to include('blog.txt')
        end
      end
    end

    describe 'caching of dependencies' do
      context 'an uncached buildpack' do
        let(:buildpack_mode) { :uncached }

        specify do
          Packager.package(options)

          expect(File).to_not exist(cached_file)
        end
      end

      context 'a cached buildpack' do
        let(:buildpack_mode) { :cached }

        context 'by default' do
          specify do
            Packager.package(options)
            expect(File).to exist(cached_file)
          end
        end

        context 'with the force download enabled' do
          context 'and the cached file does not exist' do
            it 'will write the cache file' do
              Packager.package(options.merge(force_download: true))
              expect(File).to exist(cached_file)
            end
          end

          context 'on subsequent calls' do
            it 'does not use the cached file' do
              Packager.package(options.merge(force_download: true))
              File.write(cached_file, 'asdf')
              Packager.package(options.merge(force_download: true))
              expect(File.read(cached_file)).to_not eq 'asdf'
            end
          end
        end

        context 'with the force download disabled' do
          context 'and the cached file does not exist' do
            it 'will write the cache file' do
              Packager.package(options.merge(force_download: false))
              expect(File).to exist(cached_file)
            end
          end

          context 'on subsequent calls' do
            it 'does use the cached file' do
              Packager.package(options.merge(force_download: false))

              expect_any_instance_of(Packager::Package).not_to receive(:download_file)
              Packager.package(options.merge(force_download: false))
            end
          end
        end
      end
    end

    describe 'when checking checksums' do
      context 'with an invalid MD5' do
        let(:md5) { 'wompwomp' }

        context 'in cached mode' do
          let(:buildpack_mode) { :cached }

          it 'raises an error' do
            expect do
              Packager.package(options)
            end.to raise_error(Packager::CheckSumError)
          end
        end

        context 'in uncached mode' do
          let(:buildpack_mode) { :uncached }

          it 'does not raise an error' do
            expect do
              Packager.package(options)
            end.to_not raise_error
          end
        end
      end
    end

    describe 'existence of zip' do
      let(:buildpack_mode) { :uncached }

      context 'zip is installed' do
        specify do
          expect { Packager.package(options) }.not_to raise_error
        end
      end

      context 'zip is not installed' do
        before do
          allow(Open3).to receive(:capture3).
            with("which zip").
            and_return(['', '', 'exit 1'])
        end

        specify do
          expect { Packager.package(options) }.to raise_error(RuntimeError)
        end
      end
    end

    describe 'avoid changing state of buildpack folder, other than creating the artifact (.zip)' do
      context 'create an cached buildpack' do
        let(:buildpack_mode) { :cached }

        specify 'user does not see dependencies directory in their buildpack folder' do
          Packager.package(options)

          expect(all_files(buildpack_dir)).not_to include("dependencies")
        end
      end
    end
  end
end
