using BlueskyClient
using DotEnv; DotEnv.load!()

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

image_path = "screenshot.png"
@info "Loading image fixture" path=image_path
img_bytes = read(image_path)

@info "Sending image post to Bluesky"
post = send_image(
    client,
    "Screenshot from today's build ✅",
    img_bytes,
    "BlueskyClient.jl terminal output showing the new client API",
    mime_type="image/png",
)
@info "Image post sent successfully" uri=post.uri
