#!/bin/zsh
#
# Build script for Outset

# Variables
XCODE_PATH="/Applications/Xcode_14.2.app"
XCODE_ORIGINAL_PATH="/Applications/Xcode_14.2.app"
APP_SIGNING_IDENTITY="Developer ID Application: Mac Admins Open Source (T4SK8ZXCXG)"
INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Mac Admins Open Source (T4SK8ZXCXG)"
MP_SHA="71c57fcfdf43692adcd41fa7305be08f66bae3e5"
MP_BINDIR="/tmp/munki-pkg"
CONSOLEUSER=$(/usr/bin/stat -f "%Su" /dev/console)
TOOLSDIR=$(dirname $0)
BUILDSDIR="$TOOLSDIR/build"
OUTPUTSDIR="$TOOLSDIR/outputs"
MP_ZIP="/tmp/munki-pkg.zip"
XCODE_BUILD_PATH="$XCODE_PATH/Contents/Developer/usr/bin/xcodebuild"
XCODE_NOTARY_PATH="$XCODE_PATH/Contents/Developer/usr/bin/notarytool"
XCODE_STAPLER_PATH="$XCODE_PATH/Contents/Developer/usr/bin/stapler"
CURRENT_OUTSET_MAIN_BUILD_VERSION=$(/usr/libexec/PlistBuddy -c Print:CFBundleVersion $TOOLSDIR/Outset/Info.plist)
NEWSUBBUILD=$((21615 + $(git rev-parse HEAD~0 | xargs -I{} git rev-list --count {})))

# automate the build version bump
AUTOMATED_OUTSET_BUILD="$CURRENT_OUTSET_MAIN_BUILD_VERSION.$NEWSUBBUILD"
/usr/bin/xcrun agvtool new-version -all $AUTOMATED_OUTSET_BUILD
/usr/bin/xcrun agvtool new-marketing-version $AUTOMATED_OUTSET_BUILD

# Create files to use for build process info
echo "$AUTOMATED_OUTSET_BUILD" > $TOOLSDIR/build_info.txt
echo "$CURRENT_OUTSET_MAIN_BUILD_VERSION" > $TOOLSDIR/build_info_main.txt

# Ensure Xcode is set to run-time
sudo xcode-select -s "$XCODE_PATH"

if [ -e $XCODE_BUILD_PATH ]; then
  XCODE_BUILD="$XCODE_BUILD_PATH"
else
  ls -la /Applications
  echo "Could not find required Xcode build. Exiting..."
  exit 1
fi

# Build Outset
echo "Building Outset"
$XCODE_BUILD -project "$TOOLSDIR/outset.xcodeproj" -scheme "Outset App Bundle" archive CODE_SIGN_IDENTITY=$APP_SIGNING_IDENTITY OTHER_CODE_SIGN_FLAGS="--timestamp"
XCB_RESULT="$?"
if [ "${XCB_RESULT}" != "0" ]; then
    echo "Error running xcodebuild: ${XCB_RESULT}" 1>&2
    exit 1
fi

# Zip application for notary
/bin/mkdir -p "$BUILDSDIR"
/usr/bin/ditto -c -k --keepParent "$BUILDSDIR/Build/Products/Release/Outset.app" "${BUILDSDIR}/Outset.zip"

DITTO_RESULT="$?"
if [ "${DITTO_RESULT}" != "0" ]; then
    echo "Error running ditto: ${XCB_RESULT}" 1>&2
    exit 1
fi

# Setup notary item
$XCODE_NOTARY_PATH store-credentials --apple-id "opensource@macadmins.io" --team-id "T4SK8ZXCXG" --password "$2" outset
# Notarize Outset application
$XCODE_NOTARY_PATH submit "${BUILDSDIR}/Outset.zip" --keychain-profile "outset" --wait

# Create outputs folder
if [ -e $OUTPUTSDIR ]; then
  /bin/rm -rf $OUTPUTSDIR
fi
/bin/mkdir -p "$OUTPUTSDIR"

if ! [ -n "$1" ]; then
  echo "Did not pass option to create package"
  # Move notarized zip to outputs folder
  /bin/mv "${BUILDSDIR}/Outset.zip" "$OUTPUTSDIR"
  exit 0
fi

# Download specific version of munki-pkg
echo "Downloading munki-pkg tool from github..."
if [ -f "${MP_ZIP}" ]; then
    /usr/bin/sudo /bin/rm -rf ${MP_ZIP}
fi
/usr/bin/curl https://github.com/munki/munki-pkg/archive/${MP_SHA}.zip -L -o ${MP_ZIP}
if [ -d ${MP_BINDIR} ]; then
    /usr/bin/sudo /bin/rm -rf ${MP_BINDIR}
fi
/usr/bin/unzip ${MP_ZIP} -d ${MP_BINDIR}
DL_RESULT="$?"
if [ "${DL_RESULT}" != "0" ]; then
    echo "Error downloading munki-pkg tool: ${DL_RESULT}" 1>&2
    exit 1
fi

# Create the package
echo "Creating Outset package"
PKG_PATH="$TOOLSDIR/OutsetPkg"
if [ -e $PKG_PATH ]; then
  /bin/rm -rf $PKG_PATH
fi
/bin/mkdir -p "$PKG_PATH/payload/usr/local/outset"
/bin/mkdir -p "$PKG_PATH/scripts"
/usr/bin/sudo /usr/sbin/chown -R ${CONSOLEUSER}:wheel "$PKG_PATH"
/bin/cp -R "$TARGET_BUILD_DIR/Outset.app" "$PKG_PATH/payload/usr/local/outset/Outset.app"
/bin/cp -R "$TOOLSDIR/Package/outset" "$PKG_PATH/payload/usr/local/outset/outset"
/bin/chmod a+x "$PKG_PATH/payload/usr/local/outset/outset"
/bin/cp "$TOOLSDIR/Package/Scripts/postinstall" "$PKG_PATH/scripts/postinstall"

# Create the json file for signed munkipkg Outset pkg
/bin/cat << SIGNED_JSONFILE > "$PKG_PATH/build-info.json"
{
  "ownership": "recommended",
  "suppress_bundle_relocation": true,
  "identifier": "io.macadmins.Outset",
  "postinstall_action": "none",
  "distribution_style": true,
  "version": "$AUTOMATED_OUTSET_BUILD",
  "name": "Outset-$AUTOMATED_OUTSET_BUILD.pkg",
  "install_location": "/usr/local/outset",
  "signing_info": {
    "identity": "$INSTALLER_SIGNING_IDENTITY",
    "timestamp": true
  }
}
SIGNED_JSONFILE

# Create the signed Outset pkg
python3 "${MP_BINDIR}/munki-pkg-${MP_SHA}/munkipkg" "$PKG_PATH"
PKG_RESULT="$?"
if [ "${PKG_RESULT}" != "0" ]; then
  echo "Could not sign package: ${PKG_RESULT}" 1>&2
else
  # Notarize Outset package
  $XCODE_NOTARY_PATH submit "$PKG_PATH/build/Outset-$AUTOMATED_OUTSET_BUILD.pkg" --keychain-profile "outset" --wait
  $XCODE_STAPLER_PATH staple "$PKG_PATH/build/Outset-$AUTOMATED_OUTSET_BUILD.pkg"
  # Move the Outset signed/notarized pkg
  /bin/mv "$PKG_PATH/build/Outset-$AUTOMATED_OUTSET_BUILD.pkg" "$OUTPUTSDIR"
fi
