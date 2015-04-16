require 'buildpack/packager/version'
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
      package = Package.new(options)
      package.execute!
      package
    end

    class Package < Struct.new(:options)
      def execute!
        check_for_zip

        Dir.mktmpdir do |temp_dir|
          copy_buildpack_to_temp_dir(temp_dir)

          if options[:mode] == :cached
            build_dependencies(temp_dir)
            validate_checksums_of_dependencies(temp_dir)
          end

          build_zip_file(zip_file_path, temp_dir)
        end
      end

      private

      def uri_cache_path uri
        uri.gsub(/[:\/]/, '_')
      end

      def manifest
        @manifest ||= YAML.load_file(options[:manifest_path]).with_indifferent_access
      end

      def zip_file_path
        Shellwords.escape(File.join(options[:root_dir], zip_file_name))
      end

      def zip_file_name
        "#{manifest[:language]}_buildpack#{cached_identifier}-v#{buildpack_version}.zip"
      end

      def buildpack_version
        File.read("#{options[:root_dir]}/VERSION").chomp
      end

      def cached_identifier
        return '' unless options[:mode] == :cached
        '-cached'
      end

      def copy_buildpack_to_temp_dir(temp_dir)
        FileUtils.cp_r(File.join(options[:root_dir], '.'), temp_dir)
      end

      def build_zip_file(zip_file_path, temp_dir)
        exclude_files = manifest[:exclude_files].collect { |e| "--exclude=*#{e}*" }.join(" ")
        `rm -rf #{zip_file_path}`
        `cd #{temp_dir} && zip -r #{zip_file_path} ./ #{exclude_files}`
      end

      def build_dependencies(temp_dir)
        cache_directory = options[:cache_dir] || "#{ENV['HOME']}/.buildpack-packager/cache"
        FileUtils.mkdir_p(cache_directory)

        dependency_dir = File.join(temp_dir, "dependencies")
        FileUtils.mkdir_p(dependency_dir)

        manifest[:dependencies].each do |dependency|
          translated_filename = uri_cache_path dependency['uri']
          cached_file = File.expand_path(File.join(cache_directory, translated_filename))
          if options[:force_download] || !File.exist?(cached_file)
            download_file(dependency['uri'], cached_file)
          end

          FileUtils.cp(cached_file, dependency_dir)
        end
      end

      def validate_checksums_of_dependencies(temp_dir)
        dependency_dir = File.join(temp_dir, "dependencies")
        manifest[:dependencies].each do |dependency|
          name = dependency['name']
          version = dependency['version']
          md5 = dependency['md5']
          uri = dependency['uri']

          translated_filename = uri_cache_path uri
          dependency = File.expand_path(File.join(dependency_dir, translated_filename))

          if md5 != Digest::MD5.file(dependency).hexdigest
            raise CheckSumError,
            "File: #{name}, version: #{version} (#{translated_filename}) downloaded at location #{uri} is reporting a different checksum than the one specified in the manifest."
          end
        end
      end

      def check_for_zip
        _, _, status = Open3.capture3("which zip")

        raise RuntimeError, "Zip is not installed\nTry: apt-get install zip\nAnd then rerun" if status.to_s.include?("exit 1")
      end

      def download_file(url, file)
        `curl #{url} -o #{file} -L --fail -f`
      end
    end
  end
end
