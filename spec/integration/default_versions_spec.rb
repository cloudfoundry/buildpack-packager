require 'spec_helper'
require 'fileutils'

describe 'Buildpack packager default_versions validation' do
  let(:flags)          { '--uncached' }
  let(:buildpack_dir)  { Dir.mktmpdir }
  let(:cache_dir)      { Dir.mktmpdir }
  let(:base_manifest_contents) { <<-BASE
language: python
url_to_dependency_map: []
exclude_files: []
  BASE
  }

  before do
    Dir.chdir(buildpack_dir) do
      File.write('manifest.yml', manifest)
      File.write('VERSION', '1.7.8')
    end
  end

  after do
    FileUtils.rm_rf(buildpack_dir)
    FileUtils.rm_rf(cache_dir)
  end

  shared_examples_for "general output that helps with the error is produced" do
    it "outputs a link to the Cloud Foundry custom buildpacks page" do
      output, status = run_packager_binary(buildpack_dir, flags)
      expect(output).to include("For more information, see https://docs.cloudfoundry.org/buildpacks/custom.html#specifying-default-versions")
    end

    it "states the buildpack manifest is malformed" do
      output, status = run_packager_binary(buildpack_dir, flags)
      expect(output).to include("The buildpack manifest is malformed:")
    end
  end

  context 'defaults and dependencies are in agreement' do
    let(:manifest) {<<-MANIFEST
#{base_manifest_contents}
default_versions:
  - name: python
    version: 3.3.5
dependencies:
  - name: python
    version: 3.3.5
    uri: http://example.com/
    md5: 68901bbf8a04e71e0b30aa19c3946b21
    cf_stacks:
      - cflinuxfs2
    MANIFEST
    }

    it 'emits no errors' do
      _, status = run_packager_binary(buildpack_dir, flags)

      expect(status).to be_success
    end
  end

  context 'multiple default versions for a dependency' do
    let(:manifest) {<<-MANIFEST
#{base_manifest_contents}
default_versions:
  - name: python
    version: 3.3.5
  - name: python
    version: 3.3.2
  - name: ruby
    version: 4.3.5
  - name: ruby
    version: 4.3.2
dependencies:
  - name: python
    uri: https://a.org
    version: 3.3.5
    md5: 3a2
    cf_stacks: [cflinuxfs2]
  - name: python
    uri: https://a.org
    version: 3.3.2
    md5: 3a2
    cf_stacks: [cflinuxfs2]
  - name: ruby
    uri: https://a.org
    version: 4.3.5
    md5: 3a2
    cf_stacks: [cflinuxfs2]
  - name: ruby
    uri: https://a.org
    version: 4.3.2
    md5: 3a2
    cf_stacks: [cflinuxfs2]
    MANIFEST
    }

    it_behaves_like "general output that helps with the error is produced"

    it 'fails and errors stating the context' do
      output, status = run_packager_binary(buildpack_dir, flags)

      expect(output).to include("python had more " +
                           "than one 'default_versions' entry in the buildpack manifest.")
      expect(output).to include("ruby had more " +
                                  "than one 'default_versions' entry in the buildpack manifest.")
      expect(status).to_not be_success
    end
  end

  context 'no dependency with name found for default in manifest' do
    let(:manifest) {<<-MANIFEST
#{base_manifest_contents}
default_versions:
  - name: python
    version: 3.3.5
  - name: ruby
    version: 4.3.5
dependencies: []
    MANIFEST
    }

    it_behaves_like "general output that helps with the error is produced"

    it 'fails and errors stating the context' do
      output, status = run_packager_binary(buildpack_dir, flags)

      expect(output).to include("a 'default_versions' entry for python 3.3.5 was specified by the buildpack manifest, " +
                                  "but no 'dependencies' entry for python 3.3.5 was found in the buildpack manifest.")
      expect(output).to include("a 'default_versions' entry for ruby 4.3.5 was specified by the buildpack manifest, " +
                                  "but no 'dependencies' entry for ruby 4.3.5 was found in the buildpack manifest.")
      expect(status).to_not be_success
    end
  end

  context 'no dependency with version found for default in manifest' do
    let(:manifest) {<<-MANIFEST
#{base_manifest_contents}
default_versions:
  - name: ruby
    version: 1.1.1
  - name: python
    version: 3.3.5
dependencies:
  - name: ruby
    uri: https://a.org
    version: 9.9.9
    md5: 3a2
    cf_stacks: [cflinuxfs2]
  - name: python
    uri: https://a.org
    version: 9.9.9
    md5: 3a2
    cf_stacks: [cflinuxfs2]
    MANIFEST
    }

    it_behaves_like "general output that helps with the error is produced"

    it 'fails and errors stating the context' do
      output, status = run_packager_binary(buildpack_dir, flags)

      expect(output).to include("a 'default_versions' entry for python 3.3.5 was specified by the buildpack manifest, " +
                                  "but no 'dependencies' entry for python 3.3.5 was found in the buildpack manifest.")
      expect(output).to include("a 'default_versions' entry for ruby 1.1.1 was specified by the buildpack manifest, " +
                                  "but no 'dependencies' entry for ruby 1.1.1 was found in the buildpack manifest.")
      expect(status).to_not be_success
    end
  end
end
