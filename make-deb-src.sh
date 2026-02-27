#!/bin/bash

set -euo pipefail

VERSION="$(ost run odcey.Cli -m . -- version)"
FULLNAME="odcey_${VERSION}"
ARCHIVE_NAME="${FULLNAME}.orig.tar.gz"
DEB_DIR="odcey-${VERSION}"
MAINTAINER_0="comdivbyzero <project-Vostok@yandex.ru>"

mkdir -p "built/${DEB_DIR}/pregen"
cd built
BUILT="$PWD"

rm -rf -- "${DEB_DIR}"

mkdir -p "${DEB_DIR}/pregen"
cp ../*.mod ../README.md ../LICENSE "${DEB_DIR}/"

ost to-c odcey.Cli "${DEB_DIR}/pregen/" -m ..
IMPL="share/vostok/singularity/implementation"
cd /usr/$IMPL || cd /usr/local/$IMPL
cp o7.[hc] CFiles.[hc] Platform.[hc] Uint32.h Int32.h Windows_.[hc] ArrayFill.h ArrayCopy.h CLI.[hc] OsEnv.[hc] OsExec.[hc] "${BUILT}/${DEB_DIR}/pregen/"
cd "${BUILT}"

tar -czf "${ARCHIVE_NAME}" "${DEB_DIR}"

mkdir -p "${DEB_DIR}/debian/source"

cat > "${DEB_DIR}/debian/changelog" <<EOT
odcey (0.4) stable; urgency=low

  * Added option -write-descriptors
  * Paragraph separator converts to line feed
  * The last char is always line feed when printing to stdout
  * Fixed links reading

 -- ${MAINTAINER_0}  Sat, 21 Feb 2026 00:00:00 +0200

odcey (0.3.2) stable; urgency=low

  * Used «git config» command instead of editing .git/config
  * Fixed a lot of minor drawbacks

 -- ${MAINTAINER_0}  Mon, 9 Feb 2026 00:00:00 +0200

odcey (0.3.1) stable; urgency=low

  * Fixed excess memory allocation

 -- ${MAINTAINER_0}  Sun, 1 Feb 2026 00:00:00 +0200

odcey (0.3) stable; urgency=low

  * Command «text» has become optional
  * Fixed correction of characters SHORTCHAR, specific to Blackbox, in Utf-8

 -- ${MAINTAINER_0}  Tue, 27 Jan 2026 00:00:00 +0200

odcey (0.2) stable; urgency=low

  * Initial package

 -- ${MAINTAINER_0}  Tue, 25 Mar 2025 00:00:00 +0200
EOT

MISC_DEP='${misc:Depends}'
SHLIBS_DEP='${shlibs:Depends}'

cat > "${DEB_DIR}/debian/control" <<EOT
Source: odcey
Section: utils
Priority: optional
Maintainer: ${MAINTAINER_0}
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.6.2
Homepage: https://github.com/vostok-space/odcey
Rules-Requires-Root: no

Package: odcey
Architecture: any
Depends: ${MISC_DEP}, ${SHLIBS_DEP}
Description: converter of Blackbox Component Builder .odc format to plain text
 A command-line tool to convert .odc files from Blackbox Component Builder
 into UTF-8 plain text.
EOT

cat > "${DEB_DIR}/debian/rules" <<'EOT'
#!/usr/bin/make -f

include /usr/share/dpkg/architecture.mk

CFLAGS  := $(shell dpkg-buildflags --get CFLAGS)
LDFLAGS := $(shell dpkg-buildflags --get LDFLAGS)

ifeq ($(DEB_BUILD_ARCH),$(DEB_HOST_ARCH))
  CC ?= cc
else
  CC := $(DEB_HOST_GNU_TYPE)-gcc
endif

CCF := $(CC) $(CFLAGS) $(LDFLAGS)

%:
	dh $@

override_dh_auto_build:
	ost to-bin odcey.Cli odcey -m . -cc "$(CCF)" || $(CCF) pregen/*.c -Ipregen -o odcey

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
Copyright: 2022-2026 comdivbyzero
License: Apache-2.0
EOT

cd "${DEB_DIR}"
dpkg-buildpackage --build=source --no-sign
dpkg-buildpackage --build=binary --no-sign
dpkg-buildpackage --build=binary --no-sign --host-arch=i386

cd ..

tar --create --xz --file odcey_${VERSION}.deb.src.tar.xz \
    ${FULLNAME}*.dsc "${ARCHIVE_NAME}" ${FULLNAME}*.debian.tar.xz

ls -l ${FULLNAME}*.deb*
lintian ${FULLNAME}_*.deb
