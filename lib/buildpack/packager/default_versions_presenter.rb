require 'terminal-table'

module Buildpack
  module Packager
    class DefaultVersionsPresenter < Struct.new(:default_versions)
      include TablePresentation

      attr_reader :default_versions

      def initialize(default_versions)
        default_versions = [] if default_versions.nil?
        @default_versions = default_versions
      end

      def inspect
        table = Terminal::Table.new do |table|
          default_versions.sort_by do |dependency|
            sort_string_for dependency
          end.each do |dependency|
            columns = [
              dependency['name'],
              sanitize_version_string(dependency['version'])
            ]
            table.add_row columns
          end
        end

        table.headings = %w(name version)

        table.to_s
      end

      def present
        to_markdown(inspect)
      end
    end
  end
end
