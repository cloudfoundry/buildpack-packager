# BUILDPACK PACKAGER

Simple tool to package a buildpack to upload to Cloud Foundry.

Usage - Buildpack Developers
============================

This documentation is for developers who are adding cached dependencies to their buildpack. If you are using
an existing buildpack maintained by Cloud Foundry, please see [Cloud Foundry buildpack usage](doc/cloud_foundry_buildpack_usage.md)

1. Create a ```manifest.yml``` in the root of your buildpack.
  1. Read [the manifest](#manifest) documentation below on how to structure this file
1. Run the packager for online or offline mode
```buildpack-packager [offline|online]

In either mode, the packager will add (almost) everything in your buildpack directory into a zip file.
It will exclude anything marked for exclusion in your manifest.

In offline mode, the packager will download and add dependencies as described in the manifest.

Manifest
========

The packager looks for a ```manifest.yml``` file in the current working directory, which should be the root of your
 buildpack.

A sample manifest (all keys are required):

```yaml
---
language: go

url_to_dependency_map:
- match: go(\d+\.\d+(\.\d+)?)
  name: go
  version: $1

dependencies:
  - name: go
    version: 1.1.1
    uri: http://go.googlecode.com/files/go1.1.1.linux-amd64.tar.gz
  - name: go
    version: 1.1.2
    uri: http://go.googlecode.com/files/go1.1.2.linux-amd64.tar.gz

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
The dependencies key specifies the name, version, and uri of a resource which the buildpack attempts to download during staging. By specifying them here,
the packager can download them and install them into the ```dependencies/``` folder in the zip file.

To have your buildpack use these 'cached' dependencies, use ```compile_extensions/bin/translate_dependency_url``` to translate the url into a locally cached url (useful for offline mode).
Read more on the [compile-extensions repo](https://github.com/cf-buildpacks/compile-extensions/).

exclude_files (required)
-------------
The exclude key lists files you do not want in your buildpack. This is useful to remove sensitive information before uploading.
