require 'buildpack/packager/version'
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

        if options[:mode] == :cached
          package.build_dependencies(temp_dir)
        end

        package.build_zip_file(temp_dir)
      end

      package
    end

    def self.list(options)
      package = Package.new(options)
      package.list
    end

    def self.check_for_zip
      _, _, status = Open3.capture3("which zip")

      if status.to_s.include?("exit 1")
        raise RuntimeError, "Zip is not installed\nTry: apt-get install zip\nAnd then rerun"
      end
    end
  end
end
