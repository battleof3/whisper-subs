# Tests

Most tests run the script from the AppDir (`build/package.sh appdir` makes one without packing the
AppImage). Set `WS` to test something else, e.g. the finished AppImage:

```sh
build/package.sh appdir
tests/unit_bash.sh && tests/awk_test.sh && tests/regroup_test.sh
WS=$PWD/dist/whisper-subs-2.2.0-x86_64.AppImage tests/behavior_test.sh
```

Needs `python3`, `ffmpeg`/`ffprobe` and `script` (util-linux) on the host; `distro_test.sh`,
`install_test.sh` and the mawk part of `regroup_test.sh` also need `podman`. The transcription
tests use the GPU if there is one.

| Script | What it checks |
|---|---|
| `unit_bash.sh` | time/number helpers, drag-and-drop path parsing (quoted, escaped, `file://`, `~`), progress bar width at 12–120 columns, progress loop speed |
| `awk_test.sh [awk]` | the `.srt` clean-up + transcript step is byte-identical to the reference Python in `reference_postprocess.py` (set `BENCH_SRT_DIR` to add real `.srt` files) |
| `regroup_test.sh` | subtitle layout rules (balanced splits, comma preference, merges, pauses, timing, no overlaps); optionally real word-level files in `REGROUP_WORDS_DIR`, also under Ubuntu's mawk |
| `behavior_test.sh` | fill-in-what's-missing, `--subs-only`, `--force`, silent video, `--no-vad`, `--cpu`, `--language auto`, options, drag-and-drop in a simulated terminal |
| `channel_test.sh` | `--channel` against an offline fake yt-dlp (`fake-yt-dlp/`): subs-only then fill in videos, skipping, renamed videos, `--limit`, `--force`, links files, several sources, duplicates, tidy names, retries, Ctrl-C |
| `install_test.sh` | `--install`/`--uninstall` with a throwaway `$HOME` (bash, zsh, fish), backups, upgrades, the no-FUSE launcher (in a container) |
| `distro_test.sh [image...]` | the AppImage on Ubuntu 22.04, Debian 12, Fedora and Arch containers (no GPU, no FUSE) |
| `make_qa_media.sh` | builds edge-case media in `qa/` (odd names, avi/webm/mov/mp3, no audio, no duration, timecode track, existing subtitles) |
| `run_batch.sh LABEL FILES...` | runs a batch from `qa/` while sampling memory and GPU memory; reports anything left behind |
| `interrupt_test.sh PHASE VIDEO` | Ctrl-C during `load`, `transcribe` or `mux`; expects exit 130 and full cleanup (needs `VIDEO.second.mp4` next to it) |
| `memprobe.sh` | runs a command with a memory cap, printing its memory over time |

`withint.py` restores SIGINT for background test runs (a non-interactive shell starts background
jobs with it ignored, and bash can't trap a signal that was ignored at startup).
`speech/jfk.flac` is the public-domain test clip from [openai/whisper](https://github.com/openai/whisper).
