#!/bin/bash
set -ex
set -o pipefail

QT_MAJOR_VER=$(qmake -v | sed -n 's/.*Qt version \([0-9])*\).*/\1/p')
if [ -z "$QT_MAJOR_VER" ]; then
	echo "Could not determine Qt version of string provided by qmake:"
	echo $(qmake -v)
	echo "Aborting..."
	exit 1
else
	echo "Building Qscintilla for Qt${QT_MAJOR_VER}"
fi

# Set build specs depending on current platform (Mac OS X or Linux)
if [ $(uname) == Darwin ]; then
	BUILD_SPEC=macx-clang
else
	BUILD_SPEC=linux-g++
	# g++ cannot be found afterwards, solution taken from pyqt-feedstock
	mkdir bin || true
	pushd bin
		ln -s ${GXX} g++ || true
		ln -s ${GCC} gcc || true
	popd
	export PATH=${PWD}/bin:${PATH}
fi

echo "==========================="
echo "Building Qscintilla 2"
echo "Using build spec: ${BUILD_SPEC}"
echo "==========================="

# Go to Qscintilla source dir and then to its src folder.
cd ${SRC_DIR}/src
# Build the makefile with qmake
qmake qscintilla.pro -spec ${BUILD_SPEC} -config release

# Build Qscintilla
make -j${CPU_COUNT} ${VERBOSE_AT}
# and install it
echo "Installing QScintilla"
make install

## Build Python module ##
echo "========================"
echo "Building Python bindings"
echo "========================"

# Go to python folder
cd ${SRC_DIR}/Python
# Configure compilation of Python Qsci module
mv pyproject{-qt5,}.toml
  sip-build \
    --no-make \
    --qsci-features-dir ../src/features \
    --qsci-include-dir ../src \
    --qsci-library-dir ../src \
    --api-dir ${PREFIX}/qsci/api/python

#$PYTHON configure.py --pyqt=PyQt${QT_MAJOR_VER} --sip=$PREFIX/bin/sip --qsci-incdir=${PREFIX}/include/qt --qsci-libdir=${PREFIX}/lib --spec=${BUILD_SPEC} --no-qsci-api
# Build it
cd build
make
# Install QSci.so to the site-packages folder
make install

