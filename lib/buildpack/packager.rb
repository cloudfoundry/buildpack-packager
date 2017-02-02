require 'buildpack/packager/version'
require 'buildpack/packager/table_presentation'
require 'buildpack/packager/dependencies_presenter'
require 'buildpack/packager/default_versions_presenter'
require 'buildpack/packager/package'
require 'active_support/core_ext/hash/indifferent_access'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'shellwords'

module Buildpack
  module Packager
    class CheckSumError < StandardError; end

    def self.package(options)
      check_for_zip

      package = Package.new(options)

      Dir.mktmpdir do |temp_dir|
        package.copy_buildpack_to_temp_dir(temp_dir)

        package.build_dependencies(temp_dir) if options[:mode] == :cached

        Dir.chdir(temp_dir) do
          package.run_pre_package
        end

        package.build_zip_file(temp_dir)
      end

      buildpack_type = options[:mode] == :cached ? "Cached" : "Uncached"
      human_readable_size = `du -h #{package.zip_file_path} | cut -f1`
      puts "#{buildpack_type} buildpack created and saved as #{package.zip_file_path} with a size of #{human_readable_size.strip}"

      package
    end

    def self.list(options)
      package = Package.new(options)
      package.list
    end

    def self.defaults(options)
      package = Package.new(options)
      package.defaults
    end

    def self.check_for_zip
      _, _, status = Open3.capture3('which zip')

      if status.to_s.include?('exit 1')
        raise "Zip is not installed\nTry: apt-get install zip\nAnd then rerun"
      end
    end
  end
end
