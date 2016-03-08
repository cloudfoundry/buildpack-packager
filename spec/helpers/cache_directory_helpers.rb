module CacheDirectoryHelpers
  BUILDPACK_PACKAGER_CACHE_DIR = File.join(ENV['HOME'], '.buildpack-packager', 'cache')

  def uri_to_cache_filename(uri)
    uri.gsub(/[\/:]/, '_')
  end

  def uri_to_cache_path(uri)
    File.join(BUILDPACK_PACKAGER_CACHE_DIR, uri_to_cache_filename(uri))
  end

  def remove_from_cache_dir(uri)
    FileUtils.rm_f(uri_to_cache_path(uri))
  end
end
