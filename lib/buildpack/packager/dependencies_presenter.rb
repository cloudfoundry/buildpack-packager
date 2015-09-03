require 'terminal-table'

module Buildpack
  module Packager
    class DependenciesPresenter < Struct.new(:dependencies)
      def inspect
        has_modules = dependencies.any? { |dependency| dependency["modules"] }

        table = Terminal::Table.new do |table|
          dependencies.sort_by do |dependency|
            sort_string_for dependency
          end.each do |dependency|
            columns = [
              dependency["name"],
              sanitize_version_string(dependency["version"]),
              dependency["cf_stacks"].sort.join(","),
            ]
            if has_modules
              columns += [ dependency.fetch("modules", []).sort.join(", ") ]
            end
            table.add_row columns
          end
        end

        if has_modules
          table.headings = ["name", "version", "cf_stacks", "modules"]
        else
          table.headings = ["name", "version", "cf_stacks"]
        end

        table.to_s
      end

      def to_markdown
        inspect.split("\n")[1...-1].tap { |lines| lines[1].gsub!('+', '|') }.join("\n")
      end

      private

      def sanitize_version_string version
        version == 0 ? "-" : version
      end

      def sort_string_for dependency
        interpreter_names = %w[ruby jruby php hhvm python go node]
        sort_index = interpreter_names.index(dependency["name"]) || 9999
        sprintf "%s-%s-%s", sort_index, dependency["name"], dependency["version"]
      end
    end
  end
end

