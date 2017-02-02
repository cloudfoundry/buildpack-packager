require 'active_support/core_ext/hash/indifferent_access'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'shellwords'
require 'buildpack/packager/zip_file_excluder'

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
          safe_uri = uri_without_credentials(dependency['uri'])
          translated_filename = uri_cache_path(safe_uri)
          local_cached_file = File.expand_path(File.join(local_cache_directory, translated_filename))

          if options[:force_download] || !File.exist?(local_cached_file)
	    puts "Downloading #{dependency['name']} version #{dependency['version']} from: #{safe_uri}"
            download_file(dependency['uri'], local_cached_file)
            human_readable_size = `du -h #{local_cached_file} | cut -f1`.strip
            puts "  Using #{dependency['name']} version #{dependency['version']} with size #{human_readable_size}"

            from_local_cache = false
          else
            human_readable_size = `du -h #{local_cached_file} | cut -f1`.strip
            puts "Using #{dependency['name']} version #{dependency['version']} from local cache at: #{local_cached_file} with size #{human_readable_size}"
            from_local_cache = true
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
        DependenciesPresenter.new(manifest['dependencies']).present
      end

      def defaults
        DefaultVersionsPresenter.new(manifest['default_versions']).present
      end

      def zip_file_path
        Shellwords.escape(File.join(options[:root_dir], zip_file_name))
      end

      def run_pre_package
        if manifest['pre_package'] && !Kernel.system(manifest['pre_package'])
          raise "Failed to run pre_package script: #{manifest['pre_package']}"
        end
      end

      private

      def uri_without_credentials(uri_string)
        uri = URI(uri_string)
        if uri.userinfo
          uri.user = "-redacted-" if uri.user
          uri.password = "-redacted-" if uri.password
        end
        uri.to_s.sub("file:", "file://")
      end

      def uri_cache_path uri
        uri.gsub(/[:\/\?&]/, '_')
      end

      def manifest
        @manifest ||= YAML.load_file(options[:manifest_path]).with_indifferent_access
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
        else
          puts "  #{dependency['name']} version #{dependency['version']} matches the manifest provided md5 checksum of #{dependency['md5']}\n\n"
        end
      end

      def download_file(url, file)
        raise "Failed to download file from #{url}" unless system("curl -s --retry 15 --retry-delay 2 #{url} -o #{file} -L --fail -f")
      end

      def zip_files(source_dir, zip_file_path, excluded_files)
        excluder = ZipFileExcluder.new
        manifest_exclusions = excluder.generate_manifest_exclusions excluded_files
        gitfile_exclusions = excluder.generate_exclusions_from_git_files source_dir
        all_exclusions = manifest_exclusions + ' ' + gitfile_exclusions
        `cd #{source_dir} && zip -r #{zip_file_path} ./ #{all_exclusions}`
      end
    end
  end
end

