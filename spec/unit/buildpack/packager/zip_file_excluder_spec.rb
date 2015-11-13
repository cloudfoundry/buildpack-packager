require 'buildpack/packager/zip_file_excluder'
require 'spec_helper'
require 'tmpdir'
require 'securerandom'

module Buildpack
  module Packager
    describe ZipFileExcluder do
      describe "#generate_exclude_file_list" do
        let(:excluder) { ZipFileExcluder.new }
        let(:file1) { SecureRandom.uuid }
        let(:file2) { SecureRandom.uuid }
        let(:dir) { "#{SecureRandom.uuid}/" }
        let(:excluded_files) { [file1, file2] }
        subject do
          excluder.generate_exclude_file_list excluded_files
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


        it "uses short flags to support zip 2.3.*, see [#107948062]" do
          is_expected.to include("-x")
          is_expected.to_not include("--exclude")
        end
      end
    end
  end
end
