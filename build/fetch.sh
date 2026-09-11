#!/usr/bin/env bash
# Downloads everything the build needs that isn't in the repository, verifying checksums:
#   src/whisper.cpp/          whisper.cpp source at a fixed release tag
#   src/ffmpeg-VERSION/       FFmpeg source release (the tarball is kept too: it's attached to
#                             GitHub releases for LGPL compliance)
#   models/                   Whisper large-v3-turbo (q8_0) and Silero VAD, in ggml format
# Safe to re-run: existing, verified files are kept.
set -euo pipefail
cd "$(dirname "$0")/.."

WHISPER_CPP_TAG=v1.9.3
FFMPEG_VERSION=9.0.1
FFMPEG_SHA256=cf38e0e28c7e5605942c4a77755349b0145804a397af37eb1fb4c77cb237f635  # sha256 of the official release tarball (FFmpeg also signs it: .tar.xz.asc)
MODELS=(
    "ggml-large-v3-turbo-q8_0.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin 317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1"
    "ggml-silero-v6.2.0.bin https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin 2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987"
)

mkdir -p src models

if [[ ! -d src/whisper.cpp ]]; then
    echo "== whisper.cpp $WHISPER_CPP_TAG"
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$WHISPER_CPP_TAG" \
        https://github.com/ggml-org/whisper.cpp src/whisper.cpp
fi
[[ $(git -C src/whisper.cpp describe --tags) == "$WHISPER_CPP_TAG" ]] || { echo "src/whisper.cpp isn't at $WHISPER_CPP_TAG" >&2; exit 1; }

tarball=src/ffmpeg-$FFMPEG_VERSION.tar.xz
if [[ ! -f $tarball ]]; then
    echo "== FFmpeg $FFMPEG_VERSION"
    curl -sSfL -o "$tarball" "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz"
fi
echo "$FFMPEG_SHA256  $tarball" | sha256sum -c --quiet
[[ -d src/ffmpeg-$FFMPEG_VERSION ]] || tar -xJf "$tarball" --no-same-owner -C src

for m in "${MODELS[@]}"; do
    read -r name url sha <<< "$m"
    if [[ ! -f models/$name ]]; then
        echo "== $name"
        curl -sSfL -o "models/$name.part" "$url" && mv "models/$name.part" "models/$name"
    fi
    echo "$sha  models/$name" | sha256sum -c --quiet
done
echo "All sources and models present and verified."
