module Buildpack
  module Packager
    class ZipFileExcluder
      def generate_manifest_exclusions(excluded_files)
        generate_exclusion_string excluded_files
      end

      def generate_exclusions_from_git_files(dir)
        Dir.chdir dir do
          git_files = Dir.glob('**/.git*').map do |elt|
            File.directory?(elt) ? "#{elt}/" : elt
          end

          generate_exclusion_string git_files
        end
      end

      private

      def generate_exclusion_string(file_list)
        file_list.map do |file|
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
