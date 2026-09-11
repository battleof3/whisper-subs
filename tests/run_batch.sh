#!/usr/bin/env bash
# Runs whisper-subs on the given files (from the qa dir) while sampling VRAM and process-tree RSS.
# Usage: run_batch.sh <label> files...
S=$(cd "$(dirname "$0")" && pwd)
WS=${WS:-$S/../dist/AppDir/usr/bin/whisper-subs}  # script under test
label=$1; shift
cd "$S/qa" || exit 1

tmp_before=$(ls -d /tmp/whisper-subs.* ~/.cache/whisper-subs/whisper-subs.* 2>/dev/null | wc -l)
nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -lms 500 > "$S/$label.vram" 2>&1 &
nv=$!

start=$(date +%s%N)
yes y | "$WS" "$@" > "$S/$label.log" 2>&1 &
job=$!
peak_rss=0
while kill -0 $job 2>/dev/null; do
    # Sum RSS over every process descended from the job (bash, whisper-cli, ffmpeg...).
    pids=$(pstree -pT $job 2>/dev/null | grep -o '([0-9]\+)' | tr -d '()')
    rss=$(ps -o rss= -p $(echo $pids | tr ' ' ',') 2>/dev/null | awk '{s+=$1} END {print s+0}')
    (( rss > peak_rss )) && peak_rss=$rss
    sleep 0.5
done
wait $job; code=$?
end=$(date +%s%N)
kill $nv 2>/dev/null

idle=$(head -1 "$S/$label.vram")
peak=$(sort -n "$S/$label.vram" | tail -1)
last=$(tail -1 "$S/$label.vram")
echo "== $label: exit=$code  wall=$(( (end - start) / 1000000 )) ms  peak RSS=$(( peak_rss / 1024 )) MiB"
echo "   VRAM MiB: before=$idle peak=$peak after=$last"
echo "   leftover temp dirs: $(( $(ls -d /tmp/whisper-subs.* ~/.cache/whisper-subs/whisper-subs.* 2>/dev/null | wc -l) - tmp_before ))"
echo "   leftover whisper processes: $(pgrep -xc whisper-cli)"
