require 'spec_helper'

describe Buildpack::Packager do
  it 'has a version number' do
    expect(Buildpack::Packager::VERSION).not_to be nil
  end
end
