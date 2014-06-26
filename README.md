BUILDPACK PACKAGER

Bash library to package up buildpack source and included dependencies

Dependencies will be downloaded and zipped if the mode is offline
Excluded files will not be zipped
Version will be gotten from $BIN_PATH/version
Expects BIN_PATH to be buildpack_packager_root/../bin

Usage:

```bash
language='squeak'

dependencies=(
  'http://ftp.squeak.org/4.5/Squeak-4.5-All-in-One.zip'
)

excluded_files=(
  '.git/'
  '.gitignore'
)

source buildpack-packager/lib/packager
package_buildpack online

```