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

# Install a Linux-hosted iOS toolchain.
# Use L1ghtmann's iOSToolchain (the currently maintained one): its ld64
# understands modern SDK .tbd stubs (!tapi-tbd), which the old sbingner
# clang-10 linker did not. A marker file records which toolchain is present
# so we can replace an older one on rebuild.
TOOLCHAIN_DIR="$THEOS/toolchain/linux/iphone"
MARKER="$THEOS/toolchain/.iostoolchain"
if [ ! -f "$MARKER" ]; then
  ARCH="$(uname -m)"   # x86_64 on Codespaces
  rm -rf "$THEOS/toolchain/linux"
  mkdir -p "$THEOS/toolchain"
  curl -fL --retry 3 \
    "https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-$ARCH.tar.xz" \
    -o /tmp/toolchain.tar.xz
  tar -xf /tmp/toolchain.tar.xz -C "$THEOS/toolchain"
  rm -f /tmp/toolchain.tar.xz
  touch "$MARKER"
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
