"""Reference implementation of the .srt clean-up + transcript step, from the original
fish/PyTorch version of whisper-subs. tests/awk_test.sh checks that the awk port
(POSTPROCESS_AWK in src/whisper-subs) produces byte-identical output.

Usage: python3 reference_postprocess.py file.srt transcript.txt [max_seconds]
"""
import re, sys
srt_path, txt_path = sys.argv[1], sys.argv[2]
limit = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None
PAUSE, MAX_PARA = 2.0, 600

# index line, timestamp line, then text up to the next index+timestamp pair (text may be empty)
CUE = re.compile(r"^\s*\d+\s*\n\s*(\S+)\s*-->\s*(\S+)[^\n]*\n(.*?)(?=^\s*\d+\s*\n\s*\S+\s*-->|\Z)", re.M | re.S)

def secs(t):
    h, m, s = t.strip().replace(",", ".").split(":")
    return int(h) * 3600 + int(m) * 60 + float(s)

def fmt(x):
    ms = round(x * 1000)
    return f"{ms // 3600000:02}:{ms // 60000 % 60:02}:{ms // 1000 % 60:02},{ms % 1000:03}"

cues = []
for m in CUE.finditer(open(srt_path, encoding="utf-8").read()):
    start, end = secs(m[1]), secs(m[2])
    text = [t.strip() for t in m[3].split("\n") if t.strip()]
    if not text:
        continue
    if limit is not None:
        if start >= limit:
            continue
        end = min(end, limit)
    cues.append((start, end, text))

with open(srt_path, "w", encoding="utf-8") as f:
    for i, (start, end, text) in enumerate(cues, 1):
        f.write(f"{i}\n{fmt(start)} --> {fmt(end)}\n" + "\n".join(text) + "\n\n")

paragraphs, current, prev_end = [], [], None
for start, end, text in cues:
    line = " ".join(text)
    if current:
        long_enough = len(" ".join(current)) >= MAX_PARA and current[-1].endswith((".", "?", "!"))
        if start - prev_end >= PAUSE or long_enough:
            paragraphs.append(" ".join(current))
            current = []
    current.append(line)
    prev_end = end
if current:
    paragraphs.append(" ".join(current))

with open(txt_path, "w", encoding="utf-8") as f:
    f.write("\n\n".join(paragraphs) + "\n")
