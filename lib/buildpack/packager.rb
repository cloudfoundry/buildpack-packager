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
      package = Package.new(options)
      package.execute!
      package
    end
  end
end
