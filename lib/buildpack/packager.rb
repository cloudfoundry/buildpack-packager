require "buildpack/packager/version"

module Buildpack
  module Packager
    def self.package(buildpack)
      buildpack_version = `cat #{buildpack[:root_dir]}/VERSION`.chomp
      zip_file_name = "#{buildpack[:root_dir]}/#{buildpack[:language]}_buildpack-#{buildpack[:mode]}-v#{buildpack_version}.zip"

      if buildpack[:mode] == :offline
        `mkdir #{buildpack[:root_dir]}/dependencies`
        buildpack[:dependencies].each do |url|
          translated_filename = url.gsub(/[:\/]/, '_')
          `curl #{url} -o #{buildpack[:root_dir]}/dependencies/#{translated_filename} -L --fail`
        end
      end
      `cd #{buildpack[:root_dir]} && zip -r #{zip_file_name} ./`
    end
  end
end
