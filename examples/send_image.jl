using BlueskyClient
using DotEnv; DotEnv.load!()

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
