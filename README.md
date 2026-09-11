# whisper-subs

**Subtitles and clean transcripts for your videos — made locally with Whisper, in one file.**

Drag a video into your terminal and get back a folder with the video plus a subtitle track, an
`.srt` file (ready to upload to YouTube) and a readable transcript. It runs on your own machine
(no uploads, no accounts), uses your GPU through Vulkan (NVIDIA, AMD or Intel) and falls back to
the CPU. It can also work through a whole YouTube channel or playlist.

```
$ whisper-subs "Lecture 3.mp4"

━━ [1/1] Lecture 3.mp4
  ████████████░░░░░░░░░░░░   50%  7:16 / 14:32  ETA 29s  …so the argument is valid
  ✓ Transcribed in 58s on NVIDIA GeForce GTX 1070
  ✓ Transcript written
  ✓ Subtitle track added
  ✓ Original moved into the folder

  Done in 58s  (14m 32s of video · 15.1× real time)
  Folder:     /home/you/Videos/Lecture 3 (subtitled)/
```

## Features

- **One file, no setup:** a single AppImage with everything included — the transcription engine
  ([whisper.cpp](https://github.com/ggml-org/whisper.cpp)), the Whisper large-v3-turbo model,
  voice-activity detection and FFmpeg. `--install` puts it on your `PATH`.
- **Fast:** about 15× real time on a mid-range GPU (an hour of video in about 4 minutes).
- **Careful output:**
  - no invented text over silence or music (voice-activity detection skips them),
  - no stretches of lowercase, unpunctuated text,
  - subtitles laid out for reading: whole sentences where they fit, evenly split otherwise, no
    one-word flashes.
- **Modular and resumable:** subtitles, transcript and subtitled video are each made only if
  missing. Run `--subs-only` now and add the videos later without transcribing twice.
- **YouTube channels and playlists** (with [yt-dlp](https://github.com/yt-dlp/yt-dlp)): process
  every video, one at a time; re-run later to pick up new uploads.
- **Friendly terminal UI:** drag-and-drop, a progress bar with ETA and the latest words, clean
  Ctrl-C handling.

## Install

1. Download the latest release: open the [latest release](../../releases/latest) page and get
   the `.AppImage` file under **Assets**.
2. In the folder you downloaded it to, make it executable and install it:
   ```sh
   chmod +x whisper-subs-*-x86_64.AppImage
   ./whisper-subs-*-x86_64.AppImage --install
   ```
   (If that folder has more than one version, use the full file name of the newest one.)
   This copies it to `~/.local/bin/whisper-subs` and offers to add that folder to your `PATH`
   (bash, zsh or fish). Remove it again with `whisper-subs --uninstall`.

You can also just run the AppImage directly without installing.

**Requirements:** 64-bit Linux with glibc 2.35 or newer (Ubuntu 22.04+, Debian 12+, Fedora 36+,
current Arch and derivatives). A GPU with Vulkan drivers is optional but strongly recommended.
`--channel` needs `yt-dlp` installed.

> **"fusermount" or FUSE error when starting?** Common in containers and minimal systems. Add
> `--appimage-extract-and-run` before the other options (e.g. `./whisper-subs-*.AppImage
> --appimage-extract-and-run --install`), or install `fuse3`.

## Usage

```sh
whisper-subs video.mp4 [more videos...]
whisper-subs                     # then drag video file(s) into the terminal and press Enter
```

Each video gets a folder next to it:

```
Lecture 3 (subtitled)/
├── Lecture 3.subtitled.mp4   the video with a toggleable subtitle track
├── Lecture 3.srt             the subtitles on their own
├── Lecture 3.txt             a clean transcript, in paragraphs
└── Lecture 3.mp4             the original, moved in once everything succeeded
```

MP4 and MOV inputs stay MP4/MOV. Everything else (MKV, WebM, AVI, audio files…) becomes MKV. The
video isn't re-encoded, so there's no quality loss and adding the track takes seconds.

| Option | |
|---|---|
| `--subs-only` | only the `.srt` and `.txt` |
| `--force` | redo everything, including transcription (normally only missing parts are made) |
| `-l`, `--language CODE` | spoken language, e.g. `en`, `es`, `fr`, `de`, or `auto` (default: `en`) |
| `--no-vad` | also transcribe silence and music (off by default: Whisper tends to invent text there) |
| `--cpu` | don't use the GPU |
| `--install`, `--uninstall` | put the AppImage on your `PATH` / remove it |
| `-V`, `--version`, `-h`, `--help` | |

### YouTube channels and playlists

```sh
whisper-subs --channel https://www.youtube.com/@SomeChannel -o ~/Videos/some-channel
whisper-subs --channel 'https://www.youtube.com/playlist?list=PL…' --subs-only
whisper-subs -c links.txt -c https://www.youtube.com/watch?v=VIDEO_ID
```

- A source can be a channel (its Videos tab), a playlist, a single video, or a text file of such
  links (one per line, `#` for comments). Repeat `-c` for several; a video listed twice is done once.
- **Unlisted videos** don't appear on a channel page, but they do work through playlists and
  direct links.
- Videos are processed one at a time: download (best quality up to 720p; audio only with
  `--subs-only`), transcribe, keep the outputs, delete the download.
- Folders are named `DATE TITLE [VIDEO_ID] (subtitled)`. Re-running skips finished videos and
  fills in missing parts — including after a video failed, or to add the videos after a
  `--subs-only` run — and picks up new uploads.
- `--limit N` takes the newest N videos of each channel or playlist. There's a short random pause
  before each download, and one retry if YouTube refuses a download for a moment.

## Performance

Measured on an Intel i7-6700K with an NVIDIA GTX 1070 (Vulkan):

| | |
|---|---|
| Speed on the GPU | ~15× real time (a 14.5-minute lecture in 58 s; 1 h 12 min in 4 min 41 s) |
| Speed on the CPU only | ~1× real time |
| Startup per video | ~1.5 s |
| Memory | ~1.2 GB RAM, ~1.7 GB video memory |

## How it works

1. FFmpeg extracts the audio as 16 kHz mono WAV.
2. [whisper.cpp](https://github.com/ggml-org/whisper.cpp) transcribes it with Whisper
   large-v3-turbo (8-bit quantized: same accuracy as full precision in our tests, 1.6× faster,
   half the size), on the GPU through Vulkan when available.
   - [Silero VAD](https://github.com/snakers4/silero-vad) finds the speech first. Without it,
     Whisper invents text such as "Thank you." over silence and music, and after a music intro it
     starts the first subtitle at 0:00 and drops punctuation.
   - No transcribed text is carried from one 30-second window to the next, so a slip can't
     persist for the rest of the video. For English, every window gets the same short,
     punctuated example sentence instead, which keeps punctuation and capitalization consistent.
3. Whisper's word timings are grouped into subtitles: whole sentences up to 84 characters, longer
   ones split evenly (preferring commas), short pieces merged, each subtitle shown long enough to
   read.
4. The transcript joins the subtitles into paragraphs, breaking at pauses in speech.
5. FFmpeg adds the subtitles as a track without re-encoding the video.

## Limitations

- Whisper can mishear names and technical terms; check important transcripts.
- The punctuation example sentence is English; other languages use plain decoding.
- When someone talks very fast with no pauses, subtitles change quickly: each one can only stay up
  while its words are being said, so they don't fall out of sync with the audio.
- Linux x86-64 only.

## Building from source

Needs `podman` (or Docker: `ENGINE=docker`), `git` and `curl`:

```sh
build/build-all.sh     # -> dist/whisper-subs-VERSION-x86_64.AppImage
```

This downloads and verifies the sources and models (`build/fetch.sh`), then builds whisper.cpp and
FFmpeg inside an Ubuntu 22.04 container (so the result runs on older distributions than the one
you build on) and packs the AppImage. See [`tests/README.md`](tests/README.md) for the test suite.

## Disclaimer

`--channel` downloads videos with yt-dlp. YouTube's Terms of Service restrict downloading, and
videos are protected by copyright: only use it for videos you own or have permission to use.
whisper-subs isn't affiliated with YouTube, Google, OpenAI or the whisper.cpp project.

## License

MIT — see [`LICENSE`](LICENSE). The AppImage bundles components under their own licenses (MIT and
LGPL); see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
