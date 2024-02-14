#!/bin/bash

# Dependencies

export PATH=$(pwd)/depot_tools:$PATH

# Get depot tools
if [ ! -d "depot_tools" ]; then
  git clone --depth=1 --no-tags --single-branch https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi

# Clone dawn

if [ ! -d "dawn" ]; then
  git clone --depth=1 --no-tags --single-branch https://dawn.googlesource.com/dawn
else
  cd dawn
  git restore src/dawn/native/CMakeLists.txt
  git pull --force --no-tags
  cd ..
fi

cd dawn
cp scripts/standalone.gclient .gclient
gclient sync
cd ..

cat extra.cmake >> dawn/src/dawn/native/CMakeLists.txt

cmake                                   \
  -S dawn                               \
  -B dawn.build                         \
  -D CMAKE_BUILD_TYPE=Release           \
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW   \
  -D BUILD_SHARED_LIBS=off              \
  -D BUILD_SAMPLES=OFF                  \
  -D DAWN_USE_WAYLAND=ON                \
  -D DAWN_ENABLE_D3D12=OFF              \
  -D DAWN_ENABLE_D3D11=OFF              \
  -D DAWN_ENABLE_NULL=OFF               \
  -D DAWN_ENABLE_DESKTOP_GL=OFF         \
  -D DAWN_ENABLE_OPENGLES=OFF           \
  -D DAWN_ENABLE_VULKAN=ON              \
  -D DAWN_BUILD_SAMPLES=OFF             \
  -D TINT_BUILD_SAMPLES=OFF             \
  -D TINT_BUILD_DOCS=OFF                \
  -D TINT_BUILD_TESTS=OFF

# NOTE: webgpu target is in extra.cmake
cmake --build dawn.build --config Release --target webgpu --parallel 4

cp dawn.build/gen/include/dawn/webgpu.h .
cp dawn.build/src/dawn/native/libwebgpu.so .

if [ -n "$GITHUB_WORKFLOW" ]; then

  DAWN_COMMIT=$(<dawn/.git/refs/heads/main)
  echo "$DAWN_COMMIT" > dawn_commit.txt

  LDATE=$(date +"%Y%m%d%H%M%S")
  BUILD_DATE="${LDATE:0:4}-${LDATE:4:2}-${LDATE:6:2}"

  tar -czvf webgpu-"$BUILD_DATE".zip libwebgpu.so webgpu.h dawn_commit.txt

  echo "DAWN_COMMIT=$DAWN_COMMIT" >> $GITHUB_ENV
  echo "BUILD_DATE=$BUILD_DATE" >> $GITHUB_ENV

fi
