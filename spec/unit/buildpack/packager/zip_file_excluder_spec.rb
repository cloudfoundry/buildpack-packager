require 'buildpack/packager/zip_file_excluder'
require 'spec_helper'
require 'tmpdir'
require 'securerandom'

module Buildpack
  module Packager
    describe ZipFileExcluder do
      describe '#generate_exclusions_from_manifest' do
        let(:excluder) { ZipFileExcluder.new }
        let(:file1) { SecureRandom.uuid }
        let(:file2) { SecureRandom.uuid }
        let(:dir) { "#{SecureRandom.uuid}/" }
        let(:excluded_files) { [file1, file2] }
        subject do
          excluder.generate_manifest_exclusions excluded_files
        end

        context 'does not include directories' do
          it do
            is_expected.to eq "-x #{file1} -x \\*/#{file1} -x #{file2} -x \\*/#{file2}"
          end
        end

        context 'includes directories' do
          let(:excluded_files) { [file1, dir] }
          it do
            is_expected.to eq "-x #{file1} -x \\*/#{file1} -x #{dir}\\* -x \\*/#{dir}\\*"
          end
        end

        it 'uses short flags to support zip 2.3.*, see [#107948062]' do
          is_expected.to include('-x')
          is_expected.to_not include('--exclude')
        end
      end
    end

    describe '#generate_exclusions_from_git_files' do
      let(:excluder) { ZipFileExcluder.new }

      context 'git files exist' do
        let (:files) { ['.gitignore', '.git/', '.gitmodules', 'lib/.git'] }

        it 'returns an exclusion string with all the git files' do
          Dir.mktmpdir do |dir|
            Dir.mkdir "#{dir}/lib"

            files.each do |gitfilename|
              if gitfilename =~ /.*\/$/
                Dir.mkdir "#{dir}/#{gitfilename}"
              else
                File.new "#{dir}/#{gitfilename}", 'w'
              end
            end

            git_exclusions = excluder.generate_exclusions_from_git_files dir

            expect(git_exclusions).to include '-x .gitignore -x \\*/.gitignore'
            expect(git_exclusions).to include '-x lib/.git -x \\*/lib/.git'
            expect(git_exclusions).to include '-x .gitmodules -x \\*/.gitmodules'
            expect(git_exclusions).to include '-x .git/\\* -x \\*/.git/\\*'
          end
        end
      end
    end
  end
end
