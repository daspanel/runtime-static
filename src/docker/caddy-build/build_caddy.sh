#!/usr/bin/env bash
#
# Author: @nikolaizujev
#
# Big respect to @mholt6 for making Caddy
#
# This script is based on:
#  - https://www.calhoun.io/building-caddy-server-from-source/
#  - https://g.liams.io/liam/simple-build-caddy.git 
#
#/ Usage:
#/   build_caddy.sh [-h]
#/
#/ It builds Caddy with plugins defined in `plugins` file.
#/
#/ Cross compilation:
#/   $ env OS=darwin ./build_caddy.sh
#/   $ env OS=linux ARCH=amd64 ./build_caddy.sh
#/   $ env OS=linux ARCH=arm ARM=7 ./build_caddy.sh
#/
#/ Environment variables:
#/   UPDATE=1   - force pull updates
#/   OS=        - GOOS for which to build
#/   ARCH=      - GOARCH for which to build
#/   ARM=       - GOARM for which to build

set -eo pipefail

if [[ "$1" == "--help" || "$1" == '-h' ]]; then
	grep ^#/ "$0" | cut -c4-
	exit
fi

function error {
	echo >&2 "ERROR: ${1:-unknown error occured}"
	exit 1
}

function reset_git {
	pushd "${1}"
	local branch="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
	# stash uncommited changes
	git add . && git stash
	git checkout -f "${branch}"
	popd
}

for cmd in go git sed; do
  command -v "${cmd}" >/dev/null 2>&1 || error "I require '${cmd}', but it's not installed"
done

HERE="$(pwd)"
UPDATE="${UPDATE:-}"
CADDY_VERSION="${CADDY_VERSIONX:-v0.10.9}"

OS="${OS:-}"
ARCH="${ARCH:-}"
ARM="${ARM:-}"

GOPATH="${GOPATH:-$HOME/go}"

FILE_PLUGINS_LIST="${HERE}/plugins"
DIR_CADDY_SOURCE="${GOPATH}/src/github.com/mholt/caddy"
DIR_CADDY_BUILDS="${GOPATH}/src/github.com/caddyserver/builds"

mkdir -p "${GOPATH}/src"

[ ! -d "${DIR_CADDY_SOURCE}" ] || reset_git "${DIR_CADDY_SOURCE}"
[ ! -d "${DIR_CADDY_BUILDS}" ] || reset_git "${DIR_CADDY_BUILDS}"

go get -d -v ${UPDATE:+-u} github.com/mholt/caddy  
go get -d -v ${UPDATE:+-u} github.com/caddyserver/builds  

PLUGINS=

# https://stackoverflow.com/questions/22080937/bash-skip-blank-lines-when-iterating-through-file-line-by-line
while read plugin; do 
	if [[ "$plugin" =~ [^[:space:]] ]]; then
		go get -d -v ${UPDATE:+-u} "${plugin}"
		PLUGINS="${PLUGINS}${plugin} "
	fi
done < "${FILE_PLUGINS_LIST}"

# patch caddy
pushd "${DIR_CADDY_SOURCE}"

git checkout -q "${CADDY_VERSION}"

REVISION="$(git rev-parse --short HEAD)"
CURRENT_TAG="$(git describe --exact-match HEAD 2>/dev/null || true)"
LATEST_TAG="$(git describe --abbrev=0 --tags HEAD || true)"

[[ "${CURRENT_TAG}" == "${LATEST_TAG}" ]] || REVISION="${LATEST_TAG:++}${REVISION}"

echo
echo "Caddy build info"
echo "  - version : ${CURRENT_TAG:-${LATEST_TAG}} (${REVISION})"
echo "  - plugins : ${PLUGINS:--}"
echo "  - GOOS=${OS:-}"
echo "  - GOARCH=${ARCH:-}"
echo "  - GOARM=${ARM:-}"
echo

# --- add plugins
while read plugin; do 
	if [[ "$plugin" =~ [^[:space:]] ]]; then
		sed -i -e "/other plugins get plugged in/a \\\t_ \"${plugin}\"" caddy/caddymain/run.go
	fi
done < "${FILE_PLUGINS_LIST}"

# --- remove sponsor header
# just for BC sake - https://github.com/mholt/caddy/pull/1866
#sed -i -e '/sponsors/d' caddyhttp/httpserver/server.go 

# --- add build verbosity
sed -i -e '/args :=/a \\targs = append(args, "-v")' caddy/build.go

popd

# patch build flags
pushd "${DIR_CADDY_BUILDS}"

# --- reduce build size
sed -i -e '/var ldflags/c\ldflags := []string{"-w", "-s"}' compilation.go
# --- avoid git dirty-state messages in `caddy -version`
sed -i -e '/diff-index/c\return "", nil' compilation.go

popd

# execute build itself
pushd "${DIR_CADDY_SOURCE}/caddy"

go run build.go ${OS:+-goos=${OS}} ${ARCH:+-goarch=${ARCH}} ${ARM:+-goarm=${ARM}}

mv -f caddy "${HERE}"

popd

cd $HERE

echo "=============================================="
./caddy -validate
echo "=============================================="

echo "DONE"

