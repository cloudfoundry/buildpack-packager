# BUILDPACK PACKAGER

The purpose of buildpack-packager is to cache system dependencies for partially or fully
disconnected environments.

Historically, this was called 'offline' mode.
It is now called 'Cached dependencies', although you see references to 'offline' and 'online'
as we continue to standardize.

Cached buildpacks are used in any environment where you prefer cached dependencies 
instead of reaching out to the internet while an app stages.

The list of what is cached is maintained in [the manifest](https://github.com/cloudfoundry-incubator/buildpack-packager#manifest).

Usage - Cloud Foundry Buildpacks
================================
If you are using an existing buildpack maintained by Cloud Foundry, 
please see the [disconnected environments documentation](doc/disconnected_environments.md)

Usage - Buildpack Developers
============================

1. Create a ```manifest.yml``` in the root of your buildpack.
  1. Read [the manifest](#manifest) documentation below on how to structure this file
1. Run the packager for online or offline mode

   ```buildpack-packager [offline|online]```

In either mode, the packager adds (almost) everything in your buildpack directory into a zip file.
It excludes anything marked for exclusion in your manifest.

In offline mode, the packager downloads and adds dependencies as described in the manifest.

### Loading dependencies, cached or uncached
To load the correct dependencies, use the 
[translate_dependency_url executable](https://github.com/cf-buildpacks/compile-extensions/blob/master/bin/translate_dependency_url).

Currently, we recommend submoduling the 
[buildpack compile extensions](https://github.com/cf-buildpacks/compile-extensions) into
your buildpack. See our [go buildpack](https://github.com/cloudfoundry/go-buildpack) for 
an example set up.

Manifest
========
The packager uses the ```manifest.yml``` file in the current working directory.  
Create this file in the root of your buildpack.

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
The language key gives your zip file a meaningful name.

url_to_dependency_map (required)
---------
A list of regular expressions that extract and map the values of `name` and `version` to a corresponding dependency. 

dependencies (required)
------------
The dependencies key specifies the name, version, and uri of a resource which the buildpack attempts 
to download during staging. By specifying them here, the packager downloads them and 
install them into the ```dependencies/``` folder in the zip file.

Rewrite your buildpack to use these 'cached' dependencies. We provide ```compile_extensions/bin/translate_dependency_url``` as a means to using dependencies in either cached or 
uncached buildpacks.

Learn more on the [compile-extensions repo](https://github.com/cf-buildpacks/compile-extensions/).

exclude_files (required)
-------------
The exclude key lists files you do not want in your buildpack. Use the exclude key to
remove sensitive information before uploading.
