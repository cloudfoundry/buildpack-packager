require 'spec_helper'

# Special note
# =============
#
# There are two uses of the term 'caching' in buildpack packager.
# 1. A 'cached' buildpack is a buildpack zipball that contains the buildpacks dependencies
# 2. 'Download caching' is where the packager keeps a copy of downloaded dependencies for
#    the next time it is run.
#
# This integration test is concerned with 'Download caching'

describe 'reusing previously downloaded files' do
  let(:upstream_file_path) do
    create_upstream_file('sample_download.ignore_me',
                         'sample_download original text')
  end

  let(:upstream_file_uri) { "file://#{upstream_file_path}" }

  let(:buildpack_dir) { Dir.mktmpdir('buildpack_') }

  let(:md5) { get_md5_of_file(upstream_file_path) }
  let(:manifest) do
    {
      'exclude_files' => [],
      'language' => 'sample',
      'url_to_dependency_map' => [],
      'dependencies' => [{
        'version' => '1.0',
        'name' => 'sample_download.ignore_me',
        'cf_stacks' => [],
        'md5' => md5,
        'uri' => upstream_file_uri
      }]
    }
  end

  before do
    File.write(File.join(buildpack_dir, 'manifest.yml'), manifest.to_yaml)

    `echo "1.2.3" > #{File.join(buildpack_dir, 'VERSION')}`
  end

  context 'the file is not in the cache' do
    specify 'the file should be kept in a cache when it is downloaded' do
      _, status = run_packager_binary(buildpack_dir, '--cached')

      expect(status).to be_success
      expect(File).to exist(uri_to_cache_path(upstream_file_uri))

      expect(File.read(uri_to_cache_path(upstream_file_uri))).to include('sample_download original text')
    end
  end

  context 'the file has been downloaded before' do
    specify 'the file in the cache should be used instead of downloading' do
      run_packager_binary(buildpack_dir, '--cached')

      remove_upstream_file('sample_download.ignore_me') # taking this away means packager must use the cache

      _, status = run_packager_binary(buildpack_dir, '--cached')

      expect(status).to be_success
    end

    context 'however the file has changed, and the manifest is updated to reflect the new md5' do
      before do
        run_packager_binary(buildpack_dir, '--cached')

        create_upstream_file('sample_download.ignore_me', 'sample_download updated text')
        new_md5 = get_md5_of_file(upstream_file_path)
        manifest['dependencies'].first['md5'] = new_md5
        File.write(File.join(buildpack_dir, 'manifest.yml'), manifest.to_yaml)
      end

      specify 'the cache should now contain the new upstream file' do
        output, status = run_packager_binary(buildpack_dir, '--cached')

        expect(status).to be_success
        expect(File.read(uri_to_cache_path(upstream_file_uri))).to include('sample_download updated text')
      end
    end
  end
end
