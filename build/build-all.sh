#!/usr/bin/env bash
# Builds the AppImage from a fresh clone. Needs podman (or docker: set ENGINE=docker), git, curl.
#   build/build-all.sh     -> dist/whisper-subs-VERSION-x86_64.AppImage
# Steps: fetch sources + models (verified) -> build container (Ubuntu 22.04 + Vulkan SDK) ->
# whisper.cpp -> FFmpeg -> package. Compiling takes ~10 minutes on a 4-core CPU.
set -euo pipefail
P=$(cd "$(dirname "$0")/.." && pwd)
ENGINE=${ENGINE:-podman}

"$P/build/fetch.sh"
"$ENGINE" build -t whisper-subs-build -f "$P/build/Containerfile" "$P/build"
"$ENGINE" run --rm -v "$P:/work" whisper-subs-build /work/build/build-engine.sh
"$ENGINE" run --rm -v "$P:/work" whisper-subs-build /work/build/build-ffmpeg.sh
"$P/build/package.sh"
