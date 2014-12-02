BUILDPACK PACKAGER

Simple tool to package a buildpack to upload to Cloud Foundry.

Usage
=====

1. Create a ```manifest.yml``` in your buildpack
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
language: awesomelang
dependencies:
- http://example.com/path/to/dependency
- http://example.com/path/to/another_dependency
exclude_files:
- .gitignore
- private.key
```

language (required)
--------
The language key is used to give your zip file a meaningful name.

dependencies (required)
------------
The dependencies key specifies the urls which the buildpack attempts to download during staging. By specifying them here,
the packager can download them and install them into the ```dependencies/``` folder in the zip file.

To have your buildpack use these 'cached' dependencies, use ```compile_extensions/bin/translate_dependency_url``` to
 trick curl into loading the file. Read more on the [compile-extensions repo](https://github.com/cf-buildpacks/compile-extensions/).

exclude_files (required)
-------------
The exclude key lists files you do not want in your buildpack. This is useful to remove sensitive information before uploading.
