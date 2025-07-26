#!/bin/bash

set -ex

# add /opt/bin to search path
export PATH=/opt/homebrew/bin/:$PATH

# cd script dir
cd "$(dirname "$0")" || exit
cd ..

GIT_ROOT=$(pwd)

if [ ! -e "Chromatic.xcworkspace" ]; then
    echo "Chromatic.xcworkspace not found!"
    exit 1
fi

# bartycrouch update
# bartycrouch lint
# swiftformat . --swiftversion 5.10 || true

if [ ! -e "build" ]; then
    mkdir build
else
    if [ "$1" = "clean" ]; then
        rm -rf build
        mkdir build
    fi
fi
cd build || exit

python3 "$GIT_ROOT/Resources/compile.license.py"

cd $GIT_ROOT
commit=$(git rev-parse HEAD | cut -c 1-7)
TIMESTAMP=$(TZ=UTC-8 date '+%s').${commit}
cd build

WORKING_ROOT="Release-$TIMESTAMP"

if [ -e "$WORKING_ROOT" ]; then
    rm -rf "$WORKING_ROOT"
fi

mkdir "$WORKING_ROOT"
cd "$WORKING_ROOT" || exit

WORKING_ROOT=$(pwd)
echo "Starting build at $WORKING_ROOT"

xcodebuild -workspace "$GIT_ROOT/Chromatic.xcworkspace" \
    -scheme Chromatic -configuration Release \
    -derivedDataPath "$WORKING_ROOT/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    -arch arm64 \
    -sdk iphoneos \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" \
    GCC_GENERATE_DEBUGGING_SYMBOLS=YES STRIP_INSTALLED_PRODUCT=NO \
    COPY_PHASE_STRIP=NO UNSTRIPPED_PRODUCT=NO \
    ONLY_ACTIVE_ARCH=YES \
    | tee build.log || exit 1

echo "Build completed, checking output..."
find "$WORKING_ROOT/DerivedDataApp/Build/Products" -name "*.app" -type d

mkdir PackageBuilder
cd PackageBuilder || exit

ENV_PREFIX=""

mkdir -p ".$ENV_PREFIX/Applications"

# 查找.app文件并复制
echo "Searching for .app files..."
APP_PATH=$(find "$WORKING_ROOT/DerivedDataApp/Build/Products" -name "*.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: No .app file found in build output!"
    echo "Contents of build directory:"
    find "$WORKING_ROOT/DerivedDataApp/Build/Products" -type d | head -20
    exit 1
fi
echo "Found .app file: $APP_PATH"
APP_NAME=$(basename "$APP_PATH" .app)
echo "App name: $APP_NAME"
cp -r "$APP_PATH" ".$ENV_PREFIX/Applications/"

codesign --remove ".$ENV_PREFIX/Applications/$APP_NAME.app"
if [ -e ".$ENV_PREFIX/Applications/$APP_NAME.app/_CodeSignature" ]; then
    rm -rf ".$ENV_PREFIX/Applications/$APP_NAME.app/_CodeSignature"
fi
if [ -e ".$ENV_PREFIX/Applications/$APP_NAME.app/embedded.mobileprovision" ]; then
    rm -rf ".$ENV_PREFIX/Applications/$APP_NAME.app/embedded.mobileprovision"
fi

curl -L -o "$GIT_ROOT/ldid_macosx_x86_64" https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_macosx_x86_64
chmod +x "$GIT_ROOT/ldid_macosx_x86_64"
"$GIT_ROOT/ldid_macosx_x86_64" -S"$GIT_ROOT/Application/Chromatic/Entitlements.plist" ".$ENV_PREFIX/Applications/$APP_NAME.app/$APP_NAME"
plutil -replace "CFBundleDisplayName" -string "Saily" ".$ENV_PREFIX/Applications/$APP_NAME.app/Info.plist"
plutil -replace "CFBundleIdentifier" -string "wiki.qaq.chromatic.release" ".$ENV_PREFIX/Applications/$APP_NAME.app/Info.plist"
plutil -replace "CFBundleVersion" -string "3.0" ".$ENV_PREFIX/Applications/$APP_NAME.app/Info.plist"
plutil -replace "CFBundleShortVersionString" -string "$TIMESTAMP" ".$ENV_PREFIX/Applications/$APP_NAME.app/Info.plist"

cp -r "$GIT_ROOT/build/License/ScannedLicense" ".$ENV_PREFIX/Applications/$APP_NAME.app/Bundle/ScannedLicense"
cp -r "$GIT_ROOT/Resources/DEBIAN" ./

# sed -i '' "s/ENV_PREFIX=\"\"/ENV_PREFIX=\"\/var\/jb\/\"/g" ./DEBIAN/postinst

sed -i '' "s/@@VERSION@@/3.0-roothide-release-$TIMESTAMP/g" ./DEBIAN/control
sed -i '' "s/iphoneos-arm/iphoneos-arm64e/g" ./DEBIAN/control
sed -i '' "s/Package: wiki.qaq.chromatic/Package: wiki.qaq.chromatic.roothide/g" ./DEBIAN/control
sed -i '' "s/Name: Saily/Name: Saily (RootHide)/g" ./DEBIAN/control
mv ./DEBIAN/control ./DEBIAN/control_
awk '{print} END{print "Conflicts: wiki.qaq.chromatic"}' ./DEBIAN/control_ > ./DEBIAN/control

chmod -R 0755 DEBIAN

PKG_NAME="chromatic.rel.ci.$TIMESTAMP.deb"
dpkg-deb -b . "../$PKG_NAME"

echo "Finished build at $WORKING_ROOT"
echo "Package available at $WORKING_ROOT/$PKG_NAME"

mv $WORKING_ROOT/$PKG_NAME  $GIT_ROOT

cd "$GIT_ROOT"/build

if [ -e ".lastbuild.timestamp" ]; then
    rm -rf ".lastbuild.timestamp"
fi

echo "$TIMESTAMP" > ".lastbuild.timestamp"