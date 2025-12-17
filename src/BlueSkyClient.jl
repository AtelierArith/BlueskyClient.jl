module BlueSkyClient

using Dates
using HTTP
using JSON3

export Client,
    Session,
    PostReference,
    BlueSkyError,
    login!,
    send_post,
    send_image,
    send_images,
    upload_blob

const DEFAULT_BASE_URL = "https://bsky.social"
const FEED_COLLECTION = "app.bsky.feed.post"
const IMAGES_EMBED_TYPE = "app.bsky.embed.images"
const IMAGE_BLOCK_TYPE = "app.bsky.embed.images#image"
const MAX_IMAGES_PER_POST = 4
const DEFAULT_LANGUAGE_CODE = "en"

"""
    BlueSkyError(status, code, message)

Represents an error returned by a Bluesky Personal Data Server (PDS).
"""
struct BlueSkyError <: Exception
    status::Int
    code::Union{Nothing,String}
    message::String
end

function Base.showerror(io::IO, err::BlueSkyError)
    print(io, "BlueSkyError(", err.status)
    if err.code !== nothing
        print(io, ", code=$(err.code)")
    end
    print(io, "): ", err.message)
end

"""
    Session

Holds the authentication tokens returned by `com.atproto.server.createSession`.
"""
struct Session
    did::String
    handle::String
    access_jwt::String
    refresh_jwt::String
end

"""
    Client(; base_url=DEFAULT_BASE_URL)

Create a client configured for the given Personal Data Server base URL.
The URL may include `/xrpc`, but it is not required.
"""
mutable struct Client
    base_url::String
    session::Union{Nothing,Session}
end

Client(; base_url::AbstractString = DEFAULT_BASE_URL) = Client(_normalize_base_url(String(base_url)), nothing)

"""
    PostReference(uri, cid)

Lightweight reference to a record returned from `app.bsky.feed.post`.
"""
struct PostReference
    uri::String
    cid::String
end

"""
    login!(client; identifier, password, auth_factor_token=nothing) -> Session

Authenticate with the configured PDS using the account `identifier` (handle/email) and `password`.
Stores the resulting session on `client` and returns it.
"""
function login!(
    client::Client;
    identifier::AbstractString,
    password::AbstractString,
    auth_factor_token::Union{Nothing,AbstractString}=nothing,
)
    payload = Dict(
        "identifier" => String(identifier),
        "password" => String(password),
    )

    if auth_factor_token !== nothing
        payload["authFactorToken"] = String(auth_factor_token)
    end

    response = HTTP.request(
        "POST",
        _api_url(client, "com.atproto.server.createSession");
        headers=_json_headers(),
        body=JSON3.write(payload),
    )

    data = _handle_response(response)
    session = _decode_session(data)
    client.session = session
    return session
end

"""
    send_post(client, text; repo=nothing, langs=nothing, created_at=nothing, embed=nothing) -> PostReference

Send a text post to the authenticated account (or the `repo` DID/handle if supplied).
`langs` defaults to English and `created_at` defaults to the current UTC timestamp. Pass `embed`
to attach structures such as images.
"""
function send_post(
    client::Client,
    text::AbstractString;
    repo::Union{Nothing,AbstractString}=nothing,
    langs::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
    created_at::Union{Nothing,DateTime,AbstractString}=nothing,
    embed::Union{Nothing,Dict{String,Any}}=nothing,
)
    session = _require_session(client)
    repo_id = repo === nothing ? session.did : String(repo)
    record = _build_post_record(
        String(text),
        _coerce_timestamp(created_at),
        _coerce_langs(langs),
        embed,
    )

    payload = Dict(
        "repo" => repo_id,
        "collection" => FEED_COLLECTION,
        "record" => record,
    )

    response = HTTP.request(
        "POST",
        _api_url(client, "com.atproto.repo.createRecord");
        headers=_auth_headers(client),
        body=JSON3.write(payload),
    )

    data = _handle_response(response)
    return PostReference(String(data["uri"]), String(data["cid"]))
end

"""
    upload_blob(client, data; content_type=\"application/octet-stream\")

Upload binary data (image/video/etc.) and return the blob reference payload.
"""
function upload_blob(
    client::Client,
    data::Vector{UInt8};
    content_type::AbstractString="application/octet-stream",
)
    response = HTTP.request(
        "POST",
        _api_url(client, "com.atproto.repo.uploadBlob");
        headers=_auth_headers(client; content_type=String(content_type)),
        body=data,
    )

    return _handle_response(response)
end

"""
    send_image(client, text, image, alt; mime_type=\"image/jpeg\", kwargs...)

Upload a single image with ALT text and post it alongside `text`.
"""
function send_image(
    client::Client,
    text::AbstractString,
    image::AbstractVector{UInt8},
    alt::AbstractString;
    mime_type::AbstractString="image/jpeg",
    kwargs...,
)
    return send_images(
        client,
        text,
        [Vector{UInt8}(image)];
        alts=[String(alt)],
        mime_types=[String(mime_type)],
        kwargs...,
    )
end

"""
    send_images(client, text, images; alts=nothing, mime_types=nothing, kwargs...)

Upload up to four images (per AT Protocol limits) with optional ALT text array and mime types,
then post them alongside `text`.
"""
function send_images(
    client::Client,
    text::AbstractString,
    images::AbstractVector{<:AbstractVector{UInt8}};
    alts::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
    mime_types::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
    repo::Union{Nothing,AbstractString}=nothing,
    langs::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
    created_at::Union{Nothing,DateTime,AbstractString}=nothing,
)
    isempty(images) && throw(ArgumentError("At least one image is required."))
    length(images) > MAX_IMAGES_PER_POST &&
        throw(ArgumentError("The AT Protocol allows up to $MAX_IMAGES_PER_POST images per post."))

    normalized_alts = _normalize_alts(alts, length(images))
    normalized_mimes = _normalize_mime_types(mime_types, length(images))

    blobs = Vector{Any}(undef, length(images))
    for (idx, img) in enumerate(images)
        upload = upload_blob(client, Vector{UInt8}(img); content_type=normalized_mimes[idx])
        blobs[idx] = upload["blob"]
    end

    embed = _build_images_embed(blobs, normalized_alts)
    return send_post(
        client,
        text;
        repo=repo,
        langs=langs,
        created_at=created_at,
        embed=embed,
    )
end

function _decode_session(data)
    Session(
        String(data["did"]),
        String(data["handle"]),
        String(data["accessJwt"]),
        String(data["refreshJwt"]),
    )
end

function _normalize_base_url(url::AbstractString)
    stripped = strip(url)
    stripped = isempty(stripped) ? DEFAULT_BASE_URL : stripped
    endswith(stripped, "/xrpc") && return stripped
    return string(rstrip(stripped, '/'), "/xrpc")
end

_api_url(client::Client, nsid::AbstractString) = string(client.base_url, "/", nsid)

function _json_headers()
    Pair{String,String}[
        "Content-Type" => "application/json",
        "Accept" => "application/json",
    ]
end

function _auth_headers(client::Client; content_type::Union{Nothing,String}="application/json")
    session = _require_session(client)
    headers = Pair{String,String}[]
    if content_type !== nothing
        push!(headers, "Content-Type" => String(content_type))
    end
    push!(headers, "Accept" => "application/json")
    push!(headers, "Authorization" => "Bearer $(session.access_jwt)")
    return headers
end

function _require_session(client::Client)
    session = client.session
    session === nothing && throw(ArgumentError("Client is not authenticated. Call login! first."))
    return session
end

function _handle_response(response::HTTP.Messages.Response)
    if 200 <= response.status < 300
        return _parse_json_body(response.body)
    end

    parsed = _parse_json_body(response.body)
    code = haskey(parsed, "error") ? parsed["error"] : nothing
    code_str = code === nothing ? nothing : String(code)
    message = haskey(parsed, "message") ? parsed["message"] : "HTTP $(response.status) error"
    throw(BlueSkyError(response.status, code_str, String(message)))
end

function _parse_json_body(body)
    if body === nothing || length(body) == 0
        return Dict{String,Any}()
    end

    try
        return JSON3.read(body)
    catch _
        return Dict{String,Any}()
    end
end

function _coerce_timestamp(value::Union{Nothing,DateTime,AbstractString})
    if value === nothing
        return _timestamp_iso(Dates.now(Dates.UTC))
    elseif value isa DateTime
        return _timestamp_iso(value)
    else
        return String(value)
    end
end

_timestamp_iso(dt::DateTime) = Dates.format(dt, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")

function _coerce_langs(langs::Union{Nothing,AbstractVector{<:AbstractString}})
    if langs === nothing
        return String[DEFAULT_LANGUAGE_CODE]
    end

    return [String(lang) for lang in langs]
end

function _build_post_record(text::String, created_at::String, langs::Vector{String}, embed::Union{Nothing,Dict{String,Any}})
    record = Dict{String,Any}(
        "\$type" => FEED_COLLECTION,
        "text" => text,
        "createdAt" => created_at,
    )

    if !isempty(langs)
        record["langs"] = langs
    end

    if embed !== nothing
        record["embed"] = embed
    end

    return record
end

function _normalize_alts(alts::Union{Nothing,AbstractVector{<:AbstractString}}, count::Int)
    source = alts === nothing ? String[] : [String(a) for a in alts]
    diff = count - length(source)
    if diff > 0
        return vcat(source, fill("", diff))
    elseif diff < 0
        return source[1:count]
    end
    return source
end

function _normalize_mime_types(mime_types::Union{Nothing,AbstractVector{<:AbstractString}}, count::Int)
    source = mime_types === nothing ? String[] : [String(m) for m in mime_types]
    diff = count - length(source)
    defaults = fill("image/jpeg", max(diff, 0))
    if diff > 0
        return vcat(source, defaults)
    elseif diff < 0
        return source[1:count]
    end
    return isempty(source) ? fill("image/jpeg", count) : source
end

function _build_images_embed(blobs::AbstractVector, alts::Vector{String})
    length(blobs) == length(alts) || throw(ArgumentError("ALT count must match blob count."))
    images_payload = Vector{Dict{String,Any}}(undef, length(blobs))
    for (idx, blob) in enumerate(blobs)
        images_payload[idx] = Dict(
            "\$type" => IMAGE_BLOCK_TYPE,
            "alt" => alts[idx],
            "image" => blobs[idx],
        )
    end

    return Dict("images" => images_payload, "\$type" => IMAGES_EMBED_TYPE)
end

end # module BlueSkyClient
