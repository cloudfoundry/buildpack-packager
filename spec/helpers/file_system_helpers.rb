require 'zip'
require 'fileutils'

module FileSystemHelpers
  def run_packager_binary(buildpack_dir, flags)
    packager_binary_file = File.join(`pwd`.chomp, 'bin', 'buildpack-packager')
    Open3.capture2e("cd #{buildpack_dir} && #{packager_binary_file} #{flags}")
  end

  def make_fake_files(root, file_list)
    file_list.each do |file|
      full_path = File.join(root, file)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, 'a')
    end
  end

  def all_files(root)
    Dir["#{root}/*"].map do |filename|
      filename.gsub(root, '').gsub(/^\//, '')
    end
  end

  def get_zip_contents(zip_path)
    Zip::File.open(zip_path) do |zip_file|
      zip_file
        .map(&:name)
        .select { |name| name[/\/$/].nil? }
    end
  end

  def get_md5_of_file(path)
    Digest::MD5.file(path).hexdigest
  end
end
