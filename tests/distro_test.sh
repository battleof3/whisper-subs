#!/usr/bin/env bash
# Runs the AppImage in minimal containers of other distros (no FUSE, no GPU): checks startup
# without FUSE, the extract-and-run fallback, CPU fallback, and a full transcription.
# Usage: distro_test.sh [image...]
set -u
T=$(cd "$(dirname "$0")" && pwd)
APPIMAGE=$(ls "$T"/../dist/whisper-subs-*-x86_64.AppImage | tail -1)
IMAGES=("$@"); (( ${#IMAGES[@]} )) || IMAGES=(ubuntu:22.04 debian:12 fedora:latest archlinux:latest)

for img in "${IMAGES[@]}"; do
    d=$T/distro/${img//[:\/]/_}
    rm -rf "$d" && mkdir -p "$d"
    ffmpeg -loglevel error -nostdin -y -f lavfi -i testsrc=size=160x120:rate=10 -i "$T/speech/jfk.flac" \
        -shortest -c:v libx264 -c:a aac "$d/fellow americans.mp4"
    echo "== $img"
    podman run --rm -v "$APPIMAGE:/app/whisper-subs.AppImage:ro" -v "$d:/work" -w /work "docker.io/library/$img" bash -c '
        . /etc/os-release; echo "   distro: $PRETTY_NAME, glibc $(ldd --version | head -1 | grep -o "[0-9.]*$")"
        echo "   without FUSE, no flag: $(/app/whisper-subs.AppImage --version 2>&1 | head -2 | tr "\n" " " | cut -c1-110)"
        out=$(/app/whisper-subs.AppImage --appimage-extract-and-run "fellow americans.mp4" 2>&1); code=$?
        echo "$out" | grep -E "✓|✗|!|Done in|whisper-subs:" | sed "s/^/   /"
        echo "   exit=$code  transcript: $(head -c 60 "fellow americans (subtitled)/fellow americans.txt" 2>/dev/null)"
        echo "   leftover extraction dirs: $(ls -d /tmp/appimage_extracted_* 2>/dev/null | wc -l)"
    ' 2>&1
done
