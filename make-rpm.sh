#!/bin/bash

set -e

PKG_NAME="odcey"
MAINTAINER_NAME="comdivbyzero"
MAINTAINER_EMAIL="project-Vostok@yandex.ru"

MAINTAINER="${MAINTAINER_NAME} <${MAINTAINER_EMAIL}>"
RPM_TOPDIR="${HOME}/rpmbuild"
SOURCES_DIR="${RPM_TOPDIR}/SOURCES"
SPECS_DIR="${RPM_TOPDIR}/SPECS"


mkdir -p "${SOURCES_DIR}" "${SPECS_DIR}"

VERSION="$(ost run 'log.sn(odcey.Version)' -m .)"

TMP="$(mktemp -d)"
NAME="${PKG_NAME}-${VERSION}"
mkdir -p "${TMP}/${NAME}/pregen"
cp *.mod LICENSE README.md "${TMP}/${NAME}/"
ost to-c odcey.Cli "${TMP}/${NAME}/pregen/" -m .
IMPL="share/vostok/singularity/implementation"
cd /usr/$IMPL || cd /usr/local/$IMPL
cp o7.[hc] CFiles.[hc] Platform.[hc] Uint32.h Int32.h Windows_.[hc] ArrayFill.h ArrayCopy.h CLI.[hc] OsEnv.[hc] OsExec.[hc] "${TMP}/${NAME}/pregen/"
cd "${TMP}"
tar czf "${SOURCES_DIR}/${NAME}.tar.gz" "${NAME}"
cd -
rm -rf "${TMP}"

SPEC_FILE="${SPECS_DIR}/${PKG_NAME}.spec"
cat > "${SPEC_FILE}" <<EOF
Name:           ${PKG_NAME}
Version:        ${VERSION}
Release:        0%{?dist}
Summary:        Converter of Blackbox .odc to UTF-8

License:        Apache-2.0
URL:            https://github.com/vostok-space/odcey
Source0:        %{name}-%{version}.tar.gz

Requires:       glibc

%description
A command-line tool to convert .odc files from Blackbox Component Builder
into UTF-8 plain text.

%prep
%setup -q

%build
%define CCC cc -O2 -flto=auto -s -Wl,--build-id
ost to-bin odcey.Cli odcey -m . -cc "%{CCC}" || %{CCC} pregen/*.c -Ipregen -o odcey

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 odcey %{buildroot}/usr/bin/odcey

%files
%license LICENSE
%doc README.md
/usr/bin/odcey

%changelog
* Sat 21 Feb 2026 ${MAINTAINER} - 0.4
- Added option -write-descriptors
- Paragraph separator converts to line feed
- The last char is always line feed when printing to stdout
- Fixed links reading

* Mon 9 Feb 2026 ${MAINTAINER} - 0.3.2
- Used «git config» command instead of editing .git/config
- Fixed a lot of minor drawbacks

* Sun 1 Feb 2026 ${MAINTAINER} - 0.3.1
- Fixed excess memory allocation

* Tue Jan 27 2026 ${MAINTAINER} - 0.3
- Command «text» has become optional
- Fixed correction of characters SHORTCHAR, specific to Blackbox, in Utf-8

* Thu Jul 24 2025 ${MAINTAINER} - 0.2
- Initial package
EOF

rpmbuild -ba "${SPEC_FILE}"

ls -l ~/*/SRPMS/$NAME*.rpm ~/*/RPMS/*/$NAME*.rpm
