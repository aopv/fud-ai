# LiteRT-LM Swift wrapper

This local package contains the Swift wrapper sources from
[Google AI Edge LiteRT-LM v0.16.0](https://github.com/google-ai-edge/LiteRT-LM/tree/v0.16.0/swift).
The wrapper sources are licensed under Apache-2.0; see `LICENSE`.

The native iOS and macOS binaries are not checked into Fud AI. Swift Package
Manager downloads Google's release archives and verifies the checksums pinned
in `Package.swift`.

The prebuilt binary's complete upstream notice bundle is stored once at
`../../../local-models/legal/THIRD_PARTY_NOTICES_LiteRTLM_v0.16.0.txt`, bundled
by both apps, and exposed from their offline Legal screens. Do not ship the
native runtime without reviewing those notices and the release warning in
`../../../local-models/README.md`.
