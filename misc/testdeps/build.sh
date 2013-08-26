#!/bin/bash
# Bash script for setting up integration testing dependencies.
#

function qpushd {
  # pushd without stdout output
  pushd "$1" > /dev/null
}

function qpopd {
  # popd without stdout output
  popd > /dev/null
}

function dirname_abs {
  # Get dirname as an absolute path
  qpushd "$(dirname $1)"
  echo ${PWD}
  qpopd
}

function command_exists {
  command -v "$1" > /dev/null 2>&1
}

function fetch {
  output_path="$2/$3"
  # Fetch file from source URI
  if command_exists wget; then
    # wget is available
    wget --no-host-directories \
      --output-document="${output_path}" \
      "$1"  # URI
  elif command_exists curl; then
    # curl is available
    curl -v -o "${output_path}" "$1"
  else
    echo "Error: either wget or curl must be available." >&2
    return 1
  fi
}

function create_symlinks {
  # Create symbolic links under deps root from each dependency root.
  # Args:
  #  $1: The installation prefix path.
  #  $2+: Subdirectory under $1 to be symlinked.
  prefix="$1"
  shift
  qpushd ${DEPS_ROOT}
    # For each subdirectory requested, perform the copy
    for i in "$@"; do
      symlink_srcroot="${prefix}/$i"
      # If the srcroot doesn't exist, no business here.
      if [ ! -d "${symlink_srcroot}" ]; then
        continue
      fi
      # Make sure the destination directory exists, then make symlink
      # for all files.
      mkdir -p $i
      qpushd $i
        # Only search for files
        for item in $(find "${symlink_srcroot}" -type f); do
          ln -sf "$item" .
        done
      qpopd
    done
  qpopd
}

SRCROOT_SUFFIX=src
DEPS_ROOT="$(dirname_abs ${BASH_SOURCE[0]})"
NGINX_ROOT="${DEPS_ROOT}/nginx"
REDIS_ROOT="${DEPS_ROOT}/redis"
NGINX_SRCROOT="${NGINX_ROOT}/${SRCROOT_SUFFIX}"
REDIS_SRCROOT="${REDIS_ROOT}/${SRCROOT_SUFFIX}"
NGINX_NAME="nginx-1.4.2"
REDIS_NAME="redis-2.6.15"
NGINX_TAR_NAME="${NGINX_NAME}.tar.gz"
REDIS_TAR_NAME="${REDIS_NAME}.tar.gz"

# Fetch nginx
fetch \
  "http://nginx.org/download/${NGINX_TAR_NAME}" \
  "${NGINX_SRCROOT}" "${NGINX_TAR_NAME}" \
|| die "Failed to fetch ${NGINX_TAR_NAME}..."
# Fetch redis
fetch \
  "http://download.redis.io/releases/${REDIS_TAR_NAME}" \
  "${REDIS_SRCROOT}" "${REDIS_TAR_NAME}" \
|| die "Failed to fetch ${REDIS_TAR_NAME}..."

# Extract the source archives, and make "current" symlink point to them
qpushd "${NGINX_SRCROOT}"
  tar xvzf "${NGINX_TAR_NAME}"
  rm "${NGINX_TAR_NAME}"
  ln -sf "${NGINX_NAME}" current
qpopd
qpushd "${REDIS_SRCROOT}"
  tar xvzf "${REDIS_TAR_NAME}"
  rm "${REDIS_TAR_NAME}"
  ln -sf "${REDIS_NAME}" current
qpopd

# Build nginx
qpushd "${NGINX_SRCROOT}/current"
  ./configure \
    --prefix=${NGINX_ROOT} \
    --with-http_ssl_module \
  && make clean \
  && make \
  && make install
qpopd
# Build redis
qpushd "${REDIS_SRCROOT}/current"
  make all \
  && make test \
  && make install PREFIX="${REDIS_ROOT}"
qpopd

# Make executable files available in deps root
create_symlinks "${NGINX_ROOT}" bin sbin
create_symlinks "${REDIS_ROOT}" bin sbin
