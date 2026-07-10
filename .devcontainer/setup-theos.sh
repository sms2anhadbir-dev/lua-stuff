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

# Install an iOS SDK (patched for non-Mac hosts)
SDK_DIR="$THEOS/sdks"
if [ -z "$(ls -A "$SDK_DIR" 2>/dev/null | grep -i iphoneos || true)" ]; then
  git clone --depth 1 https://github.com/theos/sdks.git /tmp/sdks
  # keep a recent SDK only, to save space
  cp -r /tmp/sdks/iPhoneOS16.5.sdk "$SDK_DIR/" 2>/dev/null || cp -r /tmp/sdks/*.sdk "$SDK_DIR/"
  rm -rf /tmp/sdks
fi

echo "export THEOS=$HOME/theos" >> "$HOME/.bashrc"
echo 'export PATH=$PATH:$THEOS/bin' >> "$HOME/.bashrc"
echo "Theos setup complete. Run: make"
