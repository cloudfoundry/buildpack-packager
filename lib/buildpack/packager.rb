require 'buildpack/packager/version'
require 'open3'
require 'fileutils'
require 'tmpdir'

module Buildpack
  module Packager
    def self.package(buildpack)
      package = Package.new(buildpack)
      package.execute!
      package
    end

    class Package < Struct.new(:buildpack)
      def execute!
        check_for_zip

        buildpack_version = File.read("#{buildpack[:root_dir]}/VERSION").chomp
        zip_file_name = "#{buildpack[:root_dir]}/#{buildpack[:language]}_buildpack-#{buildpack[:mode]}-v#{buildpack_version}.zip"

        Dir.mktmpdir do |temp_dir|
          copy_buildpack_to_temp_dir(temp_dir)

          build_dependencies(temp_dir) if buildpack[:mode] == :offline
          build_zip_file(zip_file_name, temp_dir)
        end
      end

      private
      def copy_buildpack_to_temp_dir(temp_dir)
        `cp -r #{buildpack[:root_dir]}/* #{temp_dir}`
      end

      def build_zip_file(zip_file_name, temp_dir)
        exclude_files = buildpack[:exclude_files].collect { |e| "--exclude=*#{e}*" }.join(" ")
        `cd #{temp_dir} && zip -r #{zip_file_name} ./ #{exclude_files}`
      end

      def build_dependencies(temp_dir)
        cache_directory = buildpack[:cache_dir] || "~/.buildpack-packager/cache"
        FileUtils.mkdir_p(cache_directory)

        dependency_dir = File.join(temp_dir, "dependencies")
        FileUtils.mkdir_p(dependency_dir)

        buildpack[:dependencies].each do |url|
          translated_filename = url.gsub(/[:\/]/, '_')

          cached_file = File.expand_path(File.join(cache_directory, translated_filename))
          if !buildpack[:cache] || !File.exist?(cached_file)
            download_file(url, cached_file)
          end

          FileUtils.cp(cached_file, dependency_dir)
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
