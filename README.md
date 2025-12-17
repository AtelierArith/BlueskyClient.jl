# BlueSkyClient.jl

BlueSkyClient.jl is a Julia implementation of an [AT Protocol](https://atproto.com/) client for the BlueSky social network. It aims to mirror the official TypeScript (`atproto/`) and community Python (`py_atproto/`) SDKs that live in this repository, offering an idiomatic Julia API for authenticating, posting, and eventually covering the full lexicon surface.

## Getting Started

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

This installs the dependencies declared in `Project.toml` (currently `HTTP` and `JSON3`). For active development, the repo expects Julia 1.10 or later.

### Quick Example

```julia
using BlueSkyClient

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
using BlueSkyClient

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

img_bytes = read("screenshot.png")
send_image(
    client,
    "Screenshot from today's build ✅",
    img_bytes,
    "BlueSkyClient.jl terminal output showing the new client API",
    mime_type="image/png",
)
```

For multiple images, pass a vector of byte arrays to `send_images` and provide matching `alts` (missing entries are padded with empty strings).

### Error Handling

Network or protocol failures raise `BlueSkyError`, which exposes the HTTP status, the AT error code (if provided), and the server message. You can capture it with standard Julia `try`/`catch` blocks to handle authentication failures, rate limiting, etc.

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
- Prefer BlueSky App Passwords, especially if you interact with Direct Messages or other scoped features.
- Keep dependency bumps explicit so that lexicon updates remain auditable, and verify upstream commit hashes before trusting new schema files.

## Future Work

This initial drop focuses on login and posting. The next milestones include:

1. Session refresh/import/export helpers to match `py_atproto.Client`.
2. Rich media support beyond simple image helpers (video, car uploads, record management utilities).
3. Automated lexicon bindings derived from `atproto/lexicons`.

Contributions are welcome—open issues describing the desired endpoint or lexicon change, reference the upstream implementations, and describe how you tested the change across Julia, pnpm, and poetry targets.
# BlueSkyClient.jl
