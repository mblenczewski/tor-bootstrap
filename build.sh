#!/bin/bash


export ROOT=$(pwd)
export SOURCES="${ROOT}/src"
export LOGS="${ROOT}/logs"

export ZLIB_PREFIX="/usr/local/zlib"
export LIBEVENT_PREFIX="/usr/local/libevent"
export LIBRESSL_PREFIX="/usr/local/libressl"

export TOR_PREFIX="/usr/local/tor"
export TOR_USER=tor
export TOR_GROUP=tor


## Creating directory structure
[ -d "${SOURCES}" ] && rm -rf ${SOURCES}/* || mkdir ${SOURCES}
[ -d "${LOGS}" ] && rm -rf ${LOGS}/* || mkdir ${LOGS}


## Defines a package
## $1 : The name of the package variable group (e.g. MUSL, LINUX, GCC)
## $2 : The package source version
## $3 : The package source archive compression (e.g. gz, bz2, xz)
## $4 : The package source directory prefix
## $5 : The package source archive prefix. Overrides the PKG_DIR_PREFIX if defined
DEFINE () {
	local PKG_NAME=$1
	local PKG_VER=$2
	local PKG_COMPRESSION=$3
	local PKG_DIR_PREFIX=$4
	local PKG_ARCHIVE_PREFIX=$5

	local PKG_DIR=${PKG_DIR_PREFIX}${PKG_VER}
	local PKG_ARCHIVE=${PKG_ARCHIVE_PREFIX}${PKG_VER}.tar.${PKG_COMPRESSION}

	[ -n "${PKG_VER}" ] && printf -v ${PKG_NAME}_VER ${PKG_VER}
	printf -v ${PKG_NAME}_DIR ${PKG_DIR}
	printf -v ${PKG_NAME}_ARCHIVE ${PKG_ARCHIVE}

	export "${PKG_NAME}_VER" "${PKG_NAME}_DIR" "${PKG_NAME}_ARCHIVE"
}


## Extracts a package source archive, and runs the given callback function.
## $1 : Package definition variable group name (i.e. GCC, LINUX, ZLIB)
## $2 : Processing callback function, run in source directory after unzipping
## $3 : Vanity package name.
EXTRACT () {
	local PKG_VAR_GROUP_NAME=$1
	local PROCESS_FUNC=$2
	local PKG_VANITY_NAME=${3:-${PKG_VAR_GROUP_NAME}}

	local PKG_VER=${PKG_VAR_GROUP_NAME}_VER
	local PKG_VER=${!PKG_VER}
	local PKG_DIR=${PKG_VAR_GROUP_NAME}_DIR
	local PKG_DIR=${!PKG_DIR}
	local PKG_ARCHIVE=${PKG_VAR_GROUP_NAME}_ARCHIVE
	local PKG_ARCHIVE=${!PKG_ARCHIVE}

	echo "Extracting package ${PKG_VANITY_NAME} (ver. ${PKG_VER}) source: '${PKG_ARCHIVE}' -> '${PKG_DIR}'"
	pushd ${SOURCES} > /dev/null

	local STDOUT_LOG="${PKG_VANITY_NAME}.stdout.log"
	local STDERR_LOG="${PKG_VANITY_NAME}.stderr.log"

	echo "    stdout will be logged to '${STDOUT_LOG}'; stderr will be logged to '${STDERR_LOG}'"

	local TMP_OUT="${TMPDIR:-/tmp}/out.$$" TMP_ERR="${TMPDIR:-/tmp}/err.$$"
	mkfifo "${TMP_OUT}" "${TMP_ERR}"

	tar xf ${PKG_ARCHIVE} && cd ${PKG_DIR} && \
	$PROCESS_FUNC >"${TMP_OUT}" 2>"${TMP_ERR}" & \
	tee "${LOGS}/${STDOUT_LOG}" < "${TMP_OUT}" & \
	tee "${LOGS}/${STDERR_LOG}" < "${TMP_ERR}" && \
	echo "Successfully extracted and processed package ${PKG_VANITY_NAME}!" || \
	echo "Failed to extract or process package ${PKG_VANITY_NAME}!"

	cd ${SOURCES}

	rm "${TMP_OUT}" "${TMP_ERR}" > /dev/null
	popd > /dev/null
}


## Package definitions
###### NAME		VERSION		COMPRESSION	DIR_PREFIX	ARCHIVE_PREFIX
DEFINE "ZLIB"		"1.2.11" 	"gz"		"zlib-"		"zlib-"
DEFINE "LIBEVENT"	"2.1.12-stable"	"gz"		"libevent-"	"libevent-"
DEFINE "LIBRESSL"	"3.2.2"		"gz"		"libressl-"	"libressl-"
DEFINE "TOR"		"0.4.4.5"	"gz"		"tor-"		"tor-"


## Downloading package sources
pushd ${SOURCES} > /dev/null
	wget http://zlib.net/${ZLIB_ARCHIVE}
	wget https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VER}/${LIBEVENT_ARCHIVE}
	wget https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/${LIBRESSL_ARCHIVE}
	wget https://dist.torproject.org/${TOR_ARCHIVE}
popd > /dev/null


## Building packages
ZLIB () {
	echo "Extracted ZLIB!"

	./configure \
		--prefix="${ZLIB_PREFIX}" \
		--const

	make && make install
}
EXTRACT "ZLIB" ZLIB "zlib"


LIBEVENT () {
	echo "Extracted LIBEVENT!"

	./configure \
		--prefix="${LIBEVENT_PREFIX}"

	make && make install
}
EXTRACT "LIBEVENT" LIBEVENT "libevent"


LIBRESSL () {
	echo "Extracted LIBRESSL!"

	./configure \
		--prefix="${LIBRESSL_PREFIX}"

	make && make install
}
EXTRACT "LIBRESSL" LIBRESSL "libressl"


TOR () {
	echo "Extracted TOR!"

	./configure \
		--prefix="${TOR_PREFIX}" \
		--with-tor-user=${TOR_USER} \
		--with-tor-group=${TOR_GROUP} \
		\
		--with-openssl-dir="${LIBRESSL_PREFIX}" \
		--with-libevent-dir="${LIBEVENT_PREFIX}" \
		--with-zlib-dir="${ZLIB_PREFIX}"

	make && make install

	cp ${ROOT}/tor.service /lib/systemd/system/tor.service

	cp ${ROOT}/torrc ${TOR_PREFIX}/etc/tor/torrc

	groupadd ${TOR_GROUP}
	useradd ${TOR_USER} -g ${TOR_GROUP}

	mkdir /var/{lib,log}/tor
	chown -R tor:tor /var/{lib,log}/tor
}
EXTRACT "TOR" TOR "tor"

