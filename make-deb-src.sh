#!/bin/bash

set -e

PACKAGE_NAME="odcey"
VERSION="0.2"
ARCHIVE_NAME="odcey_${VERSION}.orig.tar.gz"
DEB_DIR="odcey-${VERSION}"
MAINTAINER_0="comdivbyzero project-Vostok@yandex.ru"
MAINTAINER="${MAINTAINER_0}"

mkdir -p built
cd built

trash -f "${DEB_DIR}" "${ARCHIVE_NAME}"

mkdir -p "${DEB_DIR}/debian"
cp ../*.mod "${DEB_DIR}/"

cat > "${DEB_DIR}/debian/changelog" <<EOF
odcey (0.2) stable; urgency=low

  * initial package

 -- ${MAINTAINER_0}  Tue, 25 Mar 2025 00:00:00 +0200

EOF

tar -czf "${ARCHIVE_NAME}" "${DEB_DIR}"
trash -f ${DEB_DIR}/*.mod

mkdir -p "${DEB_DIR}/debian/source"
cat > "${DEB_DIR}/debian/control" <<EOF
Source: odcey
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.5.0
Homepage: https://github.com/vostok-space/odcey
Rules-Requires-Root: no

Package: odcey
Architecture: any
Depends: libc6
Description: converter of Blackbox Component Builder .odc format to plain text
EOF

cat > "${DEB_DIR}/debian/rules" <<EOF
#!/usr/bin/make -f

BINDIR=\$(CURDIR)/debian/odcey/usr/bin

binary:
	pwd
	mkdir -p \$(BINDIR)
	ost to-bin odcey.Cli \$(BINDIR)/odcey -m . -m ../.. -cc "cc -flto=auto -O2 -s"
	chmod 755 \$(BINDIR)/odcey

clean:

.PHONY: binary clean
EOF
chmod +x "${DEB_DIR}/debian/rules"

echo 13 > "${DEB_DIR}/debian/compat"

echo "3.0 (quilt)" > "${DEB_DIR}/debian/source/format"

cd "${DEB_DIR}"
dpkg-buildpackage -S --no-sign
dpkg-buildpackage -b --no-sign

ls -al "${DEB_DIR}"

cd ../..
