# Third-party components

The whisper-subs AppImage bundles the programs and models below. Each keeps its own license; the
full license texts are in [`licenses/`](licenses/) and inside the AppImage under
`usr/share/licenses/whisper-subs/`. The whisper-subs script itself is MIT-licensed (see
[`LICENSE`](LICENSE)).

| Component | Version | License | Source |
|---|---|---|---|
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (whisper-cli, libwhisper, ggml incl. Vulkan and CPU backends) | v1.9.3 | MIT | https://github.com/ggml-org/whisper.cpp/tree/v1.9.3 |
| Whisper large-v3-turbo model, ggml q8_0 conversion (`ggml-large-v3-turbo-q8_0.bin`) | — | MIT (OpenAI Whisper) | weights: https://github.com/openai/whisper · conversion: https://huggingface.co/ggerganov/whisper.cpp |
| Silero VAD v6.2.0, ggml conversion (`ggml-silero-v6.2.0.bin`) | v6.2.0 | MIT | https://github.com/snakers4/silero-vad · conversion: https://huggingface.co/ggml-org/whisper-vad |
| [FFmpeg](https://ffmpeg.org) (`ffmpeg`, `ffprobe`) | 9.0.1 | LGPL-2.1-or-later | see below |
| [AppImage type2-runtime](https://github.com/AppImage/type2-runtime) (the AppImage's self-mounting header) | continuous | MIT; statically includes libfuse (LGPL-2.1), squashfuse (BSD-2-Clause) and zstd (BSD) | https://github.com/AppImage/type2-runtime |

The C++ runtime (libstdc++/libgcc) is linked statically into whisper.cpp under the GCC Runtime
Library Exception.

## FFmpeg (LGPL)

The bundled FFmpeg is an LGPL build (no GPL or non-free components) made from the unmodified
[FFmpeg 9.0.1 source release](https://ffmpeg.org/releases/ffmpeg-9.0.1.tar.xz). The exact
configuration is in [`build/build-ffmpeg.sh`](build/build-ffmpeg.sh):

```
--disable-autodetect --enable-zlib --disable-debug --disable-doc --disable-ffplay
--disable-network --disable-devices --disable-hwaccels --disable-x86asm
--disable-encoders --enable-encoder=pcm_s16le,movtext,srt,subrip,webvtt,ass,ssa --enable-small
```

The corresponding source code is attached to every GitHub release of whisper-subs
(`ffmpeg-9.0.1.tar.xz`), and `build/build-ffmpeg.sh` rebuilds the binaries from it. You may replace
the bundled `ffmpeg`/`ffprobe` with your own build: extract the AppImage
(`./whisper-subs-*.AppImage --appimage-extract`), replace `squashfs-root/usr/lib/whisper-subs/ffmpeg`
and `ffprobe`, and run `squashfs-root/AppRun`.

## Not bundled

- **yt-dlp** is used by `--channel` if it's installed on your system; it isn't included, because its
  YouTube support needs frequent updates.
- **Vulkan loader and GPU drivers** come from your system.

## Test material

`tests/speech/jfk.flac` is the 11-second excerpt of John F. Kennedy's 1961 inaugural address used
by [openai/whisper](https://github.com/openai/whisper/tree/main/tests) for its own tests; the speech
is a US government work in the public domain.
