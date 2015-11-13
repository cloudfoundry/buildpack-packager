module Buildpack
  module Packager
    class ZipFileExcluder
      def generate_exclude_file_list excluded_files
        excluded_files.map do |file|
          if file.chars.last == '/'
            "-x #{file}\\* -x \\*/#{file}\\*"
          else
            "-x #{file} -x \\*/#{file}"
          end
        end.join(' ')
      end
    end
  end
end
