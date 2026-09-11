#!/usr/bin/env bash
# Sends Ctrl-C (SIGINT to the process group, like a terminal) to whisper-subs at a given phase
# and reports exit status and anything left behind.
# Usage: interrupt_test.sh <phase: load|transcribe|mux> <video>
S=$(cd "$(dirname "$0")" && pwd)
WS=${WS:-$S/../dist/AppDir/usr/bin/whisper-subs}  # script under test
phase=$1 video=$2
cd "$S/qa" || exit 1
name=${video%.*}
rm -rf "$name (subtitled)"
tmp_before=$(ls /tmp ~/.cache/whisper-subs 2>/dev/null | grep -c "^whisper-subs\.")

# withint.py restores SIGINT: jobs started in the background by a non-interactive shell have it
# ignored, and bash can't trap a signal that was ignored when it started.
setsid python3 "$S/withint.py" bash -c "'$WS' '$video' '$video.second.mp4' > '$S/int_$phase.log' 2>&1; echo \$? > '$S/int_$phase.code'" < /dev/null &
pg=$!
case $phase in
    load) sleep 3 ;;
    transcribe) sleep 14 ;;
    mux) # wait until ffmpeg starts writing the subtitled output
        for _ in $(seq 1 2400); do
            pgrep -f "ffmpeg -hide_banner.*subtitled" > /dev/null && break
            sleep 0.05
        done
        ls -la "$name (subtitled)/" | grep subtitled | sed 's/^/   partial output at interrupt: /' ;;
esac
kill -INT -- -$pg
wait $pg
sleep 0.5
echo "== phase=$phase exit=$(cat $S/int_$phase.code)  (130 expected)"
echo "   message: $(grep -o 'Interrupted' $S/int_$phase.log || echo MISSING)"
echo "   second video started? $(grep -c 'second' $S/int_$phase.log | sed 's/^1$/no/; s/^[2-9]$/YES/')"
echo "   temp files left: $(( $(ls /tmp ~/.cache/whisper-subs 2>/dev/null | grep -c "^whisper-subs\.") - tmp_before ))"
echo "   whisper/ffmpeg left: $(( $(pgrep -xc whisper-cli) + $(pgrep -xc ffmpeg) ))"
echo "   output folder: $(ls -A "$name (subtitled)" 2>/dev/null | tr '\n' '|' || true)$( [ -d "$name (subtitled)" ] || echo '(removed)')"
echo "   original still in place: $( [ -f "$video" ] && echo yes || echo NO)"
