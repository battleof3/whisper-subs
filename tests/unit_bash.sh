#!/usr/bin/env bash
# Unit tests for the bash whisper-subs: time/number helpers, drag-and-drop parsing, and the
# progress bar (width fitting and throughput). Usage: unit_bash.sh [path-to-script]
set -u
T=$(cd "$(dirname "$0")" && pwd)
SCRIPT=${1:-$T/../src/whisper-subs}
# shellcheck source=/dev/null
source "$SCRIPT"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
pass=0 fail=0
eq() {  # label expected actual
    if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "  FAIL $1: expected [$2] got [$3]"; fi
}

echo "## helpers"
eq "fmt_time 400ms" "0s" "$(fmt_time 400)"
eq "fmt_time 59.6s" "1m 00s" "$(fmt_time 59600)"
eq "fmt_time 125s" "2m 05s" "$(fmt_time 125000)"
eq "fmt_time 3600s" "1h 00m 00s" "$(fmt_time 3600000)"
eq "fmt_time 3725.2s" "1h 02m 05s" "$(fmt_time 3725200)"
eq "fmt_clock 3723s" "1:02:03" "$(fmt_clock 3723250)"
eq "fmt_clock 59s" "0:59" "$(fmt_clock 59999)"
eq "secs_to_ms 872.025397" "872025" "$(secs_to_ms 872.025397)"
eq "secs_to_ms 11" "11000" "$(secs_to_ms 11)"
eq "secs_to_ms 4.5" "4500" "$(secs_to_ms 4.5)"
eq "secs_to_ms N/A" "" "$(secs_to_ms N/A)"
eq "ts_to_ms 01:02:03.250" "3723250" "$(ts_to_ms 01:02:03.250)"
eq "ts_to_ms 00:00:08.090" "8090" "$(ts_to_ms 00:00:08.090)"
eq "language_tag en" "eng" "$(language_tag en)"
eq "language_tag xx" "und" "$(language_tag xx)"
eq "shorten" "hello w…" "$(shorten 'hello world' 8)"
echo "  helpers done"

echo "## drag-and-drop parsing"
mkdir -p "$W/d"
f1="$W/d/it's a [test] \$x.mp4"; f2="$W/d/plain.mp4"; f3="$W/d/café 🎬 (1).mkv"
touch "$f1" "$f2" "$f3"
check_drop() {  # label input expected-count
    local out=() p ok=1
    while IFS= read -r -d '' p; do out+=("$p"); [[ -f $p ]] || ok=0; done < <(parse_dropped "$2")
    if (( ok && ${#out[@]} == $3 )); then pass=$((pass + 1)); echo "  PASS $1 (${#out[@]})"
    else fail=$((fail + 1)); echo "  FAIL $1: got ${#out[@]} path(s): ${out[*]:-}"; fi
}
check_drop "raw path with spaces/quote" "$f1" 1
check_drop "backslash-escaped (ghostty)" "$(printf '%q' "$f1")" 1
check_drop "single-quoted (kitty)" "'${f2}' '${f3}'" 2
check_drop "double-quoted" "\"$f1\"" 1
check_drop "file:// URI" "file://$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$f1")" 1
check_drop "file:// URI, unicode" "file://$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$f3")" 1
check_drop "mixed + trailing space" "'$f2' $(printf '%q' "$f1")  " 2
if [[ $T == "$HOME"/* ]]; then  # a path under $HOME written with ~
    check_drop "tilde" "~/${T#"$HOME"/}/README.md" 1
else
    echo "  skip tilde (repository isn't under \$HOME)"
fi

echo "## progress bar width (frame must be narrower than the terminal)"
tty=1
update_cols() { term_cols=$TEST_COLS; }
width_fail=0
for TEST_COLS in 12 20 30 40 50 80 120; do
    for dur in 100000 36000000 ''; do
        frame=$(printf '[01:00:10.000 --> 01:00:20.000]  Some transcribed words here, café 🎬\n' \
            | progress "$dur" "$(now_us)" | tr '\r' '\n' | grep -v '^$' | tail -2 | head -1)
        plain=$(printf '%s' "$frame" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')
        w=$(printf '%s' "$plain" | wc -m)
        # the 🎬 and CJK-width halving make wc -m an under-estimate of columns by at most 1 per wide char
        if (( w >= TEST_COLS )); then width_fail=$((width_fail + 1)); echo "  WRAP cols=$TEST_COLS dur=$dur width=$w |$plain|"; fi
    done
done
(( width_fail == 0 )) && { pass=$((pass + 1)); echo "  PASS 21 frames fit"; } || fail=$((fail + 1))

echo "## progress throughput: 3000 segments (~3 h video)"
TEST_COLS=100
for (( i = 0; i < 3000; i++ )); do
    a=$(( i * 3600 )); b=$(( a + 3600 ))
    printf '[%02d:%02d:%02d.%03d --> %02d:%02d:%02d.%03d]  Segment %d of the synthetic transcript\n' \
        $((a/3600000)) $((a/60000%60)) $((a/1000%60)) $((a%1000)) $((b/3600000)) $((b/60000%60)) $((b/1000%60)) $((b%1000)) $i
done > "$W/segs.txt"
t0=$(now_us); progress 10800000 "$t0" < "$W/segs.txt" > "$W/bar.out"; t1=$(now_us)
echo "  $(( (t1 - t0) / 1000 )) ms total, $(( (t1 - t0) / 3000 )) µs per segment"
echo "  last frame: $(tr '\r' '\n' < "$W/bar.out" | grep -v '^$' | tail -2 | head -1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')"

echo "== $pass pass, $fail fail"
(( fail == 0 ))
