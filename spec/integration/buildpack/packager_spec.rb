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
      location
    end
    let(:translated_file_location) { 'file___' + file_location.gsub(/[:\/]/, '_') }

    let(:md5) { Digest::MD5.file(file_location).hexdigest }

    let(:options) do
      {
        root_dir: buildpack_dir,
        mode: buildpack_mode,
        cache_dir: cache_dir,
        manifest_path: manifest_path
      }
    end

    let(:manifest_path) { 'manifest.yml' }
    let(:manifest) do
      {
        exclude_files: [],
        language: 'sample',
        url_to_dependency_map: [{
          match: 'ruby-(d+.d+.d+)',
          name: 'ruby',
          version: '$1'
        }],
        dependencies: [{
          'version' => '1.0',
          'name' => 'etc_host',
          'md5' => md5,
          'uri' => "file://#{file_location}",
          'cf_stacks' => ['cflinuxfs2']
        }]
      }
    end

    let(:buildpack_files) do
      [
        'VERSION',
        'README.md',
        'lib/sai.to',
        'lib/rash',
        'log/log.txt',
        'first-level/log/log.txt',
        'log.txt',
        'blog.txt',
        'blog/blog.txt',
        '.gitignore',
        '.gitmodules',
        'lib/.git'
      ]
    end

    let(:git_files) { ['.gitignore', '.gitmodules', 'lib/.git'] }
    let(:cached_file) { File.join(cache_dir, translated_file_location) }

    def create_manifest(options = {})
      manifest.merge!(options)
      File.write(File.join(buildpack_dir, manifest_path), manifest.to_yaml)
    end

    before do
      make_fake_files(buildpack_dir, buildpack_files)
      buildpack_files << 'manifest.yml'
      create_manifest
      `echo "1.2.3" > #{File.join(buildpack_dir, 'VERSION')}`

      @pwd ||= Dir.pwd
      Dir.chdir(buildpack_dir)
    end

    after do
      Dir.chdir(@pwd)
      FileUtils.remove_entry tmp_dir
    end

    describe '#list' do
      let(:buildpack_mode) { :list }

      context 'default manifest.yml' do
        specify do
          create_manifest
          table = Packager.list(options)
          expect(table.to_s).to match(/etc_host.*1\.0.*cflinuxfs2/)
        end
      end

      context 'alternate manifest path' do
        let(:manifest_path) { 'my-manifest.yml' }

        specify do
          create_manifest
          table = Packager.list(options)
          expect(table.to_s).to match(/etc_host.*1\.0.*cflinuxfs2/)
        end
      end

      context 'sorted output' do
        def create_manifest_dependency_skeleton(dependencies)
          manifest = {}
          manifest['dependencies'] = []
          dependencies.each do |dependency|
            manifest['dependencies'].push('name' => dependency.first,
                                          'version'   => dependency.last,
                                          'cf_stacks' => ['cflinuxfs2'])
          end
          File.write(File.join(buildpack_dir, manifest_path), manifest.to_yaml)
        end

        %w(go hhvm jruby node php python ruby).each do |interpreter|
          it "sorts #{interpreter} interpreter first" do
            create_manifest_dependency_skeleton([
                                                  ['aaaaa', '1.0'],
                                                  [interpreter, '1.0'],
                                                  ['zzzzz', '1.0']
                                                ])
            table = Packager.list(options)
            stdout = table.to_s.split("\n")

            position_of_a = stdout.index(stdout.grep(/aaaaa/).first)
            position_of_interpreter = stdout.index(stdout.grep(/ #{interpreter} /).first)
            position_of_z = stdout.index(stdout.grep(/zzzzz/).first)

            expect(position_of_interpreter).to be < position_of_a
            expect(position_of_interpreter).to be < position_of_z
          end
        end

        it 'sorts using `name` as secondary key' do
          create_manifest_dependency_skeleton([
                                                ['b_foobar', '1.0'],
                                                ['a_foobar', '1.0'],
                                                ['c_foobar', '1.0']
                                              ])
          table = Packager.list(options)
          stdout = table.to_s.split("\n")

          position_of_a = stdout.index(stdout.grep(/a_foobar/).first)
          position_of_b = stdout.index(stdout.grep(/b_foobar/).first)
          position_of_c = stdout.index(stdout.grep(/c_foobar/).first)

          expect(position_of_a).to be < position_of_b
          expect(position_of_b).to be < position_of_c
        end

        it 'sorts using `version` as secondary key' do
          create_manifest_dependency_skeleton([
                                                ['foobar', '1.1'],
                                                ['foobar', '1.2'],
                                                ['foobar', '1.0']
                                              ])
          table = Packager.list(options)
          stdout = table.to_s.split("\n")

          position_of_10 = stdout.index(stdout.grep(/1\.0/).first)
          position_of_11 = stdout.index(stdout.grep(/1\.1/).first)
          position_of_12 = stdout.index(stdout.grep(/1\.2/).first)

          expect(position_of_10).to be < position_of_11
          expect(position_of_11).to be < position_of_12
        end
      end
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

          expect(zip_contents).to match_array(buildpack_files - git_files)
        end
      end

      context 'a cached buildpack' do
        let(:buildpack_mode) { :cached }

        specify do
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-cached-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)
          dependencies = ["dependencies/#{translated_file_location}"]

          expect(zip_contents).to match_array(buildpack_files + dependencies - git_files)
        end
      end
    end

    describe 'excluded files' do
      let(:buildpack_mode) { :uncached }

      context 'when specifying files for exclusion' do
        it 'excludes .git files from zip files' do
          create_manifest(exclude_files: ['.gitignore'])
          Packager.package(options)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to_not include('.gitignore')
          expect(zip_contents).to_not include('.gitmodules')
          expect(zip_contents).to_not include('lib/.git')
        end
      end

      context 'when using a directory pattern in exclude_files' do
        it 'excludes directories with that name' do
          create_manifest(exclude_files: ['log/'])
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
          create_manifest(exclude_files: ['*log.txt'])
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
          create_manifest(exclude_files: ['log.txt'])
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
            it 'will overwrite the cache file' do
              expect(File).to_not exist(cached_file)

              Packager.package(options.merge(force_download: true))

              expect(File).to exist(cached_file)
              expect(Digest::MD5.file(cached_file).hexdigest).to eq md5
            end
          end

          context 'and the request fails' do
            let(:file_location) { 'fake-file-that-no-one-should-have.txt' }
            let(:md5) { nil }

            it 'does not cache the file' do
              expect(File).to_not exist(cached_file)

              expect do
                Packager.package(options.merge(force_download: true))
              end.to raise_error(RuntimeError)

              expect(File).to_not exist(cached_file)
            end

            it 'raises an error about a failed download' do
              expect do
                Packager.package(options.merge(force_download: true))
              end.to raise_error(RuntimeError, 'Failed to download file from file://fake-file-that-no-one-should-have.txt')
            end
          end

          context 'on subsequent calls' do
            context 'and they are successful' do
              it 'does not use the cached file and overwrites it' do
                Packager.package(options.merge(force_download: true))
                File.write(cached_file, 'asdf')

                Packager.package(options.merge(force_download: true))
                expect(Digest::MD5.file(cached_file).hexdigest).to eq md5
              end
            end

            context 'and they fail' do
              it 'does not override the cached file' do
                Packager.package(options.merge(force_download: true))
                File.write(cached_file, 'asdf')

                File.delete(file_location)

                expect do
                  Packager.package(options.merge(force_download: true))
                end.to raise_error(RuntimeError)

                expect(File.read(cached_file)).to eq 'asdf'
              end
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
          allow(Open3).to receive(:capture3)
            .with('which zip')
            .and_return(['', '', 'exit 1'])
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

          expect(all_files(buildpack_dir)).not_to include('dependencies')
        end
      end
    end

    describe 'pre package script' do
      let(:buildpack_mode) { :uncached }

      before do
        FileUtils.mkdir_p(File.join(buildpack_dir, 'scripts'))
        script_path = File.join(buildpack_dir, 'scripts/run.sh')
        File.write(script_path, 'mkdir .cloudfoundry && touch .cloudfoundry/hwc.exe')
        File.chmod(0755, script_path)
      end

      it 'runs the pre package script if specified' do
        create_manifest(pre_package: 'scripts/run.sh')
        Packager.package(options)

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        expect(zip_contents).to include('.cloudfoundry/hwc.exe')
      end

      it 'does not run the pre package script if not specified' do
        create_manifest(pre_package: nil)
        Packager.package(options)

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        expect(zip_contents).not_to include('.cloudfoundry/hwc.exe')
      end
    end
  end
end
