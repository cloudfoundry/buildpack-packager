require 'active_support/core_ext/hash/indifferent_access'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'shellwords'
require 'terminal-table'

module Buildpack
  module Packager
    class Package < Struct.new(:options)
      def copy_buildpack_to_temp_dir(temp_dir)
        FileUtils.cp_r(File.join(options[:root_dir], '.'), temp_dir)
        FileUtils.cp(options[:manifest_path], File.join(temp_dir, 'manifest.yml'))
      end

      def build_dependencies(temp_dir)
        local_cache_directory = options[:cache_dir] || "#{ENV['HOME']}/.buildpack-packager/cache"
        FileUtils.mkdir_p(local_cache_directory)

        dependency_dir = File.join(temp_dir, "dependencies")
        FileUtils.mkdir_p(dependency_dir)

        download_dependencies(manifest[:dependencies], local_cache_directory, dependency_dir)
      end

      def download_dependencies(dependencies, local_cache_directory, dependency_dir)
        dependencies.each do |dependency|
          translated_filename = uri_cache_path(dependency['uri'])
          local_cached_file = File.expand_path(File.join(local_cache_directory, translated_filename))

          from_local_cache = true
          if options[:force_download] || !File.exist?(local_cached_file)
            download_file(dependency['uri'], local_cached_file)
            from_local_cache = false
          end

          ensure_correct_dependency_checksum({
            local_cached_file: local_cached_file,
            dependency: dependency,
            from_local_cache: from_local_cache
          })

          FileUtils.cp(local_cached_file, dependency_dir)
        end
      end

      def build_zip_file(temp_dir)
        FileUtils.rm_rf(zip_file_path)
        zip_files(temp_dir, zip_file_path, manifest[:exclude_files])
      end

      def list
        Terminal::Table.new do |table|
          manifest["dependencies"].each do |dependency|
            table.add_row [
              dependency["name"],
              sanitize_version_string(dependency["version"]),
              dependency["cf_stacks"].sort.join(",")
            ]
          end
          table.headings = ["name", "version", "cf_stacks"]
        end
      end

      private

      def uri_cache_path uri
        uri.gsub(/[:\/]/, '_')
      end

      def manifest
        @manifest ||= YAML.load_file(options[:manifest_path]).with_indifferent_access
      end

      def zip_file_path
        Shellwords.escape(File.join(options[:root_dir], zip_file_name))
      end

      def zip_file_name
        "#{manifest[:language]}_buildpack#{cached_identifier}-v#{buildpack_version}.zip"
      end

      def buildpack_version
        File.read("#{options[:root_dir]}/VERSION").chomp
      end

      def cached_identifier
        return '' unless options[:mode] == :cached
        '-cached'
      end

      def ensure_correct_dependency_checksum(local_cached_file:, dependency:, from_local_cache:)
        if dependency['md5'] != Digest::MD5.file(local_cached_file).hexdigest
          if from_local_cache
            FileUtils.rm_rf(local_cached_file)

            download_file(dependency['uri'], local_cached_file)
            ensure_correct_dependency_checksum({
              local_cached_file: local_cached_file,
              dependency: dependency,
              from_local_cache: false
            })
          else
            raise CheckSumError,
              "File: #{dependency['name']}, version: #{dependency['version']} downloaded at location #{dependency['uri']}\n\tis reporting a different checksum than the one specified in the manifest."
          end
        end
      end

      def download_file(url, file)
        `curl #{url} -o #{file} -L --fail -f`
      end

      def zip_files(source_dir, zip_file_path, excluded_files)
        exclude_list = excluded_files.map do |file|
          if file.chars.last == '/'
            "--exclude=#{file}* --exclude=*/#{file}*"
          else
            "--exclude=#{file} --exclude=*/#{file}"
          end
        end.join(' ')
        `cd #{source_dir} && zip -r #{zip_file_path} ./ #{exclude_list}`
      end

      def sanitize_version_string version
        version == 0 ? "-" : version
      end
    end
  end
end

