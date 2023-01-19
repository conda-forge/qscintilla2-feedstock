#!/bin/bash
set -ex
set -o pipefail

SIP_COMMAND="sip-build"
EXTRA_FLAGS=""

export SIP_DIR="${PREFIX}/lib/python${PY_VER}/site-packages/PyQt5/bindings"
export QMAKEFEATURES=${SRC_DIR}/src/features/

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

cd ${SRC_DIR}/designer
qmake
make
make install

## Build Python module ##
echo "========================"
echo "Building Python bindings"
echo "========================"

# Go to python folder
cd ${SRC_DIR}/Python
# Configure compilation of Python Qsci module
mv pyproject{-qt5,}.toml
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
	echo "[tool.sip.project]
	sip-include-dirs = [\"${BUILD_PREFIX}/lib/python${PY_VER}/site-packages/PyQt5/bindings\", \"${BUILD_PREFIX}/share/sip\"]" >> pyproject.toml
else
	echo "[tool.sip.project]
	sip-include-dirs = [\"${PREFIX}/lib/python${PY_VER}/site-packages/PyQt5/bindings\", \"${PREFIX}/share/sip\"]" >> pyproject.toml
fi

# Force correct flags for cross python compilation
# https://github.com/conda-forge/cross-python-feedstock/pull/65
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  SIP_COMMAND="$BUILD_PREFIX/bin/python -m sipbuild.tools.build"
  SITE_PKGS_PATH=$($PREFIX/bin/python -c 'import site;print(site.getsitepackages()[0])')
  EXTRA_FLAGS="--target-dir $SITE_PKGS_PATH"
fi

$SIP_COMMAND \
    --no-make \
    --qsci-features-dir ../src/features \
    --qsci-include-dir ../src \
    --qsci-library-dir ../src \
    --api-dir ${PREFIX}/qsci/api/python \
$EXTRA_FLAGS

#$PYTHON configure.py --pyqt=PyQt${QT_MAJOR_VER} --sip=$PREFIX/bin/sip --qsci-incdir=${PREFIX}/include/qt --qsci-libdir=${PREFIX}/lib --spec=${BUILD_SPEC} --no-qsci-api
# Build it
cd build

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
  # Make sure BUILD_PREFIX sip-distinfo is called instead of the HOST one
  cat Makefile | sed -r 's|\t(.*)sip-distinfo(.*)|\t'$BUILD_PREFIX/bin/python' -m sipbuild.distinfo.main \2|' > Makefile.temp
  rm Makefile
  mv Makefile.temp Makefile
fi

make
# Install QSci.so to the site-packages folder
make install

