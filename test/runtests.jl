using BlueSkyClient
using Dates
using Test

@testset "client configuration" begin
    default_client = Client()
    @test default_client.base_url == "https://bsky.social/xrpc"

    custom = Client(base_url="https://example.com")
    @test custom.base_url == "https://example.com/xrpc"

    already_prefixed = Client(base_url="https://example.net/xrpc")
    @test already_prefixed.base_url == "https://example.net/xrpc"
end

@testset "timestamp and language helpers" begin
    manual = BlueSkyClient._coerce_timestamp("2024-04-01T10:00:00.000Z")
    @test manual == "2024-04-01T10:00:00.000Z"

    dt = DateTime(2024, 4, 1, 12, 30, 45)
    formatted = BlueSkyClient._coerce_timestamp(dt)
    @test occursin("2024-04-01T12:30:45", formatted)
    @test endswith(formatted, "Z")

    langs = BlueSkyClient._coerce_langs(["en", "ja"])
    @test langs == ["en", "ja"]

    default_langs = BlueSkyClient._coerce_langs(nothing)
    @test default_langs == ["en"]
end

@testset "post payload construction" begin
    record = BlueSkyClient._build_post_record(
        "Hello Julia!",
        "2024-04-01T12:00:00.000Z",
        ["en", "es"],
        nothing,
    )
    @test record["\$type"] == BlueSkyClient.FEED_COLLECTION
    @test record["text"] == "Hello Julia!"
    @test record["createdAt"] == "2024-04-01T12:00:00.000Z"
    @test record["langs"] == ["en", "es"]

    client = Client()
    client.session = Session("did:plc:test", "user.bsky.social", "access", "refresh")
    auth_headers = BlueSkyClient._auth_headers(client)
    @test any(p -> p.first == "Authorization" && occursin("Bearer access", p.second), auth_headers)
end

@testset "image helpers" begin
    alts = BlueSkyClient._normalize_alts(["alt 1"], 2)
    @test alts == ["alt 1", ""]

    short_mimes = BlueSkyClient._normalize_mime_types(["image/png"], 3)
    @test short_mimes == ["image/png", "image/jpeg", "image/jpeg"]

    blob = Dict(
        "\$type" => "blob",
        "mimeType" => "image/png",
        "size" => 1234,
        "ref" => Dict("\$link" => "bafybeigdyrzt"),
    )
    embed = BlueSkyClient._build_images_embed([blob], ["ALT"])
    @test embed["\$type"] == BlueSkyClient.IMAGES_EMBED_TYPE
    @test length(embed["images"]) == 1
    image_entry = embed["images"][1]
    @test image_entry["alt"] == "ALT"
    @test image_entry["image"] == blob
end
