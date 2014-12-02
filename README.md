BUILDPACK PACKAGER

Bash library to package up buildpack source and included dependencies

Dependencies will be downloaded and zipped if the mode is offline
Excluded files will not be zipped
Version will be gotten from $BIN_PATH/version

Usage:

Add buildpack_packager as a submodule of your buildpack

```
git submodule add https://github.com/cf-buildpacks/buildpack-packager
```

Create a script in your buildpack called 'bin/package' and include the following in it:

```bash
language='squeak'

dependencies=(
  'http://ftp.squeak.org/4.5/Squeak-4.5-All-in-One.zip'
)

excluded_files=(
  '.git/'
  '.gitignore'
)

oifs=$IFS
IFS=','
$BIN/../buildpack-packager/bin/buildpack-packager $language "${dependencies[*]}" "${excluded_files[*]}" $1
IFS=$oifs
```

run the packager:

```
./bin/package [online|offline]
```
