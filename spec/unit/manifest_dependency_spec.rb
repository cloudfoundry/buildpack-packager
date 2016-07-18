require 'spec_helper'
require 'buildpack/manifest_dependency'

describe Buildpack::ManifestDependency do
  describe '#==' do
    context 'two objects with the same name and same version' do
      let(:first_dependency) { described_class.new('name', 'version') }
      let(:second_dependency) { described_class.new('name', 'version') }

      it 'returns true' do
        expect(first_dependency == second_dependency).to be true
      end
    end
    context 'two objects with the same name only' do
      let(:first_dependency) { described_class.new('name', 'version 11111111') }
      let(:second_dependency) { described_class.new('name', 'version 22222222') }

      it 'returns false' do
        expect(first_dependency == second_dependency).to be false
      end
    end

    context 'two objects with the same version only' do
      let(:first_dependency) { described_class.new('name 111', 'version') }
      let(:second_dependency) { described_class.new('name 222', 'version') }

      it 'returns false' do
        expect(first_dependency == second_dependency).to be false
      end
    end

    context 'two objects with different names and different versions' do
      let(:first_dependency) { described_class.new('name 111111', 'version 11111111') }
      let(:second_dependency) { described_class.new('name 222222', 'version 22222222') }

      it 'returns false' do
        expect(first_dependency == second_dependency).to be false
      end
    end
  end
end
