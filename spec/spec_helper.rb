$LOAD_PATH << File.expand_path('../../lib', __FILE__)
$LOAD_PATH << File.expand_path('../../spec/helpers', __FILE__)
require 'buildpack/packager'
require 'file_system_helpers'

RSpec.configure do |config|
  config.include FileSystemHelpers
end
