require 'spec_helper'
require 'tmpdir'
require 'yaml'

describe 'buildpack_packager binary' do
  def run_packager_binary
    packager_binary_file = "#{`pwd`.chomp}/bin/buildpack-packager"
    `cd #{buildpack_dir} && #{packager_binary_file} #{mode}`
  end

  let(:tmp_dir) { Dir.mktmpdir }

  let(:buildpack_dir) { File.join(tmp_dir, 'sample-buildpack-root-dir') }
  let(:remote_dependencies_dir) { File.join(tmp_dir, 'remote_dependencies') }

  let(:files_to_include) {
    [
        'VERSION',
        'README.md',
        'lib/sai.to',
        'lib/rash',
        'manifest.yml'
    ]
  }

  let(:files_to_exclude) {
    [
        '.gitignore',
        'lib/ephemeral_junkpile'
    ]
  }

  let(:files) { files_to_include + files_to_exclude }

  let(:dependencies) {
    ['dep1.txt']
  }


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

    File.open(File.join(buildpack_dir, 'manifest.yml'), 'w') do |manifest_file|
      manifest_file.write <<-MANIFEST
---
language: sample
dependencies:
- file://#{remote_dependencies_dir}/dep1.txt
exclude_files:
- .gitignore
- lib/ephemeral_junkpile
      MANIFEST
    end
  end

  after do
    FileUtils.remove_entry tmp_dir
  end

  describe 'the zip file contents' do
    context 'an online buildpack' do
      let(:mode) { 'online' }

      specify do
        run_packager_binary

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-online-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        expect(zip_contents).to match_array(files_to_include)
      end
    end

    context 'an offline buildpack' do
      let(:mode) { 'offline' }

      specify do
        run_packager_binary

        zip_file_path = File.join(buildpack_dir, 'sample_buildpack-offline-v1.2.3.zip')
        zip_contents = get_zip_contents(zip_file_path)

        dependencies_with_translation = dependencies.
            map { |dep| "file://#{remote_dependencies_dir}/#{dep}"}.
            map { |path| path.gsub(/[:\/]/, '_') }

        deps_with_path = dependencies_with_translation.map { |dep| "dependencies/#{dep}" }

        expect(zip_contents).to match_array(files_to_include + deps_with_path)
      end
    end
  end

end
