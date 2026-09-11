#!/usr/bin/env bash
# Builds edge-case test media for whisper-subs QA.
set -u
T=$(cd "$(dirname "$0")" && pwd)
Q=$T/qa
J=$T/speech/jfk.flac
rm -rf "$Q" && mkdir -p "$Q" && cd "$Q" || exit 1
V=(-f lavfi -i testsrc=size=160x120:rate=10)
mk() { ffmpeg -loglevel error -y "$@" || echo "FAILED to build: ${*: -1}"; }
H264=(-c:v libx264 -c:a aac)

mk "${V[@]}" -i $J -shortest "${H264[@]}" -- "-dash.mp4"
mk "${V[@]}" -i $J -shortest "${H264[@]}" "it's \"quoted\" \$HOME [1] ü 🎬.mp4"
mk "${V[@]}" -i $J -shortest "${H264[@]}" UPPER.MP4
mk "${V[@]}" -i $J -shortest "${H264[@]}" -f mp4 noext
mk "${V[@]}" -i $J -shortest "${H264[@]}" multi.dot.name.mkv
mk "${V[@]}" -i $J -shortest "${H264[@]}" .hidden.mp4
mk -f lavfi -i testsrc=size=160x120:rate=10:duration=5 -c:v libx264 "no audio.mp4"
mk -i $J -c:a libmp3lame "audio only.mp3"
mk "${V[@]}" -i $J -shortest -c:v mpeg4 -c:a libmp3lame legacy.avi
mk "${V[@]}" -i $J -shortest -c:v libvpx-vp9 -deadline realtime -c:a libopus web.webm
printf '1\n00:00:00,000 --> 00:00:02,000\nold sub\n\n' > old.srt
mk "${V[@]}" -i $J -i old.srt -shortest -map 0 -map 1 -map 2 "${H264[@]}" -c:s mov_text "with subs.mp4"
mk "${V[@]}" -i $J -i $J -shortest -map 0 -map 1 -map 2 "${H264[@]}" "two audio.mkv"
mk "${V[@]}" -i $J -shortest "${H264[@]}" -timecode 01:00:00:00 timecode.mov
# Written to a pipe (non-seekable), so the container has no duration.
ffmpeg -loglevel error -y "${V[@]}" -i $J -shortest "${H264[@]}" -f matroska - > streamed.mkv
mk "${V[@]}" -i $J -shortest "${H264[@]}" clip.mp4
mk "${V[@]}" -i $J -shortest "${H264[@]}" clip.mkv

ls -A1
echo "--- durations:"
for f in streamed.mkv legacy.avi noext "audio only.mp3"; do
    printf '%s: [%s]\n' "$f" "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")"
done
echo "--- timecode.mov streams:"; ffprobe -v error -show_entries stream=codec_type,codec_name -of csv=p=0 timecode.mov
