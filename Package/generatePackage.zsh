#!/bin/zsh

set -x

cd "${BUILT_PRODUCTS_DIR}"

STAGING_DIRECTORY="${TMPDIR}/staging"
INSTALL_LOCATION="/usr/local/outset/"
INSTALL_ASSETS=${SCRIPT_INPUT_FILE_1}
INSTALL_SCRIPTS=${SCRIPT_INPUT_FILE_2}
APP_NAME=${PROJECT_NAME}
IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER}"
VERSION="${MARKETING_VERSION}"

# Clean staging dir
rm -r "${STAGING_DIRECTORY}"

# Set up a staging directory with the contents to install.
mkdir -p "${STAGING_DIRECTORY}/${INSTALL_LOCATION}"
cp "outset" "${STAGING_DIRECTORY}/${INSTALL_LOCATION}"
cp -r "Outset.app" "${STAGING_DIRECTORY}/${INSTALL_LOCATION}"
cp -r "${INSTALL_ASSETS}" "${STAGING_DIRECTORY}"

# Generate the component property list.
pkgbuild --analyze --root "${STAGING_DIRECTORY}" component.plist

# Force the installation package (.pkg) to not be relocatable.
# This ensures the package components install in `INSTALL_LOCATION`.
plutil -replace BundleIsRelocatable -bool no component.plist

# Build a temporary package using the component property list.
pkgbuild --root "${STAGING_DIRECTORY}" --component-plist component.plist --identifier "${IDENTIFIER}" --version "${VERSION}" --scripts "${INSTALL_SCRIPTS}" tmp-package.pkg

# Synthesize the distribution for the temporary package.
productbuild --synthesize --package tmp-package.pkg --identifier "${IDENTIFIER}" --version "${VERSION}" Distribution

# Synthesize the final package from the distribution.
productbuild --distribution Distribution --package-path "${BUILT_PRODUCTS_DIR}" "${SCRIPT_OUTPUT_FILE_0}"
