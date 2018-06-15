#!/bin/bash

VERSION=1.0
CWD=$(pwd)
PACKAGES="$CWD/packages"
WORKSPACE="$CWD/workspace"
SCRATCH="scratch"
SOURCE
cc=clang

# LDFLAGS="-L${WORKSPACE}/lib -lm"	# 指定链接的lib文件
# CFLAGS="-I${WORKSPACE}/include"	# 指定链接的头文件
# PKG_CONFIG_PATH="${WORKSPACE}/lib/pkgconfig"

CONFIGURE_FLAGS="--enable-cross-compile --disable-stripping --disable-optimizations --disable-armv5te --disable-armv6 --disable-armv6t2 --disable-programs \
                 --disable-doc --enable-pic --disable-lzma --enable-debug"

ARCHS="x86_64"

# Speed up the process
# Env var NUMJOBS overrides automatic detection
if [[ -n $NUMJOBS ]]; then
    MJOBS=$NUMJOBS
elif [[ -f /proc/cpuinfo ]]; then
    MJOBS=$(grep -c processor /proc/cpuinfo)
elif [[ "$OSTYPE" == "darwin"* ]]; then
	MJOBS=$(sysctl -n machdep.cpu.thread_count)
else
    MJOBS=4
fi

make_dir () {
	if [ ! -d $1 ]; then
		if ! mkdir $1; then			
			printf "\n Failed to create dir %s" "$1";
			exit 1
		fi
	fi	
}

remove_dir () {
	if [ -d $1 ]; then
		rm -r "$1"
	fi	
}

execute () {
	echo "$ $*"

	OUTPUT=$($@ 2>&1)

	if [ $? -ne 0 ]; then
		echo "$OUTPUT"
		echo ""
		echo "Failed to Execute &*" >&2
		exit 1
	fi
}

download () {
	if [ ! -f "$PACKAGES/$2" ]; then
		
		echo "Downloading $1"
		curl -L --show-error -o "$PACKAGES/$2" "$1" --progress
		
		EXITCODE=$?
		if [ $EXITCODE -ne 0 ]; then
			echo ""
			echo "Failed to download $1. Exitcode $EXITCODE. Retrying in 10 seconds";
			sleep 10
			curl -L --show-error -o "$PACKAGES/$2" "$1" --progress
		fi
		
		EXITCODE=$?
		if [ $EXITCODE -ne 0 ]; then
			echo ""
			echo "Failed to download $1. Exitcode $EXITCODE";
			exit 1
		fi
		
		echo "... Done"
		
		if ! tar -xvf "$PACKAGES/$2" -C "$PACKAGES" 2>/dev/null >/dev/null; then
			echo "Failed to extract $2";
			exit 1
		fi
		
	fi

	for objName in $(ls $PACKAGES)
	do
		# SOURCE is absolute path
		[ -d $PACKAGES/$objName ] && SOURCE=$PACKAGES/$objName
	done

	echo "SOURCE is $SOURCE"
}

build () {
	echo "building $1"
	echo "==========="

	if [ -f "$PACKAGES/$1.done" ]; then
		echo "$1 alread built."
		return 1
	fi
}

command_exists() {
	if ! [[ -x $(command -v "$1") ]]; then
		return 1
	fi
	return 0
}


if ! command_exists "make"; then
	echo "make not install"
	exit 1
else
	echo "make is install"
fi

if ! command_exists "g++"; then
	echo "g++ not install"
	exit 1
else
	echo "g++ is install"
fi

if ! command_exists "curl"; then
	echo "curl not install"
	exit 1
else
	echo "curl is install"
fi

# echo "make install"

echo "packages $PACKAGES"
echo "MJOBS $MJOBS"

if build "yasm"; then
	echo "down yasm"
fi

echo "Using $MJOBS make jobs simultaneously."

make_dir $PACKAGES
make_dir $WORKSPACE

export PATH=${WORKSPACE}/bin:$PATH

echo "PATH $PATH"
echo "OSTYPE $OSTYPE"
TYPE="darwin"*
echo "TYPE $TYPE"

if [[ "$OSTYPE" == "darwin"* ]]; then
	echo "mac os"
fi

build "ffmpeg"
download "http://ffmpeg.org/releases/ffmpeg-4.0.tar.bz2" "ffmpeg-snapshot.tar.bz2"

for ARCH in $ARCHS
do
	echo "build $ARCH..."
	mkdir -p "$SCRATCH/$ARCH"
	cd "$SCRATCH/$ARCH"

	CFLAGS="-arch $ARCH"

	CC="clang"
	AS="$CC"

	CXXFLAGS="$CFLAGS"
	LDFLAGS="$CFLAGS"

	$SOURCE/configure \
        --target-os=darwin \
		--arch=$ARCH \
	    --cc="$CC" \
	    --as="$AS" \
	    $CONFIGURE_FLAGS \
	    --extra-cflags="$CFLAGS" \
	    --extra-ldflags="$LDFLAGS" \
	    --prefix="${WORKSPACE}"
	    # --prefix="$THIN/$ARCH"

	# install 将编译生成的lib和.h文件安装到"$THIN/$ARCH"目录下
	# make -j8 install || exit 1
	execute make -j $MJOBS install || exit 1

done


echo "compile and install Doned"



exit 1

# cd $PACKAGES/ffmpeg-4.0 || exit

$CWD/packages/ffmpeg-4.0/configure \
# $PACKAGES/ffmpeg-4.0/configure \
# $CWD/configure \
    # --pkgconfigdir="$WORKSPACE/lib/pkgconfig" \
    # --pkg-config-flags="--static" \
    # --extra-cflags="-I$WORKSPACE/include" \
    # --extra-ldflags="-L$WORKSPACE/lib" \
    # --extra-libs="-lpthread -lm" \
    --target-os=darwin \
    --cc="clang"
	--enable-static \
	--disable-debug \
	--disable-shared \
	--disable-ffplay \
	--disable-doc \
	--prefix="${WORKSPACE}" \
	# --enable-gpl \
	# --enable-version3 \
	# --enable-nonfree \
	# --enable-pthreads \
	# --enable-libvpx \
	# --enable-libmp3lame \
	# --enable-libtheora \
	# --enable-libvorbis \
	# --enable-libx264 \
	# --enable-libx265 \
	# --enable-runtime-cpudetect \
	# --enable-libfdk-aac \
	# --enable-avfilter \
	# --enable-libopencore_amrwb \
	# --enable-libopencore_amrnb \
	# --enable-filters \
	# --enable-libvidstab
	# enable all filters
	# enable AAC de/encoding via libfdk-aac [no]
	# enable detecting cpu capabilities at runtime (smaller binary)
	# enable HEVC encoding via x265 [no]
	# enable H.264 encoding via x264 [no]
	# enable Vorbis en/decoding via libvorbis, native implementation exists [no]
	# enable Theora encoding via libtheora [no]
	# enable MP3 encoding via libmp3lame [no]
	# enable VP8 and VP9 de/encoding via libvpx [no]
	# enable pthreads [autodetect]
	# allow use of nonfree code, the resulting libs and binaries will be unredistributable [no]
	# upgrade (L)GPL to version 3 [no]
	# allow use of GPL code, the resulting libs and binaries will be under GPL [no]
	# do not build documentation
	# disable ffserver build
	# disable ffplay build
	# build static libraries [no]
	# disable debugging symbols
	# disable build shared libraries [no]
execute make -j $MJOBS install


