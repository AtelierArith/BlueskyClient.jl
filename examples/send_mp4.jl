using BlueSkyClient
using DotEnv
using GLMakie

DotEnv.load!()

# https://docs.makie.org/stable/
using GLMakie

Base.@kwdef mutable struct Lorenz
    dt::Float64 = 0.01
    σ::Float64 = 10
    ρ::Float64 = 28
    β::Float64 = 8/3
    x::Float64 = 1
    y::Float64 = 1
    z::Float64 = 1
end

function step!(l::Lorenz)
    dx = l.σ * (l.y - l.x)
    dy = l.x * (l.ρ - l.z) - l.y
    dz = l.x * l.y - l.β * l.z
    l.x += l.dt * dx
    l.y += l.dt * dy
    l.z += l.dt * dz
    Point3f(l.x, l.y, l.z)
end

attractor = Lorenz()

points = Point3f[]
colors = Int[]

set_theme!(theme_black())

fig, ax, l = lines(points, color = colors,
    colormap = :inferno, transparency = true,
    axis = (; type = Axis3, protrusions = (0, 0, 0, 0),
              viewmode = :fit, limits = (-30, 30, -30, 30, 0, 50)))

record(fig, "lorenz.mp4", 1:120) do frame
    for i in 1:50
        push!(points, step!(attractor))
        push!(colors, frame)
    end
    ax.azimuth[] = 1.7pi + 0.3 * sin(2pi * frame / 120)
    Makie.update!(l, arg1 = points, color = colors) # Makie 0.24+
    l.colorrange = (0, frame)
end

client = Client()
login!(client; identifier=ENV["BSKY_HANDLE"], password=ENV["BSKY_PASSWORD"])

video_path = "lorenz.mp4"
video_bytes = read(video_path)

upload = upload_blob(client, Vector{UInt8}(video_bytes); content_type="video/mp4")

embed = Dict(
    "\$type" => "app.bsky.embed.video",
    "video" => upload["blob"],
    "alt" => get(ENV, "BSKY_VIDEO_ALT", "MP4 sample posted from BlueSkyClient.jl"),
    "aspectRatio" => Dict("width" => 16, "height" => 9),
)

send_post(client, "Post with MP4 attachment 🎬"; embed=embed)
