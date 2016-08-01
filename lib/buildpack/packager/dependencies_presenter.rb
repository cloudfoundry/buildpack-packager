require 'terminal-table'

module Buildpack
  module Packager
    class DependenciesPresenter < Struct.new(:dependencies)
      include TablePresentation

      def inspect
        has_modules = dependencies.any? { |dependency| dependency['modules'] }

        table = Terminal::Table.new do |table|
          dependencies.sort_by do |dependency|
            sort_string_for dependency
          end.each do |dependency|
            columns = [
              dependency['name'],
              sanitize_version_string(dependency['version']),
              dependency['cf_stacks'].sort.join(',')
            ]
            if has_modules
              columns += [dependency.fetch('modules', []).sort.join(', ')]
            end
            table.add_row columns
          end
        end

        table.headings = if has_modules
                           %w(name version cf_stacks modules)
                         else
                           %w(name version cf_stacks)
                         end

        table.to_s
      end

      def present
        to_markdown(inspect)
      end
    end
  end
end
