#!/usr/bin/env bash
# --install / --uninstall tests, using a throwaway HOME (the real ~/.local/bin is never touched).
# Host part uses FUSE; the container part covers the no-FUSE launcher.
set -u
T=$(cd "$(dirname "$0")" && pwd)
A=$(ls "$T"/../dist/whisper-subs-*-x86_64.AppImage | tail -1)
pass=0 fail=0
check() { local l=$1; shift; if "$@"; then pass=$((pass+1)); echo "  PASS $l"; else fail=$((fail+1)); echo "  FAIL $l"; fi; }
not() { ! "$@"; }
# Fake homes hold ~800 MB AppImage copies: keep them on disk (not RAM-backed /tmp), delete on exit.
HOMES=$T/tmp-homes
rm -rf "$HOMES"; mkdir -p "$HOMES"; trap 'rm -rf "$HOMES"' EXIT
fresh_home() { H=$(mktemp -d -p "$HOMES"); mkdir -p "$H/.config"; }
run() { env -i HOME="$H" PATH="${P:-/usr/bin:/bin}" SHELL="${SH_:-/bin/bash}" TERM=xterm "$@"; }

echo "## basic install (bash, ~/.local/bin not on PATH, no terminal)"
fresh_home
run "$A" --install < /dev/null > "$H/out" 2>&1
check "installed file is the AppImage" cmp -s "$A" "$H/.local/bin/whisper-subs"
check "executable" [ -x "$H/.local/bin/whisper-subs" ]
check "warns ~/.local/bin not on PATH" grep -q "not on your PATH" "$H/out"
check "shows the line to add for bash" grep -q "\.bashrc" "$H/out"
check "installed copy runs" run "$H/.local/bin/whisper-subs" --version
run "$H/.local/bin/whisper-subs" --install < /dev/null > "$H/out2" 2>&1
check "installed copy: --install says already installed" grep -q "already the installed one" "$H/out2"

echo "## replaces an older script, keeping a backup"
fresh_home; mkdir -p "$H/.local/bin"; printf '#!/usr/bin/env fish\necho old\n' > "$H/.local/bin/whisper-subs"
run "$A" --install < /dev/null > "$H/out" 2>&1
check "old script backed up" bash -c 'compgen -G "$1/.local/bin/whisper-subs.backup-*" > /dev/null' _ "$H"
check "backup keeps old content" grep -q "echo old" "$H"/.local/bin/whisper-subs.backup-*
check "new one installed" cmp -s "$A" "$H/.local/bin/whisper-subs"
run "$A" --install < /dev/null > /dev/null 2>&1
check "upgrade over an AppImage makes no second backup" [ "$(ls "$H"/.local/bin/ | grep -c backup)" = 1 ]

echo "## PATH already set: no warning"
P="/usr/bin:/bin:$H/.local/bin" run "$A" --install < /dev/null > "$H/out" 2>&1
check "no PATH warning" not grep -q "not on your PATH" "$H/out"

echo "## answering yes to adding it to PATH (simulated terminal)"
for sh in bash zsh fish; do
    fresh_home
    command -v "$sh" > /dev/null || { echo "  skip $sh (not installed)"; continue; }
    printf 'y\n' | SH_=$(command -v $sh) run script -qfec "'$A' --install" /dev/null > "$H/out" 2>&1
    case $sh in
        bash) check "bash: appended to ~/.bashrc" grep -q '.local/bin' "$H/.bashrc" ;;
        zsh)  check "zsh: appended to ~/.zshrc" grep -q '.local/bin' "$H/.zshrc" ;;
        fish) check "fish: added via fish_add_path" grep -rq 'local/bin' "$H/.config/fish/" ;;
    esac
done

echo "## uninstall"
fresh_home
run "$A" --install < /dev/null > /dev/null 2>&1
run "$H/.local/bin/whisper-subs" --uninstall > "$H/out" 2>&1
check "removed" [ ! -e "$H/.local/bin/whisper-subs" ]
run "$A" --uninstall > "$H/out" 2>&1
check "second uninstall: nothing to remove" grep -q "Nothing to remove" "$H/out"
mkdir -p "$H/.local/bin"; echo 'not ours' > "$H/.local/bin/whisper-subs"
run "$A" --uninstall > "$H/out" 2>&1; code=$?
check "refuses to remove a file that isn't ours" [ $code = 1 ]
check "  ...and leaves it alone" grep -q 'not ours' "$H/.local/bin/whisper-subs"

echo "## no FUSE (Debian container): launcher install, run from PATH, uninstall"
out=$(podman run --rm -v "$A:/app/w.AppImage:ro" -v "$T/speech:/speech:ro" docker.io/library/debian:12 bash -c '
    export PATH="$HOME/.local/bin:$PATH"
    /app/w.AppImage --appimage-extract-and-run --install < /dev/null 2>&1 | sed "s/^/    /"
    echo "LAUNCHER: $(head -2 ~/.local/bin/whisper-subs | tail -1)"
    echo "APPIMAGE_STORED: $(ls ~/.local/share/whisper-subs/)"
    cd /tmp && cp /speech/jfk.flac . && whisper-subs jfk.flac > run.log 2>&1; echo "RUN_EXIT: $?"
    echo "TRANSCRIPT: $(head -c 40 "jfk (subtitled)/jfk.txt")"
    echo "LEFTOVER: $(ls -d /tmp/appimage_extracted_* 2>/dev/null | wc -l)"
    whisper-subs --uninstall > /dev/null 2>&1
    echo "AFTER_UNINSTALL: $(find ~/.local -type f | wc -l) files left"
' 2>&1)
echo "$out" | grep '^    '
check "no-FUSE: launcher installed" grep -q "LAUNCHER: # whisper-subs launcher" <<< "$out"
check "no-FUSE: AppImage stored in ~/.local/share" grep -q "APPIMAGE_STORED: whisper-subs.AppImage" <<< "$out"
check "no-FUSE: 'whisper-subs' from PATH works" grep -q "RUN_EXIT: 0" <<< "$out"
check "no-FUSE: correct transcript" grep -q "TRANSCRIPT: And so, my fellow Americans" <<< "$out"
check "no-FUSE: no extraction left behind" grep -q "LEFTOVER: 0" <<< "$out"
check "no-FUSE: uninstall removes launcher and AppImage" grep -q "AFTER_UNINSTALL: 0 files left" <<< "$out"
grep AFTER_UNINSTALL <<< "$out" | sed 's/^/    /'

echo "== $pass pass, $fail fail"
(( fail == 0 ))
