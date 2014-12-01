require "buildpack/packager/version"
require "open3"
require 'fileutils'

module Buildpack
  module Packager
    def self.check_for_zip
      _, _, status = Open3.capture3("which zip")

      raise RuntimeError, "Zip is not installed\nTry: apt-get install zip\nAnd then rerun" if status.to_s.include?("exit 1")
    end


    def self.download_file(url, file)
      `curl #{url} -o #{file} -L --fail`
    end

    def self.package(buildpack)
      self.check_for_zip

      buildpack_version = File.read("#{buildpack[:root_dir]}/VERSION").chomp
      zip_file_name = "#{buildpack[:root_dir]}/#{buildpack[:language]}_buildpack-#{buildpack[:mode]}-v#{buildpack_version}.zip"

      cache_directory = buildpack[:cache_dir] || "~/.buildpack-packager/cache"
      FileUtils.mkdir_p(cache_directory)

      if buildpack[:mode] == :offline
        dependency_dir = File.join(buildpack[:root_dir], "dependencies")
        FileUtils.mkdir_p(dependency_dir)

        buildpack[:dependencies].each do |url|
          translated_filename = url.gsub(/[:\/]/, '_')

          cached_file = File.expand_path(File.join(cache_directory, translated_filename))
          if !buildpack[:cache] || !File.exist?(cached_file)
            self.download_file(url, cached_file)
          end

          FileUtils.cp(cached_file, dependency_dir)
        end
      end

      exclude_files = buildpack[:exclude_files].collect{|e| "--exclude=*#{e}*"}.join(" ")
      `cd #{buildpack[:root_dir]} && zip -r #{zip_file_name} ./ #{exclude_files}`
    end
  end
end
