$LOAD_PATH << File.expand_path('../../lib', __FILE__)
$LOAD_PATH << File.expand_path('../../spec/helpers', __FILE__)
require 'buildpack/packager'
require 'file_system_helpers'
require 'cache_directory_helpers'
require 'fake_binary_hosting_helpers'

RSpec.configure do |config|
  config.include FileSystemHelpers
  config.include CacheDirectoryHelpers
  config.include FakeBinaryHostingHelpers
end
