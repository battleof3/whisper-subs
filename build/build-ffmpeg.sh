#!/usr/bin/env bash
# Builds a slim, LGPL ffmpeg + ffprobe for whisper-subs. Run inside the whisper-subs-build container:
#   podman run --rm -v "$PWD:/work" whisper-subs-build /work/build/build-ffmpeg.sh
# whisper-subs only needs to read any common audio/video, write 16 kHz WAV for whisper.cpp, and
# remux with a new subtitle track (-c copy), so every native decoder/demuxer/muxer is kept but video
# encoders, hardware acceleration and auto-detected system libraries are left out.
set -euo pipefail

VERSION=9.0.1
SRC=/work/src/ffmpeg-$VERSION
OUT=/work/dist/ffmpeg

if [ ! -d "$SRC" ]; then
    curl -sSfL "https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz" | tar -xJ --no-same-owner -C /work/src
fi

BUILD=/work/build/ffmpeg-build
rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD"
"$SRC/configure" \
    --prefix="$BUILD/install" \
    --disable-autodetect \
    --enable-zlib \
    --disable-debug --disable-doc --disable-ffplay \
    --disable-network --disable-devices --disable-hwaccels \
    --disable-x86asm \
    --disable-encoders \
    --enable-encoder=pcm_s16le,movtext,srt,subrip,webvtt,ass,ssa \
    --enable-small

make -j"$(nproc)"

rm -rf "$OUT" && mkdir -p "$OUT"
cp ffmpeg ffprobe "$OUT/"
strip "$OUT/ffmpeg" "$OUT/ffprobe"

# The encoders whisper-subs uses (configure names differ from runtime names, e.g. movtext/mov_text).
for enc in pcm_s16le mov_text subrip; do
    "$OUT/ffmpeg" -hide_banner -encoders 2>/dev/null | grep -qw "$enc" || { echo "MISSING ENCODER: $enc" >&2; exit 1; }
done

echo "== contents"; ls -la "$OUT"
echo "== license"; "$OUT/ffmpeg" -hide_banner -L 2>&1 | head -3
echo "== highest glibc symbol version required"
for f in "$OUT"/*; do objdump -T "$f" | grep -o 'GLIBC_[0-9.]*'; done | sort -uV | tail -1
echo "== dynamic dependencies"
for f in "$OUT"/*; do readelf -d "$f" | grep NEEDED | grep -oP '\[\K[^]]+'; done | sort -u
