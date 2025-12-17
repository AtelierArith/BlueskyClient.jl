using BlueskyClient
using DotEnv

DotEnv.load!()

# https://docs.juliaplots.org/dev/animations/
using Plots

@userplot CirclePlot
@recipe function f(cp::CirclePlot)
    x, y, i = cp.args
    n = length(x)
    inds = circshift(1:n, 1 - i)
    linewidth --> range(0, 10, length = n)
    seriesalpha --> range(0, 1, length = n)
    aspect_ratio --> 1
    label --> false
    x[inds], y[inds]
end

@info "Generating circle animation frames"
n = 100
t = range(0, 2π, length = n)
x = sin.(t)
y = cos.(t)

anim = @animate for i ∈ 1:n
    circleplot(x, y, i)
end

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

post_text = get(ENV, "BSKY_GIF_TEXT", "Animated post from Julia 🎞️")
alt_text = get(ENV, "BSKY_GIF_ALT", "Animated GIF uploaded via BlueskyClient.jl")

gif_bytes = begin
    gif_path = tempname() * ".gif"
    try
        @info "Encoding animation to GIF" path=gif_path
        gif(anim, gif_path, fps = 15)
        read(gif_path)
    finally
        isfile(gif_path) && rm(gif_path)
    end
end

@info "Sending GIF post to Bluesky"
post = send_gif(
    client,
    post_text,
    gif_bytes;
    alt=alt_text,
)
@info "GIF post sent successfully" uri=post.uri
