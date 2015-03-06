BUILDPACK PACKAGER

Simple tool to package a buildpack to upload to Cloud Foundry.

Usage
=====

1. Create a `manifest.yml` in your buildpack
1. Run the packager for online or offline mode
`buildpack-packager [offline|online]`

In either mode, the packager will add (almost) everything in your buildpack directory into a zip file.
It will exclude anything marked for exclusion in your manifest.

In offline mode, the packager will download and add dependencies as described in the manifest.

Manifest
========

The packager looks for a `manifest.yml` file in the current working directory, which should be the root of your
 buildpack.

A sample manifest (all keys are required):

```
yaml
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
      
exclude_files:
  - .gitignore
  - private.key
```

language (required)
--------
The language key is used to give your zip file a meaningful name.

url_to_dependency_map (required)
---------
A list of regular expressions that extract and map the values of `name` and `version` to a corresponding dependency. 

dependencies (required)
------------
The dependencies key specifies the name, version, uri, md5, and the cf_stacks (the root file system(s) for which it is compiled for) of a resource which the buildpack attempts to download during staging. By specifying them here, the packager can download them and install them into the `dependencies/` folder in the zip file.

All keys are required:

- `name`, `version`, and `uri`: Required for `url_to_dependency_map` to work. Make sure to create a new entry in the `url_to_dependency_map` if a matching regex does not exist for the dependency to be curled.
- `md5`: Required to ensure that dependencies being packaged for 'offline' mode have not been compromised
- `cf_stacks`: Required to ensure the right binary is selected for the root file system in which an app will be running on.  Currently supported root file systems are lucid64(default) and cflinuxfs2. *Note that if the same dependency is
used for both root file systems, both can be listed under the `cf_stacks` key.*

To have your buildpack use these 'cached' dependencies, use `compile_extensions/bin/translate_dependency_url` to translate the url into a locally cached url (useful for offline mode).
Read more on the [compile-extensions repo](https://github.com/cf-buildpacks/compile-extensions/).

exclude_files (required)
-------------
The exclude key lists files you do not want in your buildpack. This is useful to remove sensitive information before uploading.

