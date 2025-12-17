# BlueskyClient.jl

BlueskyClient.jl is a Julia implementation of an [AT Protocol](https://atproto.com/) client for the Bluesky social network. It aims to mirror the official TypeScript (`atproto/`) and community Python (`py_atproto/`) SDKs that live in this repository, offering an idiomatic Julia API for authenticating, posting, and eventually covering the full lexicon surface.

## Getting Started

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

This installs the dependencies declared in `Project.toml` (currently `HTTP` and `JSON3`). For active development, the repo expects Julia 1.10 or later.

### Quick Example

```julia
using BlueskyClient

client = Client()  # defaults to https://bsky.social

# Prefer App Passwords with DM scope when accessing real accounts.
session = login!(client;
    identifier = ENV["BSKY_HANDLE"],
    password   = ENV["BSKY_PASSWORD"],
)

post = send_post(client, "Hello from Julia and AT Protocol!")
println("New record URI: ", post.uri)
```

`Client` automatically normalizes the Personal Data Server (PDS) base URL to include `/xrpc`. After calling `login!`, the session (DID, handle, access JWT, refresh JWT) is cached on the struct, and `send_post` will create an `app.bsky.feed.post` record against the authenticated repo unless you pass the `repo` keyword.

### Posting Images with ALT text

You can attach up to four images per post. Each image should include meaningful ALT text for accessibility:

```julia
using BlueskyClient

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

img_bytes = read("screenshot.png")
send_image(
    client,
    "Screenshot from today's build ✅",
    img_bytes,
    "BlueskyClient.jl terminal output showing the new client API",
    mime_type="image/png",
)
```

For multiple images, pass a vector of byte arrays to `send_images` and provide matching `alts` (missing entries are padded with empty strings).

Need a quick script? See `examples/send_gif.jl` for an end-to-end sample that generates a Plots.jl circle animation, writes it to a temporary GIF, and posts it with proper ALT text via `send_gif`, which performs the MP4 transcode for you. The script loads credentials via DotEnv and emits `@info` progress logs as it renders, encodes, and posts.

### Posting GIFs or Video

Animated GIFs can be sent by calling `send_gif`, which writes the bytes to a temporary file, transcodes them to MP4 via `FFMPEG.jl`, and then posts the resulting clip (Bluesky only animates `app.bsky.embed.video`). Make sure `ffmpeg` is available on your PATH (Julia's stdlib `FFMPEG` package downloads one automatically):

```julia
using BlueskyClient

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

gif_bytes = read("loop.gif")
send_gif(
    client,
    "Animated progress demo",
    gif_bytes;
    alt="Looping render of the new visualization",
    # aspect_ratio is optional; defaults to the detected width/height from ffprobe.
    aspect_ratio=AspectRatio(960, 540),
)
```

For MP4 or other video sources, fall back to `send_video` and supply the bytes explicitly:

```julia
using BlueskyClient

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

video_bytes = read("clip.mp4")
aspect = AspectRatio(1920, 1080)
send_video(
    client,
    "Launch capture from Julia 🚀",
    video_bytes;
    alt="Screen recording of the latest feature",
    aspect_ratio=aspect,
)
```
`examples/send_gif.jl` lets you override the caption with `BSKY_GIF_TEXT` / `BSKY_GIF_ALT`.

### Example Scripts

The `examples/` directory contains ready-to-run demos:

- `send_message.jl` posts a simple text status and logs send progress.
- `send_image.jl` loads `examples/screenshot.png`, posts it with ALT text, and logs when bytes are read/uploaded.
- `send_gif.jl` procedurally generates an animation, writes it to a temp GIF, and reports each step (`@info`).
- `send_mp4.jl` renders a Lorenz attractor with GLMakie, records an MP4 inside `mktempdir` (no lingering files), and logs when data generation and upload start/finish.

All scripts rely on `DotEnv.load!()` so you can keep `BSKY_HANDLE`, `BSKY_PASSWORD`, and optional caption/ALT overrides in a local `.env`.

### Error Handling

Network or protocol failures raise `BlueskyError`, which exposes the HTTP status, the AT error code (if provided), and the server message. You can capture it with standard Julia `try`/`catch` blocks to handle authentication failures, rate limiting, etc.

## Development Workflow

The repo contains upstream references that should stay authoritative:

- `atproto/`: pnpm-based TypeScript implementation (`pnpm -C atproto install && pnpm -C atproto run verify`)
- `py_atproto/`: MarshalX Python SDK (`cd py_atproto && poetry install --with dev,test && poetry run pytest`)

When porting features, mirror the behavior and tests from those directories as closely as possible. Julia tests live under `test/` and should group scenarios with descriptive `@testset`s:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Before sending patches, run JuliaFormatter to match the house style:

```bash
julia --project=. -e 'using JuliaFormatter; format("src", "test")'
```

## Credentials & Security

- Never commit real handles, passwords, or signing keys. Pull them from environment variables such as `BSKY_HANDLE` / `BSKY_PASSWORD` or a local `.env` that remains git-ignored.
- Prefer Bluesky App Passwords, especially if you interact with Direct Messages or other scoped features.
- Keep dependency bumps explicit so that lexicon updates remain auditable, and verify upstream commit hashes before trusting new schema files.

## Future Work

This initial drop focuses on login and posting. The next milestones include:

1. Session refresh/import/export helpers to match `py_atproto.Client`.
2. Rich media support beyond simple image helpers (video, car uploads, record management utilities).
3. Automated lexicon bindings derived from `atproto/lexicons`.

Contributions are welcome—open issues describing the desired endpoint or lexicon change, reference the upstream implementations, and describe how you tested the change across Julia, pnpm, and poetry targets.
