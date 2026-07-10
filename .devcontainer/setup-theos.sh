#!/usr/bin/env bash
set -euo pipefail

# Install toolchain dependencies for Theos on Linux (GitHub Codespaces)
sudo apt-get update
sudo apt-get install -y build-essential fakeroot rsync perl curl git \
    libtinfo5 zstd libxml2 unzip

export THEOS=$HOME/theos

# Install Theos
if [ ! -d "$THEOS" ]; then
  git clone --recursive https://github.com/theos/theos.git "$THEOS"
fi

# Install a Linux-hosted iOS toolchain (Swift/Clang cross toolchain)
TOOLCHAIN_DIR="$THEOS/toolchain/linux/iphone"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
  mkdir -p "$THEOS/toolchain/linux"
  # Sam Bingner's Linux toolchain build
  curl -L https://github.com/sbingner/llvm-project/releases/download/v10.0.0-1/linux-ios-arm64e-clang-toolchain.tar.lzma \
    -o /tmp/toolchain.tar.lzma
  tar --lzma -xf /tmp/toolchain.tar.lzma -C "$THEOS/toolchain/linux"
  mv "$THEOS/toolchain/linux/ios-arm64e-clang-toolchain" "$TOOLCHAIN_DIR" || true
fi

# Install an iOS SDK. Must match the clang 10 toolchain above: newer SDKs
# (16.x) use syntax clang 10 can't parse, so we pin an older, compatible one.
SDK_DIR="$THEOS/sdks"
WANT_SDK="iPhoneOS14.5.sdk"
# Drop any previously installed too-new SDK so theos doesn't pick it.
rm -rf "$SDK_DIR"/iPhoneOS15* "$SDK_DIR"/iPhoneOS16* "$SDK_DIR"/iPhoneOS17* 2>/dev/null || true
if [ ! -d "$SDK_DIR/$WANT_SDK" ]; then
  rm -rf /tmp/sdks
  git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git /tmp/sdks
  git -C /tmp/sdks sparse-checkout set "$WANT_SDK"
  mkdir -p "$SDK_DIR"
  cp -a "/tmp/sdks/$WANT_SDK" "$SDK_DIR/"
  rm -rf /tmp/sdks
fi

echo "export THEOS=$HOME/theos" >> "$HOME/.bashrc"
echo 'export PATH=$PATH:$THEOS/bin' >> "$HOME/.bashrc"
echo "Theos setup complete. Run: make"
