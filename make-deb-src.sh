#!/bin/bash

set -euo pipefail

PACKAGE_NAME="odcey"
VERSION="0.4"
ARCHIVE_NAME="${PACKAGE_NAME}_${VERSION}.orig.tar.gz"
DEB_DIR="${PACKAGE_NAME}-${VERSION}"
MAINTAINER="comdivbyzero <project-Vostok@yandex.ru>"

mkdir -p built
cd built

rm -rf -- "${DEB_DIR}" "${ARCHIVE_NAME}"

mkdir -p "${DEB_DIR}"
cp ../*.mod ../README.md ../LICENSE "${DEB_DIR}/"

tar -czf "${ARCHIVE_NAME}" "${DEB_DIR}"

mkdir -p "${DEB_DIR}/debian/source"

cat > "${DEB_DIR}/debian/changelog" <<EOT
odcey (${VERSION}) unstable; urgency=medium

  * Build source and binary Debian packages from upstream .mod sources.

 -- ${MAINTAINER}  Wed, 26 Feb 2026 00:00:00 +0000
EOT

MISC_DEP='${misc:Depends}'
SHLIBS_DEP='${shlibs:Depends}'

cat > "${DEB_DIR}/debian/control" <<EOT
Source: odcey
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.6.2
Homepage: https://github.com/vostok-space/odcey
Rules-Requires-Root: no

Package: odcey
Architecture: any
Depends: ${MISC_DEP}, ${SHLIBS_DEP}
Description: converter of Blackbox Component Builder .odc format to plain text
 A command-line tool to convert .odc files from Blackbox Component Builder
 into human-readable UTF-8 text format.
EOT

cat > "${DEB_DIR}/debian/rules" <<'EOT'
#!/usr/bin/make -f

%:
	dh $@

override_dh_auto_build:
	ost to-bin odcey.Cli odcey -m . -cc "cc -flto=auto -O2 -s"

override_dh_auto_install:
	install -D -m 0755 odcey debian/odcey/usr/bin/odcey
EOT
chmod +x "${DEB_DIR}/debian/rules"

echo "3.0 (quilt)" > "${DEB_DIR}/debian/source/format"

cat > "${DEB_DIR}/debian/copyright" <<EOT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: odcey
Source: https://github.com/vostok-space/odcey

Files: *
Copyright: 2025-2026 comdivbyzero
License: Apache-2.0
EOT

cd "${DEB_DIR}"
dpkg-buildpackage -S -us -uc
dpkg-buildpackage -b -us -uc

cd ..
ls -al
