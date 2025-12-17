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

n = 100
t = range(0, 2π, length = n)
x = sin.(t)
y = cos.(t)

anim = @animate for i ∈ 1:n
    circleplot(x, y, i)
end
gif(anim, "anim_fps15.gif", fps = 15)

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

gif_path = "anim_fps15.gif"

post_text = get(ENV, "BSKY_GIF_TEXT", "Animated post from Julia 🎞️")
alt_text = get(ENV, "BSKY_GIF_ALT", "Animated GIF uploaded via BlueskyClient.jl")

gif_bytes = read(gif_path)

send_gif(
    client,
    post_text,
    gif_bytes;
    alt=alt_text,
)
