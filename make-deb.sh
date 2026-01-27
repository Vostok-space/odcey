#!/bin/bash

set -e

ARCH="$(dpkg --print-architecture)"
TARGET_ARCH="${1:-$ARCH}"
BUILD_DIR="built/debian"
DEB_DIR="${BUILD_DIR}/odcey_${TARGET_ARCH}"
MAINTAINER_0="comdivbyzero <project-Vostok@yandex.ru>"
MAINTAINER="${MAINTAINER_0}"

trash -f "${BUILD_DIR}"
mkdir -p ${DEB_DIR}/{DEBIAN,usr/bin,usr/share/doc/odcey}

if [ "$TARGET_ARCH" = "i386" ] && [ "$ARCH" = "amd64" ]; then
  CC="cc -m32"
else
  CC="cc"
fi

ost to-bin odcey.Cli "${DEB_DIR}/usr/bin/odcey" -m . -cc "$CC -flto=auto -O2 -s"
chmod 755 "${DEB_DIR}/usr/bin/odcey"

VERSION="$(${DEB_DIR}/usr/bin/odcey version)"
DEB_FILE="odcey_${VERSION}_${TARGET_ARCH}.deb"

cat > "${DEB_DIR}/DEBIAN/control" <<EOF
Package: odcey
Version: ${VERSION}
Section: utils
Priority: optional
Depends: libc6
Architecture: ${TARGET_ARCH}
Maintainer: ${MAINTAINER}
Description: Converter of Blackbox Component Builder .odc to the plain UTF-8
 A command-line tool to convert .odc files from Blackbox Component Builder
 into human-readable UTF-8 text format.
EOF

cat > "${DEB_DIR}/usr/share/doc/odcey/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: odcey
Source: https://github.com/vostok-space/odcey

Files: *
Copyright: 2025-2026 comdivbyzero
License: Apache-2.0
EOF

cat > "${DEB_DIR}/usr/share/doc/odcey/changelog" <<EOF
odcey (0.3) stable; urgency=low

  * Fixed correction of characters SHORTCHAR, specific to Blackbox, in Utf-8

 -- ${MAINTAINER_0}  Tue, 27 Jan 2026 00:00:00 +0200

odcey (0.2) stable; urgency=low

  * Initial package

 -- ${MAINTAINER_0}  Tue, 25 Mar 2025 00:00:00 +0200
EOF
gzip -9n "${DEB_DIR}/usr/share/doc/odcey/changelog"

find "${DEB_DIR}" -type d -exec chmod 0755 {} +
find "${DEB_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 "${DEB_DIR}/usr/bin/odcey"

fakeroot dpkg-deb --build "${DEB_DIR}" "built/${DEB_FILE}"
lintian "built/${DEB_FILE}"
