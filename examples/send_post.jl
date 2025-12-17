using BlueskyClient
using DotEnv; DotEnv.load!()

client = Client()  # defaults to https://bsky.social

# Prefer App Passwords with DM scope when accessing real accounts.
session = login!(client;
    identifier = ENV["BSKY_HANDLE"],
    password   = ENV["BSKY_PASSWORD"],
)

post_text = "I'm making BlueskyClient.jl now ♩"
@info "Sending text post to Bluesky"
post = send_post(client, post_text)
@info "Text post sent successfully" uri=post.uri
println("New record URI: ", post.uri)
