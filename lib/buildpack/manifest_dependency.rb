module Buildpack
  class ManifestDependency
    attr_reader :name, :version

    def initialize(name, version)
      @name = name
      @version = version
    end

    def ==(other_object)
      name == other_object.name && version == other_object.version
    end
  end
end
