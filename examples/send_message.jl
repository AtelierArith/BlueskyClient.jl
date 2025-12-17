using BlueSkyClient
using DotEnv; DotEnv.load!()

client = Client()  # defaults to https://bsky.social

# Prefer App Passwords with DM scope when accessing real accounts.
session = login!(client;
    identifier = ENV["BSKY_HANDLE"],
    password   = ENV["BSKY_PASSWORD"],
)

post = send_post(client, "Hello from Julia and AT Protocol!")
println("New record URI: ", post.uri)
