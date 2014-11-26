require "buildpack/packager/version"

module Buildpack
  module Packager
    def self.package(buildpack)
      buildpack_version = `cat #{buildpack[:root_dir]}/VERSION`.chomp
      zip_file_name = "#{buildpack[:root_dir]}/#{buildpack[:language]}_buildpack-#{buildpack[:mode]}-v#{buildpack_version}.zip"
      `cd #{buildpack[:root_dir]} && zip -r #{zip_file_name} ./`
    end
  end
end
