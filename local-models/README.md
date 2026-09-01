# Local model artifact contract

Fud AI intentionally offers only two downloadable model families:

- **Whisper Base** for speech-to-text on supported phones in every RAM tier.
- **Gemma 4 E2B** for text and image requests on phones in the 8 GB RAM tier.

Qwen, SmolVLM, GGUF/llama.cpp chat models, and Gemma E4B are not part of this release.

## Gemma 4 E2B

Both apps use LiteRT-LM `0.16.0` with the same immutable
`gemma-4-E2B-it.litertlm` artifact in [`catalog.v1.json`](catalog.v1.json).
The Hugging Face revision is public and ungated, so the apps download it
anonymously and never ask for a Hugging Face token.

| Artifact | Exact size | SHA-256 | Model license | RAM gate |
| --- | ---: | --- | --- | ---: |
| Gemma 4 E2B LiteRT-LM | 2,588,147,712 bytes (2.59 GB / 2.41 GiB) | `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c` | Apache-2.0 | 8 GB device class |

Android determines the marketed memory class from
`ActivityManager.MemoryInfo.totalMem` because the OS reserves part of physical
RAM before reporting it. iOS similarly rounds the GiB value reported by
`ProcessInfo.physicalMemory` upward to the marketed memory class.
The model remains visible with an 8 GB requirement on smaller phones, but it
does not appear in provider selectors until the artifact is verified and
executable.

Before downloading, check free capacity on the app-private install volume.
Android reserves the larger of 256 MiB or 10% of the artifact; iOS reserves
1 GiB. Download to a sibling partial file, verify exact byte length and a
streaming SHA-256, then atomically move the verified file into place. A partial,
unverified, unsupported, or deleted model must never be selectable.

Deleting an active model first replaces every primary and fallback selection
that references it, closes the runtime, and removes only model files. It must
not remove meals, settings, or other user data.

## Whisper Base

Whisper uses platform-specific runtimes and formats, so it is not represented
as one shared artifact in `catalog.v1.json`:

- iOS pins `argmax-oss-swift` / WhisperKit `1.1.0`, variant `base`, which owns
  the multi-file `openai_whisper-base` Core ML download.
- Android pins `dev.ffmpegkit-maintained:whisper-android:1.0.0` and downloads
  `ggml-base.bin` from immutable `ggerganov/whisper.cpp` revision
  `5359861c739e955e79d9a303bcbc70fb988958b1` (147,951,465 bytes, SHA-256
  `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`).

Android's native wrapper is arm64-v8a only. Its recorded path uses 16 kHz mono
PCM WAV so local-primary/remote-fallback and remote-primary/local-fallback are
both executable. Native OS speech remains a separate live-partial provider on
both platforms.

## Runtime notices

The Gemma model license and the LiteRT-LM runtime notices are separate. The
exact LiteRT-LM `0.16.0` notice bundle is committed at
[`legal/THIRD_PARTY_NOTICES_LiteRTLM_v0.16.0.txt`](legal/THIRD_PARTY_NOTICES_LiteRTLM_v0.16.0.txt),
packaged by both apps, and exposed offline from Settings → Legal. Its SHA-256 is
`cbff17f4a653c07b4a13201927ab0fb46cc13e592485ee7fe4e2c1d1526ac52b`.

The exact Whisper Base source manifest and notices are committed at
[`legal/THIRD_PARTY_NOTICES_WhisperBase.txt`](legal/THIRD_PARTY_NOTICES_WhisperBase.txt).
It covers the OpenAI model weights, Argmax OSS Swift/WhisperKit `1.1.0`, the
exact iOS Core ML and tokenizer snapshots, the Android wrapper, its embedded
whisper.cpp/miniaudio code and NDK libc++, and Argmax's required
swift-transformers notice. Its SHA-256 is
`d414ae53d7797aeaf420cf17b4f905e0833578a700746ffce5a7018ba1fbd715`.
Bundle this file in both apps and expose it offline from Settings → Legal.

The upstream notice contains GPLv2 and MPL2 text under an ambiguous
`Google Runtime Environment` entry without SBOM relationships. Obtain upstream
or legal confirmation that no incompatible covered code is linked before
shipping the native LiteRT-LM binary through an app store.

## Verification

Run the structural check locally:

```sh
python3 local-models/verify_catalog.py
```

Confirm immutable remote metadata and anonymous range access before release:

```sh
python3 local-models/verify_catalog.py --online
```
