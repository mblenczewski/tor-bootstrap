#!/bin/sh

echo "Please run this script as the root user!"
read -p "Press enter to continue..." _

ZLIB_PREFIX="/usr/local"
LIBEVENT_PREFIX="/usr/local"
LIBRESSL_PREFIX="/usr/local"

TOR_PREFIX="/usr/local"
TOR_USER=tor
TOR_GROUP=tor

groupadd ${TOR_GROUP}
useradd ${TOR_USER} -g ${TOR_GROUP}

SRC="sources"

# creating source directory
[ -d $SRC ] && rm -rf $SRC/* || mkdir $SRC
cd $SRC

# source package definitions
ZLIB_VER="1.2.11"
ZLIB_PKG="zlib-$ZLIB_VER"
ZLIB_ARCHIVE="$ZLIB_PKG.tar.gz"

LIBEVENT_VER="2.1.12-stable"
LIBEVENT_PKG="libevent-$LIBEVENT_VER"
LIBEVENT_ARCHIVE="$LIBEVENT_PKG.tar.gz"

LIBRESSL_VER="3.3.1"
LIBRESSL_PKG="libressl-$LIBRESSL_VER"
LIBRESSL_ARCHIVE="$LIBRESSL_PKG.tar.gz"

TOR_VER="0.4.4.6"
TOR_PKG="tor-$TOR_VER"
TOR_ARCHIVE="$TOR_PKG.tar.gz"

# fetch sources
wget http://zlib.net/${ZLIB_ARCHIVE}
wget https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VER}/${LIBEVENT_ARCHIVE}
wget https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/${LIBRESSL_ARCHIVE}
wget https://dist.torproject.org/${TOR_ARCHIVE}

# building packages
tar xf $ZLIB_ARCHIVE
cd $ZLIB_PKG

./configure \
	--prefix="${ZLIB_PREFIX}" \
	--const

make && make install
cd ..

tar xf $LIBEVENT_ARCHIVE
cd $LIBEVENT_PKG

./configure \
	--prefix="${LIBEVENT_PREFIX}"

make && make install
cd ..


tar xf $LIBRESSL_ARCHIVE
cd $LIBRESSL_PKG

./configure \
	--prefix="${LIBRESSL_PREFIX}"

make && make install
cd ..

tar xf $TOR_ARCHIVE
cd $TOR_PKG

./configure \
	--prefix="${TOR_PREFIX}" \
	--with-tor-user=${TOR_USER} \
	--with-tor-group=${TOR_GROUP} \
	\
	--with-openssl-dir="${LIBRESSL_PREFIX}" \
	--with-libevent-dir="${LIBEVENT_PREFIX}" \
	--with-zlib-dir="${ZLIB_PREFIX}"

make && make install

cp ../../conf/torrc ${TOR_PREFIX}/etc/tor/torrc

mkdir /var/lib/tor /var/log/tor /var/run/tor
chown -R $TOR_USER:$TOR_GROUP /var/lib/tor /var/log/tor /var/run/tor

touch /var/run/tor/tor.pid
cd ..

