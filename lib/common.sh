#!/bin/bash
#
# common.sh: common functions for simplepkg
# feedback: rhatto at riseup.net
#
#  common.sh is free software; you can redistribute it and/or modify it under the
#  terms of the GNU General Public License as published by the Free Software
#  Foundation; either version 2 of the License, or any later version.
#
#  common.sh is distributed in the hope that it will be useful, but WITHOUT ANY
#  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
#  A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along with
#  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
#  Place - Suite 330, Boston, MA 02111-1307, USA
#
# $Rev$ - $Author$
#

BASE_CONF="/etc/simplepkg"
CONF="$BASE_CONF/simplepkg.conf"
HOME_CONF="$HOME/.simplepkg/simplepkg.conf"
DEFAULT_CONF="$BASE_CONF/defaults/simplepkg.conf"
JAIL_LIST="$BASE_CONF/jailist"
SIMPLARET="simplaret"

# -----------------------------------------------
#               pkgtool functions
# -----------------------------------------------

function pkg_ext {

  # list all possible package extensions
  local ext exts

  for ext in tgz tbz tlz txz; do
    if [ ! -z "$1" ]; then
      exts="$exts $1.$ext"
    else
      exts="$exts $ext"
    fi
  done

  echo $exts

}

function pkg_ext_grep {

  # list all possible package extensions
  # grep extended regexp version

  echo "($(pkg_ext $1))" | sed -e 's/ /|/g'

}

function pkg_ext_sed {

  # list all possible package extensions
  # sed regexp version

  echo "\($(pkg_ext $1)\)" | sed -e 's/ /\\|/g'

}

function pkg_ext_find {

  # list all possible package extensions
  # find expr version

  local match exts

  if [ ! -z "$1" ]; then
    match="$1"
  else
    match="'*'"
  fi

  exts="`echo "$(pkg_ext $match)" | sed -e 's/ / -or -name /g'`"
  echo "\( -name $exts \)"

}

function strip_basename {

  file="$1"
  shift
  for ext in $*; do
    file="`basename $file .$ext`"
  done
  echo $file

}

function strip_pkg_ext {

  strip_basename $1 `pkg_ext`

}

function package_name {

  # get the package name
  # in some places (like in /var/log/packages), the package name is appended with
  # an -upgraded information that should be striped
  strip_pkg_ext $1 | \
  sed -e 's/-upgraded-[0-9]*-[0-9]*-[0-9]*,[0-9]*:[0-9]*:[0-9]*$//' \
      -e 's/-[^-]*-[^-]*-[^-]*$//'

}

# -----------------------------------------------
#             package info functions
# -----------------------------------------------

function package_version {

  # get VERSION from a package name
  local file pack version
  file="`basename $1`"
  pack="`package_name $1`"
  echo $file | sed -e "s/^$pack-//" | cut -d "-" -f 1

}

function package_arch {

  # get ARCH from a package name
  local file pack arch
  basename $1 | sed -e "s/.*\-\(.*\)\-.*.$(pkg_ext_sed)$/\1/" -e 's/_slamd64$//g' -e 's/_sflack$//g'

}

function package_build {

  # get BUILD from a package name
  local file pack build
  basename $1 | sed -e "s/.*\-.*\-\(.*\).$(pkg_ext_sed)$/\1/"

}

function package_ext {

  # get EXT from a package name
  echo $1 | sed -e "s/.*$(pkg_ext_sed)$/\1/"

}

# -----------------------------------------------
#       package administrative functions
# -----------------------------------------------

function install_packages {

  local check installed unable_to_install root

  # check if is time to clean the local repository
  if [ "$SIMPLARET_CLEAN"  == "1" ]; then
    ARCH=$ARCH VERSION=$VERSION $SIMPLARET --purge
  elif [ ! -z "$SIMPLARET_PURGE_WEEKS" ] && [ "$SIMPLARET_PURGE_WEEKS" != "0" ]; then
    ARCH=$ARCH VERSION=$VERSION $SIMPLARET --purge -w $SIMPLARET_PURGE_WEEKS
  fi

  root="$JAIL_ROOT/$server"
  mkdir -p $root/var/log/packages

  # now tries to install each package listed in the template
  for pack in `cat $TEMPLATE | grep -v -e "^#" | cut -d : -f 1 | awk '{ print $1 }'`; do

    # try to install the package
    ROOT=/$root ARCH=$ARCH VERSION=$VERSION $SIMPLARET --install $pack --skip-checks

    # check if the package was installed
    pack="`echo $pack | sed -e 's/\+/\\\+/'`"
    installed="`check_installed $pack $root`"
    check=$?

    if [ ! -z "$installed" ] && [ "$check" == "0" ]; then
      # the package is installed
      if [ ! -z "$SIMPLARET_DELETE_DURING" ] && [ "$SIMPLARET_DELETE_DURING" != "0" ]; then
        SILENT=1 ARCH=$ARCH VERSION=$VERSION $SIMPLARET --purge
      fi
    else
      unable_to_install="$unable_to_install\n\t`echo $pack | sed -e 's/\\\+/\+/'`"
    fi

  done

  # purge packages, if needed
  if [ "$SIMPLARET_DELETE_DOWN" == "1" ]; then
    ARCH=$ARCH VERSION=$VERSION $SIMPLARET --purge
  fi

  if [ ! -z "$unable_to_install" ]; then
    echo "mkjail was unable to install the following packages on $root:"
    echo -e "$unable_to_install"
  fi

}

function remove_packages {

  local pack

  for pack in `cat $TEMPLATE | grep -v -e "^#" | cut -d : -f 1`; do
    ROOT=/$JAIL_ROOT/$server removepkg $pack
  done

}

# -----------------------------------------------
#             config file functions
# -----------------------------------------------

function eval_parameter {

  # usage: eval $1 parameter from $HOME_CONF, $CONF or $DEFAULT_CONF
  # return the evaluated parameter if available or $2 $3 ... $n

  if [ -e "$HOME_CONF" ] && grep -qe "^$1=" $HOME_CONF; then
    grep -e "^$1=" $HOME_CONF | tail -n 1 | cut -d = -f 2 | sed -e 's/"//g' -e "s/'//g" | sed -e 's/ *#.*$//'
  elif [ -e "$CONF" ] && grep -qe "^$1=" $CONF; then
    grep -e "^$1=" $CONF | tail -n 1 | cut -d = -f 2 | sed -e 's/"//g' -e "s/'//g" | sed -e 's/ *#.*$//'
  elif [ -e "$DEFAULT_CONF" ] && grep -qe "^$1=" $DEFAULT_CONF; then
    grep -e "^$1=" $DEFAULT_CONF | tail -n 1 | cut -d = -f 2 | sed -e 's/"//g' -e "s/'//g" | sed -e 's/ *#.*$//'
  else
    shift
    echo $*
  fi

}

function set_constants {

  # Set common constants
  # on/off
  on=1
  off=0
  # yes/no
  yes=1
  no=0

}

function eval_boolean_parameter {

  # get a boolean parameter from the configuration

  local value

  # get the value
  value="`eval_parameter $1 $2`"

  convert_boolean $value

}

function convert_boolean {

  # force case insensitiveness
  local value="`echo $1 | tr '[:upper:]' '[:lower:]'`"

  # convert it to wheter 0 or 1
  if [ "$value" == "yes" ] || [ "$value" == "1" ] || [ "$value" == "on" ]; then
    echo 1
  else
    echo 0
  fi

}

function eval_config {

  # simplepkg config file evaluation
  # usage: eval_config <program-name> [-u]

  if [ -f "$DEFAULT_CONF" ]; then

    DEFAULT_ARCH="`eval_parameter DEFAULT_ARCH $(default_arch)`"
    DEFAULT_VERSION="`eval_parameter DEFAULT_VERSION $(default_version)`"

    TMP="`eval_parameter TMP /tmp`"
    TMP_USER="`eval_parameter TMP_USER`"
    TMP_GROUP="`eval_parameter TMP_GROUP`"
    STORAGE="`eval_parameter STORAGE /var/simplaret/packages`"
    JAIL_ROOT="`eval_parameter JAIL_ROOT /vservers`"
    PATCHES_DIR="`eval_parameter PATCHES_DIR /var/simplaret/patches`"
    ROOT_PRIORITY="`eval_parameter ROOT_PRIORITY patches slackware extra testing pasture`"
    REPOS_PRIORITY="`eval_parameter REPOS_PRIORITY patches slackware extra testing pasture`"
    SIMPLARET_PURGE_WEEKS="`eval_parameter SIMPLARET_PURGE_WEEKS 0`"
    FTP_TOOL="`eval_parameter FTP_TOOL curl`"
    HTTP_TOOL="`eval_parameter HTTP_TOOL curl`"
    CONNECT_TIMEOUT="`eval_parameter CONNECT_TIMEOUT 0`"
    TEMPLATE_FOLDER="`eval_parameter TEMPLATE_BASE /etc/simplepkg/templates`"
    TEMPLATE_STORAGE_STYLE="`eval_parameter TEMPLATE_STORAGE_STYLE compact`"

    SIMPLARET_CLEAN="`eval_boolean_parameter SIMPLARET_CLEAN 1`"
    SIMPLARET_DELETE_DOWN="`eval_boolean_parameter SIMPLARET_DELETE_DOWN 1`"
    SIMPLARET_UPDATE="`eval_boolean_parameter SIMPLARET_UPDATE 0`"
    SIMPLARET_DELETE_DURING="`eval_boolean_parameter SIMPLARET_DELETE_DURING 0`"
    SIMPLARET_PURGE_PATCHES="`eval_boolean_parameter SIMPLARET_PURGE_PATCHES 1`"
    SIMPLARET_DOWNLOAD_FROM_NEXT_REPO="`eval_boolean_parameter SIMPLARET_DOWNLOAD_FROM_NEXT_REPO 1`"
    PASSIVE_FTP="`eval_boolean_parameter PASSIVE_FTP 0`"
    WARNING="`eval_boolean_parameter WARNING 0`"
    SIGNATURE_CHECKING="`eval_boolean_parameter SIGNATURE_CHECKING 0`"
    DEPENDENCY_CHECKING="`eval_boolean_parameter DEPENDENCY_CHECKING 1`"
    TEMPLATES_UNDER_SVN="`eval_boolean_parameter TEMPLATES_UNDER_SVN 0`"
    ADD_TO_JAIL_LIST="`eval_boolean_parameter ADD_TO_JAIL_LIST 1`"

    # Enabling this option (i.e, setting to "1" or "yes"), simplaret will
    # donwload even # already applied patches, a good option when you plan
    # to keep local copies of all needed patches for your system
    DOWNLOAD_EVEN_APPLIED_PATCHES="`eval_boolean_parameter DOWNLOAD_EVEN_APPLIED_PATCHES 0`"

    # Enabling this option, jail-upgrade will look at your
    # standard repositories for new packages; if it find a package
    # with different version of your current installed package and
    # also this package isnt in the packages folder, then the new
    # package is apllied; if in doubt, just say no or leave blank.
    CONSIDER_ALL_PACKAGES_AS_PATCHES="`eval_boolean_parameter CONSIDER_ALL_PACKAGES_AS_PATCHES 0`"

    # Enabling this option (i.e, setting to "1" or "yes"), simplaret will
    # store patches it finds on ROOT repositories on
    #
    #   $PATCHES_DIR/$ARCH/$VERSION/root-$repository_name.
    #
    # By default this option is turned off because it breaks the standard
    # way to store packages and can cause some confusion, but its an useful
    # feature if you like to see all patches apart from common packages and/or
    # stored in the same tree.
    STORE_ROOT_PATCHES_ON_PATCHES_DIR="`eval_boolean_parameter STORE_ROOT_PATCHES_ON_PATCHES_DIR 0`"

    # now we place "patches" on the top of ROOT_PRIORITY
    ROOT_PRIORITY="patches `echo $ROOT_PRIORITY | sed -e 's/patches//'`"

  else
    echo $1 error: config file $DEFAULT_CONF not found
    exit 1
  fi

  if [ ! -d "$STORAGE" ]; then
    mkdir -p $STORAGE
  fi

  if [ ! -d "$PATCHES_DIR" ]; then
    mkdir -p $PATCHES_DIR
  fi

  if [ ! -d "$TMP" ]; then
    mkdir -p $TMP
  fi

  if [ -z "$ARCH" ]; then
    ARCH="$DEFAULT_ARCH"
  fi

  if [ -z "$VERSION" ]; then
    VERSION="$DEFAULT_VERSION"
  fi

  if [ "$FTP_TOOL" != "wget" ] && [ "$FTP_TOOL" != "curl" ] && [ "$FTP_TOOL" != "ncftpget" ]; then
    echo "$1 configuration error: invalid value $FTP_TOOL for config parameter FTP_TOOL"
    echo "$1 assuming value \"curl\" for variable FTP_TOOL"
    FTP_TOOL="curl"
  fi

  if [ "$HTTP_TOOL" != "wget" ] && [ "$HTTP_TOOL" != "curl" ]; then
    echo "$1 configuration error: invalid value $HTTP_TOOL for config parameter HTTP_TOOL"
    echo "$1 assuming value \"curl\" for variable HTTP_TOOL"
    HTTP_TOOL="curl"
  fi

  if which $SIMPLARET &> /dev/null; then
    if [ "$SIMPLARET_UPDATE" == "1" ]; then
      if [ "$2" == "-u" ]; then
        ARCH=$ARCH VERSION=$VERSION $SIMPLARET --update
      fi
    fi
  else
    echo "$SIMPLARET not found, please install it before run $0"
  fi

  if [ "$TEMPLATE_STORAGE_STYLE" != "simplepkg-folder" ] && \
     [ "$TEMPLATE_STORAGE_STYLE" != "templates-folder" ] && \
     [ "$TEMPLATE_STORAGE_STYLE" != "own-folder" ] && \
     [ "$TEMPLATE_STORAGE_STYLE" != "compact" ]; then
    TEMPLATE_STORAGE_STYLE="compact"
  fi

  if [ ! -z "$ROOT" ]; then
    JAIL_ROOT="$ROOT"
  fi

}

# -----------------------------------------------
#           arch and version functions
# -----------------------------------------------

function default_version {

  # get version from /etc/slackware-version
  if [ -f "$1/etc/slackware-version" ]; then
    cat $1/etc/slackware-version | awk '{ print $2 }' | sed -e 's/.0$//'
  elif [ -f "$1/etc/slamd64-version" ]; then
    cat $1/etc/slamd64-version | awk '{ print $2 }' | sed -e 's/.0$//'
  elif [ -f "$1/etc/bluewhite64-version" ]; then
    cat $1/etc/bluewhite64-version | awk '{ print $2 }' | sed -e 's/.0$//'
  elif [ -f "$1/etc/sflack-version" ]; then
    cat $1/etc/sflack-version | awk '{ print $2 }' | sed -e 's/.0$//'
  else
    aaa_base="`basename $(ls $1/var/log/packages/aaa_base-[0-9]* 2> /dev/null)`"
    echo `package_version $aaa_base`
  fi

}

function default_arch {

  # get arch from /etc/slackware-version

  local arch

  if [ -f "$1/etc/slackware-version" ]; then
    arch="`cat $1/etc/slackware-version | awk '{ print $3 }' | sed -e 's/(//' -e 's/)//'`"
    if [ -z "$arch" ]; then
      arch="i486"
    fi
  elif [ -f "$1/etc/slamd64-version" ] || [ -f "$1/etc/bluewhite64-version" ] || [ -f "$1/etc/sflack-version" ]; then
    arch="x86_64"
  else
    aaa_base="`basename $(ls $1/var/log/packages/aaa_base-[0-9]* 2> /dev/null)`"
    echo `package_arch $aaa_base`
  fi

  if [ -z "$arch" ]; then
    echo `uname -m`
  else
    echo $arch
  fi

}

function default_distro {

  # get distro name from /etc/slackware-version
  if [ "`default_arch`" == "x86_64" ]; then
    if [ -f "$1/etc/slamd64-version" ]; then
      echo slamd64
    elif [ -f "$1/etc/bluewhite64-version" ]; then
      echo bluewhite64
    elif [ -f "$1/etc/sflack-version" ]; then
      echo sflack
    else
      echo slamd64
    fi
  else
    if [ -f "$1/etc/slackware-version" ]; then
      cat $1/etc/slackware-version | awk '{ print $1 }' | tr '[[:upper:]]' '[[:lower:]]'
    else
      echo slackware
    fi
  fi

}

# -----------------------------------------------
#              template functions
# -----------------------------------------------

function search_default_template {

  if [ -e "$BASE_CONF/default.template" ]; then
    TEMPLATE_BASE="$BASE_CONF/default"
    echo $BASENAME using default template
  elif [ -e "$TEMPLATE_FOLDER/default.template" ]; then
    TEMPLATE_BASE="$TEMPLATE_FOLDER/default"
    echo $BASENAME: using default template
  elif [ -e "$TEMPLATE_FOLDER/default/default.template" ]; then
    TEMPLATE_BASE="$TEMPLATE_FOLDER/default/default"
    echo $BASENAME: using default template
  elif [ -e "$TEMPLATE_FOLDER/default/packages" ]; then
    TEMPLATE_BASE="$TEMPLATE_FOLDER/default"
    echo $BASENAME: using default template
  elif [ -e "$BASE_CONF/defaults/templates/default/default.template" ]; then
    TEMPLATE_BASE="$BASE_CONF/defaults/templates/default/default"
    echo $BASENAME using default template
  elif [ -e "$BASE_CONF/defaults/templates/default/packages" ]; then
    TEMPLATE_BASE="$BASE_CONF/defaults/templates/default"
    echo $BASENAME using default template
  else
    echo $BASENAME: error: default template not found
    echo $BASENAME: please create a template using templatepkg
    return 1
  fi

}

function search_template {

  # determine the template to be used
  # usage: search-template <template-name> [--new | --update]

  #
  # templates can be stored either on
  #
  # - $BASE_CONF/template_name.template
  # - $TEMPLATE_FOLDER/template_name.template
  # - $TEMPLATE_FOLDER/template_name/template_name.template
  #
  # also, there's a folder for "oficial" simplepkg templates,
  # $BASE_CONF/defaults/templates/ and you can override any template
  # in the default folder by placing a template with the same name
  # in the template storage folders
  #

  if [ -f "$BASE_CONF/$1.template" ]; then
    TEMPLATE_BASE="$BASE_CONF/$1"
  elif [ -f "$TEMPLATE_FOLDER/$1.template" ]; then
    TEMPLATE_BASE="$TEMPLATE_FOLDER/$1"
  elif [ -f "$TEMPLATE_FOLDER/$1/$1.template" ]; then
    TEMPLATE_BASE="$TEMPLATE_FOLDER/$1/$1"
  elif [ -f "$TEMPLATE_FOLDER/$1/packages" ]; then
    TEMPLATE_BASE="$TEMPLATE_FOLDER/$1"
  elif [ -f "$BASE_CONF/defaults/templates/$1/$1.template" ] && \
       [ "$2" != "--update" ]; then
    TEMPLATE_BASE="$BASE_CONF/defaults/templates/$1/$1"
  else
    if [ "$2" == "--new" ]; then
      # we need to return the path for a new template
      if [ "$TEMPLATE_STORAGE_STYLE" == "simplepkg-folder" ]; then
        TEMPLATE_BASE="$BASE_CONF/$1"
      elif [ "$TEMPLATE_STORAGE_STYLE" == "templates-folder" ]; then
        TEMPLATE_BASE="$TEMPLATE_FOLDER/$1"
      elif [ "$TEMPLATE_STORAGE_STYLE" == "own-folder" ]; then
        TEMPLATE_BASE="$TEMPLATE_FOLDER/$1/$1"
      elif [ "$TEMPLATE_STORAGE_STYLE" == "compact" ]; then
        TEMPLATE_BASE="$TEMPLATE_FOLDER/$1"
      else
        TEMPLATE_BASE="$TEMPLATE_FOLDER/$1"
      fi
    elif [ "$2" == "--update" ]; then
      return 1
    else
      echo $BASENAME: template $1 not found
      search_default_template
    fi
  fi

}

function template_packages {

  if [ "$TEMPLATE_STORAGE_STYLE" == "compact" ]; then
    echo $TEMPLATE_BASE/packages
  else
    echo $TEMPLATE_BASE.template
  fi

}

function template_perms {

  if [ "$TEMPLATE_STORAGE_STYLE" == "compact" ]; then
    echo $TEMPLATE_BASE/perms
  else
    echo $TEMPLATE_BASE.perms
  fi

}

function template_files {

  if [ "$TEMPLATE_STORAGE_STYLE" == "compact" ]; then
    echo $TEMPLATE_BASE/files
  else
    echo $TEMPLATE_BASE.d
  fi

}

function template_scripts {

  if [ "$TEMPLATE_STORAGE_STYLE" == "compact" ]; then
    echo $TEMPLATE_BASE/scripts
  else
    echo $TEMPLATE_BASE.s
  fi

}

# -----------------------------------------------
#           unix permission functions
# -----------------------------------------------

function numeric_perm {

  # get the numeric permission of a file
  # usage: numeric_perm <file-name>

  # just a bit of forbidden secrets

  if [ -a "$1" ]; then
    ls -lnd $1 | awk '{ print $1 }' | \
    sed -e 's/^.//' -e 's/r/4/g' -e 's/w/2/g' -e 's/x/1/g' \
        -e 's/-/0/g' -e 's/\(.\)\(.\)\(.\)/\1+\2+\3/g' |   \
    fold -w5 | bc -l | xargs | sed -e 's/ //g'
  fi

}

function get_owner {

  # get the numeric owner for a file
  # usage: get_owner <file>

  if [ -a "$1" ]; then
    ls -lnd $1 | awk '{ print $3 }'
  fi

}

function get_group {

  # get the numeric group for a file
  # usage: get_group <file>

  if [ -a "$1" ]; then
    ls -lnd $1 | awk '{ print $4 }'
  fi

}

function is_writable_folder {

  # check if a folder is writable
  # usage: is_writable_folder <folder>

  local tmpfile folder="$1"

  if mkdir -p $folder &> /dev/null && tmpfile=`mktemp $folder/is_writable_folder.XXXXXX`; then     
    rm -f $tmpfile
    return 0
  else
    return 1
  fi

}

# -----------------------------------------------
#              subversion functions
# -----------------------------------------------

function svn_update {

  # simple wrapper around svn update
  # usage: svn_update

  svn update

}

function svn_folder {

  # simple svn folder checker
  # usage: svn_folder <folder>

  if [ -d "$1/.svn" ]; then
    return
  else
    return 1
  fi

}

function templates_under_svn {

  # check if svn usage is enabled

  if [ "$TEMPLATES_UNDER_SVN" == "1" ]; then
    if [ "$TEMPLATE_STORAGE_STYLE" == "own-folder" ] || \
       [ "$TEMPLATE_STORAGE_STYLE" == "compact" ]; then
      return 0
    else
      return 1
    fi
   else
     return 1
   fi

}

function svn_check {

  # check if a file is under svn
  # usage: svn_check <file>

  local folder file

  folder="`dirname $1`"
  file="`basename $1`"

  if [ ! -e "$folder/$file" ]; then

    return 1

  elif svn_folder $folder/$file; then

    return 0

  elif svn_folder $folder; then

    (
      cd $folder

      if [ "`svn status $file | awk '{ print $1 }'`" == "?" ]; then
        return 1
      else
        return 0
      fi
    )

  else
    return 1
  fi

}

function build_svn_repo {

  # Checkout a new slackbuild working copy
  # input: $1 - svn directory name
  #        $2 - svn address
  [ $# -ne 2 ] && exit 5
  SVN_BASEDIR="`dirname $1`"
  mkdir -p $SVN_BASEDIR || exit 4
  cd $SVN_BASEDIR
  svn checkout $2
  cd $1

}

function check_svn_repo {

  # Verify if repository exist
  # input: $1 - svn directory name
  #        $2 - svn address
  [ $# -ne 2 ] && exit 5
  [ ! -d "$1" ] && build_svn_repo $1 $2

}

function sync_svn_repo {

  # Synchronize repository
  # input: $1 - svn directory name
  #        $2 - svn address
  [ $# -ne 2 ] && exit 5

  local folder url cwd
  folder="$1"
  url="$2"
  cwd="`pwd`"

  mkdir -p $folder
  cd $folder
  if svn_folder $(pwd); then
    su_svn update
  else
    build_svn_repo $folder $url
  fi
  cd $pwd

}

function svn_add {

  local file="$1" folder folders dir_list cwd
  local subfolder subfolders

  if [ -e "$file" ] && ! svn_check $file; then

    folder="`absolute_folder $file`"
    cwd="`pwd`"

    if svn_folder $folder; then
      cd $folder
      su_svn add `basename $file`
    else

      # reverse folder order
      dir_list="`echo $folder | tr '/' ' '`"
      for i in $dir_list; do
        folders="$i $folders"
      done

      cd $folder

      for i in $folders; do
        cd ..
        if svn_folder $(pwd); then
          # add the parent folder
          su_svn add --depth=empty $i

          # add all subfolders
          cd $i
          subfolders="$(echo $folder | sed -e "s/^$(regexp_slash $(pwd))//")"
          for subfolder in `echo $subfolders | tr '/' ' '`; do
            if ! svn_check $subfolder; then
              su_svn add --depth=empty $subfolder
              cd $subfolder
            fi
          done

          # add the file
          cd $folder
          su_svn add `basename $file`

          break
        fi
      done

    fi

    cd $cwd

  fi

}

function svn_del {

  local file folder

  file="$1"
  folder="`dirname $file`"

  if [ -e "$file" ] && svn_folder $folder && svn_check $file; then
    chown_svn $file && chgrp_svn $file
    ( cd $folder && su_svn del --force `basename $file` )
  else
    ( cd $folder && rm -rf `basename $file` )
  fi

}

function svn_copy {

  # svn add file
  # usage: svn_copy <orig> <dest>

  [ $# -ne 2 ] && handle_error $ERROR_PAR_NUMBER

  if [ -e "$1" ]; then

    local orig file dest

    orig="`dirname $1`"
    file="`basename $1`"
    dest="$2"

    if [ -d "$dest" ]; then
      dest="$dest/$file"
    fi

    # copy file
    if ! is_the_same $orig $(dirname $dest); then
      cp $orig/$file $dest
    fi

    # add file to the revision system
    if svn_folder `dirname $dest`; then
      chown_svn $dest && chgrp_svn $dest
      ( cd `dirname $dest` && svn_add `basename $dest` )
    fi

  fi

}

function svn_mkdir {

  # svn make directory
  # usage: svn_mkdir <folder>

  [ $# -ne 1 ] && handle_error $ERROR_PAR_NUMBER

  DIR_LIST=`echo $1 | tr '/' ' '`

  DIR=""
  for i in $DIR_LIST; do
    DIR=$DIR/$i
    if [ ! -e ${DIR:1} ]; then
      su_svn mkdir ${DIR:1}
    elif [ -d "${DIR:1}" ] && ! svn_folder ${DIR:1}; then
      su_svn add ${DIR:1}      
    fi
  done

}

function is_inside_svn_repo {

  # check if a file is inside a svn repository
  # usage: is_inside_svn_repo <file>

  local file="$1" folder folders dir_list cwd

  if [ -e "$file" ]; then
    folder="`absolute_folder $file`"
  fi

  if svn_folder $folder; then
    return true
  fi

  # reverse folder order
  dir_list="`echo $folder | tr '/' ' '`"
  for i in $dir_list; do
    folders="$i $folders"
  done

  cwd="`pwd`"
  cd $folder

  for i in $folders; do
    cd ..
    if svn_folder $(pwd); then
      cd $cwd
      return true
    fi
  done

  cd $cwd
  return false

}

function su_svn {

  # execute svn using a different user
  if [ ! -z "$SVN_USER" ]; then
    if [ "`whoami`" != "$SVN_USER" ]; then
      su $SVN_USER -c "svn $*"
    else
      svn $*
    fi
  else
    svn $*
  fi

}

function chown_svn {

  # set svn folder ownership
  if [ ! -z "$SVN_USER" ] && [ -e "$1" ]; then
    chown -R $SVN_USER $1
  fi

}

function chgrp_svn {

  # set svn folder group
  if [ ! -z "$SVN_GROUP" ] && [ -e "$1" ]; then
    chgrp -R $SVN_GROUP $1
  fi

}

function svn_remove_empty_folders {

  if [ -z "$1" ] && [ ! -d "$1" ]; then
    return 1
  fi

  local folder

  for folder in `find $1 -type d -print | grep -v "/\.svn" | sort -r`; do
    if [ "`ls -A -1 $folder | grep -v -e '^\.svn' | wc -l`" -eq "0" ]; then
      svn_del $folder
    fi
  done

}

function commit_changes {

  # usage: commit_changes <path>

  local repos="$1" tmpfile
  shift

  if svn_folder $repos; then
    cwd="`pwd`"
    chown_svn $repos && chgrp_svn $repos
    cd $repos
    if [ ! -z "$1" ]; then
      if tmpfile=`mktemp $TMP/simplepkg_commit.XXXXXX`; then
        echo $* > $tmpfile
        chmod +r $tmpfile
        su_svn commit -F $tmpfile
        rm -f $tmpfile
      else
        su_svn commit
      fi
    else
      su_svn commit
    fi
    cd $cwd
  fi

}

function valid_svn_repo {

  # check a svn repository URL
  # usage: set_svn_repo <repository>

  if [ ! -z "$1" ]; then
    if echo $1 | grep -q -v -e "^svn://"; then
      if echo $1 | grep -q -v -e "svn+.\+://"; then
        if echo $1 | grep -q -v -e "^file://"; then
          echo $BASENAME: invalid repository URL $1
          return 1
        fi
      fi
    fi
  else
    echo $BASENAME: no repository defined
    return 1
  fi

}

function check_and_create_svn_repo {

  # check and create svn repository
  # usage: check_and_create_svn_repo <repository>

  local repository="$1" repository_type repository_path

  if ! echo $repository | grep -q ":"; then
    repository="file://$repository"
  fi

  repository_type="`echo $repository | cut -d : -f 1`"
  repository_path="`echo $repository | cut -d : -f 2`"

  if [ "$repository_type" == "file" ] && [ ! -d "$repository_path" ]; then
    echo "Creating subversion repository $repository..."
    mkdir -p `dirname $repository_path`
    svnadmin create $repository_path --fs-type fsfs
    if [ "$?" != "0" ]; then
      EXIT_CODE="1"
      return $EXIT_CODE
    else
      return 0
    fi
  fi

}

function repository_import {

  # import a folder into a subversion repository
  # usage: repository_import <folder> <repository>

  local folder="$1" oldfolder tmpfile
  local repository="$2" repository_type repository_path

  if [ ! -d "$folder" ] || [ -z "$repository" ]; then
    EXIT_CODE="1"
    return $EXIT_CODE
  fi

  if ! valid_svn_repo $repository; then
    echo "Invalid repository $repository, aborting."
    EXIT_CODE="1"
    return $EXIT_CODE
  fi

  if ! echo $repository | grep -q ":"; then
    repository="file://$repository"
  fi

  mkdir -p $folder

  if svn_folder $folder; then
    echo "Packages folder $folder seens to be already under revision control, aborting."
    EXIT_CODE="1"
    return $EXIT_CODE
  fi

  check_and_create_svn_repo $repository
  if [ "$?" != "0" ]; then
    EXIT_CODE="1"
    return $EXIT_CODE
  fi

  repository_path="`echo $repository | cut -d : -f 2`"
  if [ -d "$repository_path" ]; then
    chown_svn $repository_path && chgrp_svn $repository_path
  fi

  echo "Importing files from $folder into $repository..."
  if tmpfile=`mktemp $TMP/simplepkg_import.XXXXXX`; then
    echo "initial import" > $tmpfile
    chmod +r $tmpfile
    su_svn import $folder $repository -F $tmpfile
    rm -f $tmpfile
  else
    EXIT_CODE="1"
    return $EXIT_CODE
  fi

  if [ "$?" == "0" ]; then
    echo "Making $folder a working copy of $repository..."
    oldfolder="$(mktemp -d $(echo $folder | sed -e 's/\/*$//g').XXXXXX)"
    echo "Backing up old $folder at $oldfolder..."
    mv $folder $oldfolder
    chown_svn `dirname $folder` && chgrp_svn `dirname $folder`
    su_svn checkout $repository $folder
  else
    EXIT_CODE="1"
    return $EXIT_CODE
  fi

}

# -----------------------------------------------
#           update jail functions
# -----------------------------------------------

function update_template_files {

  # update template files from svn
  # usage: update_template_files

  if templates_under_svn && svn_folder `template_files`; then
    echo Checking out last template revision from svn...
    cd `dirname $TEMPLATE_BASE`
    svn update
  fi

}

function update_jail_packages {

  # update jail packages according the template
  # usage: update_jail_packages <jail-path>

  # check if installed packages are listed in the template
  for pack in `ls -1 $1/var/log/packages/`; do
    pack=`package_name $pack`
    if ! `grep -v -e "^#" $(template_packages) | cut -d : -f 1 | awk '{ print $1 }' | grep -q -e "^$pack\$"`; then
      ROOT=$1 removepkg $pack
    fi
  done

  # check if each package from the template is installed
  grep -v -e "^#" `template_packages` | cut -d : -f 1 | awk '{ print $1 }' | while read pack; do

    # check if the package is installed
    pack="`echo $pack | sed -e 's/\+/\\\+/'`"
    installed="`check_installed $pack $1`"
    check=$?

    if [ -z "$installed" ] || [ "$check" != "0" ]; then
      # the package isn't installed
      ROOT=$1 simplaret install $pack
    fi
  done

}

function copy_template_files {

  # copy template files into jail
  # usage: copy_template_files <jail-path>

  if [ -d "$1" ]; then
    if [ -d "`template_files`" ]; then
      echo "Copying template files to $1..."
      if templates_under_svn && svn_folder `template_files`; then
        rsync -av --exclude=.svn `template_files`/ $1/
      else
        rsync -av `template_files`/ $1/
      fi
    fi
  fi

}

function set_jail_perms {

  # set template file permissions under a jail
  # usage: set_jail_perms <jail-path>

  if [ -s "`template_perms`" ]; then
    echo Setting jail $1 permissions...
    cat `template_perms` | while read entry; do
      file="`echo $entry | cut -d ";" -f 1`"
      if [ -e "`template_files`/$file" ] && [ -a "$1/$file" ]; then
        owner="`echo $entry | cut -d ";" -f 2`"
        group="`echo $entry | cut -d ";" -f 3`"
        perms="`echo $entry | cut -d ";" -f 4`"
        chmod $perms $1/$file
        chown $owner:$group $1/$file
      fi
    done
  fi

}

# -----------------------------------------------
#           repository build functions
# -----------------------------------------------

function svn_add_meta {

  find . -name '*meta' -exec svn add {} 2> /dev/null \;

}

function gen_filelist {

  # generate FILELIST.TXT
  # usage: gen_filelist

  eval find . -type f -and $(pkg_ext_find) -follow -print | sort | tr '\n' '\0' | \
       xargs -0r ls -ldL --time-style=long-iso > FILELIST.TXT
  echo "Created new FILELIST.TXT"

  svn_add FILELIST.TXT

}

function gen_patches_filelist {

  # generate FILE_LIST
  # usage: gen_patches_filelist <folder>

  if [ ! -z "$1" ] && [ -d "$1" ]; then

    local folder
    folder="$1"

    (

      cd $folder

      eval find . -type f -and $(pkg_ext_find) -follow -print | sort | tr '\n' '\0' | \
      xargs -0r ls -ldL --time-style=long-iso > FILE_LIST

      svn_add FILE_LIST

    )

    if [ "$1" == "." ]; then
      echo "Created new FILE_LIST"
    else
      echo "Created new $1/FILE_LIST"
    fi

  fi

}

function gen_packages_txt {

  # generate PACKAGES.TXT
  # usage: gen_packages_txt <folder>

  if [ ! -z "$1" ] && [ -d "$1" ]; then

    local folder
    folder="$1"

    (

      cd $folder

      echo '' > PACKAGES.TXT
      find . -type f -name '*.meta' -exec cat {} \; >> PACKAGES.TXT
      cat PACKAGES.TXT | gzip -9 -c - > PACKAGES.TXT.gz

      svn_add PACKAGES.TXT
      svn_add PACKAGES.TXT.gz

    )

    if [ "$1" == "." ]; then
      echo "Created new PACKAGES.TXT and PACKAGES.TXT.gz"
    else
      echo "Created new $1/PACKAGES.TXT and $1/PACKAGES.TXT.gz for $folder"
    fi

  fi

}

function gen_md5_checksums {

  # generate CHECKSUMS.md5
  # usage: gen_md5_checksums <folder>

  if [ -d "$1" ]; then

    local folder
    folder="$1"

    (

      cd $folder

      echo 'MD5 digest for files in this directory.' > CHECKSUMS.md5
      echo '' >> CHECKSUMS.md5
      eval find . -type f -and $(pkg_ext_find) -exec md5sum {} \; >> CHECKSUMS.md5
      cat CHECKSUMS.md5 | gzip -9 -c - > CHECKSUMS.md5.gz

      svn_add CHECKSUMS.md5
      svn_add CHECKSUMS.md5.gz

    )

    if [ "$1" == "." ]; then
      echo "Created new CHECKSUMS.md5 and CHECKSUMS.md5.gz"
    else
      echo "Created new $1/CHECKSUMS.md5 and $1/CHECKSUMS.md5.gz for $folder"
    fi

  fi

}

function update_md5_checksum {

  # update CHECKSUMS.md5
  # usage: update_md5_checksums <folder> <file>

  if [ -z "$2" ] || [ ! -d "$1" ] || [ ! -f "$1/$2" ]; then
    return 1
  else
    local file folder
    file="$2"
    folder="$1"
  fi

  (

    cd $folder

    if [ ! -f CHECKSUMS.md5 ]; then
      gen_md5_checksums .
    else
      # TODO: in case of packages, must remove also existing entries
      #       (including the ones with different extensions)
      # remove the old entry and add a new one
      sed -i "/ \.*\/*$(regexp_slash $file)$/d" CHECKSUMS.md5
      file="`echo $file | sed -e 's/\.*\/*//'`" # remove additional ./
      md5sum ./$file >> CHECKSUMS.md5
    fi

    cat CHECKSUMS.md5 | gzip -9 -c - > CHECKSUMS.md5.gz

    echo "Updated CHECKSUMS.md5 at $folder"

    svn_add CHECKSUMS.md5
    svn_add CHECKSUMS.md5.gz

  )

}

function gen_meta {

  # generate metafiles
  # usage: gen_meta <package-file>

  if [ ! -f $1 ]; then
    return 1
  else
    file="$1"
  fi

  if [ "`echo $file | grep -E \"(.*{1,})\-(.*[\.\-].*[\.\-].*).$(pkg_ext_grep)[ ]{0,}$\"`" == "" ]; then
    return
  fi

  NAME=$(basename $file)
  LOCATION=$(dirname $file)
  SIZE=$( expr `gunzip -l $file | tail -n 1 | awk '{ print $1 }'` / 1024 )
  USIZE=$( expr `gunzip -l $file | tail -n 1 | awk '{ print $2 }'` / 1024 )
  REQUIRED=$(tar xzfO $file install/slack-required 2>/dev/null | grep -v -e "^#" | xargs -r -iZ echo -n "Z," | sed -e "s/,$//")
  CONFLICTS=$(tar xzfO $file install/slack-conflicts 2>/dev/null | grep -v -e "^#" | xargs -r -iZ echo -n "Z," | sed -e "s/,$//")
  SUGGESTS=$(tar xzfO $file install/slack-suggests 2>/dev/null | grep -v -e "^#" | xargs -r )
  METAFILE="$(strip_pkg_ext $NAME).meta"

  echo "PACKAGE NAME:  $NAME" > $LOCATION/$METAFILE

  if [ -n "$DL_URL" ]; then
    echo "PACKAGE MIRROR:  $DL_URL" >> $LOCATION/$METAFILE
  fi

  echo "PACKAGE LOCATION:  $LOCATION" >> $LOCATION/$METAFILE
  echo "PACKAGE SIZE (compressed):  $SIZE K" >> $LOCATION/$METAFILE
  echo "PACKAGE SIZE (uncompressed):  $USIZE K" >> $LOCATION/$METAFILE
  echo "PACKAGE REQUIRED:  $REQUIRED" >> $LOCATION/$METAFILE
  echo "PACKAGE CONFLICTS:  $CONFLICTS" >> $LOCATION/$METAFILE
  echo "PACKAGE SUGGESTS:  $SUGGESTS" >> $LOCATION/$METAFILE
  echo "PACKAGE DESCRIPTION:" >> $LOCATION/$METAFILE

  tar xzfO $file install/slack-desc | grep -E '\w+\:' | grep -v '^#' >> $LOCATION/$METAFILE

  echo "" >> $LOCATION/$METAFILE
  echo "Created metafile for `basename $file`"

  ( cd `dirname $file` && svn_add `strip_pkg_ext $file`.meta )

}

function repo_gpg_key {

  # adds or updates a repository keyring
  # usage: repo_gpg_key <folder> [update]

  local folder="$1" update="$2" tmp_gpg_folder

  if [ -z "$SIGN_KEYID" ]; then
    echo "GPG-KEY checking failed, no sign key id set."
    return 1
  fi

  if [ "$update" == "--update" ]; then
    update=true
  else
    update=false
  fi

  if [ $SIGN -eq $on ]; then
    if [ -f "$folder/GPG-KEY" ]; then
      if $update || ! gpg --with-colons < $folder/GPG-KEY | cut -d : -f 5 | grep -q -e "$SIGN_KEYID$"; then
        echo "Adding OpenPGP key id $SIGN_KEYID to $folder/GPG-KEY file..."

        tmp_gpg_folder="`mktemp -d $TMP/tmp_gpg_folder.XXXXXX`"
        tmp_gpg_pubkey="`mktemp -d $TMP/tmp_gpg_pubkey.XXXXXX`"

        if [ ! -z "$SIGN_USER" ] && [ "`whoami`" != "$SIGN_USER" ]; then
          chown $SIGN_USER $tmp_gpg_folder
          chown $SIGN_USER $tmp_gpg_pubkey

          # merge pubkey information in a temporary keyring
          su $SIGN_USER -c "gpg --export --armor $SIGN_KEYID > $tmp_gpg_pubkey/pubkey.asc"
          su $SIGN_USER -c "gpg --homedir $tmp_gpg_folder --import < $folder/GPG-KEY"
          su $SIGN_USER -c "gpg --homedir $tmp_gpg_folder --import < $tmp_gpg_pubkey/pubkey.asc"

          # export temporary keyring to repository keyring
          su $SIGN_USER -c "gpg --homedir $tmp_gpg_folder --export --armor" > $folder/GPG-KEY
        else
          # merge pubkey information in a temporary keyring
          gpg --export --armor $SIGN_KEYID > $tmp_gpg_pubkey/pubkey.asc
          gpg --homedir $tmp_gpg_folder --import < $folder/GPG-KEY
          gpg --homedir $tmp_gpg_folder --import < $tmp_gpg_pubkey/pubkey.asc

          # export temporary keyring to repository keyring
          gpg --homedir $tmp_gpg_folder --export --armor > $folder/GPG-KEY
        fi

        # cleanup
        rm -rf $tmp_gpg_folder $tmp_gpg_pubkey

      fi
    else
      echo "Adding OpenPGP key id $SIGN_KEYID to $folder/GPG-KEY file..."
      if [ ! -z "$SIGN_USER" ] && [ "`whoami`" != "$SIGN_USER" ]; then
        su $SIGN_USER -c "gpg --export --armor $SIGN_KEYID" > $folder/GPG-KEY
      else
        gpg --export --armor $SIGN_KEYID > $folder/GPG-KEY
      fi
    fi
    svn_add $folder/GPG-KEY
  fi

}

# -----------------------------------------------
#                 Error functions
# -----------------------------------------------

function error_codes {

  # Slackbuilds error codes ** not change **
  ERROR_WGET=31       # wget error
  ERROR_MAKE=32       # make source error
  ERROR_INSTALL=33    # make install error
  ERROR_MD5=34        # md5sum error
  ERROR_CONF=35       # ./configure error
  ERROR_HELP=36       # dasable
  ERROR_TAR=37        # tar error
  ERROR_MKPKG=38      # makepkg error
  ERROR_GPG=39        # gpg check error
  ERROR_PATCH=40      # patch error
  ERROR_VCS=41        # cvs error
  ERROR_MKDIR=42      # make directory error
  ERROR_MANIFEST=43   # manifest error
  # Slackbuilds error codes ** not change **

  # Commum error codes
  ERROR_FILE_NOTFOUND=100                   # file not found
  ERROR_NOT_NUMBER=101                      # argument is not a number
  ERROR_PAR_NUMBER=102                      # incorrect number of parameters
  ERROR_COMMON_NOT_FOUND=103                # common.sh not found

  # Createpkg error codes
  ERROR_CREATEPKG_INSTALLPKG=200            # installpkg error
  ERROR_CREATEPKG_DEPENDENCY=201            # dependency error
  ERROR_CREATEPKG_SLACKBUILD_NOTFOUND=202   # Script or package not found

  # Mkbuild error codes
  ERROR_MKBUILD_FILE_NOT_FOUND=500
  ERROR_MKBUILD_CONSTRUCTION=501
  ERROR_MKBUILD_PROGRAM=502
  ERROR_MKBUILD_INPUT_PAR=503
  ERROR_MKBUILD_SVN=504

  # Mkpatch error codes
  ERROR_MKPATCH=600
}

function handle_error {

  # This function deals with internal createpkg errors
  # and also with non-zero exit codes from slackbuilds
  # Input:    $1 - error code
  # Output:   Error mensage
  #
  # check slackbuild exit status are:
  #
  # ERROR_WGET=31;      ERROR_MAKE=32;      ERROR_INSTALL=33
  # ERROR_MD5=34;       ERROR_CONF=35;      ERROR_HELP=36
  # ERROR_TAR=37;       ERROR_MKPKG=38      ERROR_GPG=39
  # ERROR_PATCH=40;     ERROR_VCS=41;       ERROR_MKDIR=42
  #

  # we don't want to process when exit status = 0
  [ "$1" == "0" ] && return

  # Exit codes
  case $1 in
    #
    # Slackbuilds errors
    $ERROR_WGET)
      eecho $error "$BASENAME: error downloading source/package for $2" ;;
    $ERROR_MAKE)
      eecho $error "$BASENAME: error compiling $2 source code" ;;
    $ERROR_INSTALL)
      eecho $error "$BASENAME: error installing $2" ;;
    $ERROR_MD5)
      eecho $error "$BASENAME: error on source code integrity check for $2" ;;
    $ERROR_CONF)
      eecho $error "$BASENAME: error configuring the source code for $2" ;;
    $ERROR_HELP)
      exit 0 ;; # its supposed to never happen here :P
    $ERROR_TAR)
      eecho $error "$BASENAME: error decompressing source code for $2" ;;
    $ERROR_MKPKG)
      eecho $error "$BASENAME: error creating package $2" ;;
    $ERROR_GPG)
      eecho $error "$BASENAME: error verifying GPG signature the source code for $2" ;;
    $ERROR_PATCH)
      eecho $error "$BASENAME: error patching the source code for $2" ;;
    $ERROR_VCS)
      eecho $error "$BASENAME: error downloading $2 source from version control system" ;;
    $ERROR_MKDIR)
      eecho $error "$BASENAME: make directory $2 error, aborting" ;;
    $ERROR_MANIFEST)
      eecho $error "$BASENAME: problem with Manifest file, aborting" ;;

    #
    # General errors
    $ERROR_FILE_NOTFOUND)
      eecho $error "$BASENAME: file $2 not found!" ;;
    $ERROR_NOT_NUMBER)
      eecho $error "$BASENAME: $2 need a number argument" ;;
    $ERROR_PAR_NUMBER)
      eecho $error "$BASENAME: incorrect number of parameters" ;;
    #$ERROR_COMMON_NOT_FOUND)
    #  eecho $error "$BASENAME: file $COMMON_SH not found. Check your $BASENAME installation" ;;

    #
    # Createpkg errors
    $ERROR_CREATEPKG_INSTALLPKG)
      eecho $error "$BASENAME: install package $2 error, aborting" ;;
    $ERROR_CREATEPKG_DEPENDENCY)
      eecho $error "$BASENAME: dependency solve error, aborting" ;;
    $ERROR_CREATEPKG_SLACKBUILD_NOTFOUND)
      eecho $error "$BASENAME: SlackBuild or package not found" ;;

    #
    # Mkbuild errors
    $ERROR_MKBUILD_CONSTRUCTION)
      eecho $error "$BASENAME: Construction error in $2 variable." ;;
    $ERROR_MKBUILD_PROGRAM)
      eecho $error "$BASENAME: Program logical error." ;;
    $ERROR_MKBUILD_INPUT_PAR)
      eecho $error "$BASENAME: Input parameter $2 error. See \"mkbuild --help\"." ;;
    $ERROR_MKPATCH)
      eecho $error "$BASENAME: Mkpatch error. Check .mkbuild file." ;;
    $ERROR_MKBUILD_VCS)
      eecho $error "$BASENAME: VCS or empty URL. Disable this sections in .mkbuild file:\n - download_source;\n - md5sum_download_and_check_0;\n - md5sum_download_and_check_1;\n - gpg_signature_check\n - untar_source"
      ;;
    #
    # Others errors
    *)
      eecho $error "$BASENAME: unknown error or user interrupt" ;;
  esac

  is_number $1 && exit $1 || exit 1

}

# -----------------------------------------------
#                 misc functions
# -----------------------------------------------

function slash {

  # remove additional slashes
  echo $* | sed -e 's/\/\+/\//g'

}

function color_select {

  # Select color mode: gray, color or none (*)
  # commun - Communication
  # messag - Commum messages
  # error - Error messages
  # normal   - turn off color

  case "$1" in
  'gray')
    # colors
    normal="\033[m"
    dark_gray="\033[30;1m"
    gray="\033[37m"
    white="\033[37;1m"

    red=$dark_gray
    blue=$dark_gray
    green=$gray
    yellow=$gray

    # Actions
    commun=$white
    messag=$white
    error=$dark_gray
    alert=$gray
    ;;
  'color')
    # colors
    normal="\033[m"
    dark_gray="\033[30;1m"
    gray="\033[37m"
    white="\033[37;1m"

    red="\033[31;1m"
    blue="\033[34;1m"
    green="\033[32;1m"
    yellow="\033[33;1m"

    # Actions
    commun=$green
    messag=$blue
    error=$red
    alert=$yellow
    ;;
  *)
    commun=""
    messag=""
    error=""
    alert=""
    ;;
  esac

}

function eecho {

  # echoes a message
  # usage: eecho <message-type> <message>
  # message-type can be: commun, messag, error, normal

  echo -e "${1}${2}${normal}"

}

function is_number {

    # Check if $1 is a number
    local -i int
    if [ $# -eq 0 ]; then
        return 1
    else
        (let int=$1)  2>/dev/null
        return $? # Exit status of the let thread
    fi

}

function regexp_slash {

  # escape slashes
  echo $1 | sed -e 's/\//\\\//g'

}

function is_the_same {

  # check if two files are in fact the same
  # usage: is_the_same <path1> <path2>

  if [ -e "$1" ] && [ -e "$2" ] && \
     [ "`stat -c '%d' $1`" == "`stat -c '%d' $2`" ] && \
     [ "`stat -c '%i' $1`" == "`stat -c '%i' $2`" ]; then
     return 0
  else
    return 1
  fi

}

function check_gnupg {

  # setup gnupg keyring if needed
  # usage: check_gnupg [username]

  local user="$1" home

  if [ ! -z "$user" ]; then
    home="`grep "^$user:" /etc/passwd | cut -d : -f 6`"
    if [ ! -d "$home/.gnupg" ]; then
      echo "Setting up gnupg..."
      su $user -c "gpg --list-keys"
    fi
  else
    if [ ! -d "$HOME/.gnupg" ]; then
      echo "Setting up gnupg..."
      gpg --list-keys
    fi
  fi

}

function strip_gpg_signature {

  # strip gpg signature from file
  # usage: strip_gpg_signature <file>

  local file="$1"

  if [ -e "$file" ]; then
    if grep -q -- "-----BEGIN PGP SIGNED MESSAGE-----" $file; then    
      sed -e '1,3d' -e '/^$/d' -e '/-----BEGIN PGP SIGNATURE-----/,/-----END PGP SIGNATURE-----/d' $file
    else
      cat $file
    fi
  fi

}

function get_sign_user {

  # get sign package user
  # usage: get_sign_package_user

  check_gnupg $SIGN_USER

  if [ -z "$SIGN_KEYID" ]; then
    if [ ! -z "$SIGN_USER" ] && [ "`whoami`" != "$SIGN_USER" ]; then
      SIGN_KEYID="`su $SIGN_USER -c \
      "gpg --list-secret-keys --with-colons | grep ^sec | head -n 1 | cut -d : -f 5 | sed 's/^.*\(.\{8\}\)$/\1/'"`"
    else
      SIGN_KEYID="`gpg --list-secret-keys --with-colons | grep ^sec | head -n 1 | cut -d : -f 5 | sed 's/^.*\(.\{8\}\)$/\1/'`"
    fi
  fi

}

function update_keyring  {

  # update keyring using GPG-KEY from a repository
  # usage: update_keyring <keyfile>

  local keyring keys key

  keyring="$1"

  if [ ! -e "$keyring" ]; then
    repo_gpg_key `dirname $keyring`
    return
  fi
  
  keys="`gpg --with-colons $keyring | cut -d : -f 5 | sed -e '/^$/d'`"

  for key in $keys; do
    if [ ! -z "$SIGN_USER" ] && [ "`whoami`" != "$SIGN_USER" ]; then
      su $SIGN_USER -c "gpg --list-keys $key &> /dev/null"
      if [ "$?" != "0" ]; then
        echo "Updating keyring using $keyring..."
        su $SIGN_USER -c "gpg --import $keyring"
        break
      fi
    else
      gpg --list-keys $key &> /dev/null
      if [ "$?" != "0" ]; then
        echo "Updating keyring using $keyring..."
        gpg --import $keyring
        break
      fi
    fi
  done

}

function rmd160sum {

  # computes RIPEMD-160 message digest
  # usage: rmd160sum <file>

  local sum file="$1"

  if [ ! -e "$file" ]; then
    return 1
  fi

  sum="`openssl rmd160 $file | awk '{ print $2 }'`"
  echo "$sum  $file"

}

function gethash {

  # get a file's hash
  # usage: gethash <algorithm> <file>

  if [ ! -e "$2" ]; then
    return 1
  fi

  $1sum $file | awk '{ print $1 }'

}

function file_size {

  # get file size
  # usage: filesize <file>

  if [ ! -e "$1" ]; then
    return 1
  fi

  wc -c $file | awk '{ print $1 }'

}

function file_extension {

  # output file extension
  # usage: filesize <filename>

  echo `basename $1` | sed -e 's/.*\.\(.*\)$/\1/'

}

function absolute_folder {

  # get the absolute folder from a file
  # usage: absolute_folder <file>

  local file="$1" cwd

  if [ -e "$file" ]; then
    cwd="`pwd`"
    cd `dirname $file`
    pwd
    cd $cwd
  fi

}

function list_builds {

  # list all available builds
  # usage: list_builds <folder> <file_type>

  local folder="$1" file_type="$2"
  local i j k

  if [ ! -d "$folder" ] || [ -z "$file_type" ]; then
    return
  fi

  cd $folder
  echo "Sarava $file_type list"
  # level 1
  for i in *; do
    if [ -d $i ]; then
      echo -e "  $i: "
      (
        cd $i
        # level 2
        for j in *; do
          if [ -d $j ]; then
            eecho $commun "    $j"
            (
              cd $j
              BUILD="`ls *.$file_type 2>/dev/null`"
              if [ "$BUILD" != "" ]; then
                # level 3
                for k in $BUILD; do
                  eecho $messag "      $k"
                done
              else
                BUILD=""
              fi
              for k in *; do
                if [ -d $k ]; then
                  eecho $messag "      $k.$file_type"
                fi
              done
            )
          fi
        done
      )
    fi
  done

}

function check_installed {

  # checks if a package is installed 
  # usage: check_installed <package_name> [root]

  eval "ls /$2/var/log/packages/ | grep -E '^$1-[^-]+-[^-]+-[^-]+$'"

}
