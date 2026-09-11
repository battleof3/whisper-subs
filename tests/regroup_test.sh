#!/usr/bin/env bash
# Tests for the subtitle layout step (REGROUP_AWK in src/whisper-subs): synthetic word timings
# with known right answers, then (optional, if present) real word-level files in
# $REGROUP_WORDS_DIR (default bench/regroup/words, not in the repository): words must survive
# unchanged, and gawk and Ubuntu's mawk must produce identical output.
set -u
T=$(cd "$(dirname "$0")" && pwd)
P=$T/..
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
sed -n "/^read -r -d '' REGROUP_AWK <<'AWK'/,/^AWK\$/p" "$P/src/whisper-subs" | sed '1d;$d' > "$W/regroup.awk"

python3 - "$W" <<'EOF'
import re, subprocess, sys
from pathlib import Path
W = Path(sys.argv[1])
CUE = re.compile(r"^\s*\d+\s*\n\s*(\S+)\s*-->\s*(\S+)[^\n]*\n(.*?)(?=^\s*\d+\s*\n\s*\S+\s*-->|\Z)", re.M | re.S)
def ts(x):
    ms = round(x * 1000); return f"{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}"
def secs(t):
    h, m, s = t.replace(",", ".").split(":"); return int(h) * 3600 + int(m) * 60 + float(s)
def words_srt(items):  # items: (word, start, end)
    return "".join(f"{i}\n{ts(a)} --> {ts(b)}\n {w}\n\n" for i, (w, a, b) in enumerate(items, 1))
def speak(text, t=0.0, per_word=0.3, gaps=None):
    """Words spoken back to back; gaps = {word_index: pause before it}."""
    out = []
    for i, w in enumerate(text.split()):
        t += (gaps or {}).get(i, 0)
        out.append((w, t, t + per_word)); t += per_word
    return out
def layout(items):
    (W / "in.srt").write_text(words_srt(items))
    r = subprocess.run(["awk", "-f", str(W / "regroup.awk"), str(W / "in.srt")], capture_output=True, text=True, check=True)
    return [(secs(a), secs(b), " ".join(t.split())) for a, b, t in CUE.findall(r.stdout)]

passed = failed = 0
def check(label, cond, detail=""):
    global passed, failed
    if cond: passed += 1; print(f"  PASS {label}")
    else: failed += 1; print(f"  FAIL {label} {detail}")

print("## layout rules")
s88 = "This sentence is written to be a little longer than the limit so it needs splitting again."
cs = layout(speak(s88))
check("88-char sentence -> 2 balanced cues, no 1-word leftover",
      len(cs) == 2 and min(len(t) for *_, t in cs) >= 30, [t for *_, t in cs])
sc = "We looked at premises and conclusions, and today we turn to the question of validity in general."
cs = layout(speak(sc))
check("prefers breaking right after a comma", cs and cs[0][2].endswith("conclusions,"), [t for *_, t in cs])
cs = layout(speak("Okay. Right. So today we will talk about arguments."))
check("short sentences ('Okay. Right.') merged into the next", len(cs) == 1, [t for *_, t in cs])
cs = layout(speak("I think that this is valid but that one is not", gaps={6: 1.2}))
check("a 1.2 s pause splits a sentence", len(cs) == 2 and cs[0][2] == "I think that this is valid", [t for *_, t in cs])
cs = layout(speak("Yes.", t=5.0) + speak("Now something completely different follows here.", t=9.0))
check("isolated short cue stays up at least 1 s", cs[0][1] - cs[0][0] >= 1.0 - 1e-6, cs[:1])
cs = layout(speak("First sentence is here.", t=0) + speak("Second sentence follows.", t=0.3 * 4 + 0.2))
check("small gap between cues closed (no flicker)", abs(cs[0][1] - cs[1][0]) < 1e-6, cs)
cs = layout(speak("Last words of the video are here.", t=10))
check("last cue lingers 0.6 s after its last word", abs(cs[-1][1] - (10 + 7 * 0.3 + 0.6)) < 0.002, cs)
long_text = " ".join(["word"] * 60) + "."
cs = layout(speak(long_text, per_word=0.25))
check("very long sentence: every cue <= 84 chars, none tiny",
      all(len(t) <= 84 for *_, t in cs) and min(len(t) for *_, t in cs) >= 40, [len(t) for *_, t in cs])
check("no overlaps anywhere", all(a1 >= b0 - 1e-6 for (a0, b0, _), (a1, _, __) in zip(cs, cs[1:])))
(W / "in.srt").write_text("")
r = subprocess.run(["awk", "-f", str(W / "regroup.awk"), str(W / "in.srt")], capture_output=True, text=True)
check("empty input -> empty output", r.returncode == 0 and r.stdout == "")
(W / "counts").write_text(f"{passed} {failed}")
EOF
read -r pass fail < "$W/counts"

echo "## real word-level files: words unchanged; gawk == mawk"
for f in "${REGROUP_WORDS_DIR:-$P/bench/regroup/words}"/*.srt; do
    [[ -f $f ]] || continue
    awk -f "$W/regroup.awk" "$f" > "$W/g.srt"
    in_words=$(grep -vE '^[0-9]+$|-->|^[[:space:]]*$' "$f" | tr -s ' \n' '\n\n' | grep -v '^$' | md5sum)
    out_words=$(grep -vE '^[0-9]+$|-->|^[[:space:]]*$' "$W/g.srt" | tr -s ' \n' '\n\n' | grep -v '^$' | md5sum)
    m=$(podman run --rm -v "$W:/w" -v "$f:/in.srt:ro" docker.io/library/ubuntu:22.04 mawk -f /w/regroup.awk /in.srt | md5sum)
    if [[ $in_words == "$out_words" && $m == "$(md5sum < "$W/g.srt")" ]]; then
        pass=$((pass + 1)); echo "  PASS ${f##*/}: words unchanged, mawk identical ($(grep -c -- '-->' "$W/g.srt") cues)"
    else
        fail=$((fail + 1)); echo "  FAIL ${f##*/}: words $([[ $in_words == "$out_words" ]] && echo ok || echo CHANGED), mawk $([[ $m == "$(md5sum < "$W/g.srt")" ]] && echo same || echo DIFFERENT)"
    fi
done
echo "== $pass pass, $fail fail"
(( fail == 0 ))
