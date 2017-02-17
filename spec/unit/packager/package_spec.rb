require 'spec_helper'
require 'tmpdir'

module Buildpack
  module Packager
    describe Package do
      let(:packager) { Buildpack::Packager::Package.new(options) }
      let(:manifest_path) { 'manifest.yml' }
      let(:dependency) { double(:dependency) }
      let(:mode) { :uncached }
      let(:local_cache_dir) { nil }
      let(:force_download) { false }
      let(:options) do
        {
          root_dir: 'root_dir',
          mode: mode,
          cache_dir: local_cache_dir,
          manifest_path: manifest_path,
          force_download: force_download
        }
      end

      let(:manifest) do
        {
          language: 'fake_language',
          dependencies: [dependency],
          exclude_files: ['.DS_Store', '.gitignore']
        }
      end

      before do
        allow(YAML).to receive(:load_file).and_return(manifest)
      end

      describe '#copy_buildpack_to_temp_dir' do
        context 'with full manifest specified' do
          let(:manifest_path) { 'manifest-including-unsupported.yml' }

          before do
            allow(FileUtils).to receive(:mv)
            allow(FileUtils).to receive(:cp_r)
            allow(FileUtils).to receive(:cp)
            allow(FileUtils).to receive(:rm)
          end

          it 'replaces the default manifest with the full manifest' do
            expect(FileUtils).to receive(:cp).with('manifest-including-unsupported.yml', File.join('hello_dir', 'manifest.yml'))
            packager.copy_buildpack_to_temp_dir('hello_dir')
          end
        end
      end

      describe '#build_dependencies' do
        let(:mode) { :cached }

        before do
          allow(FileUtils).to receive(:mkdir_p)
          allow(packager).to receive(:download_dependencies)
        end

        context 'when cache_dir is provided' do
          let(:local_cache_dir) { 'local_cache_dir' }

          it 'creates the provided cache dir' do
            expect(FileUtils).to receive(:mkdir_p).with(local_cache_dir)
            packager.build_dependencies('hello_dir')
          end

          it 'creates the dependency dir' do
            expect(FileUtils).to receive(:mkdir_p).with(File.join('hello_dir', 'dependencies'))
            packager.build_dependencies('hello_dir')
          end

          it 'calls download_dependencies with right arguments' do
            expect(packager).to receive(:download_dependencies).with([dependency], local_cache_dir, File.join('hello_dir', 'dependencies'))
            packager.build_dependencies('hello_dir')
          end
        end

        context 'when cache_dir is NOT provided' do
          it 'creates the default cache dir' do
            expect(FileUtils).to receive(:mkdir_p).with(File.join(ENV['HOME'], '.buildpack-packager', 'cache'))
            packager.build_dependencies('hello_dir')
          end
        end
      end

      describe '#download_dependencies' do
        let(:local_cache_dir) { 'local_cache_dir' }
        let(:dependency_dir) { File.join('hello_dir', 'dependencies') }
        let(:url_with_parameters) { 'http://some.cdn/with?parameters=true&secondParameter=present' }

        before do
          allow(dependency).to receive(:[])
          allow(dependency).to receive(:[]).with('uri').and_return('file:///fake_uri.tgz')
          allow(packager).to receive(:ensure_correct_dependency_checksum)
          allow(FileUtils).to receive(:cp)
          allow(packager).to receive(:download_file)
        end

        context 'before dependency has been cached locally' do
          before do
            allow(File).to receive(:exist?).and_return(false)
          end

          it 'downloads the dependency to the local cache' do
            expanded_local_file_location = File.expand_path(File.join('local_cache_dir', 'file____fake_uri.tgz'))
            expect(packager).to receive(:download_file).with('file:///fake_uri.tgz', expanded_local_file_location)
            packager.download_dependencies([dependency], local_cache_dir, dependency_dir)
          end

          it 'copies the dependency from the local cache to the dependency_dir' do
            expanded_local_file_location = File.expand_path(File.join('local_cache_dir', 'file____fake_uri.tgz'))
            expect(FileUtils).to receive(:cp).with(expanded_local_file_location, dependency_dir)
            packager.download_dependencies([dependency], local_cache_dir, dependency_dir)
          end
        end

        context 'after dependency has been cached locally' do
          before do
            allow(File).to receive(:exist?).and_return(true)
          end

          it 'does not re-download the dependency' do
            expect(packager).not_to receive(:download_file)
            packager.download_dependencies([dependency], local_cache_dir, dependency_dir)
          end

          it 'copies the dependency from the local cache to the dependency_dir' do
            expanded_local_file_location = File.expand_path(File.join('local_cache_dir', 'file____fake_uri.tgz'))
            expect(FileUtils).to receive(:cp).with(expanded_local_file_location, dependency_dir)
            packager.download_dependencies([dependency], local_cache_dir, dependency_dir)
          end
        end

        context 'with :force_download option active and a locally cached dependency' do
          let(:force_download) { true }

          before do
            allow(File).to receive(:exist?).and_return(true)
          end

          it 're-downloads the dependency anyway' do
            expect(packager).to receive(:download_file)
            packager.download_dependencies([dependency], local_cache_dir, dependency_dir)
          end
        end

        it 'translates ? and & characters in the url to underscores' do
          package = Package.new
          expect(package.send(:uri_cache_path, url_with_parameters)).to eq("http___some.cdn_with_parameters=true_secondParameter=present")
        end

        context 'url has login and password authentication credentials' do
          let(:url_with_credentials) { 'http://log!i213:pas!9sword@some.cdn/with' }

          it 'redacts the credentials in the resulting file path' do
            package = Package.new
            expect(package.send(:uri_without_credentials, url_with_credentials)).to eq("http://-redacted-:-redacted-@some.cdn/with")
          end
        end

        context 'url has a login authentication credential' do
          let(:url_with_credentials) { 'http://log!i213@some.cdn/with' }

          it 'redacts the credential in the resulting file path' do
            package = Package.new
            expect(package.send(:uri_without_credentials, url_with_credentials)).to eq("http://-redacted-@some.cdn/with")
          end
        end
      end

      describe '#build_zip_file' do
        before do
          allow(packager).to receive(:buildpack_version).and_return('1.0.0')
          allow(FileUtils).to receive(:rm_rf)
          allow(packager).to receive(:zip_files)
          allow(packager).to receive(:zip_file_path)
            .and_return(File.join('root_dir', 'fake_language_buildpack-v1.0.0.zip'))
        end

        it 'removes the file at the zip file path' do
          zip_file_path = File.join('root_dir', 'fake_language_buildpack-v1.0.0.zip')
          expect(FileUtils).to receive(:rm_rf).with(zip_file_path)
          packager.build_zip_file('hello_dir')
        end

        it 'zips up the temp directory to the zip file path without the excluded files' do
          zip_file_path = File.join('root_dir', 'fake_language_buildpack-v1.0.0.zip')
          expect(packager).to receive(:zip_files).with('hello_dir', zip_file_path, ['.DS_Store', '.gitignore'])
          packager.build_zip_file('hello_dir')
        end
      end

      describe '#run_pre_package' do
        context 'when manifest has pre_package set' do
          let(:manifest) do
            { pre_package: 'scripts/build.sh' }
          end

          context 'when the pre package script succeeds' do
            it 'does not raise an error' do
              allow(Kernel).to receive(:system)
                .with('scripts/build.sh')
                .and_return(true)

              packager.run_pre_package
              expect(Kernel).to have_received(:system)
            end
          end

          context 'when the pre package script fails' do
            it 'raises an error' do
              allow(Kernel).to receive(:system)
                .with('scripts/build.sh')
                .and_return(false)
              expect { packager.run_pre_package }.to raise_error('Failed to run pre_package script: scripts/build.sh')
            end
          end
        end

        context 'when manifest does not have pre_package set' do
          it 'does nothing' do
            expect(Kernel).not_to receive(:system)

            packager.run_pre_package
          end
        end
      end
    end
  end
end
