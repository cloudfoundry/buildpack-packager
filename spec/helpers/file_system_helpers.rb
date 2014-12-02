require 'zip'

module FileSystemHelpers
  def make_fake_files(root, file_list)
    file_list.each do |file|
      full_path = File.join(root, file)
      `mkdir -p #{File.dirname(full_path)}`
      `echo 'a' > #{full_path}`
    end
  end

  def all_files(root)
    `tree -afi --noreport #{root}`.
        split("\n").
        map { |filename| filename.gsub(root, "").gsub(/^\//, "") }
  end

  def get_zip_contents(zip_path)
    Zip::File.open(zip_path) do |zip_file|
      zip_file.
          map { |entry| entry.name }.
          select { |name| name[/\/$/].nil? }
    end
  end
end
