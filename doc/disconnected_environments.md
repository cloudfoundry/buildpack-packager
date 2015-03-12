# Disconnected environments

### Deploying Apps on disconnected environments
Cached buildpacks only ensure that a the buildpacks dependencies are cached, not your applications.

When you work with a disconnected environment, it's important to use your package manager
to 'vendor' your applications dependencies.

The specific mechanism varies between platforms. See your buildpack's documentation for 'vendoring' advice.

## Building a cached buildpack
1. Make sure you have fetched submodules

  ```shell
  git submodule update --init
  ```

1. Get the latest buildpack dependencies

  ```shell
  BUNDLE_GEMFILE=cf.Gemfile bundle
  ```

1. Build the buildpack

  ```shell
  BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager [ uncached | cached ]
  ```
  
  This produces a buildpack for use on Cloud Foundry.
  
  'cached' generates a zip with all the dependencies cached.
  
  'uncached' does not include the dependencies, however it excludes some files as specified 
  in manifest.yml. 

1. Use in Cloud Foundry

  Currently, you can only specify cached buildpacks by creating Cloud Foundry Admin Buildpacks.
  
  This means you need admin rights. See the 
  [Open source admin documentation](http://docs.cloudfoundry.org/adminguide/buildpacks.html)
  for more information.
  
  Upload the buildpack to your Cloud Foundry and specify it by name:

  ```shell
  cf create-buildpack custom_ruby_buildpack ruby_buildpack-cached-custom.zip 1
  ```

