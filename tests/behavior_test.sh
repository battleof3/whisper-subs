#!/usr/bin/env bash
# Behavior checks for whisper-subs (bash version): prompts, reruns, no speech, options, drag mode.
# Usage: behavior_test.sh   (uses tests/speech/jfk.flac; works in tests/behavior/)
set -u
T=$(cd "$(dirname "$0")" && pwd)
WS=${WS:-$T/../dist/AppDir/usr/bin/whisper-subs}
B=$T/behavior
rm -rf "$B" && mkdir -p "$B" && cd "$B" || exit 1
pass=0 fail=0
check() {  # label condition...
    local label=$1; shift
    if "$@"; then pass=$((pass + 1)); echo "  PASS $label"; else fail=$((fail + 1)); echo "  FAIL $label"; fi
}
not() { ! "$@"; }
mkvid() { ffmpeg -loglevel error -nostdin -y -f lavfi -i testsrc=size=160x120:rate=10 -i "$T/speech/jfk.flac" -shortest -c:v libx264 -c:a aac "$1"; }

echo "## modular outputs: --subs-only, fill in later, --force"
mkvid a.mp4
"$WS" --subs-only a.mp4 > r1.log 2>&1
check "subs-only: .srt and .txt made" test -s "a (subtitled)/a.srt" -a -s "a (subtitled)/a.txt"
check "subs-only: no subtitled video" not test -e "a (subtitled)/a.subtitled.mp4"
check "subs-only: original moved into folder" test -f "a (subtitled)/a.mp4"
srt_before=$(stat -c %Y "a (subtitled)/a.srt"); sleep 1.1
"$WS" "a (subtitled)/a.mp4" > r2.log 2>&1
check "default run afterwards: reuses subtitles" grep -q "Using the existing subtitles" r2.log
check "  ...no re-transcription (.srt not rewritten)" test "$(stat -c %Y "a (subtitled)/a.srt")" = "$srt_before"
check "  ...subtitled video added" test -f "a (subtitled)/a.subtitled.mp4"
rm "a (subtitled)/a.txt"
"$WS" "a (subtitled)/a.mp4" > r3.log 2>&1
check "missing transcript rebuilt from subtitles" grep -q "Transcript rebuilt" r3.log
check "  ...and it exists again" test -s "a (subtitled)/a.txt"
"$WS" "a (subtitled)/a.mp4" > r4.log 2>&1; code=$?
check "complete: 'Nothing to do', exit 0" bash -c '[ $0 = 0 ] && grep -q "Nothing to do" "$1"' $code r4.log
"$WS" --force "a (subtitled)/a.mp4" > r5.log 2>&1
check "--force re-transcribes" grep -q "Transcribed in" r5.log
check "  ...(.srt rewritten)" test "$(stat -c %Y "a (subtitled)/a.srt")" != "$srt_before"

echo "## re-run from inside the output folder"
echo y | "$WS" "a (subtitled)/a.mp4" > run4.log 2>&1
check "reuses the folder (no nested folder)" [ ! -e "a (subtitled)/a (subtitled)" ]
check "reports success" grep -q "Nothing to do" run4.log

echo "## silent video"
ffmpeg -loglevel error -nostdin -y -f lavfi -i testsrc=size=160x120:rate=10:duration=5 -f lavfi -i anullsrc=r=16000:cl=mono -shortest -c:v libx264 -c:a aac silent.mp4
"$WS" silent.mp4 > silent.log 2>&1; code=$?
check "no speech: exit 1" [ $code = 1 ]
check "no speech: message" grep -q "No speech found" silent.log
check "no speech: folder cleaned up" [ ! -e "silent (subtitled)" ]
check "no speech: original kept" [ -f silent.mp4 ]
"$WS" --no-vad silent.mp4 > silent_novad.log 2>&1
check "--no-vad transcribes silence (Whisper invents text)" grep -q "Done in" silent_novad.log

echo "## --cpu and --language auto"
mkvid b.mp4
"$WS" --cpu b.mp4 > cpu.log 2>&1
check "--cpu runs on the CPU" grep -q "on the CPU" cpu.log
check "--cpu output correct" grep -qi "fellow americans" "b (subtitled)/b.txt"
echo "     ($(grep -o 'Transcribed in [^o]*' cpu.log))"
mkvid c.mkv
"$WS" --language auto c.mkv > auto.log 2>&1
check "--language auto tags detected language (eng)" \
    [ "$(ffprobe -v error -select_streams s -show_entries stream_tags=language -of csv=p=0 "c (subtitled)/c.subtitled.mkv")" = eng ]
check "--language auto: no English style prompt used" not grep -q "Hello, and welcome" "c (subtitled)/c.srt"

echo "## options"
"$WS" --bogus > bogus.log 2>&1; code=$?
check "unknown option: exit 1" [ $code = 1 ]
check "unknown option: message" grep -q "unknown option" bogus.log
"$WS" --help | grep -q -- "--install"; check "--help lists --install" [ $? = 0 ]
"$WS" < /dev/null > nofiles.log 2>&1; code=$?
check "no files + no terminal: exit 1" [ $code = 1 ]
check "no files + no terminal: usage shown" grep -q Usage nofiles.log

echo "## drag-and-drop mode (simulated terminal)"
mkvid "drag me.mp4"
printf '%s\n' "$(printf '%q' "$B/drag me.mp4")" | script -qfec "'$WS'" drag.tty > /dev/null
check "dropped (escaped) path processed" [ -f "drag me (subtitled)/drag me.subtitled.mp4" ]
check "prompt shown" grep -q "Drag video file" drag.tty

echo "== $pass pass, $fail fail"
(( fail == 0 ))
