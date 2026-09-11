#!/usr/bin/env bash
# The awk post-processing (POSTPROCESS_AWK in src/whisper-subs) must produce byte-identical
# .srt/.txt to the reference Python implementation (tests/reference_postprocess.py, from the
# original version of whisper-subs). Usage: awk_test.sh [awk-binary]   (default: awk)
# Set BENCH_SRT_DIR to a folder of real .srt files to also compare those.
set -u
AWK_BIN=${1:-awk}
T=$(cd "$(dirname "$0")" && pwd)
P=$T/..
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

sed -n "/^read -r -d '' POSTPROCESS_AWK <<'AWK'/,/^AWK\$/p" "$P/src/whisper-subs" | sed '1d;$d' > "$W/pp.awk"
cp "$T/reference_postprocess.py" "$W/pp.py"

pass=0 fail=0
check() {  # label srt-content limit
    local label=$1 limit=$3
    printf '%b' "$2" > "$W/in.srt"
    cp "$W/in.srt" "$W/a.srt"; cp "$W/in.srt" "$W/p.srt"
    "$AWK_BIN" -v srt_out="$W/a.out.srt" -v txt_out="$W/a.txt" -v limit="$limit" -f "$W/pp.awk" "$W/a.srt" || { echo "  FAIL $label (awk error)"; fail=$((fail+1)); return; }
    if [[ -s $W/pp.py ]]; then
        python3 "$W/pp.py" "$W/p.srt" "$W/p.txt" $limit 2>/dev/null
        # Intentional difference: with no cues left, Python writes "\n" as the transcript, awk
        # writes an empty file (both are treated as "no speech" and removed).
        [[ ! -s $W/a.txt && $(cat "$W/p.txt") == "" ]] && : > "$W/p.txt"
        if cmp -s "$W/a.out.srt" "$W/p.srt" && cmp -s "$W/a.txt" "$W/p.txt"; then
            echo "  PASS $label — identical to Python ($(grep -c -- '-->' "$W/a.out.srt") cues, $(wc -w < "$W/a.txt") words)"; pass=$((pass+1))
        else
            echo "  FAIL $label — differs from Python"; fail=$((fail+1))
            diff <(cat "$W/p.srt" "$W/p.txt") <(cat "$W/a.out.srt" "$W/a.txt") | head -6 | sed 's/^/      /'
        fi
    else
        echo "  ---- $label (no Python reference available)"; cat "$W/a.txt"
    fi
}

echo "## $("$AWK_BIN" -W version 2>/dev/null | head -1 || "$AWK_BIN" --version 2>/dev/null | head -1)"
check "normal"            '1\n00:00:00,000 --> 00:00:02,000\nHello.\n\n2\n00:00:05,000 --> 00:00:06,000\nWorld.\n\n' 10
check "empty cue text"    '1\n00:00:00,000 --> 00:00:02,000\n\n\n2\n00:00:02,000 --> 00:00:03,000\nAfter empty.\n\n' 10
check "multi-line cue"    '1\n00:00:00,000 --> 00:00:02,000\nLine one\nline two.\n\n' 10
check "CRLF endings"      '1\r\n00:00:00,000 --> 00:00:02,000\r\nWindows.\r\n\r\n' 10
check "no duration"       '1\n00:00:00,000 --> 00:00:02,000\nNo limit.\n\n' ''
check "all past limit"    '1\n00:00:05,000 --> 00:00:06,000\nToo late.\n\n' 2
check "capped end"        '1\n00:00:00,000 --> 00:00:29,980\nThank you.\n\n' 4.023
check "numeric cue text"  '1\n00:00:00,000 --> 00:00:02,000\n42\n\n2\n00:00:03,000 --> 00:00:04,000\nNext.\n\n' 10
check "unicode"           '1\n00:00:00,000 --> 00:00:02,000\nCafé — naïve 日本語 🎬\n\n' 10
check "leading spaces"    '1\n00:00:00,000 --> 00:00:02,000\n   Spaced text.   \n\n' 10
for f in "${BENCH_SRT_DIR:-/nonexistent}"/*.srt; do
    [[ -f $f ]] && check "real file: ${f##*/}" "$(sed 's/\\/\\\\/g' "$f")" 900
done
echo "== $pass pass, $fail fail"
(( fail == 0 ))
