require 'spec_helper'
require 'tmpdir'
require 'yaml'
require 'open3'

describe 'buildpack_packager binary' do
  def create_manifests
    create_manifest
    create_full_manifest
  end

  def create_manifest
    File.open(File.join(buildpack_dir, 'manifest.yml'), 'w') do |manifest_file|
      manifest_file.write <<-MANIFEST
---
language: sample

url_to_dependency_map:
  - match: fake_name(\d+\.\d+(\.\d+)?)
    name: fake_name
    version: $1

dependencies:
  - name: fake_name
    version: 1.2
    uri: file://#{file_location}
    md5: #{md5}
    modules: ["one", "two", "three"]
    cf_stacks:
      - lucid64
      - cflinuxfs2

exclude_files:
  - .gitignore
  - lib/ephemeral_junkpile
MANIFEST
    end

    files_to_include << 'manifest.yml'
  end

  def create_full_manifest
    File.open(File.join(buildpack_dir, 'manifest-including-default-versions.yml'), 'w') do |manifest_file|
      manifest_file.write <<-MANIFEST
---
language: sample

url_to_dependency_map:
  - match: fake_name(\d+\.\d+(\.\d+)?)
    name: fake_name
    version: $1

default_versions:
  - name: fake_name
    version: 1.2

dependencies:
  - name: fake_name
    version: 1.2
    uri: file://#{file_location}
    md5: #{md5}
    cf_stacks:
      - lucid64
      - cflinuxfs2
  - name: fake_name
    version: 1.1
    uri: file://#{deprecated_file_location}
    md5: #{deprecated_md5}
    cf_stacks:
      - lucid64
      - cflinuxfs2

exclude_files:
  - .gitignore
  - lib/ephemeral_junkpile
MANIFEST
    end

    files_to_include << 'manifest-including-default-versions.yml'
  end

  def create_invalid_manifest
    File.open(File.join(buildpack_dir, 'manifest.yml'), 'w') do |manifest_file|
      manifest_file.write <<-MANIFEST
---
language: sample
dependencies:
  - name: fake_name
    version: 1.2
    uri: file://#{file_location}
    md5: md5
    cf_stacks: [cflinuxfs2]
MANIFEST
    end

    files_to_include << 'manifest.yml'
  end

  let(:tmp_dir) { Dir.mktmpdir }
  let(:buildpack_dir) { File.join(tmp_dir, 'sample-buildpack-root-dir') }
  let(:remote_dependencies_dir) { File.join(tmp_dir, 'remote_dependencies') }
  let(:file_location) { "#{remote_dependencies_dir}/dep1.txt" }
  let(:md5) { Digest::MD5.file(file_location).hexdigest }
  let(:deprecated_file_location) { "#{remote_dependencies_dir}/dep2.txt" }
  let(:deprecated_md5) { Digest::MD5.file(deprecated_file_location).hexdigest }

  let(:files_to_include) do
    [
      'VERSION',
      'README.md',
      'lib/sai.to',
      'lib/rash'
    ]
  end

  let(:files_to_exclude) do
    [
      '.gitignore',
      'lib/ephemeral_junkpile'
    ]
  end

  let(:files) { files_to_include + files_to_exclude }

  let(:dependencies) do
    ['dep1.txt', 'dep2.txt']
  end

  before do
    make_fake_files(
      remote_dependencies_dir,
      dependencies
    )

    make_fake_files(
      buildpack_dir,
      files
    )

    `echo "1.2.3" > #{File.join(buildpack_dir, 'VERSION')}`
  end

  after do
    FileUtils.remove_entry tmp_dir
  end

  describe 'flags' do
    describe '--list flag' do
      let(:flags) { '--list' }

      before do
        create_manifests
      end

      context 'default manifest' do
        it 'emits a table of contents' do
          output = run_packager_binary(buildpack_dir, flags)
          stdout = output.first

          expect(stdout).to match(/fake_name.*1\.2/)
          expect(stdout).to match(/------/) # it's a table!
        end

        context 'and there are modules' do
          it 'emit a table for modules' do
            output = run_packager_binary(buildpack_dir, flags)
            stdout = output.first

            expect(stdout).to match /modules/
            expect(stdout).to match /one, three, two/
          end
        end
      end

      context 'custom manifest' do
        let(:flags) { '--list --use-custom-manifest=manifest-including-default-versions.yml' }

        it 'emits a table of contents' do
          output = run_packager_binary(buildpack_dir, flags)
          stdout = output.first

          expect(stdout).to match(/fake_name.*1\.1/)
          expect(stdout).to match(/fake_name.*1\.2/)
          expect(stdout).to match(/------/) # it's a table!
        end

        context 'and there are no modules' do
          it 'ensures there is no modules column' do
            output = run_packager_binary(buildpack_dir, flags)
            stdout = output.first

            expect(stdout).to_not match /modules/
          end
        end
      end
    end

    describe '--defaults flag' do
      let(:flags) { '--defaults' }

      before do
        create_manifests
      end

      context 'default manifest with no default_versions' do
        it 'emits an empty table' do
          output = run_packager_binary(buildpack_dir, flags)
          stdout = output.first

          expect(stdout).to match(/ name | version/)
          expect(stdout).to match(/------/) # it's a table!
          expect(stdout.split("\m").length).to eq(2)
        end
      end

      context 'custom manifest with default_versions' do
        let(:flags) { '--defaults --use-custom-manifest=manifest-including-default-versions.yml' }

        it 'emits a table of the manifest specified default dependency versions' do
          output = run_packager_binary(buildpack_dir, flags)
          stdout = output.first

          expect(stdout).to match(/ name | version/)
          expect(stdout).to match(/fake_name.*1\.2/)
          expect(stdout).to match(/------/) # it's a table!
        end
      end
    end

    describe '--use-custom-manifest' do
      let(:flags) { '--uncached' }

      before do
        create_manifests
      end

      context 'with the flag' do
        let(:flags) { '--uncached --use-custom-manifest=manifest-including-default-versions.yml' }

        it 'uses the specified manifest' do
          run_packager_binary(buildpack_dir, flags)

          manifest_location = File.join(Dir.mktmpdir, 'manifest.yml')
          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')

          Zip::File.open(zip_file_path) do |zip_file|
            generated_manifest = zip_file.find { |file| file.name == 'manifest.yml' }
            generated_manifest.extract(manifest_location)
          end

          manifest_contents = File.read(manifest_location)

          expect(manifest_contents).to eq(File.read(File.join(buildpack_dir, 'manifest-including-default-versions.yml')))
        end
      end

      context 'without the flag' do
        it 'uses the skinny manifest' do
          run_packager_binary(buildpack_dir, flags)

          manifest_location = File.join(Dir.mktmpdir, 'manifest.yml')
          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')

          Zip::File.open(zip_file_path) do |zip_file|
            generated_manifest = zip_file.find { |file| file.name == 'manifest.yml' }
            generated_manifest.extract(manifest_location)
          end

          manifest_contents = File.read(manifest_location)

          expect(manifest_contents).to eq(File.read(File.join(buildpack_dir, 'manifest.yml')))
        end
      end
    end
  end

  context 'without a manifest' do
    let(:flags) { '--uncached' }

    specify do
      output, status = run_packager_binary(buildpack_dir, flags)

      expect(output).to include('Could not find manifest.yml')
      expect(status).not_to be_success
    end
  end

  context 'with an invalid manifest' do
    let(:flags) { '--uncached' }

    before do
      create_invalid_manifest
    end

    specify do
      output, status = run_packager_binary(buildpack_dir, flags)

      expect(output).to include('conform to the schema')
      expect(status).not_to be_success
    end
  end

  describe 'usage' do
    context 'without a flag' do
      let(:flags) { '' }
      specify do
        output, status = run_packager_binary(buildpack_dir, flags)

        expect(output).to include('USAGE: buildpack-packager < --cached | --uncached | --list | --defaults >')
        expect(status).not_to be_success
      end
    end

    context 'with an invalid flag' do
      let(:flags) { 'beast' }

      it 'reports proper usage' do
        output, status = run_packager_binary(buildpack_dir, flags)

        expect(output).to include('USAGE: buildpack-packager < --cached | --uncached | --list | --defaults >')
        expect(status).not_to be_success
      end
    end
  end

  context 'with a manifest' do
    before do
      create_manifest
    end

    describe 'the zip file contents' do
      context 'an uncached buildpack' do
        let(:flags) { '--uncached' }

        specify do
          output, status = run_packager_binary(buildpack_dir, flags)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          expect(zip_contents).to match_array(files_to_include)
          expect(status).to be_success
        end
      end

      context 'an cached buildpack' do
        let(:flags) { '--cached' }

        specify do
          _, status = run_packager_binary(buildpack_dir, flags)

          zip_file_path = File.join(buildpack_dir, 'sample_buildpack-cached-v1.2.3.zip')
          zip_contents = get_zip_contents(zip_file_path)

          dependencies_in_manifest = YAML.load_file(File.join(buildpack_dir, 'manifest.yml'))['dependencies']

          dependencies_with_translation = dependencies_in_manifest
                                          .map { |dep| "file://#{remote_dependencies_dir}/#{dep['uri'].split('/').last}" }
                                          .map { |path| path.gsub(/[:\/]/, '_') }

          deps_with_path = dependencies_with_translation.map { |dep| "dependencies/#{dep}" }

          expect(zip_contents).to match_array(files_to_include + deps_with_path)
          expect(status).to be_success
        end

        context 'vendored dependencies with invalid checksums' do
          let(:md5) { 'InvalidMD5_123' }

          specify do
            stdout, status = run_packager_binary(buildpack_dir, flags)
            expect(status).not_to be_success
          end
        end
      end
    end
  end
end
