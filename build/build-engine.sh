#!/usr/bin/env bash
# Builds a portable whisper.cpp (whisper-cli + dynamically loaded CPU/Vulkan backends).
# Run inside the whisper-subs-build container, from the repository root (or use build-all.sh):
#   podman run --rm -v "$PWD:/work" whisper-subs-build /work/build/build-engine.sh
# Output: /work/dist/engine/ — whisper-cli and every .so it needs, all in one folder ($ORIGIN rpath).
set -euo pipefail

SRC=/work/src/whisper.cpp
BUILD=/work/build/cmake-build
OUT=/work/dist/engine

cmake -S "$SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_VULKAN=ON \
    -DGGML_OPENMP=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DWHISPER_SDL2=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -DCMAKE_SHARED_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -DCMAKE_MODULE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DCMAKE_INSTALL_RPATH='$ORIGIN'

cmake --build "$BUILD" -j"$(nproc)" --target whisper-cli

# Collect whisper-cli, its libraries, and every backend module into one folder.
rm -rf "$OUT" && mkdir -p "$OUT"
cp "$BUILD/bin/whisper-cli" "$OUT/"
find "$BUILD" \( -name 'libwhisper.so*' -o -name 'libggml*.so*' \) -exec cp -P {} "$OUT/" \;

echo "== contents"; ls -la "$OUT"
echo "== highest glibc symbol version required"
for f in "$OUT"/*; do objdump -T "$f" 2>/dev/null | grep -o 'GLIBC_[0-9.]*'; done | sort -uV | tail -1
echo "== dynamic dependencies outside the folder"
for f in "$OUT"/*; do readelf -d "$f" 2>/dev/null | grep NEEDED | grep -oP '\[\K[^]]+'; done | sort -u \
    | while read -r lib; do [ -e "$OUT/$lib" ] || echo "  $lib"; done
