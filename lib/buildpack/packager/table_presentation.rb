require 'terminal-table'

module Buildpack
  module Packager
    module TablePresentation
      def to_markdown(table_contents)
        table_contents.split("\n")[1...-1].tap { |lines| lines[1].tr!('+', '|') }.join("\n")
      end

      def sanitize_version_string(version)
        version == 0 ? '-' : version
      end

      def sort_string_for(dependency)
        interpreter_names = %w(ruby jruby php hhvm python go node)
        sort_index = interpreter_names.index(dependency['name']) || 9999
        sprintf '%s-%s-%s', sort_index, dependency['name'], dependency['version']
      end
    end
  end
end
