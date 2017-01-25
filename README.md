# Buildpack Packager

A [RubyGem](https://rubygems.org/) that provides tooling to package a buildpack for upload to Cloud Foundry.

For officially supported Cloud Foundry buildpacks, it is used in conjunction with [compile-extensions](https://github.com/cloudfoundry-incubator/compile-extensions).


# Usage

## Packaging a Buildpack

Within your buildpack directory:

1. Create a `Gemfile` and the line `gem 'buildpack-packager', git: 'https://github.com/cloudfoundry-incubator/buildpack-packager'`.
1. Run `bundle install`.
1. Create a `manifest.yml`
1. Run the packager for uncached or cached mode:

	```
	buildpack-packager [cached|uncached]
	```

In either mode, the packager will add (almost) everything in your
buildpack directory into a zip file.  It will exclude anything marked
for exclusion in your manifest.

In `cached` mode, the packager will download and add dependencies as
described in the manifest.


## Examining a manifest

If you'd like to get a pretty-printed summary of what's in a manifest,
run in `list` mode:

```
buildpack-packager list
```

Example output:

```
+----------------------------+------------------------------+------------+
| name                       | version                      | cf_stacks  |
+----------------------------+------------------------------+------------+
| ruby                       | 2.0.0                        | cflinuxfs2 |
| ruby                       | 2.1.5                        | cflinuxfs2 |
| ruby                       | 2.1.6                        | cflinuxfs2 |
| ruby                       | 2.2.1                        | cflinuxfs2 |
| ruby                       | 2.2.2                        | cflinuxfs2 |
| jruby                      | ruby-1.9.3-jruby-1.7.19      | cflinuxfs2 |
| jruby                      | ruby-2.0.0-jruby-1.7.19      | cflinuxfs2 |
| jruby                      | ruby-2.2.2-jruby-9.0.0.0.rc1 | cflinuxfs2 |
| node                       | 0.12.2                       | cflinuxfs2 |
| bundler                    | 1.9.7                        | cflinuxfs2 |
| libyaml                    | 0.1.6                        | cflinuxfs2 |
| openjdk1.8-latest          | -                            | cflinuxfs2 |
| rails3_serve_static_assets | -                            | cflinuxfs2 |
| rails_log_stdout           | -                            | cflinuxfs2 |
+----------------------------+------------------------------+------------+
```

### Option Flags

#### --force-download

By default, `buildpack-packager` stores the dependencies that it
downloads while building a cached buildpack in a local cache at
`~/.buildpack-packager`. This is in order to avoid redownloading them
when repackaging similar buildpacks. Running `buildpack-packager
cached` with the `--force-download` option will force the packager
to download dependencies from the s3 host and ignore the local cache.

#### --use-custom-manifest

If you would like to include a different manifest file in your
packaged buildpack, you may call `buildpack-packager` with the
`--use-custom-manifest [path/to/manifest.yml]`
option. `buildpack-packager` will generate a buildpack with the
specified manifest. If you are building a cached buildpack,
`buildpack-packager` will vendor dependencies from the specified
manifest as well.


# Manifest

The packager looks for a `manifest.yml` file in the current working
directory, which should be the root of your buildpack.

A sample manifest (all keys (excepting dependency_deprecation_dates) are required):

```yaml
---
language: ruby

url_to_dependency_map:
- match: bundler-(\d+\.\d+\.\d+)
  name: bundler
  version: $1
- match: ruby-(\d+\.\d+\.\d+)
  name: ruby
  version: $1

dependencies:
  - name: bundler
    version: 1.7.12
    uri: https://pivotal-buildpacks.s3.amazonaws.com/ruby/binaries/lucid64/bundler-1.7.12.tgz
    md5: ab7ebd9c9e945e3ea91c8dd0c6aa3562
    cf_stacks:
      - lucid64
      - cflinuxfs2
  - name: ruby
    version: 2.1.4
    uri: https://pivotal-buildpacks.s3.amazonaws.com/ruby/binaries/lucid64/ruby-2.1.4.tgz
    md5: 72b4d193a11766e2a4c45c1fed65754c
    cf_stacks:
      - lucid64

dependency_deprecation_dates:
- match: 2.1.\\d
  version_line: 2.1
  name: ruby
  date: 2016-03-30

exclude_files:
  - .gitignore
  - private.key
```

## language (required)

The language key is used to give your zip file a meaningful name.


## url_to_dependency_map (required)

A list of regular expressions that extract and map the values of `name` and `version` to a corresponding dependency. 


## dependencies (required)


The dependencies key specifies the name, version, uri, md5, and the
cf_stacks (the root file system(s) for which it is compiled for) of a
resource which the buildpack attempts to download during staging. By
specifying them here, the packager can download them and install them
into the `dependencies/` folder in the zip file.

All keys are required:

- `name`, `version`, and `uri`:
Required for `url_to_dependency_map` to work. Make sure to create a new entry in the `url_to_dependency_map` if a matching regex does not exist for the dependency to be curled.

- `md5`:
Required to ensure that dependencies being packaged for 'cached' mode have not been compromised

- `cf_stacks`:
Required to ensure the right binary is selected for the root file system in which an app will be running on.  Currently supported root file systems are lucid64(default) and cflinuxfs2. *Note that if the same dependency is used for both root file systems, both can be listed under the `cf_stacks` key.*

To have your buildpack use these 'cached' dependencies, use
`compile_extensions/bin/translate_dependency_url` to translate the url
into a locally cached url (useful for cached mode).

Read more on the [compile-extensions repo](https://github.com/cloudfoundry-incubator/compile-extensions).


## dependency_deprecation_dates (optional)


The dependency_deprecation_dates specifies the date at which dependencies
will be end of life (and thus removed from the buildpack). By specifying
EOL here, buildpack maintainers can set a date which will trigger warnings
for users 30 days before the EOL date is reached.

All keys are required:

- `name`, `match`:
Required for `dependency_deprecation_dates` to work. Dependencies are matched to the
name and a regexp of `match` and the dependency version

- `date`, `version_line`:
Required to generate the warning message for users, eg:
`WARNING: Ruby 2.1 will no longer be available in new buildpacks released after 2016-03-30`

## exclude_files (required)

The exclude key lists files you do not want in your buildpack. This is
useful to remove sensitive information or extraneous files before uploading.

# Development

## Propagating Packager Changes to CF Buildpacks

Latest changes to master will not be automatically reflected in the various Cloud Foundry buildpacks.
To propagate buildpack-packager changes:

1. Update the version in `lib/buildpack/packager/version.rb`.
2. Commit this change and push to master.
3. Tag the new version with a release tag (e.g., `git tag v2.2.6`).
4. Push the tag to origin with `git push --tags`.
5. Update the `cf.Gemfile`s in the various buildpacks with the new release tag like so:
```
gem 'buildpack-packager', git: 'https://github.com/cloudfoundry/buildpack-packager', tag: 'v2.2.6'
```
