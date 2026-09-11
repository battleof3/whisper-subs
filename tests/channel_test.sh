#!/usr/bin/env bash
# --channel tests against an offline fake yt-dlp (tests/fake-yt-dlp/yt-dlp): subs-only first,
# fill in videos later without re-transcribing, skip finished videos, title changes, failures,
# --limit, channel-root URLs, --force, missing yt-dlp, Ctrl-C mid-download.
set -u
T=$(cd "$(dirname "$0")" && pwd)
WS=${WS:-$T/../dist/AppDir/usr/bin/whisper-subs}
C=$T/channel
rm -rf "$C" && mkdir -p "$C" && cd "$C" || exit 1
export PATH="$T/fake-yt-dlp:$PATH" FAKE_LOG=$C/yt-dlp.log FAKE_LIST=$C/list.tsv FAKE_LIST2=$C/list2.tsv FAKE_MEDIA=$C/media.mp4 FAKE_FAIL=vidP
ffmpeg -loglevel error -nostdin -y -f lavfi -i testsrc=size=320x240:rate=10 -i "$T/speech/jfk.flac" -shortest -c:v libx264 -c:a aac "$FAKE_MEDIA"
printf 'vid1\tFirst lecture\nvid2\tSecond lecture: arguments\nvidP\tPrivate one\n' > "$FAKE_LIST"
URL='https://www.youtube.com/playlist?list=PLtest'
pass=0 fail=0
check() { local l=$1; shift; if "$@"; then pass=$((pass+1)); echo "  PASS $l"; else fail=$((fail+1)); echo "  FAIL $l"; fi; }
not() { ! "$@"; }
downloads() { grep -c '^DOWNLOAD' "$FAKE_LOG"; }
F1="out/2024-01-01 First lecture [vid1] (subtitled)"
F2="out/2024-01-02 Second lecture - arguments [vid2] (subtitled)"

echo "## 1. --subs-only on a 3-video playlist (one private)"
: > "$FAKE_LOG"
"$WS" --channel "$URL" --subs-only -o out > r1.log 2>&1; code=$?
check "exit 1 because of the private video" [ $code = 1 ]
check "summary: 2 processed, 1 failed" grep -q "2 processed, 0 already done, 1 failed" r1.log
check "private video error shown" grep -q "Download failed" r1.log
check "audio-only downloads (-f ba/b)" grep -q -- "-f ba/b" "$FAKE_LOG"
check "sleep between downloads (5-10 s)" grep -q -- "--sleep-interval 5 --max-sleep-interval 10" "$FAKE_LOG"
check "bundled ffmpeg passed to yt-dlp" grep -qE -- "--ffmpeg-location [^ ]*/usr/lib/whisper-subs( |$)" "$FAKE_LOG"
check "folders named by date, tidy title and ID (':' -> ' - ')" test -d "$F1" -a -d "$F2"
check "srt + txt made" test -s "$F1/2024-01-01 First lecture [vid1].srt" -a -s "$F2/2024-01-02 Second lecture - arguments [vid2].txt"
check "no media kept (audio deleted, no video)" test "$(find out -name '*.m4a' -o -name '*.mp4' -o -name '*.mkv' | wc -l)" = 0
check "no download folder left" not test -e out/.whisper-subs-downloading
srt1=$(stat -c %Y "$F1/2024-01-01 First lecture [vid1].srt")

echo "## 2. same command again: finished videos skipped, nothing re-downloaded"
: > "$FAKE_LOG"
"$WS" --channel "$URL" --subs-only -o out > r2.log 2>&1
check "summary: 0 processed, 2 already done" grep -q "0 processed, 2 already done, 1 failed" r2.log
check "only the failing video was attempted" test "$(downloads)" = 0

echo "## 3. default mode later: download videos, reuse subtitles"
sleep 1.1; : > "$FAKE_LOG"
"$WS" --channel "$URL" -o out > r3.log 2>&1
check "2 processed" grep -q "2 processed, 0 already done, 1 failed" r3.log
check "video downloads, best up to 720p, MP4 preferred" grep -q -- "-S res:720,ext:mp4:m4a" "$FAKE_LOG"
check "videos only downloaded (no audio-only)" not grep -q "DOWNLOAD vid[12] m4a" "$FAKE_LOG"
check "subtitles reused (no re-transcription)" test "$(grep -c 'Using the existing subtitles' r3.log)" = 2
check "  ...srt not rewritten" test "$(stat -c %Y "$F1/2024-01-01 First lecture [vid1].srt")" = "$srt1"
check "subtitled video added" test -f "$F1/2024-01-01 First lecture [vid1].subtitled.mp4"
check "  ...with an English subtitle track" test "$(ffprobe -v error -select_streams s -show_entries stream_tags=language -of csv=p=0 "$F1/2024-01-01 First lecture [vid1].subtitled.mp4")" = eng
check "downloaded original not kept next to it" test "$(ls "$F1" | wc -l)" = 3

echo "## 4. again: everything done, zero downloads"
: > "$FAKE_LOG"
"$WS" --channel "$URL" -o out > r4.log 2>&1
check "2 already done" grep -q "0 processed, 2 already done" r4.log
check "no downloads" test "$(downloads)" = 0

echo "## 5. title changed on YouTube + transcript deleted: matched by ID, rebuilt without download"
printf 'vid1\tFirst lecture (updated title)\nvid2\tSecond lecture: arguments\nvidP\tPrivate one\n' > "$FAKE_LIST"
rm "$F1/2024-01-01 First lecture [vid1].txt"; : > "$FAKE_LOG"
"$WS" --channel "$URL" -o out > r5.log 2>&1
check "transcript rebuilt" grep -q "Transcript rebuilt" r5.log
check "no download" test "$(downloads)" = 0
check "no second folder for the renamed video" test "$(ls -d out/*"[vid1]"* | wc -l)" = 1

echo "## 6. --limit and channel-root URLs"
: > "$FAKE_LOG"
"$WS" --channel https://www.youtube.com/@SomeChannel --limit 1 -o out > r6.log 2>&1
check "channel root → its Videos tab" grep -q "LIST_URL https://www.youtube.com/@SomeChannel/videos" "$FAKE_LOG"
check "--limit 1 → --playlist-items 1:1" grep -q -- "--playlist-items 1:1" "$FAKE_LOG"
check "only 1 video considered" grep -q "1 video(s)" r6.log

echo "## 7. --force re-downloads and re-transcribes"
sleep 1.1; : > "$FAKE_LOG"
"$WS" --channel "$URL" --limit 1 --force -o out > r7.log 2>&1
check "re-transcribed" grep -q "Transcribed in" r7.log
check "  ...srt rewritten" test "$(stat -c %Y "$F1/2024-01-01 First lecture [vid1].srt")" != "$srt1"
check "  ...still one subtitled video" test "$(ls "$F1"/*.subtitled.* | wc -l)" = 1

echo "## 8. yt-dlp not installed"
mkdir -p nobin; for f in /usr/bin/*; do [[ ${f##*/} == yt-dlp ]] || ln -sf "$f" "nobin/${f##*/}"; done
PATH=$C/nobin "$WS" --channel "$URL" -o out > r8.log 2>&1; code=$?
check "clear error, exit 1" bash -c '[ $0 = 1 ] && grep -q "needs yt-dlp" "$1"' $code r8.log

echo "## 9. Ctrl-C during a download"
printf 'vid9\tNew upload\n' > "$FAKE_LIST"; : > "$FAKE_LOG"
FAKE_SLEEP=5 setsid python3 "$T/withint.py" "$WS" --channel "$URL" -o out > r9.log 2>&1 < /dev/null &
pg=$!; for _ in $(seq 60); do grep -q "DOWNLOAD vid9" "$FAKE_LOG" 2>/dev/null && break; sleep 0.25; done
kill -INT -- -$pg; wait $pg; code=$?
check "exit 130" [ $code = 130 ]
check "download folder removed" not test -e out/.whisper-subs-downloading
check "no folder for the interrupted video" not compgen -G "out/*\[vid9\]*"

echo "## 10. several sources: links file (comments, blanks), a second playlist, a single video; duplicates once"
printf 'vid1\tFirst lecture\nvid2\tSecond lecture: arguments\nvidP\tPrivate one\n' > "$FAKE_LIST"
printf 'vid3\tThird lecture\nvid1\tFirst lecture\n' > "$FAKE_LIST2"
printf '# course playlists\n%s\n\n  https://www.youtube.com/playlist?list=PLsecond  \nhttps://www.youtube.com/watch?v=vid2\n' "$URL" > links.txt
: > "$FAKE_LOG"
"$WS" --channel links.txt -o out > r10.log 2>&1
check "all three sources listed" test "$(grep -c '^LIST_URL' "$FAKE_LOG")" = 3
check "4 unique videos in total (vid1 and vid2 listed twice)" grep -q "4 video(s) in total" r10.log
check "only the new one (vid3) downloaded" bash -c '[ "$(grep -c "^DOWNLOAD" "$1")" = 1 ] && grep -q "^DOWNLOAD vid3" "$1"' _ "$FAKE_LOG"
check "  ...and processed" test -d "out/2024-01-04 Third lecture [vid3] (subtitled)"
: > "$FAKE_LOG"
"$WS" -c "$URL" -c https://www.youtube.com/watch?v=vid3 -o out > r10b.log 2>&1
check "repeated -c works the same way" grep -q "4 video(s) in total\|0 processed, 3 already done" r10b.log

echo "## 11. awkward, long title -> tidy, shortened name"
long='Lecture 12: Validity | Soundness / Truth? A "very" long title about modus ponens, modus tollens, and friends'
printf 'vidL\t%s\n' "$long" > "$FAKE_LIST"; : > list2.tsv; : > "$FAKE_LOG"
"$WS" --channel "$URL" --subs-only -o out > r11.log 2>&1
d=$(ls -d out/*"[vidL] (subtitled)" 2>/dev/null)
check "folder created" test -n "$d"
check "  ...no look-alike or awkward characters" not grep -q '[：｜|/?"<>]' <<< "${d##*/}"
check "  ...title part at most 80 characters" bash -c 'n=${1##*/}; n=${n#* }; n=${n% \[*}; (( ${#n} <= 80 ))' _ "$d"
echo "     ${d##*/}"

echo "## 12. a source that isn't a URL or a file"
"$WS" --channel not-a-url -o out > r12.log 2>&1; code=$?
check "clear error, exit 1" bash -c '[ $0 = 1 ] && grep -q "not a YouTube URL" "$1"' $code r12.log

echo "## 13. temporary YouTube refusal (HTTP 403) retried once; private videos not retried"
printf 'vidF\tFlaky one\nvidP\tPrivate one\n' > "$FAKE_LIST"; : > "$FAKE_LOG"; rm -f "$FAKE_LOG".flaky.*
FAKE_FLAKY=vidF "$WS" --channel "$URL" --subs-only -o out > r13.log 2>&1
check "flaky video succeeded on the retry" test -d "$(ls -d out/*"[vidF] (subtitled)" 2>/dev/null | head -1)"
check "  ...after saying it would retry" grep -q "trying once more" r13.log
check "private video tried only once" test "$(grep -c 'watch?v=vidP' "$FAKE_LOG")" = 1

echo "== $pass pass, $fail fail"
(( fail == 0 ))
