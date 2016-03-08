module FakeBinaryHostingHelpers
  def upstream_host_dir
    @upstream_host_dir ||= Dir.mktmpdir('upstream_host_')
  end

  def create_upstream_file(file_name, file_content)
    file_path = generate_upstream_file_path(file_name)
    File.write(file_path, file_content)
    file_path
  end

  def remove_upstream_file(file_name)
    FileUtils.rm_f(generate_upstream_file_path(file_name))
  end

  private

  def generate_upstream_file_path(file_name)
    File.join(upstream_host_dir, file_name)
  end
end
