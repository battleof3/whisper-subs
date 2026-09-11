# Changelog

## 2.2.0 — 2026-09-11 (first public release)

- **Readable subtitle layout.** Subtitles are now built from word-level timings: one sentence per
  subtitle when it fits in 84 characters, longer sentences split into evenly sized pieces
  (preferring breaks after commas), very short or brief pieces merged into a neighbour, each
  subtitle kept on screen long enough to read, with no flicker or overlaps. Previously, a sentence
  slightly over the limit left its last word alone on screen for a fraction of a second (up to 42%
  of subtitles on fast speech).
- **`--channel` takes several sources:** repeat `-c`, and use channel, playlist or single-video
  URLs, or a text file of links (one per line, `#` comments). A video listed more than once is
  processed once. Unlisted videos work through playlists or direct links.
- **Tidy folder names** from YouTube titles: plain `-` instead of look-alike Unicode characters for
  `:` `|` `/`, awkward characters dropped, titles cut to 80 characters at a word boundary.
- **One automatic retry** (after 15 s) when YouTube briefly refuses a download, except for errors
  that won't go away (private, removed, members-only, age-restricted videos).
- License texts for all bundled components are included in the AppImage.

## 2.1.0

- **`--channel URL`**: download and process every video of a YouTube channel or playlist, one at a
  time (best quality up to 720p). Folders are named `DATE TITLE [VIDEO_ID] (subtitled)`, and
  re-running skips finished videos, so it also picks up new uploads.
- **`--subs-only`**: only the `.srt` and `.txt` (with `--channel`, audio-only downloads).
- **Fill in what's missing**: re-running reuses existing subtitles instead of transcribing again
  (e.g. add the videos after a `--subs-only` run); a missing transcript is rebuilt from the
  subtitles. `--force` redoes everything. This replaces the "Overwrite?" prompt.
- `--output DIR`, `--limit N`, random 5–10 s pauses between downloads.

## 2.0.0

- Rewritten as a single, self-contained AppImage: whisper.cpp with Vulkan (NVIDIA, AMD and Intel
  GPUs; CPU fallback), bundled FFmpeg and models; runs on Linux distributions from 2022 onward.
- About 1.7x faster than the previous PyTorch-based version, with ~1.5 s startup per video.
- Silero voice-activity detection: no invented "Thank you." over silence or music, and correct
  subtitle start times after music intros.
- A punctuated style prompt on every 30-second window (English) prevents stretches of lowercase,
  unpunctuated text.
- `--install` / `--uninstall`, `--language`, `--no-vad`, `--cpu`, `--version`.
