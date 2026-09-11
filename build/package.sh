#!/usr/bin/env bash
# Assembles the AppDir from the built pieces and (unless "appdir" is given) packs the AppImage.
#   build/package.sh           AppDir + AppImage
#   build/package.sh appdir    AppDir only (for testing the script in its real layout)
# Inputs: src/whisper-subs, dist/engine/ (build-engine.sh), dist/ffmpeg/ (build-ffmpeg.sh), models/.
set -euo pipefail

P=$(cd "$(dirname "$0")/.." && pwd)
APPDIR=$P/dist/AppDir
VERSION=$(sed -n 's/^VERSION=//p' "$P/src/whisper-subs")
MODEL=ggml-large-v3-turbo-q8_0.bin
VAD_MODEL=ggml-silero-v6.2.0.bin

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib/whisper-subs" "$APPDIR/usr/share/whisper-subs/models"
install -m 755 "$P/src/whisper-subs" "$APPDIR/usr/bin/whisper-subs"
cp -a "$P/dist/engine" "$APPDIR/usr/lib/whisper-subs/engine"
install -m 755 "$P/dist/ffmpeg/ffmpeg" "$P/dist/ffmpeg/ffprobe" "$APPDIR/usr/lib/whisper-subs/"
# Hard links: the models are large and the AppDir is only a staging area.
cp -l "$P/models/$MODEL" "$P/models/$VAD_MODEL" "$APPDIR/usr/share/whisper-subs/models/"

# License texts for everything bundled (see THIRD_PARTY_NOTICES.md).
mkdir -p "$APPDIR/usr/share/licenses/whisper-subs"
cp "$P/LICENSE" "$P/THIRD_PARTY_NOTICES.md" "$P"/licenses/* "$APPDIR/usr/share/licenses/whisper-subs/"

cat > "$APPDIR/usr/share/whisper-subs/versions.txt" <<EOF
model:   Whisper large-v3-turbo (ggml q8_0), Silero VAD v6.2.0
engine:  whisper.cpp $(git -C "$P/src/whisper.cpp" describe --tags 2>/dev/null || echo unknown) (Vulkan + CPU backends)
ffmpeg:  $(basename "$(ls -d "$P"/src/ffmpeg-*/ | head -1)" | sed 's/^ffmpeg-//') (LGPL build)
EOF

# AppImage entry point + the desktop entry and icon appimagetool requires.
ln -s usr/bin/whisper-subs "$APPDIR/AppRun"
cat > "$APPDIR/whisper-subs.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=whisper-subs
Comment=Subtitles and transcripts for videos, made with Whisper
Exec=whisper-subs
Icon=whisper-subs
Terminal=true
Categories=AudioVideo;Video;
EOF
cp "$P/build/whisper-subs.svg" "$APPDIR/whisper-subs.svg"
ln -s whisper-subs.svg "$APPDIR/.DirIcon"

echo "AppDir ready: $APPDIR ($(du -shL "$APPDIR" | cut -f1))"
[[ ${1:-} == appdir ]] && exit 0

TOOL=$P/build/tools/appimagetool-x86_64.AppImage
if [[ ! -x $TOOL ]]; then
    mkdir -p "$(dirname "$TOOL")"
    curl -sSfL -o "$TOOL" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x "$TOOL"
fi
OUT=$P/dist/whisper-subs-$VERSION-x86_64.AppImage
ARCH=x86_64 "$TOOL" --no-appstream "$APPDIR" "$OUT"
echo "AppImage: $OUT ($(du -sh "$OUT" | cut -f1))"
